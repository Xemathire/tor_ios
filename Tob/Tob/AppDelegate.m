//
//  AppDelegate.m
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import "AppDelegate.h"
#include <Openssl/sha.h>
#import "Bridge.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import <sys/utsname.h>
#import "BridgeViewController.h"
#import "JFMinimalNotification.h"
#import "iRate.h"
#include <arpa/inet.h>

@interface AppDelegate ()
- (Boolean)torrcExists;
- (void)afterFirstRun;
@end

@implementation AppDelegate

@synthesize
sslWhitelistedDomains,
startUrl,
tor = _tor,
window = _window,
tabsViewController,
logViewController,
managedObjectContext = __managedObjectContext,
managedObjectModel = __managedObjectModel,
persistentStoreCoordinator = __persistentStoreCoordinator,
doPrepopulateBookmarks
;

+ (void)initialize
{
    [iRate sharedInstance].onlyPromptIfLatestVersion = NO;
    [iRate sharedInstance].eventsUntilPrompt = 10;
    [iRate sharedInstance].daysUntilPrompt = 5;
    
    // Set these values because of the different bundle ID for this version
    // [iRate sharedInstance].appStoreID = 1063151782;
    // [iRate sharedInstance].applicationBundleID = @"com.JustKodding.TheOnionBrowser";
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // Detect bookmarks file.
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];
    NSString *oldVersionPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    oldVersionPath = [oldVersionPath stringByAppendingPathComponent:@"bookmarks.plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    doPrepopulateBookmarks = (![fileManager fileExistsAtPath:[storeURL path]]) || [fileManager fileExistsAtPath:oldVersionPath];
    
    [self getSettings];
    
    /* Tell iOS to encrypt everything in the app's sandboxed storage. */
    [self updateFileEncryption];
    // Repeat encryption every 15 seconds, to catch new caches, cookies, etc.
    [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(updateFileEncryption) userInfo:nil repeats:YES];
    //[self performSelector:@selector(testEncrypt) withObject:nil afterDelay:8];
    
    /*********** WebKit options **********/
    // http://objectiveself.com/post/84817251648/uiwebviews-hidden-properties
    // https://git.chromium.org/gitweb/?p=external/WebKit_trimmed.git;a=blob;f=Source/WebKit/mac/WebView/WebPreferences.mm;h=2c25b05ef6a73f478df9b0b7d21563f19aa85de4;hb=9756e26ef45303401c378036dff40c447c2f9401
    // Block JS if we are on "Block All" mode.
    /* TODO: disabled for now, since Content-Security-Policy handles this (and this setting
     * requires app restart to take effect)
     NSInteger blockingSetting = [[settings valueForKey:@"javascript"] integerValue];
     if (blockingSetting == CONTENTPOLICY_STRICT) {
     [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitJavaScriptEnabled"];
     [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitJavaScriptEnabledPreferenceKey"];
     } else {
     [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WebKitJavaScriptEnabled"];
     [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WebKitJavaScriptEnabledPreferenceKey"];
     }
     */
    
    // Always disable multimedia (Tor leak)
    // TODO: These don't seem to have any effect on the QuickTime player appearing (and transfering
    //       data outside of Tor). Work-in-progress.
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitAVFoundationEnabledKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitWebAudioEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitWebAudioEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitQTKitEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitQTKitEnabledPreferenceKey"];
    
    // Always disable localstorage & databases
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDatabasesEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDatabasesEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitLocalStorageEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitLocalStorageEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebKitLocalStorageDatabasePath"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebKitLocalStorageDatabasePathPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebDatabaseDirectory"];
    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"WebKitStorageBlockingPolicy"];
    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"WebKitStorageBlockingPolicyKey"];
    
    // Always disable caches
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitUsesPageCache"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitUsesPageCachePreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitPageCacheSupportsPlugins"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitPageCacheSupportsPluginsPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitOfflineWebApplicationCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitOfflineWebApplicationCacheEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDiskImageCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebKitLocalCache"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    /*********** /WebKit options **********/
    
    // Wipe all cookies & caches from previous invocations of app (in case we didn't wipe
    // cleanly upon exit last time)
    [self wipeAppData];
    
    /* Used to save app state when the app is crashing */
    NSSetUncaughtExceptionHandler(&HandleException);
    
    struct sigaction signalAction;
    memset(&signalAction, 0, sizeof(signalAction));
    signalAction.sa_handler = &HandleSignal;
    
    sigaction(SIGABRT, &signalAction, NULL);
    sigaction(SIGILL, &signalAction, NULL);
    sigaction(SIGBUS, &signalAction, NULL);
    
    logViewController = [[LogViewController alloc] init];
    tabsViewController = [[TabsViewController alloc] init];
    tabsViewController.restorationIdentifier = @"WebViewController";
    
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _window.rootViewController = tabsViewController;
    [_window makeKeyAndVisible];
    
    // OLD IOS SECURITY WARNINGS
    if ([[[UIDevice currentDevice] systemVersion] compare:@"8.2" options:NSNumericSearch] == NSOrderedAscending) {
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Outdated iOS Warning", nil) message:NSLocalizedString(@"You are running a version of iOS that may use weak HTTPS encryption; iOS 8.2 contains a fix for this issue.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self startup2];
        }]];
        
        if (alert) {
            [_window.rootViewController presentViewController:alert animated:YES completion:NULL];
        } else {
            JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleDefault title:NSLocalizedString(@"Outdated iOS Warning", nil) subTitle:NSLocalizedString(@"You are running a version of iOS that may use weak HTTPS encryption; iOS 8.2 contains a fix for this issue.", nil) dismissalDelay:10.0];
            minimalNotification.layer.zPosition = MAXFLOAT;
            [_window.rootViewController.view addSubview:minimalNotification];
            [minimalNotification show];
            
            [self startup2];
        }
    } else {
        [self startup2];
    }
    
    return YES;
}

-(void) startup2 {
    if (![self torrcExists] && ![self isRunningTests]) {
        UIAlertController *alert2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Welcome to Tob", nil) message:NSLocalizedString(@"If you are in a location that blocks connections to Tor, you may configure bridges before trying to connect for the first time.", nil) preferredStyle:UIAlertControllerStyleAlert];
        
        [alert2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Connect to Tor", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self afterFirstRun];
        }]];
        [alert2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Configure Bridges", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            BridgeViewController *bridgesVC = [[BridgeViewController alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
            navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            [_window.rootViewController presentViewController:navController animated:YES completion:nil];
        }]];
        [_window.rootViewController presentViewController:alert2 animated:YES completion:NULL];
    } else {
        [self afterFirstRun];
    }
    
    sslWhitelistedDomains = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *settings = self.getSettings;
    NSInteger cookieSetting = [[settings valueForKey:@"cookies"] integerValue];
    if (cookieSetting == COOKIES_ALLOW_ALL) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    } else if (cookieSetting == COOKIES_BLOCK_THIRDPARTY) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
    } else if (cookieSetting == COOKIES_BLOCK_ALL) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
    }
    
    // Start the spinner for the "connecting..." phase
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    /*******************/
    // Clear any previous caches/cookies
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
}

-(void) afterFirstRun {
    [self updateTorrc];
    _tor = [[TorController alloc] init];
    [_tor startTor];
}


#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Settings" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             NSFileProtectionComplete, NSFileProtectionKey,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return __persistentStoreCoordinator;
}

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

void HandleException(NSException *exception) {
    // Save state on crash if the user chose to
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if ([[appDelegate.getSettings valueForKey:@"save-app-state"] boolValue]) {
        [[(AppDelegate *)[[UIApplication sharedApplication] delegate] tabsViewController] saveAppState];
    }
}

void HandleSignal(int signal) {
    // Save state on crash if the user chose to
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if ([[appDelegate.getSettings valueForKey:@"save-app-state"] boolValue]) {
        [[(AppDelegate *)[[UIApplication sharedApplication] delegate] tabsViewController] saveAppState];
    }
}


#pragma mark - App lifecycle

- (void)applicationWillResignActive:(UIApplication *)application {
    [_tor disableTorCheckLoop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (!_tor.didFirstConnect) {
        // User is trying to quit app before we have finished initial
        // connection. This is basically an "abort" situation because
        // backgrounding while Tor is attempting to connect will almost
        // definitely result in a hung Tor client. Quit the app entirely,
        // since this is also a good way to allow user to retry initial
        // connection if it fails.
#ifdef DEBUG
        NSLog(@"Went to BG before initial connection completed: exiting.");
#endif
        exit(0);
    } else {
        [tabsViewController saveAppState];
        [_tor disableTorCheckLoop];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    _window.hidden = NO;
    
    // Don't want to call "activateTorCheckLoop" directly since we
    // want to HUP tor first.
    [_tor appDidBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Wipe all cookies & caches on the way out.
    [tabsViewController saveAppState];
    [self wipeAppData];
    _window.hidden = YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSString *urlStr = [url absoluteString];
    NSURL *newUrl = nil;
    
#ifdef DEBUG
    NSLog(@"Received URL: %@", urlStr);
#endif
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    BOOL appIsTob = [bundleIdentifier isEqualToString:@"com.JustKodding.Tob"];
    BOOL srcIsTob = (appIsTob && [sourceApplication isEqualToString:bundleIdentifier]);
    
    if (appIsTob && [urlStr hasPrefix:@"tob:/"]) {
        // HTTP
        urlStr = [urlStr stringByReplacingCharactersInRange:NSMakeRange(0, 14) withString:@"http:/"];
#ifdef DEBUG
        NSLog(@" -> %@", urlStr);
#endif
        newUrl = [NSURL URLWithString:urlStr];
    } else if (appIsTob && [urlStr hasPrefix:@"tobs:/"]) {
        // HTTPS
        urlStr = [urlStr stringByReplacingCharactersInRange:NSMakeRange(0, 15) withString:@"https:/"];
#ifdef DEBUG
        NSLog(@" -> %@", urlStr);
#endif
        newUrl = [NSURL URLWithString:urlStr];
    } else {
        return YES;
    }
    if (newUrl == nil) {
        return YES;
    }
    
    if ([_tor didFirstConnect]) {
        if (srcIsTob) {
            [tabsViewController loadURL:newUrl];
        } else {
            [tabsViewController askToLoadURL:newUrl];
        }
    } else {
#ifdef DEBUG
        NSLog(@" -> have not yet connected to tor, deferring load");
#endif
        startUrl = newUrl;
    }
    return YES;
}


#pragma mark App helpers

- (NSUInteger) deviceType{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    
#ifdef DEBUG
    NSLog(@"%@", platform);
#endif
    
    if (([platform rangeOfString:@"iPhone"].location != NSNotFound)||([platform rangeOfString:@"iPod"].location != NSNotFound)) {
        return 0;
    } else if ([platform rangeOfString:@"iPad"].location != NSNotFound) {
        return 1;
    } else {
        return 2;
    }
}

- (Boolean)torrcExists {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *destTorrc = [[[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"torrc"] relativePath];
    return [fileManager fileExistsAtPath:destTorrc];
}

- (void)updateTorrc {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *destTorrc = [[[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"torrc"] relativePath];
    if ([fileManager fileExistsAtPath:destTorrc]) {
        [fileManager removeItemAtPath:destTorrc error:NULL];
    }
    NSString *sourceTorrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    NSError *error = nil;
    [fileManager copyItemAtPath:sourceTorrc toPath:destTorrc error:&error];
    if (error != nil) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        if (![fileManager fileExistsAtPath:sourceTorrc]) {
            NSLog(@"(Source torrc %@ doesnt exist)", sourceTorrc);
        }
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];
    
    error = nil;
    NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (mutableFetchResults == nil) {
        
    } else if ([mutableFetchResults count] > 0) {
        NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:destTorrc];
        [myHandle seekToEndOfFile];
        
        [myHandle writeData:[@"UseBridges 1\n" dataUsingEncoding:NSUTF8StringEncoding]];
        for (Bridge *bridge in mutableFetchResults) {
            [myHandle writeData:[[NSString stringWithFormat:@"bridge %@\n", bridge.conf] dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    // Encrypt the new torrc (since this "running" copy of torrc may now contain bridges)
    NSDictionary *f_options = [NSDictionary dictionaryWithObjectsAndKeys:
                               NSFileProtectionCompleteUnlessOpen, NSFileProtectionKey, nil];
    [fileManager setAttributes:f_options ofItemAtPath:destTorrc error:nil];
}

- (void)wipeAppData {
    [[self tabsViewController] stopLoading];
    
    /* This is probably incredibly redundant since we just delete all the files, below */
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    
    /* Delete all Caches, Cookies, Preferences in app's "Library" data dir. (Connection settings
     * & etc end up in "Documents", not "Library".) */
    NSArray *dataPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if ((dataPaths != nil) && ([dataPaths count] > 0)) {
        NSString *dataDir = [dataPaths objectAtIndex:0];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        if ((dataDir != nil) && [fm fileExistsAtPath:dataDir isDirectory:nil]){
            NSString *cookiesDir = [NSString stringWithFormat:@"%@/Cookies", dataDir];
            if ([fm fileExistsAtPath:cookiesDir isDirectory:nil]){
                [fm removeItemAtPath:cookiesDir error:nil];
            }
            
            NSString *cachesDir = [NSString stringWithFormat:@"%@/Caches", dataDir];
            if ([fm fileExistsAtPath:cachesDir isDirectory:nil]){
                [fm removeItemAtPath:cachesDir error:nil];
            }
            
            NSString *prefsDir = [NSString stringWithFormat:@"%@/Preferences", dataDir];
            if ([fm fileExistsAtPath:prefsDir isDirectory:nil]){
                [fm removeItemAtPath:prefsDir error:nil];
            }
            
            NSString *wkDir = [NSString stringWithFormat:@"%@/WebKit", dataDir];
            if ([fm fileExistsAtPath:wkDir isDirectory:nil]){
                [fm removeItemAtPath:wkDir error:nil];
            }
        }
    } // TODO: otherwise, WTF
}

- (Boolean)isRunningTests {
    NSDictionary* environment = [ [ NSProcessInfo processInfo ] environment ];
    NSString* theTestConfigPath = environment[ @"XCTestConfigurationFilePath" ];
    return theTestConfigPath != nil;
}


- (NSString *)settingsFile {
    return [[[self applicationDocumentsDirectory] path] stringByAppendingPathComponent:@"Settings.plist"];
}

- (NSMutableDictionary *)getSettings {
    NSPropertyListFormat format;
    NSMutableDictionary *d;
    
    NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:self.settingsFile];
    if (plistXML == nil) {
        // We didn't have a settings file, so we'll want to initialize one now.
        d = [NSMutableDictionary dictionary];
    } else {
        d = (NSMutableDictionary *)[NSPropertyListSerialization propertyListWithData:plistXML options:NSPropertyListMutableContainersAndLeaves format:&format error:nil];
    }
    
    // SETTINGS DEFAULTS
    // we do this here in case the user has an old version of the settings file and we've
    // added new keys to settings. (or if they have no settings file and we're initializing
    // from a blank slate.)
    Boolean update = NO;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([d objectForKey:@"homepage"] == nil) {
        [d setObject:@"https://duckduckgo.com" forKey:@"homepage"]; // DEFAULT HOMEPAGE
        update = YES;
    }
    if ([d objectForKey:@"cookies"] == nil) {
        [d setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_THIRDPARTY] forKey:@"cookies"];
        update = YES;
    }
    if ([d objectForKey:@"uaspoof"] == nil || [[d objectForKey:@"uaspoof"] integerValue] == UA_SPOOF_UNSET || [userDefaults objectForKey:@"ua_agent"]) {
        /* Convert from old settings or initialize */
        if ([[userDefaults objectForKey:@"ua_agent"] isEqualToString:@"UA_SPOOF_SAFARI_MAC"])
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_SAFARI_MAC] forKey:@"uaspoof"];
        else if ([[userDefaults objectForKey:@"ua_agent"] isEqualToString:@"UA_SPOOF_IPHONE"])
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPHONE] forKey:@"uaspoof"];
        else if ([[userDefaults objectForKey:@"ua_agent"] isEqualToString:@"UA_SPOOF_IPAD"])
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPAD] forKey:@"uaspoof"];
        else if ([[userDefaults objectForKey:@"ua_agent"] isEqualToString:@"UA_SPOOF_WIN7_TORBROWSER"])
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_WIN7_TORBROWSER] forKey:@"uaspoof"];
        else {
            if (IS_IPAD)
                [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPAD] forKey:@"uaspoof"];
            else
                [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPHONE] forKey:@"uaspoof"];
        }
        update = YES;
    }
    if ([d objectForKey:@"dnt"] == nil || [userDefaults objectForKey:@"send_dnt"]) {
        if ([userDefaults objectForKey:@"send_dnt"] && [[userDefaults objectForKey:@"send_dnt"] boolValue]  == false)
            [d setObject:[NSNumber numberWithInteger:DNT_HEADER_CANTRACK] forKey:@"dnt"];
        else
            [d setObject:[NSNumber numberWithInteger:DNT_HEADER_NOTRACK] forKey:@"dnt"];
        update = YES;
    }
    if ([d objectForKey:@"tlsver"] == nil || [userDefaults objectForKey:@"min_tls_version"]) {
        if ([[userDefaults objectForKey:@"min_tls_version"] isEqualToString:@"1.2"])
            [d setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1_2_ONLY] forKey:@"tlsver"];
        else
            [d setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1] forKey:@"tlsver"];
        update = YES;
    }
    if ([d objectForKey:@"javascript"] == nil || [userDefaults objectForKey:@"content_policy"]) { // for historical reasons, CSP setting is named "javascript"
        if ([[userDefaults objectForKey:@"content_policy"] isEqualToString:@"open"])
            [d setObject:[NSNumber numberWithInteger:CONTENTPOLICY_PERMISSIVE] forKey:@"javascript"];
        else if ([[userDefaults objectForKey:@"content_policy"] isEqualToString:@"strict"])
            [d setObject:[NSNumber numberWithInteger:CONTENTPOLICY_STRICT] forKey:@"javascript"];
        else
            [d setObject:[NSNumber numberWithInteger:CONTENTPOLICY_BLOCK_CONNECT] forKey:@"javascript"];
        update = YES;
    }
    if ([d objectForKey:@"javascript-toggle"] == nil) {
        [d setObject:[NSNumber numberWithInteger:JS_NO_PREFERENCE] forKey:@"javascript-toggle"];
        update = YES;
    }
    if ([d objectForKey:@"save-app-state"] == nil || [userDefaults objectForKey:@"save_state_on_close"]) {
        if ([userDefaults objectForKey:@"save_state_on_close"] && [[userDefaults objectForKey:@"save_state_on_close"] boolValue] == false)
            [d setObject:[NSNumber numberWithBool:false] forKey:@"save-app-state"];
        else
            [d setObject:[NSNumber numberWithBool:true] forKey:@"save-app-state"];
        update = YES;
    }
    if ([d objectForKey:@"search-engine"] == nil || [userDefaults objectForKey:@"search_engine"]) {
        if ([[userDefaults objectForKey:@"search_engine"] isEqualToString:@"Google"])
            [d setObject:@"Google" forKey:@"search-engine"];
        else
            [d setObject:@"DuckDuckGo" forKey:@"search-engine"];
        update = YES;
    }
    if ([d objectForKey:@"night-mode"] == nil || [userDefaults objectForKey:@"dark_interface"]) {
        if ([userDefaults objectForKey:@"dark_interface"] && [[userDefaults objectForKey:@"dark_interface"] boolValue]== true)
            [d setObject:[NSNumber numberWithBool:true] forKey:@"night-mode"];
        else
            [d setObject:[NSNumber numberWithBool:false] forKey:@"night-mode"];
        update = YES;
    }
    
    if (update) {
        [self saveSettings:d];
        NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    }
    // END SETTINGS DEFAULTS
    
    return d;
}

- (void)saveSettings:(NSMutableDictionary *)settings {
    NSError *error;
    NSData *data =
    [NSPropertyListSerialization dataWithPropertyList:settings
                                               format:NSPropertyListXMLFormat_v1_0
                                              options:0
                                                error:&error];
    if (data == nil) {
        NSLog (@"error serializing to xml: %@", error);
        return;
    } else {
        NSUInteger fileOption = NSDataWritingAtomic | NSDataWritingFileProtectionComplete;
        [data writeToFile:self.settingsFile options:fileOption error:nil];
    }
}

- (NSString *)homepage {
    NSMutableDictionary *d = self.getSettings;
    return [d objectForKey:@"homepage"];
}



#ifdef DEBUG
- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application {
    NSLog(@"app data encrypted");
}
- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application {
    NSLog(@"data decrypted, now available");
}
#endif

- (void)updateFileEncryption {
    /* This will traverse the app's sandboxed storage directory and add the NSFileProtectionCompleteUnlessOpen flag
     * to every file encountered.
     *
     * NOTE: the NSFileProtectionKey setting doesn't have any effect on iOS Simulator OR if user does not
     * have a passcode, since the OS-level encryption relies on the iOS physical device as per
     * https://ssl.apple.com/ipad/business/docs/iOS_Security_Feb14.pdf .
     *
     * To test data encryption:
     *   1 compile and run on your own device (with a passcode)
     *   2 open app, allow app to finish loading, configure app, etc.
     *   3 close app, wait a few seconds for it to sleep, force-quit app
     *   4 open XCode organizer (command-shift-2), go to device, go to Applications, select Tob app
     *   5 click "download"
     *   6 open the xcappdata directory you saved, look for Documents/Settings.plist, etc
     *   - THEN: unlock device, open app, and try steps 4-6 again with the app open & device unlocked.
     *   - THEN: comment out "fileManager setAttributes" line below and test steps 1-6 again.
     *
     * In cases where data is encrypted, the "xcappdata" download received will not contain the encrypted data files
     * (though some lock files and sqlite journal files are kept). If data is not encrypted, the download will contain
     * all files pertinent to the app.
     */
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *dirs = [NSArray arrayWithObjects:
                     [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@".."],
                     [[NSBundle mainBundle] bundleURL],
                     [self applicationDocumentsDirectory],
                     [NSURL URLWithString:NSTemporaryDirectory()],
                     nil
                     ];
    
    for (NSURL *bundleURL in dirs) {
        
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:bundleURL
                                              includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey, NSURLIsHiddenKey]
                                                                 options:0
                                                            errorHandler:^(NSURL *url, NSError *error) {
                                                                // ignore errors
                                                                return YES;
                                                            }];
        
        // NOTE: doNotEncryptAttribute is only up in here because for some versions of Onion
        //       Browser we were encrypting even Tob.app, which possibly caused
        //       the app to become invisible. so we'll manually set anything inside executable
        //       app to be unencrypted (because it will never store user data, it's just
        //       *our* bundle.)
        NSDictionary *fullEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                              NSFileProtectionComplete, NSFileProtectionKey, nil];
        // allow Tor-related files to be read by the app even when in the background. helps
        // let Tor come back from sleep.
        NSDictionary *torEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                             NSFileProtectionCompleteUnlessOpen, NSFileProtectionKey, nil];
        NSDictionary *doNotEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                               NSFileProtectionNone, NSFileProtectionKey, nil];
        
        NSString *appDir = [[[[NSBundle mainBundle] bundleURL] absoluteString] stringByReplacingOccurrencesOfString:@"/private/var/" withString:@"/var/"];
        NSString *tmpDirStr = [[[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", NSTemporaryDirectory()]] absoluteString] stringByReplacingOccurrencesOfString:@"/private/var/" withString:@"/var/"];
        
#ifdef DEBUG
        // NSLog(@"%@", appDir);
#endif
        
        for (NSURL *fileURL in enumerator) {
            NSNumber *isDirectory;
            NSString *filePath = [[fileURL absoluteString] stringByReplacingOccurrencesOfString:@"/private/var/" withString:@"/var/"];
            [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            
            if (![isDirectory boolValue]) {
                // Directories can't be set to "encrypt"
                if ([filePath hasPrefix:appDir]) {
                    // Don't encrypt the Tob.app directory, because otherwise
                    // the system will sometimes lose visibility of the app. (We're re-setting
                    // the "NSFileProtectionNone" attribute because prev versions of Tob
                    // may have screwed this up.)
#ifdef DEBUG
                    // NSLog(@"NO: %@", filePath);
#endif
                    [fileManager setAttributes:doNotEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
                } else if (
                           [filePath rangeOfString:@"torrc"].location == NSNotFound ||
                           [filePath hasPrefix:[NSString stringWithFormat:@"%@cached-certs", tmpDirStr]] ||
                           [filePath hasPrefix:[NSString stringWithFormat:@"%@cached-microdesc", tmpDirStr]] ||
                           [filePath hasPrefix:[NSString stringWithFormat:@"%@control_auth_cookie", tmpDirStr]] ||
                           [filePath hasPrefix:[NSString stringWithFormat:@"%@lock", tmpDirStr]] ||
                           [filePath hasPrefix:[NSString stringWithFormat:@"%@state", tmpDirStr]] ||
                           [filePath hasPrefix:[NSString stringWithFormat:@"%@tor", tmpDirStr]]
                           ) {
                    // Tor related files should be encrypted, but allowed to stay open
                    // if app was open & device locks.
#ifdef DEBUG
                    // NSLog(@"TOR ENCRYPT: %@", filePath);
#endif
                    [fileManager setAttributes:torEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
                } else {
                    // Full encrypt. This is a file (not a directory) that was generated on the user's device
                    // (not part of our .app bundle).
#ifdef DEBUG
                    // NSLog(@"FULL ENCRYPT: %@", filePath);
#endif
                    [fileManager setAttributes:fullEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
                }
            }
        }
    }
}
/*
 - (void)testEncrypt {
 
 NSURL *settingsPlist = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.plist"];
 //NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];
 NSLog(@"protected data available: %@",[[UIApplication sharedApplication] isProtectedDataAvailable] ? @"yes" : @"no");
 
 NSError *error;
 
 NSString *test = [NSString stringWithContentsOfFile:[settingsPlist path]
 encoding:NSUTF8StringEncoding
 error:NULL];
 NSLog(@"file contents: %@\nerror: %@", test, error);
 }
 */


- (NSString *)javascriptInjection {
    NSMutableString *str = [[NSMutableString alloc] init];
    
    Byte uaspoof = [[self.getSettings valueForKey:@"uaspoof"] integerValue];
    if (uaspoof == UA_SPOOF_SAFARI_MAC) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/600.1.17 (KHTML, like Gecko) Version/7.1 Safari/537.85.10';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'MacIntel';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/600.1.17 (KHTML, like Gecko) Version/7.1 Safari/537.85.10';});"];
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Windows)';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'Win32';});"];
        [str appendString:@"navigator.__defineGetter__('language',function(){return 'en-US';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Windows NT 6.1; rv:24.0) Gecko/20100101 Firefox/24.0';});"];
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPhone; CPU iPhone OS 8_0_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12A405 Safari/600.1.4';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPhone';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPhone; CPU iPhone OS 8_0_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12A405 Safari/600.1.4';});"];
    } else if (uaspoof == UA_SPOOF_IPAD) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPad; CPU OS 8_0_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12A405 Safari/600.1.4';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPad';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPad; CPU OS 8_0_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12A405 Safari/600.1.4';});"];
    }
    
    Byte activeContent = [[self.getSettings valueForKey:@"javascript"] integerValue];
    if (activeContent != CONTENTPOLICY_PERMISSIVE) {
        [str appendString:@"function Worker(){};"];
        [str appendString:@"function WebSocket(){};"];
        [str appendString:@"function sessionStorage(){};"];
        [str appendString:@"function localStorage(){};"];
        [str appendString:@"function globalStorage(){};"];
        [str appendString:@"function openDatabase(){};"];
    }
    return str;
}
- (NSString *)customUserAgent {
    Byte uaspoof = [[self.getSettings valueForKey:@"uaspoof"] integerValue];
    if (uaspoof == UA_SPOOF_SAFARI_MAC) {
        return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/600.1.17 (KHTML, like Gecko) Version/7.1 Safari/537.85.10";
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        return @"Mozilla/5.0 (Windows NT 6.1; rv:24.0) Gecko/20100101 Firefox/24.0";
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        return @"Mozilla/5.0 (iPhone; CPU iPhone OS 8_0_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12A405 Safari/600.1.4";
    } else if (uaspoof == UA_SPOOF_IPAD) {
        return @"Mozilla/5.0 (iPad; CPU OS 8_0_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12A405 Safari/600.1.4";
    }
    return nil;
}

@end
