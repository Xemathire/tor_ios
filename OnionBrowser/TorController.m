//
//  TorController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 9/5/12.
//
//

#import "TorController.h"
#import "NSData+Conversion.h"
#import "AppDelegate.h"
#import "Reachability.h"
#import "ALToastView.h"

@implementation TorController {
    int nbrFailedAttempts;
}

#define STATUS_CHECK_TIMEOUT 3.0f
#define MAX_FAILED_ATTEMPTS 20

@synthesize
didFirstConnect,
torControlPort = _torControlPort,
torSocksPort = _torSocksPort,
torThread = _torThread,
torCheckLoopTimer = _torCheckLoopTimer,
torStatusTimeoutTimer = _torStatusTimeoutTimer,
mSocket = _mSocket,
controllerIsAuthenticated = _controllerIsAuthenticated,
connectionStatus = _connectionStatus
;

-(id)init {
    if (self = [super init]) {
        _torControlPort = (arc4random() % (57343-49153)) + 49153;
        _torSocksPort = (arc4random() % (65534-57344)) + 57344;
        
        _controllerIsAuthenticated = NO;
        _connectionStatus = CONN_STATUS_NONE;
        
        nbrFailedAttempts = 0;
        
        // listen to changes in connection state
        // (tor has auto detection when external IP changes, but if we went
        //  offline, tor might not handle coming back gracefully -- we will SIGHUP
        //  on those)
        Reachability* reach = [Reachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        [reach startNotifier];
    }
    return self;
}

-(void)startTor {
    // Starts or restarts tor thread.
    
    if (_torCheckLoopTimer != nil) {
        [_torCheckLoopTimer invalidate];
    }
    if (_torStatusTimeoutTimer != nil) {
        [_torStatusTimeoutTimer invalidate];
    }
    if (_torThread != nil) {
        [_torThread cancel];
        _torThread = nil;
    }
    
    _torThread = [[TorWrapper alloc] init];
    [_torThread start];
    
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)stopTor {
    // [_mSocket writeString:@"SIGNAL SIGINT\n" encoding:NSUTF8StringEncoding];
    // [_mSocket writeString:@"SIGNAL SHUTDOWN\n" encoding:NSUTF8StringEncoding];
    // [_mSocket writeString:@"SIGNAL HALT\n" encoding:NSUTF8StringEncoding];
    [_mSocket writeString:@"sudo killall tor\n" encoding:NSUTF8StringEncoding];
}

- (void)rebootTor {
    if (_torThread != nil) {
        [_torThread cancel];
        _torThread = nil;
    }
    
    if (_mSocket) {
        [_mSocket close];
        _mSocket = nil;
    }
    
    if (_torCheckLoopTimer != nil) {
        [_torCheckLoopTimer invalidate];
    }
    if (_torStatusTimeoutTimer != nil) {
        [_torStatusTimeoutTimer invalidate];
    }
    
    nbrFailedAttempts = 0;
    
    [self startTor];
    [self performSelector:@selector(startTor) withObject:nil afterDelay:1.0];
}

- (void)hupTor {
    if (_torCheckLoopTimer != nil) {
        [_torCheckLoopTimer invalidate];
    }
    if (_torStatusTimeoutTimer != nil) {
        [_torStatusTimeoutTimer invalidate];
    }
    
    [_mSocket writeString:@"SIGNAL HUP\n" encoding:NSUTF8StringEncoding];
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)requestNewTorIdentity {
#ifdef DEBUG
    NSLog(@"[tor] Requesting new identity (SIGNAL NEWNYM)" );
#endif
    [_mSocket writeString:@"SIGNAL NEWNYM\n" encoding:NSUTF8StringEncoding];
}


#pragma mark -
#pragma mark App / connection status callbacks

- (void)reachabilityChanged {
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    
    if (reach.currentReachabilityStatus != NotReachable) {
#ifdef DEBUG
        NSLog(@"[tor] Reachability changed (now online), sending HUP" );
#endif
        [self hupTor];
    }
}

- (void)appWillEnterBackground {
    [self stopTor];
}

- (void)appDidEnterBackground {
    [self disableTorCheckLoop];
    nbrFailedAttempts = 0;
}

- (void)appDidBecomeActive {
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.25f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
    
    nbrFailedAttempts = 0;
    
    if (![_mSocket isConnected]) {
#ifdef DEBUG
        NSLog(@"[tor] Came back from background, sending HUP" );
#endif
        
        [self hupTor];
    }
}

#pragma mark -
#pragma mark Tor control port

- (void)activateTorCheckLoop {
#ifdef DEBUG
    NSLog(@"[tor] Checking Tor Control Port" );
#endif
    
    _controllerIsAuthenticated = NO;
    
    [ULINetSocket ignoreBrokenPipes];
    // Create a new ULINetSocket connected to the host. Since ULINetSocket is asynchronous, the socket is not
    // connected to the host until the delegate method is called.
    _mSocket = [ULINetSocket netsocketConnectedToHost:@"127.0.0.1" port:_torControlPort];
    
    // Schedule the ULINetSocket on the current runloop
    [_mSocket scheduleOnCurrentRunLoop];
    
    // Set the ULINetSocket's delegate to ourself
    [_mSocket setDelegate:self];
}

- (void)disableTorCheckLoop {
    // When in background, don't poll the Tor control port.
    [ULINetSocket ignoreBrokenPipes];
    
    [_mSocket close];
    _mSocket = nil;
    
    [_torCheckLoopTimer invalidate];
}

- (void)checkTor {
    if (!didFirstConnect) {
        // We haven't loaded a page yet, so we are checking against bootstrap first.
        [_mSocket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
    }
    else {
        // This is a "heartbeat" check, so we are checking our circuits.
        [_mSocket writeString:@"getinfo orconn-status\n" encoding:NSUTF8StringEncoding];
        if (_torStatusTimeoutTimer != nil) {
            [_torStatusTimeoutTimer invalidate];
        }
        _torStatusTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:STATUS_CHECK_TIMEOUT
                                                                  target:self
                                                                selector:@selector(checkTorStatusTimeout)
                                                                userInfo:nil
                                                                 repeats:NO];
    }
}

- (void)checkTorStatusTimeout {
    // Our orconn-status check didn't return before the alotted timeout.
    // (We're basically giving it STATUS_CHECK_TIMEOUT seconds -- default 1 sec
    // -- since this is a LOCAL port and LOCAL instance of tor, it should be
    // near instantaneous.)
    //
    // Fail: Restart Tor? (Maybe HUP?)
    // NSLog(@"[tor] checkTor timed out, attempting to restart tor");
    NSLog(@"[tor] checkTor timed out");
    // [self startTor];
    // [self hupTor];
}

- (void)netsocketConnected:(ULINetSocket *)inNetSocket {
    /* Authenticate on first control port connect */
#ifdef DEBUG
    NSLog(@"[tor] Control Port Connected" );
#endif
    
    NSData *torCookie = [_torThread readTorCookie];
    
    NSString *authMsg = [NSString stringWithFormat:@"authenticate %@\n", [torCookie hexadecimalString]];
    [_mSocket writeString:authMsg encoding:NSUTF8StringEncoding];
    
    _controllerIsAuthenticated = NO;
}

- (void)netsocketDisconnected:(ULINetSocket *)inNetSocket {
#ifdef DEBUG
    NSLog(@"[tor] Control Port Disconnected" );
#endif
    
    // Attempt to reconnect the netsocket
    if (nbrFailedAttempts <= MAX_FAILED_ATTEMPTS) {
        [self disableTorCheckLoop];
        [self activateTorCheckLoop];

        nbrFailedAttempts += didFirstConnect; // If didn't first connect, will remain at 0
    } else {
        //nbrFailedAttempts = 0;
        [self performSelectorOnMainThread:@selector(stopTor) withObject:nil waitUntilDone:YES];
        // [(AppDelegate *)[[UIApplication sharedApplication] delegate] restartTor];
    }
}

- (void)netsocket:(ULINetSocket*)inNetSocket dataAvailable:(unsigned)inAmount {
    NSString *newMsgIn = [_mSocket readString:NSUTF8StringEncoding];
    
    if (!_controllerIsAuthenticated) {
        // Response to AUTHENTICATE
        if ([newMsgIn hasPrefix:@"250"]) {
#ifdef DEBUG
            NSLog(@"[tor] Control Port Authenticated Successfully" );
#endif
            _controllerIsAuthenticated = YES;
            
            [_mSocket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
            _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
        else {
#ifdef DEBUG
            NSLog(@"[tor] Control Port: Got unknown post-authenticate message %@", _msgIn);
#endif
            // Could not authenticate with control port. This is the worst thing
            // that can happen on app init and should fail badly so that the
            // app does not just hang there.
            if (didFirstConnect) {
                // If we've already performed initial connect, wait a couple
                // seconds and try to HUP tor.
                if (_torCheckLoopTimer != nil) {
                    [_torCheckLoopTimer invalidate];
                }
                if (_torStatusTimeoutTimer != nil) {
                    [_torStatusTimeoutTimer invalidate];
                }
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:2.5f
                                                                      target:self
                                                                    selector:@selector(hupTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            } else {
                // Otherwise, crash because we don't know the app's current state
                // (since it hasn't totally initialized yet).
                // exit(0);
                AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

                [ALToastView toastInView:appDelegate.appWebView.view withText:@"Unknown Tor state, you may need to force quit & relaunch the app..." andBackgroundColor:[UIColor colorWithRed:1 green:0.231 blue:0.188 alpha:1] andDuration:3];
            }
        }
    } else if ([newMsgIn rangeOfString:@"-status/bootstrap-phase="].location != NSNotFound) {
        // Response to "getinfo status/bootstrap-phase"
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        if ([newMsgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
            _connectionStatus = CONN_STATUS_CONNECTED;
        }
        
        WebViewTab *wvc = appDelegate.appWebView.curWebViewTab;
        if (!didFirstConnect) {
            if ([newMsgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

                // This is our first go-around (haven't loaded page into webView yet)
                // but we are now at 100%, so go ahead.
                if (appDelegate.startUrl != nil) {
                    [wvc askToLoadURL:appDelegate.startUrl];
                } else {
                    /* Load saved state */
                    if ([userDefaults boolForKey:@"save_state_on_close"] && [[appDelegate appWebView] restoreFromSavedState]) {
                        [ALToastView toastInView:appDelegate.appWebView.view withText:@"Saved tabs restored"];
                    } else {
                        // Didn't launch with a "theonionbrowser://" or "theonionbrowsers://" URL, or failed to restore tabs
                        // so just launch the regular home page.
                        [wvc loadURL:[NSURL URLWithString:@"theonionbrowser:home"]];
                    }
                }
                didFirstConnect = YES;
                
                // See "checkTor call in middle of app" a little bit below.
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:3.0f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
                
                // Check if the tutorial should be displayed
                if ([userDefaults stringForKey:@"app_version_number"] == nil || [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] compare:[userDefaults stringForKey:@"app_version_number"] options:NSNumericSearch] == NSOrderedDescending) {
                    // If the stored version number is strictly less than the current version, show tutorial
                    [userDefaults setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] forKey:@"app_version_number"];
                    [userDefaults synchronize];
                    
                    [appDelegate.appWebView showTutorial];
                } else
                    [ALToastView toastInView:appDelegate.appWebView.view withText:@"Initializing Tor circuit...\nFirst page load may be slow to start." andDuration:5];
            } else {
                // Haven't done initial load yet and still waiting on bootstrap, so
                // render status.
                
                if (_msgIn == NULL)
                    _msgIn = newMsgIn;
                
                [wvc renderTorStatus:@[newMsgIn, _msgIn]];
                _msgIn = newMsgIn;
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            }
        }
    } else if ([newMsgIn rangeOfString:@"+orconn-status="].location != NSNotFound) {
        [_torStatusTimeoutTimer invalidate];
        
        // Response to "getinfo orconn-status"
        // This is a response to a "checkTor" call in the middle of our app.
        if ([newMsgIn rangeOfString:@"250 OK"].location == NSNotFound) {
            // Bad stuff! Should HUP since this means we can still talk to
            // Tor, but Tor is having issues with it's onion routing connections.
            NSLog(@"[tor] Control Port: orconn-status: NOT OK\n    %@",
                  [newMsgIn
                   stringByReplacingOccurrencesOfString:@"\n"
                   withString:@"\n    "]
                  );
            
            [self hupTor];
        } else {
#ifdef DEBUG
            NSLog(@"[tor] Control Port: orconn-status: OK");
#endif
            _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
    }
}

- (void)netsocketDataSent:(ULINetSocket*)inNetSocket { }


@end
