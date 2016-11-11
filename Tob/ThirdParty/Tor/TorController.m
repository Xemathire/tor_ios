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
#import <QuartzCore/QuartzCore.h>

@implementation TorController {
    int nbrFailedAttempts;
}

#define STATUS_CHECK_TIMEOUT 3.0f
#define TOR_STATUS_WAIT 1.0f
#define MAX_FAILED_ATTEMPTS 10

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
    if (self=[super init]) {
        _torControlPort = (arc4random() % (57343-49153)) + 49153;
        _torSocksPort = (arc4random() % (65534-57344)) + 57344;
        
        _controllerIsAuthenticated = NO;
        _connectionStatus = CONN_STATUS_NONE;
        
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

- (void)requestTorInfo {
#ifdef DEBUG
    NSLog(@"[tor] Requesting Tor info (getinfo orconn-status)" );
#endif
    // getinfo orconn-status: not the user's IP
    // getinfo circuit-status: not the user's IP
    // entry-guards: not the user's IP
    [_mSocket writeString:@"getinfo circuit-status\n" encoding:NSUTF8StringEncoding];
}

- (void)requestNewTorIdentity {
#ifdef DEBUG
    NSLog(@"[tor] Requesting new identity (SIGNAL NEWNYM)" );
#endif
    [_mSocket writeString:@"SIGNAL NEWNYM\n" encoding:NSUTF8StringEncoding];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.logViewController logInfo:@"[tor] Requesting new identity"];
}


#pragma mark -
#pragma mark App / connection status callbacks

- (void)reachabilityChanged {
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    
    if (reach.currentReachabilityStatus != NotReachable) {
#ifdef DEBUG
        NSLog(@"[tor] Reachability changed (now online), sending HUP" );
#endif
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.logViewController logInfo:@"[tor] Reachability changed (now online)"];
        [self hupTor];
    }
}


- (void)appDidEnterBackground {
    [self disableTorCheckLoop];
    nbrFailedAttempts = 0;
}

- (void)appDidBecomeActive {
    nbrFailedAttempts = 0;
    
    if (![_mSocket isConnected]) {
        [_mSocket writeString:@"SIGNAL HUP\n" encoding:NSUTF8StringEncoding];
    }
#ifdef DEBUG
    NSLog(@"[tor] Came back from background, trying to talk to Tor again" );
#endif
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.logViewController logInfo:@"[tor] Came back from background, trying to talk to Tor again"];

    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.25f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
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
    NSLog(@"[tor] checkTor timed out, attempting to restart tor");
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.logViewController logInfo:@"[tor] checkTor timed out, attempting to restart tor"];
    //[self startTor];
    [self hupTor];
}

- (void) disableNetwork {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [[appDelegate tabsViewController] stopLoading];
    [[appDelegate tabsViewController] setTabsNeedForceRefresh:YES];
    [_mSocket writeString:@"setconf disablenetwork=1\n" encoding:NSUTF8StringEncoding];
    [appDelegate.logViewController logInfo:@"[tor] DisableNetwork is set. Tor will not make or accept non-control network connections. Shutting down all existing connections."];
}

- (void) enableNetwork {
    [_mSocket writeString:@"setconf disablenetwork=0\n" encoding:NSUTF8StringEncoding];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [[appDelegate tabsViewController] refreshCurrentTab];
    [appDelegate.logViewController logInfo:@"[tor] Received reload signal (hup). Reloading config and resetting internal state."];
}


- (void)netsocketConnected:(ULINetSocket*)inNetSocket {
    /* Authenticate on first control port connect */
#ifdef DEBUG
    NSLog(@"[tor] Control Port Connected" );
#endif
    NSData *torCookie = [_torThread readTorCookie];
    
    NSString *authMsg = [NSString stringWithFormat:@"authenticate %@\n",
                         [torCookie hexadecimalString]];
    [_mSocket writeString:authMsg encoding:NSUTF8StringEncoding];
    
    _controllerIsAuthenticated = NO;
}


- (void)netsocketDisconnected:(ULINetSocket*)inNetSocket {
#ifdef DEBUG
    NSLog(@"[tor] Control Port Disconnected" );
#endif
    
    // Attempt to reconnect the netsocket
    if (nbrFailedAttempts <= MAX_FAILED_ATTEMPTS) {
        [self disableTorCheckLoop];
        // [self activateTorCheckLoop];
        [self performSelector:@selector(activateTorCheckLoop) withObject:nil afterDelay:0.5];
        nbrFailedAttempts += didFirstConnect; // If didn't first connect, will remain at 0
    }
}

- (void)netsocket:(ULINetSocket*)inNetSocket dataAvailable:(unsigned)inAmount {
    NSString *msgIn = [_mSocket readString:NSUTF8StringEncoding];
    
    if (!_controllerIsAuthenticated) {
        // Response to AUTHENTICATE
        if ([msgIn hasPrefix:@"250"]) {
#ifdef DEBUG
            NSLog(@"[tor] Control Port Authenticated Successfully" );
#endif
            
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate.logViewController logInfo:@"[tor] Control Port Authenticated Successfully"];
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
            NSLog(@"[tor] Control Port: Got unknown post-authenticate message %@", msgIn);
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
#warning crash removed
                // exit(0);
            }
        }
    } else if ([msgIn rangeOfString:@"-status/bootstrap-phase="].location != NSNotFound) {
        // Response to "getinfo status/bootstrap-phase"
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        
        if ([msgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
            _connectionStatus = CONN_STATUS_CONNECTED;
        }
        
        TabsViewController *tvc = appDelegate.tabsViewController;
        if (!didFirstConnect) {
            if ([msgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
                // This is our first go-around (haven't loaded page into webView yet)
                // but we are now at 100%, so go ahead.
                didFirstConnect = YES;
                
                [tvc renderTorStatus:msgIn];
                
                JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleDefault title:NSLocalizedString(@"Initializing Tor circuit…", nil) subTitle:NSLocalizedString(@"First page load may be slow to start.", nil) dismissalDelay:4.0];
                minimalNotification.layer.zPosition = MAXFLOAT;
                [tvc.view addSubview:minimalNotification];
                [minimalNotification show];
                
                // See "checkTor call in middle of app" a little bit below.
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            } else {
                // Haven't done initial load yet and still waiting on bootstrap, so
                // render status.
                [tvc renderTorStatus:msgIn];
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:TOR_STATUS_WAIT
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            }
        }
    } else if ([msgIn rangeOfString:@"orconn-status="].location != NSNotFound) {
        [_torStatusTimeoutTimer invalidate];
        // Response to "getinfo orconn-status"
        // This is a response to a "checkTor" call in the middle of our app.
        if ([msgIn rangeOfString:@"250 OK"].location == NSNotFound) {
            // Bad stuff! Should HUP since this means we can still talk to
            // Tor, but Tor is having issues with it's onion routing connections.
            NSLog(@"[tor] Control Port: orconn-status: NOT OK\n    %@",
                  [msgIn
                   stringByReplacingOccurrencesOfString:@"\n"
                   withString:@"\n    "]
                  );
            
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate.logViewController logInfo:[NSString stringWithFormat:@"[tor] Control Port: orconn-status: NOT OK\n    %@", [msgIn stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "]]];

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
    /*
    else if ([msgIn rangeOfString:@"entry-guards="].location != NSNotFound) {
        NSMutableArray *guards = [[msgIn componentsSeparatedByString: @"\r\n"] mutableCopy];
        
        if ([guards count] > 1) {
            // If the value is correct, the first object should be "250+entry-guards="
            // The next ones should be "$<ID>~<NAME> <STATUS>"
            [guards removeObjectAtIndex:0];
            
            for (NSString *exit in guards) {
                NSRange r1 = [exit rangeOfString:@"$"];
                NSRange r2 = [exit rangeOfString:@"~"];
                NSRange idRange = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
                
                if (r1.location != NSNotFound && r2.location != NSNotFound && idRange.location != NSNotFound) {
                    NSString *exitID = [exit substringWithRange:idRange];
                    NSLog(@"exitID (up): %@", exitID);
                    
                    // Get IP for the current exit
                    [_mSocket writeString:[NSString stringWithFormat:@"getinfo ns/id/%@\n", exitID] encoding:NSUTF8StringEncoding];
                }
            }
        }
    } 
     */    
    else if ([msgIn rangeOfString:@"circuit-status="].location != NSNotFound) {
        NSMutableArray *guards = [[msgIn componentsSeparatedByString: @"\r\n"] mutableCopy];
        
        if ([guards count] > 1) {
            // If the value is correct, the first object should be "250+entry-guards="
            // The next ones should be "$<ID>~<NAME> <STATUS>"
            [guards removeObjectAtIndex:0];
            
            for (NSString *exit in guards) {
                NSRange r1 = [exit rangeOfString:@"$"];
                NSRange r2 = [exit rangeOfString:@"~"];
                NSRange idRange = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
                
                if (r1.location != NSNotFound && r2.location != NSNotFound && idRange.location != NSNotFound) {
                    NSString *exitID = [exit substringWithRange:idRange];
                    NSLog(@"exitID: %@", exitID);
                    
                    // Get IP for the current exit
                    [_mSocket writeString:[NSString stringWithFormat:@"getinfo ns/id/%@\n", exitID] encoding:NSUTF8StringEncoding];
                }
            }
        }
    } else if ([msgIn rangeOfString:@"ns/id/"].location != NSNotFound) {
        // getinfo ip-to-country/216.66.24.2
        // Multiple results can be received at the same time
        NSArray *requests = [msgIn componentsSeparatedByString:@"250+ns/id/"];
        
        for (NSString *msg in requests) {
            NSMutableArray *infoArray = [[msg componentsSeparatedByString: @"\r\n"] mutableCopy];
            
            if ([infoArray count] > 1) {
                // Format should be "<NAME> C3ZsrjOVPuRpCX2dprynFoY/jrQ awageVh+KgvJYAgPcG5kruCcJPo <TIME> <IP> 9001 9030"
                // e.g. "Iroha C3ZsrjOVPuRpCX2dprynFoY/jrQ awageVh+KgvJYAgPcG5kruCcJPo 2016-05-22 05:04:19 185.21.217.32 9001 9030"
                
                NSString *infoString = [infoArray objectAtIndex:1];
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" options:NSRegularExpressionCaseInsensitive error:nil];
                
                NSArray* matches = [regex matchesInString:infoString
                                                  options:0
                                                    range:NSMakeRange(0, [infoString length])];
                for (NSTextCheckingResult *match in matches) {
                    NSLog(@"IP: %@", [infoString substringWithRange:[match rangeAtIndex:0]]);
                }
                
            }
        }
    } else {
        NSLog(@"msgIn: %@", msgIn);
    }
}

- (void)netsocketDataSent:(ULINetSocket*)inNetSocket { }


@end
