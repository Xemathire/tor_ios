/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"
#import "BookmarkController.h"
#import "SSLCertificateViewController.h"
#import "WebViewController.h"
#import "WebViewTab.h"
#import "WebViewMenuController.h"
#import "WYPopoverController.h"
#import "EAIntroView.h"
#import "URLInterceptor.h"

@implementation WebViewController {
    AppDelegate *appDelegate;
    
    UIScrollView *tabScroller;
    UIPageControl *tabChooser;
    int curTabIndex;
    NSMutableArray *webViewTabs;
    
    UIView *toolbar;
    UIButton *lockIcon;
    UIButton *brokenLockIcon;
    UIProgressView *progressBar;
    UIToolbar *tabToolbar;
    UILabel *tabCount;
    UITextField *urlField;
    int keyboardHeight;
    
    UIButton *backButton;
    UIButton *forwardButton;
    UIButton *tabsButton;
    UIButton *settingsButton;
    
    UIBarButtonItem *tabAddButton;
    UIBarButtonItem *tabDoneButton;
    UIButton *addButton;
    UIButton *doneButton;
    
    float lastWebViewScrollOffset;
    CGRect origTabScrollerFrame;
    BOOL webViewScrollIsDecelerating;
    BOOL webViewScrollIsDragging;
    BOOL shouldHideStatusBar;
    BOOL hasBlur;
    
    WYPopoverController *popover;
    
    BookmarkController *bookmarks;
    
    CGPoint originalPoint;
    CGPoint panGestureOriginPoint;
    int panGestureRecognizerType; // 0: None, 1: Remove tab, 2: Change page
    
    UIPanGestureRecognizer *tabSelectionPanGestureRecognizer;
}

@synthesize showingTabs;

- (void)loadView
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate setAppWebView:self];
    
    UIWebView *twv = [[UIWebView alloc] initWithFrame:CGRectZero];
    [appDelegate setDefaultUserAgent:[twv stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"]];
    twv = nil;
    
    webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];
    curTabIndex = 0;
    
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].applicationFrame.size.width, [UIScreen mainScreen].applicationFrame.size.height)];
    
    tabScroller = [[UIScrollView alloc] init];
    [tabScroller setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [[self view] addSubview:tabScroller];
    
    toolbar = [[UIView alloc] init];
    [toolbar setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [toolbar setClipsToBounds:YES];
    [[self view] addSubview:toolbar];
    
    self.toolbarOnBottom = [userDefaults boolForKey:@"toolbar_on_bottom"];
    self.darkInterface = [userDefaults boolForKey:@"dark_interface"];

    keyboardHeight = 0;
    
    progressBar = [[UIProgressView alloc] init];
    [progressBar setTrackTintColor:[UIColor clearColor]];
    [progressBar setTintColor:self.view.window.tintColor];
    [progressBar setProgress:0.0];
    [toolbar addSubview:progressBar];
    
    backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *backImage = [[UIImage imageNamed:@"back"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [backButton setImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:backButton];
        
    forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *forwardImage = [[UIImage imageNamed:@"forward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [forwardButton setImage:forwardImage forState:UIControlStateNormal];
    [forwardButton addTarget:self action:@selector(goForward:) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:forwardButton];
    
    urlField = [[UITextField alloc] init];
    [urlField setBorderStyle:UITextBorderStyleRoundedRect];
    [urlField setKeyboardType:UIKeyboardTypeWebSearch];
    [urlField setFont:[UIFont systemFontOfSize:15]];
    [urlField setReturnKeyType:UIReturnKeyGo];
    [urlField setClearButtonMode:UITextFieldViewModeWhileEditing];
    [urlField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    [urlField setLeftViewMode:UITextFieldViewModeAlways];
    [urlField setSpellCheckingType:UITextSpellCheckingTypeNo];
    [urlField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [urlField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [urlField setPlaceholder:@"URL or query"];
    [urlField setDelegate:self];
    [toolbar addSubview:urlField];
    
    lockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
    [lockIcon setFrame:CGRectMake(0, 0, 24, 16)];
    [lockIcon setImage:[[UIImage imageNamed:@"lock"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [[lockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
    [lockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];
    
    brokenLockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
    [brokenLockIcon setFrame:CGRectMake(0, 0, 24, 16)];
    [brokenLockIcon setImage:[[UIImage imageNamed:@"broken_lock"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [[brokenLockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
    [brokenLockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];
    
    tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *tabsImage = [[UIImage imageNamed:@"tabs"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [tabsButton setImage:tabsImage forState:UIControlStateNormal];
    [tabsButton setTintColor:[progressBar tintColor]];
    [tabsButton addTarget:self action:@selector(showTabs:) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:tabsButton];
    
    tabCount = [[UILabel alloc] init];
    [tabCount setText:@""];
    [tabCount setTextAlignment:NSTextAlignmentCenter];
    [tabCount setFont:[UIFont systemFontOfSize:11]];
    [tabCount setTextColor:[progressBar tintColor]];
    [toolbar addSubview:tabCount];
    
    settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *settingsImage = [[UIImage imageNamed:@"settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [settingsButton setImage:settingsImage forState:UIControlStateNormal];
    [settingsButton setTintColor:[progressBar tintColor]];
    [settingsButton addTarget:self action:@selector(showPopover:) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:settingsButton];
    
    [tabScroller setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
    [tabScroller setAutoresizesSubviews:NO];
    [tabScroller setShowsHorizontalScrollIndicator:NO];
    [tabScroller setShowsVerticalScrollIndicator:NO];
    [tabScroller setScrollsToTop:NO];
    [tabScroller setDelaysContentTouches:NO];
    [tabScroller setDelegate:self];
    
    tabChooser = [[UIPageControl alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - TOOLBAR_HEIGHT - 12, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    [tabChooser setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin)];
    [tabChooser addTarget:self action:@selector(slideToCurrentTab:) forControlEvents:UIControlEventValueChanged];
    [tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
    [tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];
    [tabChooser setNumberOfPages:0];
    [self.view insertSubview:tabChooser aboveSubview:toolbar];
    [tabChooser setHidden:true];
    [tabChooser addTarget:self action:@selector(touchedPageControlDot:) forControlEvents:UIControlEventTouchUpInside];
    
    tabToolbar = [[UIToolbar alloc] init];
    [tabToolbar setClipsToBounds:YES];
    [tabToolbar setBackgroundImage:[UIImage new]
                forToolbarPosition:UIToolbarPositionAny
                        barMetrics:UIBarMetricsDefault];
    
    [tabToolbar setBackgroundColor:[UIColor clearColor]];
    [tabToolbar setHidden:true];
    [self.view insertSubview:tabToolbar aboveSubview:toolbar];
    
    // Create custom button with + symbol and blur
    //addButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.5f, 30.0f, 30.0f)]; // 0.5f because the eye always thinks the cross isn't centered when using integers as position values
    addButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 30.0f)];
    addButton.titleLabel.font = [UIFont fontWithName:@"Helvetica-Light" size:28.0f];
    [addButton setTitle:@"＋" forState:UIControlStateNormal];
    [addButton setTitleColor:self.view.tintColor forState:UIControlStateNormal];
    [addButton setTitleColor:[UIColor colorWithRed:190.0/255 green:215.0/255 blue:243.0/255 alpha:1.0] forState:UIControlStateHighlighted];
    [addButton addTarget:self action:@selector(addNewTabFromToolbar:) forControlEvents:UIControlEventTouchUpInside];
    
    // Create custom done button
    doneButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 35.0f, 30.0f)];
    [doneButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16.0f]];
    [doneButton setTitle:@"OK" forState:UIControlStateNormal];
    [doneButton setTitleColor:self.view.tintColor forState:UIControlStateNormal];
    [doneButton setTitleColor:[UIColor colorWithRed:190.0/255 green:215.0/255 blue:243.0/255 alpha:1.0] forState:UIControlStateHighlighted];
    [doneButton addTarget:self action:@selector(doneWithTabsButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // Add blur
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    UIVisualEffectView *addEffectView = [[UIVisualEffectView alloc] initWithEffect:blur];
    [addEffectView setAlpha:1];
    addEffectView.frame = CGRectMake(0.0 , 0.0f, 30.0f, 30.0f);
    addEffectView.layer.cornerRadius = 5.0;
    addEffectView.clipsToBounds = YES;
    
    UIVisualEffectView *doneEffectView = [[UIVisualEffectView alloc] initWithEffect:blur];
    [doneEffectView setAlpha:1];
    doneEffectView.frame = CGRectMake(0.0 , 0.0f, 35.0f, 30.0f);
    doneEffectView.layer.cornerRadius = 5.0;
    doneEffectView.clipsToBounds = YES;
    
    [addEffectView addSubview:addButton];
    [doneEffectView addSubview:doneButton];
    
    if (!addEffectView || ! doneEffectView) {
        // Blur isn't supported or something went wrong: just add the plain buttons.
        tabAddButton = [[UIBarButtonItem alloc] initWithCustomView:addButton];
        tabDoneButton = [[UIBarButtonItem alloc] initWithCustomView:doneButton];
        hasBlur = NO;
    } else {
        tabAddButton = [[UIBarButtonItem alloc] initWithCustomView:addEffectView];
        tabDoneButton = [[UIBarButtonItem alloc] initWithCustomView:doneEffectView];
        hasBlur = YES;
    }
    
    tabToolbar.items = [NSArray arrayWithObjects:
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
                        tabAddButton,
                        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
                        tabDoneButton,
                        nil];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [self adjustLayoutToSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height + STATUSBAR_HEIGHT)];
    [self updateSearchBarDetails];
    
    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
    shouldHideStatusBar = NO; // Only hide it when closing a tab
    
    [self.view.window makeKeyAndVisible];
}

- (id)settingsButton
{
    return settingsButton;
}

- (BOOL)prefersStatusBarHidden
{
    return shouldHideStatusBar;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)saveCurrentState {
    if (webViewTabs && webViewTabs.count > 0) {        
        NSMutableArray *wvtd = [[NSMutableArray alloc] initWithCapacity:webViewTabs.count - 1];
        for (WebViewTab *wvt in webViewTabs) {
            if (wvt.url == nil)
                continue;
                        
            [wvtd addObject:@{@"url" : wvt.url, @"title" : wvt.title.text}];
        }
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"savedCoder.txt"];
        
        NSMutableArray *dataArray = [NSMutableArray array];
        [dataArray addObject:wvtd];
        [dataArray addObject:[NSNumber numberWithInt:curTabIndex]];
        
        [NSKeyedArchiver archiveRootObject:dataArray toFile:appFile];
        
        // Successfully saved state
        return YES;
    }
    
    // Failed to save state
    return NO;
}

- (BOOL)restoreFromSavedState {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"savedCoder.txt"];
    NSMutableArray *dataArray = [NSKeyedUnarchiver unarchiveObjectWithFile:appFile];
    
    // [dataArray count] should be > 1 because we save the current tab index
    // dataArray[0] is the array containing the tabs to restore
    if (dataArray && [dataArray count] > 1 && [dataArray[0] count] > 0) {
        [self animateAllTabsRemoval];
        [self decodeRestorableStateWithArray:dataArray];
        
        // Successfully restored state, return yes
        return YES;
    }
    
    // Faile to restore state, return no
    return NO;
}

- (void)decodeRestorableStateWithArray:(NSArray *)dataArray
{
    NSMutableArray *wvt = dataArray[0];
    for (int i = 0; i < wvt.count; i++) {
        NSDictionary *params = wvt[i];
        if ([params objectForKey:@"url"]) {
            WebViewTab *wvt = [self addNewTabForURL:[params objectForKey:@"url"] forRestoration:YES withCompletionBlock:nil];
            [[wvt title] setText:[params objectForKey:@"title"]];
        } else {
            [self addNewTabForURL:nil forRestoration:YES withCompletionBlock:nil];
        }
    }
    
    NSNumber *cp = dataArray[1];
    if (cp != nil) {
        if ([cp intValue] <= [webViewTabs count] - 1)
            [self setCurTabIndex:[cp intValue]];
        
        [tabScroller setContentOffset:CGPointMake([self frameForTabIndex:tabChooser.currentPage].origin.x, 0) animated:NO];
        
        /* wait for the UI to catch up */
        [[self curWebViewTab] performSelector:@selector(forceRefresh) withObject:nil afterDelay:0.5];
        [[self curWebViewTab] setNeedsForceRefresh:NO];
    }
    
    [self updateSearchBarDetails];

    if (showingTabs) {
        [self performSelectorOnMainThread:@selector(showTabsWithCompletionBlock:) withObject:nil waitUntilDone:YES];
    }
}

/*
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    
    [self saveCurrentState];
}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
}
*/

- (void)viewDidAppear:(BOOL)animated
{
    
    [super viewDidAppear:animated];
    /* we made it this far, remove lock on previous startup */
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
    [userDefaults synchronize];
    
    [self viewIsVisible];
}

/* called when we've become visible (possibly again, from app delegate applicationDidBecomeActive) */
- (void)viewIsVisible
{
    if (webViewTabs.count == 0) {
        NSString *startingString = [NSString stringWithFormat:@"<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Starting Tor</title><style>div{position: fixed;width: 98%%;top: 15%%;left: 1%%;right: 1%%;margin: 10px;}p {text-align: center;font-family: sans-serif;font-size: 5vw;font-style: normal;}.title {font-size: 6vw;}</style></head><body><div><p class=\"title\">Starting Tor</p><p>The Onion Browser will be redirected shortly, please wait…<br/>After 20 seconds, please force quit the app and relaunch.</p></div></body></html>"];
        
        [self addNewTabForURL:nil];
        [self.curWebViewTab.webView loadHTMLString:startingString baseURL:[NSURL URLWithString:@"Starting..."]];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardStart = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect keyboardEnd = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    /* on devices with a bluetooth keyboard attached, both values should be the same for a 0 height */
    keyboardHeight = keyboardStart.origin.y - keyboardEnd.origin.y;
    
    [self adjustLayoutToSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    keyboardHeight = 0;
    [self adjustLayoutToSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (showingTabs) {
            /* not sure why, but the transition looks nicer to do these linearly rather than adjusting layout in a completion block to ending tab showing */
            [self showTabsWithCompletionBlock:nil];
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self adjustLayoutToSize:size];
        [self updateSearchBarDetails];
    }];
}

- (void)adjustLayoutToSize:(CGSize)size
{
    self.view.frame = CGRectMake(0, 0, size.width, size.height);
    float y = ((TOOLBAR_HEIGHT - TOOLBAR_BUTTON_SIZE) / 2);
    float statusBarHeight = STATUSBAR_HEIGHT * ![[UIApplication sharedApplication] isStatusBarHidden];
    
    if (self.toolbarOnBottom)
        toolbar.frame = tabToolbar.frame = CGRectMake(0, size.height - TOOLBAR_HEIGHT - keyboardHeight, size.width, TOOLBAR_HEIGHT + keyboardHeight);
    else
        toolbar.frame = tabToolbar.frame = CGRectMake(0, statusBarHeight, size.width, TOOLBAR_HEIGHT);
    
    backButton.frame = CGRectMake(TOOLBAR_PADDING_LEFT, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
    forwardButton.frame = CGRectMake(backButton.frame.origin.x + backButton.frame.size.width + TOOLBAR_PADDING_LEFT, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
    
    settingsButton.frame = CGRectMake(size.width - backButton.frame.size.width - TOOLBAR_PADDING_RIGHT, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
    tabsButton.frame = CGRectMake(settingsButton.frame.origin.x - backButton.frame.size.width - TOOLBAR_PADDING_RIGHT, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
    
    tabCount.frame = CGRectMake(tabsButton.frame.origin.x + 6, tabsButton.frame.origin.y + 12, 14, 10);
    urlField.frame = [self frameForUrlField];
    
    if (self.toolbarOnBottom) {
        progressBar.frame = CGRectMake(0, 0, toolbar.frame.size.width, 2);
        tabChooser.frame = CGRectMake(0, size.height - 24 - TOOLBAR_HEIGHT, size.width, 24);
    }
    else {
        progressBar.frame = CGRectMake(0, toolbar.frame.size.height - 2, toolbar.frame.size.width, 2);
        tabChooser.frame = CGRectMake(0, size.height - 24, size.width, 24);
    }
    
    if (self.darkInterface) {
        [self.view setBackgroundColor:[UIColor darkGrayColor]];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        
        [tabScroller setBackgroundColor:[UIColor darkGrayColor]];
        [tabToolbar setBarTintColor:[UIColor grayColor]];
        [toolbar setBackgroundColor:[UIColor darkGrayColor]];
        [urlField setBackgroundColor:[UIColor grayColor]];
        
        [doneButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateNormal];
        [addButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateNormal];

        if (hasBlur) {
            [doneButton setBackgroundColor:[UIColor grayColor]];
            [addButton setBackgroundColor:[UIColor grayColor]];
        }
        
        [settingsButton setTintColor:[UIColor lightTextColor]];
        [backButton setTintColor:[UIColor lightTextColor]];
        [forwardButton setTintColor:[UIColor lightTextColor]];
        [tabsButton setTintColor:[UIColor lightTextColor]];
        [tabCount setTextColor:[UIColor lightTextColor]];
        [lockIcon setTintColor:[UIColor blackColor]];
        [brokenLockIcon setTintColor:[UIColor blackColor]];
        
        [tabChooser setPageIndicatorTintColor:[UIColor lightGrayColor]];
        [tabChooser setCurrentPageIndicatorTintColor:[UIColor whiteColor]];
    }
    else {
        [self.view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
        
        [tabScroller setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
        [tabToolbar setBarTintColor:[UIColor groupTableViewBackgroundColor]];
        [toolbar setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
        [urlField setBackgroundColor:[UIColor whiteColor]];
        
        [doneButton setTitleColor:[progressBar tintColor] forState:UIControlStateNormal];
        [doneButton setBackgroundColor:[UIColor clearColor]];
        [addButton setTitleColor:[progressBar tintColor] forState:UIControlStateNormal];
        [addButton setBackgroundColor:[UIColor clearColor]];
        
        [settingsButton setTintColor:[progressBar tintColor]];
        [backButton setTintColor:[progressBar tintColor]];
        [forwardButton setTintColor:[progressBar tintColor]];
        [tabsButton setTintColor:[progressBar tintColor]];
        [tabCount setTextColor:[progressBar tintColor]];
        [lockIcon setTintColor:[UIColor lightGrayColor]];
        [brokenLockIcon setTintColor:[UIColor lightGrayColor]];
        
        [tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
        [tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];
    }

    tabScroller.frame = CGRectMake(0, 0, size.width, size.height);
    
    for (int i = 0; i < webViewTabs.count; i++) {
        WebViewTab *wvt = webViewTabs[i];
        [wvt updateFrame:[self frameForTabIndex:i withSize:CGSizeMake(size.width, size.height - statusBarHeight)]];
    }
    
    tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, size.height);
    [tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
    
    [self.view setNeedsDisplay];
}

- (CGRect)frameForTabIndex:(NSUInteger)number
{
    return [self frameForTabIndex:number withSize:CGSizeMake(0, 0)];
}

- (CGRect)frameForTabIndex:(NSUInteger)number withSize:(CGSize)size
{
    float screenWidth = size.width, screenHeight = size.height;
    
    if (size.width == 0) {
        screenWidth = [UIScreen mainScreen].applicationFrame.size.width;
        screenHeight = [UIScreen mainScreen].applicationFrame.size.height;
    }
    
    float statusBarHeight = STATUSBAR_HEIGHT * ![[UIApplication sharedApplication] isStatusBarHidden];

    if (self.toolbarOnBottom)
        return CGRectMake((screenWidth * number), statusBarHeight, screenWidth, screenHeight - TOOLBAR_HEIGHT);
    else
        return CGRectMake((screenWidth * number), TOOLBAR_HEIGHT + statusBarHeight, screenWidth, screenHeight - TOOLBAR_HEIGHT);
}

- (CGRect)frameForUrlField
{
    float x = forwardButton.frame.origin.x + forwardButton.frame.size.width + TOOLBAR_PADDING_LEFT;
    float y = (TOOLBAR_HEIGHT - tabsButton.frame.size.height) / 2;
    float w = tabsButton.frame.origin.x - TOOLBAR_PADDING_RIGHT - forwardButton.frame.origin.x - forwardButton.frame.size.width - TOOLBAR_PADDING_RIGHT;
    float h = tabsButton.frame.size.height;
    
    if (backButton.hidden || [urlField isFirstResponder]) {
        x -= backButton.frame.size.width + TOOLBAR_PADDING_LEFT;
        w += backButton.frame.size.width + TOOLBAR_PADDING_LEFT;
    }
    
    if (forwardButton.hidden || [urlField isFirstResponder]) {
        x -= forwardButton.frame.size.width + TOOLBAR_PADDING_LEFT;
        w += forwardButton.frame.size.width + TOOLBAR_PADDING_LEFT;
    }
    
    return CGRectMake(x, y, w, h);
}

- (NSMutableArray *)webViewTabs
{
    return webViewTabs;
}

- (__strong WebViewTab *)curWebViewTab
{
    if (webViewTabs.count > 0)
        return webViewTabs[curTabIndex];
    else
        return nil;
}

- (void)setCurTabIndex:(int)tab
{
    if (curTabIndex == tab)
        return;
    
    curTabIndex = tab;
    tabChooser.currentPage = tab;
    
    for (int i = 0; i < webViewTabs.count; i++) {
        WebViewTab *wvt = [webViewTabs objectAtIndex:i];
        [[[wvt webView] scrollView] setScrollsToTop:(i == tab)];
    }
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url
{
    return [self addNewTabForURL:url forRestoration:NO withCompletionBlock:nil];
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration withCompletionBlock:(void(^)(BOOL))block
{
    WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] withRestorationIdentifier:(restoration ? [url absoluteString] : nil)];
    [wvt.webView.scrollView setDelegate:self];
    
    [webViewTabs addObject:wvt];
    [tabChooser setNumberOfPages:webViewTabs.count];
    [wvt setTabIndex:[NSNumber numberWithLong:(webViewTabs.count - 1)]];
    
    [tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];
    
    [tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
    [tabScroller addSubview:wvt.viewHolder];
    [tabScroller bringSubviewToFront:toolbar];
    
    if (showingTabs)
        [wvt zoomOut];
    
    void (^swapToTab)(BOOL) = ^(BOOL finished) {
        [self setCurTabIndex:(int)webViewTabs.count - 1];
        
        [self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
            if (url != nil)
                [wvt loadURL:url];
            
            [self showTabsWithCompletionBlock:block];
        }];
    };
    
    if (!restoration) {
        /* animate zooming out (if not already), switching to the new tab, then zoom back in */
        if (showingTabs) {
            swapToTab(YES);
        }
        else if (webViewTabs.count > 1) {
            [self showTabsWithCompletionBlock:swapToTab];
        }
        else if (url != nil) {
            [wvt loadURL:url];
        }
    } else {
        if (url != nil) {
            // Don't load the urls, as the current tab's url will be loaded later and we don't want to load the other ones to avoid using bandwidth
            [wvt setUrl:url];
            [wvt setNeedsForceRefresh:YES];
        }
    }
    
    // Add a pan gesture recognizer for "two finger to change tab"
    // NOTE: not using an edge recognizer to control the edge's side, as the regular one is too small for 2 fingers and makes the feature hard to use
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerDrag:)];
    [panGestureRecognizer setMinimumNumberOfTouches:2];
    [panGestureRecognizer setMaximumNumberOfTouches:2];
    [panGestureRecognizer setDelegate:self];
    [wvt.viewHolder addGestureRecognizer:panGestureRecognizer];
    
    return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
    id urlFieldBlock = urlField;
    [self addNewTabForURL:nil forRestoration:NO withCompletionBlock:^(BOOL finished) {
        [urlFieldBlock becomeFirstResponder];
    }];
}

- (void)removeWithoutFocusingTab:(NSNumber *)tabNumber {
    [self removeTab:tabNumber andFocusTab:[NSNumber numberWithInt:-2]];
}

- (void)removeTab:(NSNumber *)tabNumber
{
    [self removeTab:tabNumber andFocusTab:[NSNumber numberWithInt:-1]];
}

- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus
{
    if (tabNumber.intValue > [webViewTabs count] - 1)
        return;
    
    WebViewTab *wvt = (WebViewTab *)webViewTabs[tabNumber.intValue];
    
#ifdef TRACE
    NSLog(@"removing tab %@ (%@) and focusing %@", tabNumber, wvt.title.text, toFocus);
#endif
    int futureFocusNumber = toFocus.intValue;
    if (futureFocusNumber > -1) {
        if (futureFocusNumber == tabNumber.intValue) {
            futureFocusNumber = -1;
        }
        else if (futureFocusNumber > tabNumber.intValue) {
            futureFocusNumber--;
        }
    }
    
    long wvtHash = [wvt hash];
    [[wvt viewHolder] removeFromSuperview];
    [webViewTabs removeObjectAtIndex:tabNumber.intValue];
    [wvt close];
    wvt = nil;
    
    [[appDelegate cookieJar] clearNonWhitelistedDataForTab:wvtHash];
    
    [tabChooser setNumberOfPages:webViewTabs.count];
    [tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];
    
    if (futureFocusNumber == -1 || futureFocusNumber == -2) {
        if (curTabIndex == tabNumber.intValue) {
            if (webViewTabs.count > tabNumber.intValue && webViewTabs[tabNumber.intValue]) {
                /* keep currentPage pointing at the page that shifted down to here */
            }
            else if (tabNumber.intValue > 0 && webViewTabs[tabNumber.intValue - 1]) {
                /* removed last tab, keep the previous one */
                [self setCurTabIndex:tabNumber.intValue - 1];
            }
            else {
                /* no tabs left, add one and zoom out */
                id urlFieldBlock = urlField;
                [self addNewTabForURL:nil forRestoration:false withCompletionBlock:^(BOOL finished) {
                    [urlFieldBlock becomeFirstResponder];
                }];
                return;
            }
        }
    }
    else {
        [self setCurTabIndex:futureFocusNumber];
    }
    
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        tabScroller.contentSize = CGSizeMake(self.view.frame.size.width * tabChooser.numberOfPages, self.view.frame.size.height);
        
        for (int i = 0; i < webViewTabs.count; i++) {
            WebViewTab *wvt = webViewTabs[i];
            
            wvt.viewHolder.transform = CGAffineTransformIdentity;
            wvt.viewHolder.frame = [self frameForTabIndex:i];
            wvt.viewHolder.transform = CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE);
        }
    } completion:^(BOOL finished) {
        if (futureFocusNumber != -2) {
            [self setCurTabIndex:curTabIndex];
            
            [self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
                showingTabs = true;
                [self showTabs:nil];
            }];
        }
    }];
}

- (void)removeAllTabs
{
    curTabIndex = 0;
    
    for (int i = 0; i < webViewTabs.count; i++) {
        WebViewTab *wvt = (WebViewTab *)webViewTabs[i];
        [[wvt viewHolder] removeFromSuperview];
        [wvt close];
    }
    
    [webViewTabs removeAllObjects];
    [tabChooser setNumberOfPages:0];
    
    [self updateSearchBarDetails];
}

- (void)animateAllTabsRemoval {
    if (!showingTabs) {
        [self performSelectorOnMainThread:@selector(showTabsWithCompletionBlock:) withObject:nil waitUntilDone:YES];
    }
    
    [self removeAllTabs];
}

- (void)updateSearchBarDetails
{
    /* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */
    
    if (urlField.isFirstResponder) {
        /* focused, don't muck with the URL while it's being edited */
        [urlField setTextAlignment:NSTextAlignmentNatural];
        [urlField setTextColor:[UIColor darkTextColor]];
        [urlField setLeftView:nil];
    } else {
        [urlField setTextAlignment:NSTextAlignmentCenter];
        [urlField setTextColor:[UIColor darkTextColor]];
        
        BOOL isEV = NO;
                
        if (self.curWebViewTab && self.curWebViewTab.secureMode >= WebViewTabSecureModeSecure) {
            [urlField setLeftView:lockIcon];
            if (self.curWebViewTab.secureMode == WebViewTabSecureModeSecureEV) {
                // wait until the page is done loading
                if ([progressBar progress] >= 1.0) {
                    [urlField setTextColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];
                    
                    if ([self.curWebViewTab.SSLCertificate evOrgName] == nil)
                        [urlField setText:@"Unknown Organization"];
                    else
                        [urlField setText:self.curWebViewTab.SSLCertificate.evOrgName];
                    
                    isEV = YES;
                }
            }
        }
        else if (self.curWebViewTab && self.curWebViewTab.secureMode == WebViewTabSecureModeMixed) {
            [urlField setLeftView:brokenLockIcon];
        }
        else {
            [urlField setLeftView:nil];
        }
        
        if (!isEV) {
            NSString *host;
            if (self.curWebViewTab.url == nil)
                host = @"";
            else {
                host = [self.curWebViewTab.url host];
                if (host == nil)
                    host = [self.curWebViewTab.url absoluteString];
            }
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
            NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
            
            [urlField setTextColor:[UIColor darkTextColor]];
            [urlField setText:hostNoWWW];
            
            if ([urlField.text isEqualToString:@""]) {
                [urlField setTextAlignment:NSTextAlignmentLeft];
            }
        }
    }
    
    UIColor *tintColor = (self.darkInterface ? [UIColor lightTextColor] : [progressBar tintColor]);
    backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
    [backButton setTintColor:(backButton.enabled ? tintColor : [UIColor grayColor])];
    
    forwardButton.hidden = !(self.curWebViewTab && self.curWebViewTab.canGoForward);
    [forwardButton setTintColor:(forwardButton.enabled ? tintColor : [UIColor grayColor])];
    
    [urlField setFrame:[self frameForUrlField]];
    [self updateProgress];
}

- (void)updateProgress
{
    BOOL animated = YES;
    float fadeAnimationDuration = 0.15;
    float fadeOutDelay = 0.3;
    
    float progress = [[[self curWebViewTab] progress] floatValue];
    if (progressBar.progress == progress) {
        return;
    }
    else if (progress == 0.0) {
        /* reset without animation, an actual update is probably coming right after this */
        progressBar.progress = 0.0;
        return;
    }
    
#ifdef TRACE
    NSLog(@"[Tab %@] loading progress of %@ at %f", self.curWebViewTab.tabIndex, [self.curWebViewTab.url absoluteString], progress);
#endif
    
    if (progress >= 1.0) {
        [progressBar setProgress:progress animated:NO];
        
        [UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveLinear animations:^{
            progressBar.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self updateSearchBarDetails];
        }];
    }
    else {
        [UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            [progressBar setProgress:progress animated:YES];
            
            if (showingTabs)
                progressBar.alpha = 0.0;
            else
                progressBar.alpha = 1.0;
        } completion:nil];
    }
}

- (void)webViewTouched
{
    if ([urlField isFirstResponder]) {
        [urlField resignFirstResponder];
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField != urlField)
        return;
    
#ifdef TRACE
    NSLog(@"started editing");
#endif
    
    [urlField setText:[self.curWebViewTab.url absoluteString]];
    
    if (bookmarks == nil) {
        bookmarks = [[BookmarkController alloc] init];
        bookmarks.embedded = true;
        
        float statusBarHeight = STATUSBAR_HEIGHT * ![[UIApplication sharedApplication] isStatusBarHidden];
        
        if (self.toolbarOnBottom)
        /* we can't size according to keyboard height because we don't know it yet, so we'll just put it full height below the toolbar */
            bookmarks.view.frame = CGRectMake(0, statusBarHeight, self.view.frame.size.width, self.view.frame.size.height);
        else
            bookmarks.view.frame = CGRectMake(0, toolbar.frame.size.height + toolbar.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
        
        [self addChildViewController:bookmarks];
        [self.view insertSubview:[bookmarks view] belowSubview:toolbar];
    }
    
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        [urlField setTextAlignment:NSTextAlignmentNatural];
        [backButton setHidden:true];
        [forwardButton setHidden:true];
        [urlField setFrame:[self frameForUrlField]];
    } completion:^(BOOL finished) {
        [urlField performSelector:@selector(selectAll:) withObject:nil afterDelay:0.1];
    }];
    
    [self updateSearchBarDetails];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField != nil && textField != urlField)
        return;
    
#ifdef TRACE
    NSLog(@"ended editing with: %@", [textField text]);
#endif
    if (bookmarks != nil) {
        [[bookmarks view] removeFromSuperview];
        [bookmarks removeFromParentViewController];
        bookmarks = nil;
    }
    
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        [urlField setTextAlignment:NSTextAlignmentCenter];
        [backButton setHidden:false];
        [forwardButton setHidden:!(self.curWebViewTab && self.curWebViewTab.canGoForward)];
        [urlField setFrame:[self frameForUrlField]];
    } completion:nil];
    
    [self updateSearchBarDetails];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField != urlField) {
        return YES;
    }
    
    [self prepareForNewURLFromString:urlField.text];
    
    return NO;
}

- (void)prepareForNewURLFromString:(NSString *)url
{
    /* user is shifting to a new place, probably a good time to clear old data */
    [[appDelegate cookieJar] clearAllOldNonWhitelistedData];
    
    NSURL *enteredURL = [NSURL URLWithString:url];
    
    if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
        /* no scheme so if it has a space or no dots, assume it's a search query */
        if ([url containsString:@" "] || ![url containsString:@"."]) {
            [[self curWebViewTab] searchFor:url];
            enteredURL = nil;
        }
        else
            enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];
    }
    
    [urlField resignFirstResponder]; /* will unfocus and call textFieldDidEndEditing */
    
    if (enteredURL != nil)
        [[self curWebViewTab] loadURL:enteredURL];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != tabScroller)
        return;
    
    int page = round(scrollView.contentOffset.x / scrollView.frame.size.width);
    if (page < 0) {
        page = 0;
    }
    else if (page > tabChooser.numberOfPages) {
        page = (int)tabChooser.numberOfPages;
    }
    [self setCurTabIndex:page];
}

- (void)goBack:(id)_id
{
    if (self.curWebViewTab && self.curWebViewTab.canGoBack)
        [self.curWebViewTab goBack];
}

- (void)goForward:(id)_id
{
    if (self.curWebViewTab && self.curWebViewTab.canGoForward)
        [self.curWebViewTab goForward];}

- (void)refresh
{
    [[self curWebViewTab] refresh];
}

- (void)forceRefresh
{
    [[self curWebViewTab] forceRefresh];
}

- (void)showPopover:(id)_id
{
    popover = [[WYPopoverController alloc] initWithContentViewController:[[WebViewMenuController alloc] init]];
    [popover setDelegate:self];
    
    [popover beginThemeUpdates];
    [popover setTheme:[WYPopoverTheme themeForIOS7]];
    [popover.theme setDimsBackgroundViewsTintColor:NO];
    [popover.theme setOuterCornerRadius:4];
    [popover.theme setOuterShadowBlurRadius:8];
    [popover.theme setOuterShadowColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.75]];
    [popover.theme setOuterShadowOffset:CGSizeMake(0, 2)];
    [popover.theme setOverlayColor:[UIColor clearColor]];
    [popover endThemeUpdates];
    
    [popover presentPopoverFromRect:CGRectMake(settingsButton.frame.origin.x, toolbar.frame.origin.y + settingsButton.frame.origin.y + settingsButton.frame.size.height - 30, settingsButton.frame.size.width, settingsButton.frame.size.height) inView:self.view permittedArrowDirections:WYPopoverArrowDirectionAny animated:YES options:WYPopoverAnimationOptionFadeWithScale];
}

- (void)dismissPopover
{
    [popover dismissPopoverAnimated:YES];
}

- (BOOL)popoverControllerShouldDismissPopover:(WYPopoverController *)controller
{
    return YES;
}

#pragma mark - InAppSettings
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [URLInterceptor setSendDNT:[userDefaults boolForKey:@"send_dnt"]];
    [[appDelegate cookieJar] setOldDataSweepTimeout:[NSNumber numberWithInteger:[userDefaults integerForKey:@"old_data_sweep_mins"]]];
    
    BOOL oldtob = self.toolbarOnBottom;
    BOOL olddark = self.darkInterface;
    self.toolbarOnBottom = [userDefaults boolForKey:@"toolbar_on_bottom"];
    self.darkInterface = [userDefaults boolForKey:@"dark_interface"];
    
    if (self.toolbarOnBottom != oldtob || self.darkInterface != olddark) {
        [self adjustLayoutToSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
        [self updateSearchBarDetails];
    } else if (self.darkInterface) {
        // Change back the status bar style if necessary (was changed to default when opening the settings)
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    }
}

- (void)settingsViewController:(IASKAppSettingsViewController *)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    if ([specifier.key isEqualToString:@"ButtonShowTutorial"]) {
        [sender dismiss:nil];
        [self showTutorial];
    }
}

- (void)showTabs:(id)_id
{
    return [self showTabsWithCompletionBlock:nil];
}

- (void)showTabsWithCompletionBlock:(void(^)(BOOL))block
{
    shouldHideStatusBar = NO; // Just in case
    [self setNeedsStatusBarAppearanceUpdate];

    if (showingTabs == false) {
        /* zoom out */
        
        /* make sure no text is selected */
        [urlField resignFirstResponder];
        
        origTabScrollerFrame = tabScroller.frame;
        
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
            for (int i = 0; i < webViewTabs.count; i++) {
                [(WebViewTab *)webViewTabs[i] zoomOut];
            }
            
            tabChooser.hidden = false;
            toolbar.hidden = true;
            tabToolbar.hidden = false;
            progressBar.alpha = 0.0;
            
            float yOffset = 0;
            if (self.toolbarOnBottom && UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
                yOffset -= 20; // To avoid button overlapping is tab selection view
            }
            
            tabScroller.frame = CGRectMake(tabScroller.frame.origin.x, yOffset, tabScroller.frame.size.width, tabScroller.frame.size.height);
        } completion:block];
        
        tabScroller.contentOffset = CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0);
        tabScroller.scrollEnabled = YES;
        tabScroller.pagingEnabled = YES;
        
        UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnWebViewTab:)];
        singleTapGestureRecognizer.numberOfTapsRequired = 1;
        singleTapGestureRecognizer.enabled = YES;
        singleTapGestureRecognizer.cancelsTouchesInView = NO;
        [tabScroller addGestureRecognizer:singleTapGestureRecognizer];
        
        tabSelectionPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
        [tabSelectionPanGestureRecognizer setMinimumNumberOfTouches:1];
        [tabSelectionPanGestureRecognizer setMaximumNumberOfTouches:1];
        [tabScroller addGestureRecognizer:tabSelectionPanGestureRecognizer];
    }
    else {
        [tabScroller removeGestureRecognizer:tabSelectionPanGestureRecognizer];
        tabSelectionPanGestureRecognizer = nil;
        
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
            for (int i = 0; i < webViewTabs.count; i++) {
                [(WebViewTab *)webViewTabs[i] zoomNormal];
            }
            
            tabChooser.hidden = true;
            toolbar.hidden = false;
            tabToolbar.hidden = true;
            progressBar.alpha = (progressBar.progress > 0.0 && progressBar.progress < 1.0 ? 1.0 : 0.0);
            tabScroller.frame = origTabScrollerFrame;
        } completion:block];
        
        tabScroller.scrollEnabled = NO;
        tabScroller.pagingEnabled = NO;
        
        // Refresh/force refresh if necessary
        if ([[self curWebViewTab] needsForceRefresh]) {
            [[self curWebViewTab] forceRefresh];
            [[self curWebViewTab] setNeedsForceRefresh:NO];
        }
        
        if ([[self curWebViewTab] needsRefresh]) {
            [[self curWebViewTab] refresh];
            [[self curWebViewTab] setNeedsRefresh:NO];
        }
        
        [self updateSearchBarDetails];
    }
    
    showingTabs = !showingTabs;
}

- (void)doneWithTabsButton:(id)_id
{
    [self showTabs:nil];
}

- (void)showSSLCertificate
{
    if ([[self curWebViewTab] SSLCertificate] == nil)
        return;
    
    SSLCertificateViewController *scvc = [[SSLCertificateViewController alloc] initWithSSLCertificate:[[self curWebViewTab] SSLCertificate]];
    scvc.title = [[[self curWebViewTab] url] host];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:scvc];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)tappedOnWebViewTab:(UITapGestureRecognizer *)gesture
{
    if (!showingTabs) {
        if ([urlField isFirstResponder]) {
            [urlField resignFirstResponder];
        }
        
        return;
    }
    
    CGPoint point = [gesture locationInView:self.curWebViewTab.viewHolder];
    
    /* fuzz a bit to make it easier to tap */
    int fuzz = 15;
    CGRect closerFrame = CGRectMake(self.curWebViewTab.closer.frame.origin.x - fuzz, self.curWebViewTab.closer.frame.origin.y - fuzz, self.curWebViewTab.closer.frame.size.width + (fuzz * 2), self.curWebViewTab.closer.frame.size.width + (fuzz * 2));
    if (CGRectContainsPoint(closerFrame, point)) {
        [self removeWithoutFocusingTab:[NSNumber numberWithLong:curTabIndex]];
    }
    else {
        [self showTabs:nil];
    }
}

- (void)handleTwoFingerDrag:(UIPanGestureRecognizer *)gesture {
    if (!showingTabs) {
        CGPoint vel = [gesture velocityInView:tabScroller];
        
        if (CGPointEqualToPoint(panGestureOriginPoint, CGPointZero)) {
            panGestureOriginPoint = [gesture locationInView:self.curWebViewTab.viewHolder];
        }
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_NONE && fabs(vel.x) > 50 && tabChooser.numberOfPages > 1) {
            // User is trying to change tab, and there are at least 2 tabs

            if (panGestureOriginPoint.x <= PAN_GESTURE_RECOGNIZER_EDGE_SIZE || panGestureOriginPoint.x >= (self.curWebViewTab.viewHolder.bounds.size.width - PAN_GESTURE_RECOGNIZER_EDGE_SIZE)) {
                // User started from the edge of the screen
                panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_SIDE;
                // Prevent scrolling/zooming while the user is changing tab
                [self.curWebViewTab.webView.scrollView.pinchGestureRecognizer setEnabled:NO];
                [self.curWebViewTab.webView.scrollView.panGestureRecognizer setEnabled:NO];
            }
        }
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_SIDE) {
            CGFloat xDistance = [gesture translationInView:tabScroller].x;
            
            switch (gesture.state) {
                case UIGestureRecognizerStateChanged: {
                    CGRect frame = tabScroller.frame;
                    frame.origin.x = frame.size.width * curTabIndex;
                    frame.origin.y = 0;
                    
                    // Disable "impossible" drags to remove ugly transitions
                    if (xDistance < 0 && curTabIndex == tabChooser.numberOfPages - 1)
                        xDistance = 0;
                    else if (xDistance > 0 && curTabIndex == 0)
                        xDistance = 0;
                    
                    [tabScroller setContentOffset:CGPointMake(frame.origin.x - xDistance, frame.origin.y) animated:NO];
                    break;
                };
                    
                case UIGestureRecognizerStateCancelled: {
                    // Reset everything
                    [self.curWebViewTab.webView.scrollView.pinchGestureRecognizer setEnabled:YES];
                    [self.curWebViewTab.webView.scrollView.panGestureRecognizer setEnabled:YES];
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    panGestureOriginPoint = CGPointZero;
                }
                    
                case UIGestureRecognizerStateFailed: {
                    // Reset everything
                    [self.curWebViewTab.webView.scrollView.pinchGestureRecognizer setEnabled:YES];
                    [self.curWebViewTab.webView.scrollView.panGestureRecognizer setEnabled:YES];
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    panGestureOriginPoint = CGPointZero;
                }
                    
                case UIGestureRecognizerStateEnded: {
                    [self.curWebViewTab.webView.scrollView.pinchGestureRecognizer setEnabled:YES];
                    [self.curWebViewTab.webView.scrollView.panGestureRecognizer setEnabled:YES];

                    if ((xDistance <= -100 || vel.x <= -300) && curTabIndex < tabChooser.numberOfPages - 1) {
                        // Moved enough to change tab (go right), and there is at least 1 tab on the right
                        [tabChooser setCurrentPage:curTabIndex + 1];
                        curTabIndex += 1;
                    } else if ((xDistance >= 100 || vel.x >= 300) && curTabIndex > 0) {
                        // Moved enough to change tab (go left), and there is at least 1 tab on the left
                        [tabChooser setCurrentPage:curTabIndex - 1];
                        curTabIndex -= 1;
                    }
                    
                    // If the page index wasn't changed, it will just scroll back to the page's original position
                    CGRect frame = tabScroller.frame;
                    frame.origin.x = frame.size.width * curTabIndex;
                    frame.origin.y = 0;
                    [tabScroller setContentOffset:frame.origin animated:YES];
                    
                    // Update the searchBar to match the selected tab
                    [self updateSearchBarDetails];
                    
                    
                    // Refresh/force refresh if necessary
                    if ([[self curWebViewTab] needsForceRefresh]) {
                        [[self curWebViewTab] forceRefresh];
                        [[self curWebViewTab] setNeedsForceRefresh:NO];
                    }
                    
                    if ([[self curWebViewTab] needsRefresh]) {
                        [[self curWebViewTab] refresh];
                        [[self curWebViewTab] setNeedsRefresh:NO];
                    }

                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    panGestureOriginPoint = CGPointZero;
                    
                    break;
                };
                    
                default: break;
            }
            
        } else if (gesture.state == UIGestureRecognizerStateEnded) {
            // Reset the origin point for the gesture
            panGestureOriginPoint = CGPointZero;
            self.curWebViewTab.webView.scrollView.panGestureRecognizer.enabled = YES;
            self.curWebViewTab.webView.scrollView.scrollEnabled = YES;
        }
    }
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    if (showingTabs) {
        CGPoint vel = [gesture velocityInView:tabScroller];
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_NONE) {
            if (fabs(vel.x) > fabs(vel.y) && fabs(vel.x) > 50) {
                /* User is trying to change page */
                panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_SIDE;
            } else if (fabs(vel.y) > fabs(vel.x) && vel.y < -50) {
                // We only care about speed < 0 because the user needs to swipe up to close the tab
                /* User is trying to remove a tab */
                panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_UP;
            }
        }
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_SIDE) {
            CGFloat xDistance = [gesture translationInView:tabScroller].x;
            
            switch (gesture.state) {
                case UIGestureRecognizerStateChanged: {
                    CGRect frame = tabScroller.frame;
                    frame.origin.x = frame.size.width * curTabIndex;
                    frame.origin.y = 0;

                    [tabScroller setContentOffset:CGPointMake(frame.origin.x - xDistance, frame.origin.y) animated:NO];
                    break;
                };
                    
                case UIGestureRecognizerStateEnded: {
                    if ((xDistance <= -100 || vel.x <= -300) && curTabIndex < tabChooser.numberOfPages - 1) {
                        // Moved enough to change page (go right), and there is at least 1 page on the right
                        [tabChooser setCurrentPage:curTabIndex + 1];
                        curTabIndex += 1;
                    } else if ((xDistance >= 100 || vel.x >= 300) && curTabIndex > 0) {
                        // Moved enough to change page (go left), and there is at least 1 page on the left
                        [tabChooser setCurrentPage:curTabIndex - 1];
                        curTabIndex -= 1;
                    }
                    
                    // If the page index wasn't changed, it will just scroll back to the page's original position
                    CGRect frame = tabScroller.frame;
                    frame.origin.x = frame.size.width * curTabIndex;
                    frame.origin.y = 0;
                    [tabScroller setContentOffset:frame.origin animated:YES];
                    
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    
                    break;
                };
                    
                default: break;
            }
            
        } else if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_UP) {
            CGFloat yDistance = [gesture translationInView:tabScroller].y;
            UIView *tabView = [(WebViewTab *)webViewTabs[curTabIndex] viewHolder];
            
            switch (gesture.state) {
                case UIGestureRecognizerStateBegan: {
                    originalPoint = [tabView center];
                    [UIView animateWithDuration:0.2 animations:^{
                        shouldHideStatusBar = YES;
                        [self setNeedsStatusBarAppearanceUpdate];
                    }];
                    
                    break;
                };
                case UIGestureRecognizerStateChanged: {
                    if (yDistance <= 0) {
                        tabView.center = CGPointMake(originalPoint.x, originalPoint.y + yDistance);
                    }
                    
                    break;
                };
                case UIGestureRecognizerStateEnded: {
                    if (-yDistance <= self.view.frame.size.height/3 && vel.y >= -1500) {
                        // Moved the view less than 1/4th of the view height, or is moving fast enough to consider the user wants to close
                        [UIView animateWithDuration:0.5 animations:^{
                            [tabView setCenter:originalPoint];
                        } completion:^(BOOL finished) {}];
                    } else {
                        [UIView animateWithDuration:0.2 animations:^{
                            [tabView setCenter:CGPointMake(originalPoint.x, -originalPoint.y)];
                        } completion:^(BOOL finished) {
                            [self removeWithoutFocusingTab:[NSNumber numberWithLong:curTabIndex]];
                        }];
                    }
                    
                    [UIView animateWithDuration:0.2 animations:^{
                        shouldHideStatusBar = NO;
                        [self setNeedsStatusBarAppearanceUpdate];
                    }];
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    
                    break;
                };
                    
                default: break;
            }
        }
        
    }
}

- (void)touchedPageControlDot:(id)sender {
    UIPageControl *pager = sender;
    NSInteger page = pager.currentPage;
    [tabChooser setCurrentPage:page];
    curTabIndex = (int)page;
    CGRect frame = tabScroller.frame;
    frame.origin.x = frame.size.width * page;
    frame.origin.y = 0;
    [tabScroller setContentOffset:frame.origin animated:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)slideToCurrentTabWithCompletionBlock:(void(^)(BOOL))block
{
    [self updateProgress];
    
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
    } completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
    [self slideToCurrentTabWithCompletionBlock:nil];
}

- (void)goHome:(NSURL *)url {
    [self removeAllTabs];
    [self addNewTabForURL:url];
}

- (void)showTutorial {
    // Change orientation to portrait, the tutorial doesn't nicelly support landscape
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    
    // Compute the image views' frame
    CGRect frame = appDelegate.appWebView.view.bounds;
    frame.size.height -= 100;
    frame.origin.y -= 50;
    
    
    // Initialize the image views
    UIImageView *view1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"page_1"]];
    [view1 setContentMode:UIViewContentModeScaleAspectFit];
    [view1 setFrame:frame];
    
    UIImageView *view2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"page_2"]];
    [view2 setContentMode:UIViewContentModeScaleAspectFit];
    [view2 setFrame:frame];
    
    UIImageView *view3 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"page_3"]];
    [view3 setContentMode:UIViewContentModeScaleAspectFit];
    [view3 setFrame:frame];
    
    UIImageView *view4 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"page_4"]];
    [view4 setContentMode:UIViewContentModeScaleAspectFit];
    [view4 setFrame:frame];
    
    
    // Initialize all the pages with their content
    EAIntroPage *page1 = [EAIntroPage page];
    [page1 setDesc:@"Use two fingers and drag from the edge of the screen to change tab."];
    [page1 setDescColor:[UIColor blackColor]];
    [page1 setDescFont:[UIFont systemFontOfSize:16]];
    [page1 setBgColor:[UIColor whiteColor]];
    [page1 setTitleIconView:view1];
    [page1 setDescPositionY:90];
    [page1 setTitleIconPositionY:20];
    
    EAIntroPage *page2 = [EAIntroPage page];
    [page2 setDesc:@"Swipe up with one finger to close a tab from the tabs selection view."];
    [page2 setDescColor:[UIColor blackColor]];
    [page2 setDescFont:[UIFont systemFontOfSize:16]];
    [page2 setBgColor:[UIColor whiteColor]];
    [page2 setTitleIconView:view2];
    [page2 setDescPositionY:90];
    [page2 setTitleIconPositionY:20];
    
    EAIntroPage *page3 = [EAIntroPage page];
    [page3 setDesc:@"Added security features: disable javascript, use HTTPS Everywhere to encrypt communications..."];
    [page3 setDescColor:[UIColor blackColor]];
    [page3 setDescFont:[UIFont systemFontOfSize:15]];
    [page3 setBgColor:[UIColor whiteColor]];
    [page3 setTitleIconView:view3];
    [page3 setDescPositionY:90];
    [page3 setTitleIconPositionY:20];
    
    EAIntroPage *page4 = [EAIntroPage page];
    [page4 setDesc:@"A new tabs restoration feature reopens your tabs each time you launch the app."];
    [page4 setDescColor:[UIColor blackColor]];
    [page4 setDescFont:[UIFont systemFontOfSize:16]];
    [page4 setBgColor:[UIColor whiteColor]];
    [page4 setTitleIconView:view4];
    [page4 setDescPositionY:90];
    [page4 setTitleIconPositionY:20];
    
    // Initialize the view containing all the pages
    EAIntroView *intro = [[EAIntroView alloc] initWithFrame:appDelegate.appWebView.view.bounds andPages:@[page1, page2, page3, page4]];
    [intro setPageControlY:20];
    [[intro pageControl] setPageIndicatorTintColor:[UIColor lightGrayColor]];
    [[intro pageControl] setCurrentPageIndicatorTintColor:[UIColor grayColor]];
    [[intro skipButton] setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    // Display the view
    [intro showInView:appDelegate.appWebView.view animateDuration:0.3];
}

-(UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

@end
