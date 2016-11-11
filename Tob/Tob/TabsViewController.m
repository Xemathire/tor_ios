//
//  ViewController.m
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import "TabsViewController.h"
#import "WebViewTab.h"
#import "CustomTextField.h"
#import "AppDelegate.h"
#import "BookmarkTableViewController.h"
#import "SettingsTableViewController.h"
#import "Bookmark.h"
#import "BridgeViewController.h"
#import "NSStringPunycodeAdditions.h"
#import "iRate.h"
#import "LogViewController.h"
#import <objc/runtime.h>

#define UNIBAR_DEFAULT_X 12
#define UNIBAR_DEFAULT_Y [[UIApplication sharedApplication] statusBarFrame].size.height == 0 ? 10 : [[UIApplication sharedApplication] statusBarFrame].size.height + 5
#define UNIBAR_DEFAULT_WIDTH [[UIScreen mainScreen] bounds].size.width - 20
#define UNIBAR_DEFAULT_WIDTH_WITH(ORIENTATION) [[UIScreen mainScreen] bounds].size.width - 20
#define UNIBAR_DEFAULT_HEIGHT 29

#define UNIBAR_FINISHED_X 11.5
#define UNIBAR_FINISHED_Y [[UIApplication sharedApplication] statusBarFrame].size.height == 0 ? 0 : [[UIApplication sharedApplication] statusBarFrame].size.height - 5
#define UNIBAR_FINISHED_WIDTH [[UIScreen mainScreen] bounds].size.width - 20
#define UNIBAR_FINISHED_HEIGHT 25

#define kNavigationBarAnimationTime 0.2

#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height
#define SCREEN_WIDTH [[UIScreen mainScreen] bounds].size.width

#define DeviceOrientation [[UIApplication sharedApplication] statusBarOrientation]

#define ALERTVIEW_SSL_WARNING 1
#define ALERTVIEW_EXTERN_PROTO 2
#define ALERTVIEW_INCOMING_URL 3
#define ALERTVIEW_TORFAIL 4

@interface TabsViewController () <UIScrollViewDelegate, UIWebViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate>

@end

const char AlertViewExternProtoUrl;
const char AlertViewIncomingUrl;
static const CGFloat kRestoreAnimationDuration = 0.0f;


@implementation TabsViewController {
    // Array of titles that are presented at the top of each tab's container view
    NSMutableArray *_titles;
    
    // Array of subtitles that are presented on top of the views
    NSMutableArray *_subtitles;
    
    // Array of the TLSS Statuses for the webviews
    NSMutableArray *_tlsStatuses;
    
    // Array of contentviews that are displayed in the tabs
    NSMutableArray *_contentViews;
    
    // Array of the progress for each web view
    NSMutableArray *_progressValues;
    
    // Scrolling
    BOOL _userScrolling;
    BOOL _toolbarUpInMiddleOfPageNowScrollingDown;
    CGPoint _previousScrollOffset;
    CGPoint _initialScrollOffset;
    BOOL _skipScrolling;
    
    // Web
    UIWebView *_webViewObject;
    UIProgressView *_progressView;
    
    // Nav bar
    CustomTextField *_addressTextField;
    BOOL _addressTextFieldEditing;
    UIButton *_cancelButton;
    
    // Selected toolbar
    UIBarButtonItem *_backBarButtonItem;
    UIBarButtonItem *_forwardBarButtonItem;
    UIBarButtonItem *_settingsBarButtonItem;
    UIBarButtonItem *_onionBarButtonItem;
    UIBarButtonItem *_tabsBarButtonItem;
    
    // Deselected toolbar
    UIBarButtonItem *_deselectedSettingsBarButtonItem;
    
    // Tor progress view
    UIProgressView *_torProgressView;
    UIView *_torLoadingView;
    UIView *_torDarkBackgroundView;
    UILabel *_torProgressDescription;
    
    // Tor panel view
    UIView *_torPanelView;
    UILabel *_IPAddressLabel;
    
    // Bookmarks
    BookmarkTableViewController *_bookmarks;
}

#pragma mark - Initializing

- (id)init {
    self = [super init];
    if (self) {
        self.restorationIdentifier = @"tabsViewController";
        self.restorationClass = [self class];
        _newIdentityNumber = 0;
        [self initUI];
    }
    return self;
}

- (void)initUI {
    // Initialize the tab view
    self.tabView.addingStyle = MOTabViewAddingAtLastIndex;
    self.tabView.navigationBarHidden = NO;
    self.maxNumberOfViews = 99;
    
    // Remove the title label
    UITextField *titleField = nil;
    [self.tabView setTitleField:titleField];
    
    // Add a custom cancel button to the navigation bar
    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelButton.frame = CGRectMake(SCREEN_WIDTH - 60, UNIBAR_DEFAULT_Y, 55, UNIBAR_DEFAULT_HEIGHT);
    [_cancelButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [_cancelButton setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    _cancelButton.alpha = 0.0;
    [self.tabView.navigationBar addSubview:_cancelButton];
    
    // Use a custom title field for the navigation bar
    _addressTextField = [[CustomTextField alloc] initWithFrame:CGRectMake(UNIBAR_DEFAULT_X, UNIBAR_DEFAULT_Y, UNIBAR_DEFAULT_WIDTH_WITH(currentOrientation), UNIBAR_DEFAULT_HEIGHT)];
    _addressTextField.delegate = self;
    _addressTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _addressTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _addressTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _addressTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    _addressTextField.returnKeyType = UIReturnKeyGo;
    _addressTextField.adjustsFontSizeToFitWidth = YES;
    _addressTextField.keyboardType = UIKeyboardTypeWebSearch;
    _addressTextField.placeholder = NSLocalizedString(@"Search or enter an address", nil);
    _addressTextField.rightViewMode = UITextFieldViewModeUnlessEditing;
    _addressTextField.delegate = self;
    [self.tabView setNavigationBarField:_addressTextField];
    
    [_addressTextField.cancelButton addTarget:self action:@selector(stopTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_addressTextField.refreshButton addTarget:self action:@selector(refreshTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    self.tabView.editableTitles = YES;
    
    _progressView = [[UIProgressView alloc] init];
    [self.view addSubview:_progressView];
    
    UIView *navBar = self.tabView.navigationBar;
    
    if (navBar) {
        [[self view] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[navBar]-[_progressView(2@20)]"
                                                                            options:NSLayoutFormatDirectionLeadingToTrailing
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(_progressView, navBar)]];
        
        [[self view] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_progressView]|"
                                                                            options:NSLayoutFormatDirectionLeadingToTrailing
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(_progressView)]];
    }
    
    [_progressView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_progressView setProgress:0.0f animated:NO];
    [self hideProgressBarAnimated:NO];
    
    // Add a settings button to the deselected toolbar
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:self.deselectedToolbar.items];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [items insertObject:flexibleSpace atIndex:0];
    [items insertObject:self.deselectedSettingsBarButtonItem atIndex:0];
    self.deselectedToolbar.items = items;
    
    [self.selectedToolbar setFrame:CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44)];
    _tabsBarButtonItem = self.selectedToolbar.items[1];
    
    // Select the restore/opened tab
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if ([appDelegate startUrl]) {
        [UIView animateWithDuration:kRestoreAnimationDuration animations:^{
            [self.tabView deselectCurrentViewAnimated:NO];
            [self.tabView selectViewAtIndex:[self numberOfViewsInTabView:self.tabView] - 1 animated:NO];
        } completion:^(BOOL finished){
            [self.tabView selectCurrentViewAnimated:NO];
        }];
    } else if ([appDelegate restoredData] && [appDelegate restoredIndex] != self.tabView.currentIndex) {
        [UIView animateWithDuration:kRestoreAnimationDuration animations:^{
            [self.tabView deselectCurrentViewAnimated:NO];
            [self.tabView selectViewAtIndex:[appDelegate restoredIndex] animated:NO];
        } completion:^(BOOL finished){
            if (self.tabView.currentIndex != 0)
                ((WebViewTab *)[self.contentViews objectAtIndex:0]).frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

            [self.tabView selectCurrentViewAnimated:NO];
            [self.view bringSubviewToFront:_torDarkBackgroundView];
            [self.view bringSubviewToFront:_torLoadingView];
        }];
    }
    
    // Add a loading view for Tor
    _torDarkBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    _torDarkBackgroundView.backgroundColor = [UIColor blackColor];
    _torDarkBackgroundView.alpha = 0.5;
    [self.view addSubview:_torDarkBackgroundView];
    
    _torLoadingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    _torLoadingView.center = self.view.center;
    _torLoadingView.layer.cornerRadius = 5.0f;
    _torLoadingView.layer.masksToBounds = YES;

    UILabel *titleProgressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, _torLoadingView.frame.size.width, 30)];
    titleProgressLabel.text = NSLocalizedString(@"Initializing Tor…", nil);
    titleProgressLabel.textAlignment = NSTextAlignmentCenter;
    [_torLoadingView addSubview:titleProgressLabel];

    UIButton *settingsButton = [[UIButton alloc] initWithFrame:CGRectMake(_torLoadingView.frame.size.width - 40, 10, 30, 30)];
    [settingsButton setImage:[[UIImage imageNamed:@"Settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [settingsButton addTarget:self action:@selector(settingsTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_torLoadingView addSubview:settingsButton];
    
    UIButton *logButton = [[UIButton alloc] initWithFrame:CGRectMake(13, 13, 24, 24)];
    [logButton setImage:[[UIImage imageNamed:@"Log"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [logButton addTarget:self action:@selector(showLog) forControlEvents:UIControlEventTouchUpInside];
    [_torLoadingView addSubview:logButton];
    
    _torProgressView = [[UIProgressView alloc] initWithFrame:CGRectMake(10, 50, _torLoadingView.frame.size.width - 20, 10)];
    [_torLoadingView addSubview:_torProgressView];
    
    _torProgressDescription = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, _torLoadingView.frame.size.width - 20, 30)];
    _torProgressDescription.numberOfLines = 1;
    _torProgressDescription.textAlignment = NSTextAlignmentCenter;
    _torProgressDescription.adjustsFontSizeToFitWidth = YES;
    _torProgressDescription.text = @"0% - Starting";
    [_torLoadingView addSubview:_torProgressDescription];
    
    [appDelegate.logViewController logInfo:@"[tor] 0% - Starting"];
    
    [self.view addSubview:_torLoadingView];
    
    if (appDelegate.doPrepopulateBookmarks){
        [self prePopulateBookmarks];
    }
    
    [self updateTintColor];
    [self updateNavigationItems];
}

- (void)updateTintColor {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;
    
    if (![[settings valueForKey:@"night-mode"] boolValue]) {
        UIView *backgroundView = [[UIView alloc] init];
        backgroundView.frame = self.tabView.frame;
        backgroundView.backgroundColor = [UIColor groupTableViewBackgroundColor];
        [self.tabView setBackgroundView:backgroundView];
        
        UILabel *subtitleLabel = [[UILabel alloc] init];
        [subtitleLabel setTextAlignment:NSTextAlignmentCenter];
        [subtitleLabel setTextColor:[UIColor blackColor]];
        [self.tabView setSubtitleLabel:subtitleLabel];
        
        _cancelButton.tintColor = self.view.tintColor;
        
        _addressTextField.backgroundColor = [UIColor whiteColor];
        _addressTextField.textColor = [UIColor blackColor];
        _addressTextField.tintColor = self.view.tintColor;
        _addressTextField.tlsButton.tintColor = [UIColor blackColor];
        _addressTextField.cancelButton.tintColor = [UIColor blackColor];
        _addressTextField.refreshButton.tintColor = [UIColor blackColor];
        
        // Use custom colors for the page control (to make it more visible)
        self.tabView.pageControl.tintColor = [UIColor darkGrayColor];
        self.tabView.pageControl.pageIndicatorTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        self.tabView.pageControl.currentPageIndicatorTintColor = [UIColor grayColor];
        
        // Use a custom appearence for the navigation bar
        [self.tabView.navigationBar setBarTintColor:[UIColor groupTableViewBackgroundColor]];
        [self.tabView.navigationBar setTranslucent:NO];
        
        _progressView.trackTintColor = [UIColor colorWithRed:0.90 green:0.90 blue:0.92 alpha:1.0];
        _progressView.progressTintColor = self.view.tintColor;
        _torProgressView.trackTintColor = [UIColor colorWithRed:0.80 green:0.80 blue:0.82 alpha:1.0];;
        _torProgressView.progressTintColor = self.view.tintColor;
        
        _torLoadingView.backgroundColor = [UIColor groupTableViewBackgroundColor];
        
        for (UIView *subview in [_torLoadingView subviews]) {
            if ([subview class] == [UILabel class])
                [(UILabel *)subview setTextColor:[UIColor blackColor]];
            else if ([subview class] == [UIButton class])
                [(UIButton *) subview setTintColor:self.view.tintColor];
        }
        
        _torProgressDescription.textColor = [UIColor blackColor];
        
        _tabsBarButtonItem.tintColor = self.view.tintColor;
        self.numberOfViewsLabel.textColor = self.view.tintColor;
        
        [self.selectedToolbar setBarTintColor:[UIColor groupTableViewBackgroundColor]];
        [self.deselectedToolbar setBarTintColor:[UIColor groupTableViewBackgroundColor]];
        [self.selectedToolbar setTintColor:self.view.tintColor];
        [self.deselectedToolbar setTintColor:self.view.tintColor];
        self.selectedToolbar.translucent = YES;
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    } else {
        UIView *backgroundView = [[UIView alloc] init];
        backgroundView.frame = self.tabView.frame;
        backgroundView.backgroundColor = [UIColor darkGrayColor];
        [self.tabView setBackgroundView:backgroundView];
        
        UILabel *subtitleLabel = [[UILabel alloc] init];
        [subtitleLabel setTextAlignment:NSTextAlignmentCenter];
        [subtitleLabel setTextColor:[UIColor whiteColor]];
        [self.tabView setSubtitleLabel:subtitleLabel];
        
        _cancelButton.tintColor = [UIColor whiteColor];
        
        _addressTextField.backgroundColor = [UIColor lightGrayColor];
        _addressTextField.textColor = [UIColor whiteColor];
        _addressTextField.tintColor = [UIColor whiteColor];
        _addressTextField.tlsButton.tintColor = [UIColor whiteColor];
        _addressTextField.cancelButton.tintColor = [UIColor whiteColor];
        _addressTextField.refreshButton.tintColor = [UIColor whiteColor];
        
        self.tabView.pageControl.tintColor = [UIColor whiteColor];
        self.tabView.pageControl.pageIndicatorTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        self.tabView.pageControl.currentPageIndicatorTintColor = [UIColor whiteColor];
        
        [self.tabView.navigationBar setBarTintColor:[UIColor darkGrayColor]];
        [self.tabView.navigationBar setTranslucent:NO];
        
        _progressView.trackTintColor = [UIColor lightGrayColor];
        _progressView.progressTintColor = [UIColor whiteColor];
        _torProgressView.trackTintColor = [UIColor grayColor];
        _torProgressView.progressTintColor = [UIColor whiteColor];
        
        _torLoadingView.backgroundColor = [UIColor darkGrayColor];
        
        for (UIView *subview in [_torLoadingView subviews]) {
            if ([subview class] == [UILabel class])
                [(UILabel *)subview setTextColor:[UIColor whiteColor]];
            else if ([subview class] == [UIButton class])
                [(UIButton *) subview setTintColor:[UIColor whiteColor]];
        }
        
        _torProgressDescription.textColor = [UIColor whiteColor];
        
        _tabsBarButtonItem.tintColor = [UIColor whiteColor];
        self.numberOfViewsLabel.textColor = [UIColor whiteColor];
        
        [self.selectedToolbar setBarTintColor:[UIColor darkGrayColor]];
        [self.deselectedToolbar setBarTintColor:[UIColor darkGrayColor]];
        [self.selectedToolbar setTintColor:[UIColor whiteColor]];
        [self.deselectedToolbar setTintColor:[UIColor whiteColor]];
        self.selectedToolbar.translucent = YES;
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateTintColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setAutomaticallyAdjustsScrollViewInsets:YES];
    [self setExtendedLayoutIncludesOpaqueBars:YES];
    
    if (self.tabView.isTabSelected) {
        [self.view bringSubviewToFront:self.selectedToolbar];
        [self.view bringSubviewToFront:_bookmarks.tableView];
        [self.view bringSubviewToFront:_torDarkBackgroundView];
        [self.view bringSubviewToFront:_torLoadingView];
        [self.view bringSubviewToFront:_torPanelView];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Update the toolbar's frame
    [self.selectedToolbar setFrame:CGRectMake(0, size.height - 44, size.width, 44)];
    [self.deselectedToolbar setFrame:CGRectMake(0, size.height - 44, size.width, 44)];
    _userScrolling = NO;
    
    CGRect frame = self.tabView.frame;
    frame.size = size;
    
    [self.tabView selectCurrentView];
        
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // Update the frame for all the content views
        for (WebViewTab *tab in self.contentViews) {
            [tab setFrame:frame];
        }
        
        [self.tabView setFrame:frame];
        [self showNavigationBarAtFullHeight];
        
        _torDarkBackgroundView.frame = CGRectMake(0, 0, size.width, size.height);
        _torLoadingView.center = CGPointMake(size.width / 2, size.height / 2);
        _torPanelView.center = CGPointMake(size.width / 2, size.height / 2);
        [self.view bringSubviewToFront:_torDarkBackgroundView];
        [self.view bringSubviewToFront:_torLoadingView];
        [self.view bringSubviewToFront:_torPanelView];
        
        _cancelButton.frame = CGRectMake(size.width - 60, UNIBAR_DEFAULT_Y, 55, UNIBAR_DEFAULT_HEIGHT);
        _bookmarks.view.frame = CGRectMake(0, [[UIApplication sharedApplication] statusBarFrame].size.height + 44, size.width, size.height - ([[UIApplication sharedApplication] statusBarFrame].size.height + 44));
        [self unibarStopEditing];
    } completion: ^(id<UIViewControllerTransitionCoordinatorContext> context) {
        int maxNavbarSize = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
        if (_webViewObject.scrollView.contentSize.height <= SCREEN_HEIGHT)
            _webViewObject.frame =  CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - (44 + maxNavbarSize));
        else
            _webViewObject.frame =  CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
        
        _cancelButton.frame = CGRectMake(size.width - 60, UNIBAR_DEFAULT_Y, 55, UNIBAR_DEFAULT_HEIGHT);
        CGRect textFieldFrame = _addressTextField.frame;
        textFieldFrame.origin.y = UNIBAR_DEFAULT_Y;
        _addressTextField.frame = textFieldFrame;
        
        [self.view bringSubviewToFront:_torDarkBackgroundView];
        [self.view bringSubviewToFront:_torLoadingView];
        [self.view bringSubviewToFront:_torPanelView];
    }];
}

- (void)saveAppState {
    NSMutableArray *tabsDataArray = [[NSMutableArray alloc] initWithCapacity:_subtitles.count - 1];
    for (int i = 0; i < _subtitles.count; i++) {
        if ([[[self.contentViews objectAtIndex:i] url] absoluteString] && [self.subtitles objectAtIndex:i]) {
            [tabsDataArray addObject:@{@"url" : [[[self.contentViews objectAtIndex:i] url] absoluteString], @"title" : [self.subtitles objectAtIndex:i]}];
        } else if ([[[self.contentViews objectAtIndex:i] url] absoluteString]) {
            [tabsDataArray addObject:@{@"url" : [[[self.contentViews objectAtIndex:i] url] absoluteString], @"title" : @""}];
        } else if ([_subtitles objectAtIndex:i]) {
            [tabsDataArray addObject:@{@"url" : @"", @"title" : [self.subtitles objectAtIndex:i]}];
        }
        
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"state.bin"];
    [NSKeyedArchiver archiveRootObject:@[[NSNumber numberWithInt:self.tabView.currentIndex], tabsDataArray] toFile:appFile];
}

- (void)getRestorableData {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"state.bin"];
    
    if ([[appDelegate.getSettings valueForKey:@"save-app-state"] boolValue]) {
        NSMutableArray *dataArray = [NSKeyedUnarchiver unarchiveObjectWithFile:appFile];
        
        if ([dataArray count] == 2) {
            appDelegate.restoredIndex = [[dataArray objectAtIndex:0] intValue];
            appDelegate.restoredData = [dataArray objectAtIndex:1];
        }
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:appFile error:nil];
        appDelegate.restoredIndex = 0;
        appDelegate.restoredData = nil;
    }
}


#pragma mark - UIViewController Methods

- (NSMutableArray *)subtitles {
    if (!_subtitles) {
        [self getRestorableData];
        _subtitles = [[NSMutableArray alloc] init];
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if ([appDelegate restoredData]) {
            for (int i = 0; i < [appDelegate restoredData].count; i++) {
                NSDictionary *params = [appDelegate restoredData][i];
                [_subtitles addObject:[params objectForKey:@"title"]];
            }
        }
        
        if ([appDelegate startUrl]) {
            [_subtitles addObject:[[appDelegate startUrl] host]];
        }
        
        if (![_subtitles count]) {
            _subtitles = @[NSLocalizedString(@"New tab", nil)].mutableCopy;
        }
    }
    
    return _subtitles;
}

- (NSMutableArray *)titles {
    if (!_titles) {
        _titles = [[NSMutableArray alloc] init];
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if ([appDelegate restoredData]) {
            for (int i = 0; i < [appDelegate restoredData].count; i++) {
                NSDictionary *params = [appDelegate restoredData][i];
                [_titles addObject:[params objectForKey:@"url"]];
            }
        }
        
        if ([appDelegate startUrl]) {
            [_titles addObject:[[appDelegate startUrl] absoluteString]];
        }
        
        int diff = (int)([self.subtitles count] - [_titles count]);
        
        if (diff > 0 && [_titles count] == 0) {
            [_titles addObject:[appDelegate homepage]];
        }
        
        diff--;
        
        for (int i = 0; i <= diff; i++) {
            [_titles addObject:@""];
        }
    }
    
    return _titles;
}

- (NSMutableArray *)tlsStatuses {
    if (!_tlsStatuses) {
        _tlsStatuses = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < [[self subtitles] count]; i++) {
            [_tlsStatuses addObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN]];
        }
    }
    
    return _tlsStatuses;
}

- (NSMutableArray *)contentViews {
    if (!_contentViews) {
        _contentViews = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < [[self subtitles] count]; i++) {
            WebViewTab *contentView = [[WebViewTab alloc] initWithFrame:self.tabView.bounds];
            [contentView setIndex:i];
            [contentView setParent:self];
            [_contentViews addObject:contentView];
        }
    }
    return _contentViews;
}

- (NSMutableArray *)progressValues {
    if (!_progressValues) {
        _progressValues = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < [[self subtitles] count]; i++) {
            [_progressValues addObject:[NSNumber numberWithFloat:0.0f]];
        }
    }
    
    return _progressValues;
}

- (UIBarButtonItem *)backBarButtonItem {
    if (!_backBarButtonItem) {
        _backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"Backward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(goBackTapped:)];
    }
    return _backBarButtonItem;
}

- (UIBarButtonItem *)forwardBarButtonItem {
    if (!_forwardBarButtonItem) {
        _forwardBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"Forward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(goForwardTapped:)];
        _forwardBarButtonItem.width = 18.0f;
    }
    return _forwardBarButtonItem;
}

- (UIBarButtonItem *)settingsBarButtonItem {
    if (!_settingsBarButtonItem) {
        _settingsBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"Settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(settingsTapped:)];
    }
    return _settingsBarButtonItem;
}

- (UIBarButtonItem *)onionBarButtonItem {
    if (!_onionBarButtonItem) {
        _onionBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"Onion"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(onionTapped:)];
    }
    return _onionBarButtonItem;
}

- (UIBarButtonItem *)deselectedSettingsBarButtonItem {
    if (!_deselectedSettingsBarButtonItem) {
        _deselectedSettingsBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"Settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(settingsTapped:)];
    }
    return _deselectedSettingsBarButtonItem;
}

- (void)updateNavigationItems {
    if (![_addressTextField isEditing])
        _addressTextField.text = [_titles objectAtIndex:self.tabView.currentIndex];
    
    self.backBarButtonItem.enabled = _webViewObject.canGoBack;
    self.forwardBarButtonItem.enabled = _webViewObject.canGoForward;
    
    UIButton *refreshStopButton = _webViewObject.isLoading ? _addressTextField.cancelButton : _addressTextField.refreshButton;
    refreshStopButton.hidden = _addressTextField.isEditing;
        
    _addressTextField.rightView = refreshStopButton;

    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    NSArray *items = [NSArray arrayWithObjects:fixedSpace, self.backBarButtonItem, flexibleSpace, self.forwardBarButtonItem, flexibleSpace, self.settingsBarButtonItem, flexibleSpace, self.onionBarButtonItem, flexibleSpace, _tabsBarButtonItem, fixedSpace, nil];
    
    self.selectedToolbar.items = items;
}

- (void)updateProgress:(float)progress animated:(BOOL)animated {
    [_progressView setProgress:progress animated:animated];
}

- (void)showProgressBarAnimated:(BOOL)animated {
    if (animated)
        [UIView animateWithDuration:0.2 animations:^{
            [_progressView setAlpha:1.0f];
        }];
    else
        [_progressView setAlpha:1.0f];
}

- (void)hideProgressBarAnimated:(BOOL)animated {
    if (animated)
        [UIView animateWithDuration:0.2 animations:^{
            [_progressView setAlpha:0.0f];
        }];
    else
        [_progressView setAlpha:0.0f];
}

- (void)prePopulateBookmarks {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSManagedObjectContext *context = [appDelegate managedObjectContext];
    NSError *error = nil;

    NSUInteger i = 0;
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"bookmarks.plist"];
    Boolean restored = NO;
    
    // Attempt to restore old bookmarks
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        NSDictionary *bookmarks = [[NSDictionary alloc] initWithContentsOfFile:path];
        
        NSNumber *v = [bookmarks objectForKey:@"version"];
        if (v != nil) {
            NSArray *tlist = [bookmarks objectForKey:@"bookmarks"];
            for (int i = 0; i < [tlist count]; i++) {
                Bookmark *bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
                [bookmark setTitle:[tlist[i] objectForKey:@"name"]];
                [bookmark setUrl:[tlist[i] objectForKey:@"url"]];
                [bookmark setOrder:i];
            }
        }
        
        if ([context save:&error])
            restored = YES;
        
        [fileManager removeItemAtPath:path error:nil];
    }
    
    if (!restored) {
        Bookmark *bookmark;
        
        bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
        [bookmark setTitle:NSLocalizedString(@"Search: DuckDuckGo", nil)];
        [bookmark setUrl:@"http://3g2upl4pq6kufc4m.onion/html/"];
        [bookmark setOrder:i++];
        
        bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
        [bookmark setTitle:NSLocalizedString(@"Search: DuckDuckGo (Plain HTTPS)", nil)];
        [bookmark setUrl:@"https://duckduckgo.com/html/"];
        [bookmark setOrder:i++];
        
        bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
        [bookmark setTitle:NSLocalizedString(@"IP Address Check", nil)];
        [bookmark setUrl:@"https://duckduckgo.com/lite/?q=what+is+my+ip"];
        [bookmark setOrder:i++];
        
        if (![context save:&error]) {
            NSLog(@"Error adding bookmarks: %@", error);
        }
    }
}

-(NSString *)isURL:(NSString *)userInput {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"TLDs" ofType:@"json"];
    NSString *jsonString = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSArray *urlEndings;
    
    if (!jsonString) {
#ifdef DEBUG
        NSLog(@"TLDs.json file not found! Defaulting to a shorter list.");
#endif
        urlEndings = @[@".com",@".co",@".net",@".io",@".org",@".edu",@".to",@".ly",@".gov",@".eu",@".cn",@".mil",@".gl",@".info",@".onion",@".uk",@".fr"];
    } else {
        NSError *error = nil;
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        urlEndings = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        
        if (error) {
#ifdef DEBUG
            NSLog(@"TLDs.json file not found! Defaulting to a shorter list.");
#endif
            urlEndings = @[@".com",@".co",@".net",@".io",@".org",@".edu",@".to",@".ly",@".gov",@".eu",@".cn",@".mil",@".gl",@".info",@".onion",@".uk",@".fr"];
        }
    }
    
    NSString *workingInput = @"";
    
    // Check if it's escaped
    if (![[userInput stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] isEqualToString:userInput])
        return nil;
    
    // Check if it's an IP address
    BOOL isIP = YES;
    NSString *ipString = [userInput stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    ipString = [ipString stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    
    if ([ipString rangeOfString: @"/"].location != NSNotFound)
        ipString = [ipString substringWithRange:NSMakeRange(0, [ipString rangeOfString: @"/"].location)];
    if ([ipString rangeOfString: @":"].location != NSNotFound)
        ipString = [ipString substringWithRange:NSMakeRange(0, [ipString rangeOfString: @":"].location)];
    
    NSArray *components = [ipString componentsSeparatedByString:@"."];
    if (components.count != 4)
        isIP = NO;

    NSCharacterSet *unwantedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
    if ([ipString rangeOfCharacterFromSet:unwantedCharacters].location != NSNotFound)
        isIP = NO;

    for (NSString *string in components) {
        if ((string.length < 1) || (string.length > 3 )) {
            isIP = NO;
        }
        if (string.intValue > 255) {
            isIP = NO;
        }
    }
    if  ([[components objectAtIndex:0]intValue]==0){
        isIP = NO;
    }
    
    if (isIP) {
        if (![userInput hasPrefix:@"http://"] && ![userInput hasPrefix:@"https://"])
            userInput = [@"http://" stringByAppendingString:userInput];
            
        return userInput;
    }
    
    // Check if it's another type of URL
    if ([userInput hasPrefix:@"http://"] || [userInput hasPrefix:@"https://"])
        workingInput = userInput;
    else if ([userInput hasPrefix:@"www."])
        workingInput = [@"http://" stringByAppendingString:userInput];
    else if ([userInput hasPrefix:@"m."])
        workingInput = [@"http://" stringByAppendingString:userInput];
    else if ([userInput hasPrefix:@"mobile."])
        workingInput = [@"http://" stringByAppendingString:userInput];
    else
        workingInput = [@"http://www." stringByAppendingString:userInput];
    
    NSURL *url = [NSURL URLWithString:workingInput];
    for (NSString *extension in urlEndings) {
        if ([url.host hasSuffix:extension]) {
            return workingInput;
        }
    }
    
    return nil;
}

- (void)webViewDidFinishLoading {
    if (_webViewObject.scrollView.contentSize.height <= SCREEN_HEIGHT)
        _webViewObject.frame =  CGRectMake(0, self.tabView.navigationBar.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - (44 + self.tabView.navigationBar.frame.size.height));
    else
        _webViewObject.frame =  CGRectMake(0, self.tabView.navigationBar.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - self.tabView.navigationBar.frame.size.height);
}

- (void)webViewDidStartLoading {
    int maxNavbarSize = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    [UIView animateWithDuration:0.2 animations:^{
        [self showNavigationBarAtFullHeight];
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
        _webViewObject.frame = CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
    }];
}

- (void)loadURL:(NSURL *)url {
    [self unibarStopEditing];
    
    NSString *urlProto = [[url scheme] lowercaseString];
    if ([urlProto isEqualToString:@"tob"]||[urlProto isEqualToString:@"tobs"]||[urlProto isEqualToString:@"http"]||[urlProto isEqualToString:@"https"]) {
        /***** One of our supported protocols *****/
        
        // Cancel any existing nav
        [_webViewObject stopLoading];
        
        // Build request and go.
        _webViewObject.scalesPageToFit = YES;
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [req setHTTPShouldUsePipelining:YES];
        [_webViewObject loadRequest:req];
        
        if ([urlProto isEqualToString:@"https"]) {
            [self.tlsStatuses replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInt:TLSSTATUS_SECURE]];
            [self showTLSStatus];
        } else if (urlProto && ![urlProto isEqualToString:@""]) {
            [self.tlsStatuses replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInt:TLSSTATUS_INSECURE]];
            [self showTLSStatus];
        } else {
            [self.tlsStatuses replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN]];
            [self showTLSStatus];
        }
    } else {
        /***** NOT a protocol that this app speaks, check with the OS if the user wants to *****/
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            //NSLog(@"can open %@", [navigationURL absoluteString]);
            NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"Tob cannot load a '%@' link, but another app you have installed can.\n\nNote that the other app will not load data over Tor, which could leak identifying information.\n\nDo you wish to proceed?", nil), url.scheme, nil];
            UIAlertView* alertView = [[UIAlertView alloc]
                                      initWithTitle:NSLocalizedString(@"Open Other App?", nil)
                                      message:msg
                                      delegate:nil
                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                      otherButtonTitles:NSLocalizedString(@"Open", nil), nil];
            alertView.delegate = self;
            alertView.tag = ALERTVIEW_EXTERN_PROTO;
            [alertView show];
            objc_setAssociatedObject(alertView, &AlertViewExternProtoUrl, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        } else {
            NSLog(@"cannot open %@", [url absoluteString]);
            return;
        }
    }
}

- (void)askToLoadURL:(NSURL *)url {
    /* Used on startup, if we opened the app from an outside source.
     * Will ask for user permission and display requested URL so that
     * the user isn't tricked into visiting a URL that includes their
     * IP address (or other info) that an attack site included when the user
     * was on the attack site outside of Tor.
     */
    NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"Another app has requested that Tob load the following link. Because the link is generated outside of Tor, please ensure that you trust the link & that the URL does not contain identifying information. Canceling will open the normal homepage.\n\n%@", nil), url.absoluteString, nil];
    UIAlertView* alertView = [[UIAlertView alloc]
                              initWithTitle:NSLocalizedString(@"Open This URL?", nil)
                              message:msg
                              delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              otherButtonTitles:NSLocalizedString(@"Open This Link", nil), nil];
    alertView.delegate = self;
    alertView.tag = ALERTVIEW_INCOMING_URL;
    [alertView show];
    objc_setAssociatedObject(alertView, &AlertViewIncomingUrl, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)addNewTabForURL:(NSURL *)url {
    [UIView animateWithDuration:(0.4) animations:^{
        [self.tabView deselectCurrentViewAnimated:NO];
        [self.tabView insertNewView];
        [self showNavigationBarAtFullHeight];
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        
        NSString *urlProto = [[url scheme] lowercaseString];
        if ([urlProto isEqualToString:@"https"]) {
            [self.tlsStatuses replaceObjectAtIndex:[self numberOfViewsInTabView:self.tabView] - 1 withObject:[NSNumber numberWithInt:TLSSTATUS_SECURE]];
            [self showTLSStatus];
        } else if (urlProto && ![urlProto isEqualToString:@""]) {
            [self.tlsStatuses replaceObjectAtIndex:[self numberOfViewsInTabView:self.tabView] - 1 withObject:[NSNumber numberWithInt:TLSSTATUS_INSECURE]];
            [self showTLSStatus];
        } else {
            [self.tlsStatuses replaceObjectAtIndex:[self numberOfViewsInTabView:self.tabView] - 1 withObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN]];
            [self showTLSStatus];
        }
        
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [[self.contentViews objectAtIndex:[self numberOfViewsInTabView:self.tabView] - 1] loadRequest:request];
        [self.view bringSubviewToFront:self.selectedToolbar];
    }];
}

- (void)stopLoading {
    for (WebViewTab *tab in self.contentViews) {
        [tab stopLoading];
    }
}

- (void)updateTorProgress:(NSNumber *)progress {
    [_torProgressView setProgress:[progress floatValue] animated:YES];
}

- (void)refreshCurrentTab {
    if (_webViewObject)
        [_webViewObject reload];
}

- (void)setTabsNeedForceRefresh:(BOOL)needsForceRefresh {
    for (int i = 0; i < [[self subtitles] count]; i++) {
        [[[self contentViews] objectAtIndex:i] setNeedsForceRefresh:needsForceRefresh];
    }
}

- (void)removeTorProgressView {
    [_torLoadingView removeFromSuperview];
    [_torDarkBackgroundView removeFromSuperview];
    _torLoadingView = nil;
    _torDarkBackgroundView = nil;
    
    // Don't load the tabs in the background
    for (int i = 0; i < [[self subtitles] count]; i++) {
        [[[self contentViews] objectAtIndex:i] setNeedsForceRefresh:YES];
        [[[self contentViews] objectAtIndex:i] setUrl:[NSURL URLWithString:[self.titles objectAtIndex:i]]];
    }
    
    // Load the current tab
    NSURL *url = [NSURL URLWithString:[[self titles] objectAtIndex:self.tabView.currentIndex]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [[[self contentViews] objectAtIndex:self.tabView.currentIndex] setNeedsForceRefresh:NO];
    
    NSString *urlProto = [[url scheme] lowercaseString];
    if ([urlProto isEqualToString:@"https"]) {
        [self.tlsStatuses replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInt:TLSSTATUS_SECURE]];
        [self showTLSStatus];
    } else if (urlProto && ![urlProto isEqualToString:@""]){
        [self.tlsStatuses replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInt:TLSSTATUS_INSECURE]];
        [self showTLSStatus];
    } else {
        [self.tlsStatuses replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN]];
        [self showTLSStatus];
    }
    
    [[[self contentViews] objectAtIndex:self.tabView.currentIndex] loadRequest:request];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.restoredIndex = 0;
    appDelegate.restoredData = nil;
}

- (void)renderTorStatus:(NSString *)statusLine {
    NSRange progress_loc = [statusLine rangeOfString:@"BOOTSTRAP PROGRESS="];
    NSRange progress_r = {
        progress_loc.location+progress_loc.length,
        3
    };
    NSString *progress_str = @"";
    if (progress_loc.location != NSNotFound)
        progress_str = [statusLine substringWithRange:progress_r];
    
    progress_str = [progress_str stringByReplacingOccurrencesOfString:@"%%" withString:@""];
    progress_str = [progress_str stringByReplacingOccurrencesOfString:@" T" withString:@""]; // Remove a T which sometimes appears
    
    NSRange summary_loc = [statusLine rangeOfString:@" SUMMARY="];
    NSString *summary_str = @"";
    if (summary_loc.location != NSNotFound)
        summary_str = [statusLine substringFromIndex:summary_loc.location+summary_loc.length+1];
    NSRange summary_loc2 = [summary_str rangeOfString:@"\""];
    if (summary_loc2.location != NSNotFound)
        summary_str = [summary_str substringToIndex:summary_loc2.location];
    
    [self performSelectorOnMainThread:@selector(updateTorProgress:) withObject:[NSNumber numberWithFloat:[progress_str intValue]/100.0] waitUntilDone:NO];
    _torProgressDescription.text = [NSString stringWithFormat:@"%@%% - %@", progress_str, summary_str];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // Log the progress if it hasn't been logged yet
    if ([appDelegate.logViewController.logTextView.text rangeOfString:[@"[tor] " stringByAppendingString:_torProgressDescription.text]].location == NSNotFound)
        [appDelegate.logViewController logInfo:[@"[tor] " stringByAppendingString:_torProgressDescription.text]];
    
    if ([progress_str isEqualToString:@"100"]) {
        [self performSelectorOnMainThread:@selector(removeTorProgressView) withObject:nil waitUntilDone:NO];
    }
}

- (void)displayTorPanel {
    _torPanelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 120)];
    _torPanelView.center = self.view.center;
    _torPanelView.layer.cornerRadius = 5.0f;
    _torPanelView.layer.masksToBounds = YES;
    _torPanelView.alpha = 0;
    
    _torDarkBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    _torDarkBackgroundView.backgroundColor = [UIColor blackColor];
    _torDarkBackgroundView.alpha = 0;
    
    [self.view addSubview:_torDarkBackgroundView];
    [self.view addSubview:_torPanelView];
    
    UILabel *torTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 30)];
    torTitle.text = NSLocalizedString(@"Tor panel", nil);
    torTitle.font = [UIFont systemFontOfSize:20.0f];
    torTitle.textAlignment = NSTextAlignmentCenter;
    [_torPanelView addSubview:torTitle];
    
    UIButton *closeButton = [[UIButton alloc] initWithFrame:CGRectMake(260, 10, 30, 30)];
    [closeButton setTitle:[NSString stringWithFormat:@"%C", 0x2715] forState:UIControlStateNormal];
    [closeButton.titleLabel setFont:[UIFont systemFontOfSize:25.0f weight:UIFontWeightLight]];
    [closeButton addTarget:self action:@selector(hideTorPanel) forControlEvents:UIControlEventTouchUpInside];
    [_torPanelView addSubview:closeButton];
    
    UIButton *logButton = [[UIButton alloc] initWithFrame:CGRectMake(13, 13, 24, 24)];
    [logButton setImage:[[UIImage imageNamed:@"Log"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [logButton addTarget:self action:@selector(showLog) forControlEvents:UIControlEventTouchUpInside];
    [_torPanelView addSubview:logButton];
    
    _IPAddressLabel = [[UILabel alloc] initWithFrame:CGRectMake(25, 45, 250, 30)];
    
    if (_IPAddress)
        _IPAddressLabel.text = [NSString stringWithFormat:NSLocalizedString(@"IP: %@", nil), _IPAddress];
    else {
        _IPAddressLabel.text = NSLocalizedString(@"IP: Loading…", nil);
        [self getIPAddress];
    }
    
    _IPAddressLabel.textAlignment = NSTextAlignmentLeft;
    [_torPanelView addSubview:_IPAddressLabel];
    
    UIButton *newIdentityButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 80, 135, 30)];
    newIdentityButton.titleLabel.numberOfLines = 1;
    newIdentityButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    newIdentityButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    [newIdentityButton setTitle:NSLocalizedString(@"New identity", nil) forState:UIControlStateNormal];
    [newIdentityButton addTarget:self action:@selector(newIdentity) forControlEvents:UIControlEventTouchUpInside];
    [_torPanelView addSubview:newIdentityButton];
    
    UIButton *addBridgeButton = [[UIButton alloc] initWithFrame:CGRectMake(155, 80, 135, 30)];
    addBridgeButton.titleLabel.numberOfLines = 1;
    addBridgeButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    addBridgeButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    [addBridgeButton setTitle:NSLocalizedString(@"Add bridge", nil) forState:UIControlStateNormal];
    [addBridgeButton addTarget:self action:@selector(openBridgeView) forControlEvents:UIControlEventTouchUpInside];
    [_torPanelView addSubview:addBridgeButton];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;
    
    if (![[settings valueForKey:@"night-mode"] boolValue]) {
        _torPanelView.backgroundColor = [UIColor groupTableViewBackgroundColor];
        torTitle.textColor = [UIColor blackColor];
        [closeButton setTitleColor:self.view.tintColor forState:UIControlStateNormal];
        [logButton setTintColor:self.view.tintColor];
        _IPAddressLabel.textColor = [UIColor blackColor];
        [newIdentityButton setTitleColor:self.view.tintColor forState:UIControlStateNormal];
        [addBridgeButton setTitleColor:self.view.tintColor forState:UIControlStateNormal];
    } else {
        _torPanelView.backgroundColor = [UIColor darkGrayColor];
        torTitle.textColor = [UIColor whiteColor];
        [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [logButton setTintColor:[UIColor whiteColor]];
        _IPAddressLabel.textColor = [UIColor whiteColor];
        [newIdentityButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [addBridgeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    [self.view bringSubviewToFront:_torDarkBackgroundView];
    [self.view bringSubviewToFront:_torPanelView];
    
    [UIView animateWithDuration:0.3 animations:^{
        _torDarkBackgroundView.alpha = 0.5f;
        _torPanelView.alpha = 1.0f;
    }];
}

- (void)hideTorPanel {
    [UIView animateWithDuration:0.3 animations:^{
        _torDarkBackgroundView.alpha = 0;
        _torPanelView.alpha = 0;
    } completion:^(BOOL finished) {
        [_torDarkBackgroundView removeFromSuperview];
        [_torPanelView removeFromSuperview];
        _torDarkBackgroundView = nil;
        _torPanelView = nil;
    }];
}

- (void)showLog {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionPush;
    transition.subtype = kCATransitionFromRight;
    [self.view.window.layer addAnimation:transition forKey:nil];
    [self presentViewController:appDelegate.logViewController animated:NO completion:nil];
}

- (void)showTLSStatus {
    if ([self.tlsStatuses objectAtIndex:self.tabView.currentIndex] == [NSNumber numberWithInt:TLSSTATUS_HIDDEN] || [_addressTextField isFirstResponder]) {
        [_addressTextField setLeftViewMode:UITextFieldViewModeNever];
    } else if ([self.tlsStatuses objectAtIndex:self.tabView.currentIndex] == [NSNumber numberWithInt:TLSSTATUS_SECURE]) {
        [_addressTextField setLeftViewMode:UITextFieldViewModeAlways];
        [_addressTextField.tlsButton setImage:[[UIImage imageNamed:@"Lock"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    } else {
        [_addressTextField setLeftViewMode:UITextFieldViewModeAlways];
        [_addressTextField.tlsButton setImage:[[UIImage imageNamed:@"BrokenLock"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    }
}

- (void)hideTLSStatus {
    [_addressTextField setLeftViewMode:UITextFieldViewModeNever];
}

// Get IP Address
- (void)getIPAddress {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.tor requestTorInfo];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int currentIndentityNumber = _newIdentityNumber;
        
        NSURL *URL = [[NSURL alloc] initWithString:@"https://api.duckduckgo.com/?q=my+ip&l=1&no_redirect=1&format=json"];
        NSData *data = [NSData dataWithContentsOfURL:URL];
        
        if (data) {
            NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            
            NSString *IP = [dictionary objectForKey:@"Answer"];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" options:0 error:NULL];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (IP && _newIdentityNumber == currentIndentityNumber) {
                    NSArray *matches = [regex matchesInString:IP options:0 range:NSMakeRange(0, [IP length])];
                    if ([matches count] > 0) {
                        // Extract only the IP address without the text arround it
                        _IPAddress = [IP substringWithRange:[[matches objectAtIndex:0] range]];
                        _IPAddressLabel.text = [NSString stringWithFormat:NSLocalizedString(@"IP: %@", nil), _IPAddress];
                    } else {
                        [self getIPAddress]; // Try again
                        _IPAddressLabel.text = NSLocalizedString(@"IP: Error, trying again…", nil);
                    }
                } else if (_newIdentityNumber == currentIndentityNumber) {
                    [self getIPAddress]; // Try again
                    _IPAddressLabel.text = NSLocalizedString(@"IP: Error, trying again…", nil);
                }
            });
        } else if (_newIdentityNumber == currentIndentityNumber) {
            [self getIPAddress]; // Try again
            _IPAddressLabel.text = NSLocalizedString(@"IP: Error, trying again…", nil);
        }
    });
}


#pragma mark - Target actions

- (void)goBackTapped:(UIBarButtonItem *)sender {
    [_webViewObject stopLoading];
    [_webViewObject goBack];
}

- (void)goForwardTapped:(UIBarButtonItem *)sender {
    [_webViewObject stopLoading];
    [_webViewObject goForward];
}

- (void)refreshTapped:(UIBarButtonItem *)sender {
    [_webViewObject reload];
}

- (void)stopTapped:(UIBarButtonItem *)sender {
    [_webViewObject stopLoading];
    [self updateNavigationItems];
}

- (void)settingsTapped:(UIBarButtonItem *)sender {
    // Increment the rating counter, and show it if the requirements are met
    [[iRate sharedInstance] logEvent:NO];
    [self openSettingsView];
}

- (void)onionTapped:(UIBarButtonItem *)sender {
    [self displayTorPanel];
}

- (void)newIdentity {
    [self hideTorPanel];
    
    _newIdentityNumber ++;
    _IPAddress = nil;
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate wipeAppData];
    [appDelegate.tor requestNewTorIdentity];
    
    for (int i = 0; i < [[self contentViews] count]; i++) {
        if (i != self.tabView.currentIndex)
            [[[self contentViews] objectAtIndex:i] setNeedsForceRefresh:YES];
        else
            [[[self contentViews] objectAtIndex:i] reload];
    }
}

- (void)openBridgeView {
    [self hideTorPanel];
    
    BridgeViewController *bridgesVC = [[BridgeViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:navController animated:YES completion:nil];
}

-(void)openSettingsView {
    SettingsTableViewController *settingsController = [[SettingsTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *settingsNavController = [[UINavigationController alloc]
                                                     initWithRootViewController:settingsController];
    
    [self presentViewController:settingsNavController animated:YES completion:nil];
}


#pragma mark - Gesture recognizer

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)singleTapGestureCaptured:(UITapGestureRecognizer *)gesture {
    CGPoint touchPoint = [gesture locationInView:_webViewObject];
    int screenWidth = [[UIScreen mainScreen] bounds].size.width;
    if (CGRectContainsPoint(CGRectMake(0, _webViewObject.frame.size.height - 44, screenWidth, 44), touchPoint)) {
        [UIView animateWithDuration:kNavigationBarAnimationTime animations:^{
            [self showNavigationBarAtFullHeight];
        }];
    }
}


#pragma mark - uniBar

- (void)cancel {
    _addressTextField.selectedTextRange = nil;
    [self unibarStopEditing];
}

- (void)updateUnibar {
    _addressTextField.placeholder = [NSString stringWithFormat:NSLocalizedString(@"Search or enter an address", @"Search or enter an address")];
}

- (void)unibarStopEditing {
    if ([_addressTextField isFirstResponder]) {
        [_addressTextField resignFirstResponder];
        
        [_bookmarks.tableView removeFromSuperview];
        _addressTextField.textAlignment = NSTextAlignmentCenter;
        _addressTextField.clearButtonMode = UITextFieldViewModeNever;
        
        [UIView animateWithDuration:kNavigationBarAnimationTime animations:^{
            [self showNavigationBarAtFullHeight];
            self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
            _cancelButton.alpha = 0.0;
            
        } completion:^(BOOL finished) {
            _addressTextField.refreshButton.hidden = NO;
            _addressTextField.rightViewMode = UITextFieldViewModeAlways;
            _addressTextFieldEditing = YES;
        }];
    }
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField.frame.size.height == UNIBAR_FINISHED_HEIGHT) {
        [UIView animateWithDuration:kNavigationBarAnimationTime animations:^{
            [self showNavigationBarAtFullHeight];
            self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
        }];
        
        return NO;
    }
    
    [self hideTLSStatus];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _addressTextFieldEditing = YES;
    _addressTextField.refreshButton.hidden = YES;
    _addressTextField.rightViewMode = UITextFieldViewModeNever;
    _addressTextField.textAlignment = NSTextAlignmentLeft;
    
    _addressTextField.clearButtonMode = UITextFieldViewModeAlways;
    
    // Get current selected range , this example assumes is an insertion point or empty selection
    UITextRange *selectedRange = [textField selectedTextRange];
    
    // Calculate the new position, - for left and + for right
    UITextPosition *newPosition = [textField positionFromPosition:selectedRange.start offset:-textField.text.length];
    
    // Construct a new range using the object that adopts the UITextInput, our textfield
    UITextRange *newRange = [textField textRangeFromPosition:newPosition toPosition:selectedRange.start];
    
    // Set new range
    [textField setSelectedTextRange:newRange];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (_bookmarks == nil) {
        _bookmarks = [[BookmarkTableViewController alloc] init];
        
        NSManagedObjectContext *context = [appDelegate managedObjectContext];
        _bookmarks.managedObjectContext = context;
        
        _bookmarks.view.frame = CGRectMake(0, [[UIApplication sharedApplication] statusBarFrame].size.height + 44, SCREEN_WIDTH, SCREEN_HEIGHT - ([[UIApplication sharedApplication] statusBarFrame].size.height + 44));
    }
    
    NSMutableDictionary *settings = appDelegate.getSettings;
    if (![[settings valueForKey:@"night-mode"] boolValue])
        [_bookmarks setLightMode];
    else
        [_bookmarks setDarkMode];
    
    [_bookmarks setEmbedded:YES];
    
    [UIView animateWithDuration:kNavigationBarAnimationTime animations:^{
        [self showNavigationBarAtFullHeight];
        CGRect unibarFrame = _addressTextField.frame;
        unibarFrame.size.width = unibarFrame.size.width - 60;
        _addressTextField.frame = unibarFrame;
        _cancelButton.alpha = 1.0;
        [self.view addSubview:_bookmarks.tableView];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self unibarStopEditing];
    [self showTLSStatus];
    
    NSString *urlString = [self isURL:textField.text];
    if (urlString) {
        if ([urlString hasPrefix:@"https"])
            [[self tlsStatuses] replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInteger:TLSSTATUS_SECURE]];
        else
            [[self tlsStatuses] replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInteger:TLSSTATUS_INSECURE]];
        
        NSURL *url = [NSURL URLWithString:urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [_webViewObject loadRequest:request];
    } else {
        BOOL javascriptEnabled = true;
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger js_setting = [[settings valueForKey:@"javascript-toggle"] integerValue];
        NSInteger csp_setting = [[settings valueForKey:@"javascript"] integerValue];
        
        if (csp_setting == CONTENTPOLICY_STRICT || js_setting == JS_BLOCKED)
            javascriptEnabled = false;
        
        NSString *searchEngine = [settings valueForKey:@"search-engine"];
        NSDictionary *searchEngineURLs = [NSMutableDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"searchEngineURLs.plist"]];
        
        if (javascriptEnabled)
            urlString = [[NSString stringWithFormat:[[searchEngineURLs objectForKey:searchEngine] objectForKey:@"search"], textField.text] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        else
            urlString = [[NSString stringWithFormat:[[searchEngineURLs objectForKey:searchEngine] objectForKey:@"search_no_js"], textField.text] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        if ([urlString hasPrefix:@"https"])
            [[self tlsStatuses] replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInteger:TLSSTATUS_SECURE]];
        else
            [[self tlsStatuses] replaceObjectAtIndex:self.tabView.currentIndex withObject:[NSNumber numberWithInteger:TLSSTATUS_INSECURE]];
        
        NSURL *url = [NSURL URLWithString:urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [_webViewObject loadRequest:request];
    }
    
    return YES;
}


#pragma mark - TabViewDataSource

- (UIView *)tabView:(MOTabView *)tabView viewForIndex:(NSUInteger)index {
    if (![self.contentViews objectAtIndex:index]) {
        WebViewTab *contentView = [[WebViewTab alloc] initWithFrame:tabView.bounds];
        [contentView setIndex:index];
        [contentView setParent:self];
        [self.contentViews replaceObjectAtIndex:index withObject:contentView];
        [self.tlsStatuses replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN]];
        return contentView;
    } else {
        [self.view bringSubviewToFront:[self.contentViews objectAtIndex:index]];
        [[self.contentViews objectAtIndex:index] setIndex:index];
        [[self.contentViews objectAtIndex:index] setParent:self];
        return [self.contentViews objectAtIndex:index];
    }
}

- (NSUInteger)numberOfViewsInTabView:(MOTabView *)tabView {
    return self.subtitles.count;
}

- (NSString *)titleForIndex:(NSUInteger)index {
    return [self.titles objectAtIndex:index];
}

- (NSString *)subtitleForIndex:(NSUInteger)index {
    return [self.subtitles objectAtIndex:index];
}


#pragma mark - TabViewDelegate

- (void)tabView:(MOTabView *)tabView willEditView:(MOTabViewEditingStyle)editingStyle atIndex:(NSUInteger)index {
    [super tabView:tabView willEditView:editingStyle atIndex:index];
    
    if (editingStyle == MOTabViewEditingStyleDelete) {
        [self.contentViews[index] stopLoading];
        [self.titles removeObjectAtIndex:index];
        [self.subtitles removeObjectAtIndex:index];
        [self.contentViews removeObjectAtIndex:index];
        [self.tlsStatuses removeObjectAtIndex:index];
        [self.progressValues removeObjectAtIndex:index];
    } else if (editingStyle == MOTabViewEditingStyleUserInsert) {
        [self.titles insertObject:@"" atIndex:index];
        [self.subtitles insertObject:NSLocalizedString(@"New tab", nil) atIndex:index];
        WebViewTab *contentView = [[WebViewTab alloc] initWithFrame:tabView.bounds];
        [contentView setIndex:index];
        [contentView setParent:self];
        [self.contentViews insertObject:contentView atIndex:index];
        [self.tlsStatuses insertObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN] atIndex:index];
        [self.progressValues insertObject:[NSNumber numberWithFloat:0.0f] atIndex:index];
    }
}

- (void)tabView:(MOTabView *)tabView willSelectViewAtIndex:(NSUInteger)index {
    [super tabView:tabView willSelectViewAtIndex:index];
    
    if (index < [self.contentViews count]) {
        _webViewObject = [self.contentViews objectAtIndex:index];
        [UIView animateWithDuration:0.3
                         animations:^{
                             // Move the webView down so that it's not hidden by the navbar
                             if (_webViewObject.scrollView.contentSize.height <= SCREEN_HEIGHT)
                                 _webViewObject.frame =  CGRectMake(0, self.tabView.navigationBar.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - (44 + self.tabView.navigationBar.frame.size.height));
                             else
                                 _webViewObject.frame =  CGRectMake(0, self.tabView.navigationBar.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - self.tabView.navigationBar.frame.size.height);
                             [[_webViewObject scrollView] setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
                         }
                         completion:nil];
    }
}

- (void)tabView:(MOTabView *)tabView didSelectViewAtIndex:(NSUInteger)index {
    [super tabView:tabView didSelectViewAtIndex:index];
    
    _webViewObject = [self.contentViews objectAtIndex:index];
    // Re-animate it case it hasn't been done on "willSelectViewAtIndex"
    [UIView animateWithDuration:0.3
                     animations:^{
                         // Move the webView down so that it's not hidden by the navbar
                         if (_webViewObject.scrollView.contentSize.height <= SCREEN_HEIGHT)
                             _webViewObject.frame =  CGRectMake(0, self.tabView.navigationBar.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - (44 + self.tabView.navigationBar.frame.size.height));
                         else
                             _webViewObject.frame =  CGRectMake(0, self.tabView.navigationBar.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - self.tabView.navigationBar.frame.size.height);
                         [[_webViewObject scrollView] setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
                     }
                     completion:nil];
    
    _webViewObject.scrollView.delegate = self;
    _webViewObject.delegate = (WebViewTab *)_webViewObject;
    
    [(UIScrollView *)[_webViewObject.subviews objectAtIndex:0] setScrollsToTop:YES];
    [self.view bringSubviewToFront:self.selectedToolbar];
    _progressView.hidden = NO;
    [_progressView setProgress:[[_progressValues objectAtIndex:index] floatValue]];
    
    UIButton *refreshStopButton = _webViewObject.isLoading ? _addressTextField.cancelButton : _addressTextField.refreshButton;
    _addressTextField.rightView = refreshStopButton;
    
    if ([self.progressValues objectAtIndex:index] == [NSNumber numberWithFloat:1.0f]) {
        _progressView.alpha = 0.0f; // Done loading for this page, don't show the progress
    }
    
    if ([[self.titles objectAtIndex:index] isEqualToString:@""] && ![_webViewObject isLoading]) {
        [_addressTextField becomeFirstResponder];
        _progressView.alpha = 0.0f;
    }
    
    [self showTLSStatus];
    
    if ([(WebViewTab *)_webViewObject needsForceRefresh]) {
        NSURL *url = [NSURL URLWithString:[self.titles objectAtIndex:index]];
        
        NSString *urlProto = [[url scheme] lowercaseString];
        if ([urlProto isEqualToString:@"https"]) {
            [self.tlsStatuses replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:TLSSTATUS_SECURE]];
            [self showTLSStatus];
        } else if (urlProto && ![urlProto isEqualToString:@""]) {
            [self.tlsStatuses replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:TLSSTATUS_INSECURE]];
            [self showTLSStatus];
        } else {
            [self.tlsStatuses replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:TLSSTATUS_HIDDEN]];
            [self showTLSStatus];
        }
        
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [_webViewObject loadRequest:request];
        [(WebViewTab *)_webViewObject setNeedsForceRefresh:NO];
    }
}

- (void)tabView:(MOTabView *)tabView willDeselectViewAtIndex:(NSUInteger)index {
    [super tabView:tabView willDeselectViewAtIndex:index];
    
    [self unibarStopEditing];
    [(UIScrollView *)[_webViewObject.subviews objectAtIndex:0] setScrollsToTop:NO];
    _webViewObject = nil;

    [UIView animateWithDuration:0.2
                     animations:^{
                         // Move the webView down so that it's not hidden by the navbar
                         ((WebViewTab *)[self.contentViews objectAtIndex:index]).frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
                     }
                     completion:nil];
    
    _progressView.hidden = YES;
}


#pragma mark - Scrollview Delegate

- (void)showNavigationBarAtFullHeight {
    // Navigation
    int maxNavbarSize = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    self.tabView.navigationBar.frame = CGRectMake(0, 0, SCREEN_WIDTH, maxNavbarSize);
    
    // Address Bar
    _addressTextField.frame = CGRectMake(UNIBAR_DEFAULT_X, UNIBAR_DEFAULT_Y, UNIBAR_DEFAULT_WIDTH, UNIBAR_DEFAULT_HEIGHT);
    _addressTextField.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];
    ((UIView *)_addressTextField.subviews[0]).alpha = 1.0;
    
    _addressTextField.refreshButton.alpha = 1.0;
    _addressTextField.refreshButton.frame = CGRectMake(_addressTextField.frame.size.width - 29, 0, 29, 29);
    
    _addressTextField.tlsButton.alpha = 1.0;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    int maxNavbarSize = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    [UIView animateWithDuration:0.2 animations:^{
        [self showNavigationBarAtFullHeight];
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
        _webViewObject.frame = CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
    }];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _userScrolling = YES;
    _initialScrollOffset = scrollView.contentOffset;
    [self unibarStopEditing];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!_userScrolling) return;
    
    int minNavbarSize = 20 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    int maxNavbarSize = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    if (scrollView.contentSize.height <= SCREEN_HEIGHT) {
        // Page is less than/= to the screens height, no need to scroll anything.
        _webViewObject.frame =  CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - (maxNavbarSize + 44));
        [self showNavigationBarAtFullHeight];
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
        
        [[_webViewObject scrollView] setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
        [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
        return;
    } else
        [[_webViewObject scrollView] setContentInset:UIEdgeInsetsMake(0, 0, 44, 0)];
    
    if (scrollView.contentOffset.y <= 0) {
        // Scrolling above the page
        [self showNavigationBarAtFullHeight];
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
        _webViewObject.frame = CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
    }
    
    CGFloat contentOffset = scrollView.contentOffset.y - _initialScrollOffset.y;
    if (scrollView.contentOffset.y <= 24) {
        contentOffset = scrollView.contentOffset.y;
    } else {
        if (contentOffset < 0 && (scrollView.contentOffset.y - _previousScrollOffset.y) > 0) {
            _initialScrollOffset = scrollView.contentOffset;
        }
    }
    contentOffset = roundf(contentOffset);
    if (contentOffset <= 24 && contentOffset >= 0) {
        // Perform the animation if the offset of current position is less than/= to 24. but above 0
        CGRect navFrame = self.tabView.navigationBar.frame;
        if (scrollView.contentOffset.y < _previousScrollOffset.y) {
            // Up
            if (navFrame.size.height == maxNavbarSize) {
                _skipScrolling = YES;
            }
        }
        
        if (navFrame.size.height == minNavbarSize && scrollView.contentOffset.y > 24) {
            // If the height is minNavbarSize already, skip.
            _skipScrolling = YES;
        }
        
        if (_skipScrolling == NO) {
            // If everything else passes and skip scrolling is NO, perform scrolling animation
            navFrame.size.height = maxNavbarSize - contentOffset;
            if (navFrame.size.height <= maxNavbarSize && navFrame.size.height >= minNavbarSize) {
                self.tabView.navigationBar.frame = navFrame;
                _webViewObject.frame = CGRectMake(0, maxNavbarSize - (maxNavbarSize - navFrame.size.height), SCREEN_WIDTH, SCREEN_HEIGHT - (maxNavbarSize - (maxNavbarSize - navFrame.size.height)));
                
                CGFloat XOffset = (contentOffset - 2) * 2;
                if (XOffset < 0) {
                    XOffset = 0;
                }
                CGFloat X = 12 + XOffset;
                
                CGFloat Y = UNIBAR_DEFAULT_Y - (contentOffset / 3.42857143);
                
                CGFloat widthOffset = (contentOffset - 2) * 4.04545455;
                if (widthOffset < 0) {
                    widthOffset = 0;
                }
                CGFloat width = UNIBAR_DEFAULT_WIDTH - widthOffset;
                
                // 29 to 20
                CGFloat height = UNIBAR_DEFAULT_HEIGHT - (contentOffset / 2.66666667);
                
                _addressTextField.frame = CGRectMake(X, Y, width, height);
                
                // Font and alpha
                CGFloat fontSize = (navFrame.size.height + (20 - [[UIApplication sharedApplication] statusBarFrame].size.height)) / 3.764; // We always want the initial size to be 64 / 3.764
                if (fontSize < 11.0f) { // The minimum font size should be 11, otherwise it's unreadable
                    fontSize = 11.0f;
                }
                _addressTextField.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:fontSize];
                ((UIView *)_addressTextField.subviews[0]).alpha = 1.0 - ((maxNavbarSize - navFrame.size.height) * (1.0 / 24));
                _addressTextField.refreshButton.alpha = 1.0 - ((maxNavbarSize - navFrame.size.height) * (1.0 / 24));
                _addressTextField.tlsButton.alpha = _addressTextField.refreshButton.alpha;
            }
        }
    }
    else if (contentOffset > 24) {
        // Scrolled past the initial animation point. Small navigation bar
        self.tabView.navigationBar.frame = CGRectMake(0, 0, SCREEN_WIDTH, minNavbarSize);
        _addressTextField.frame = CGRectMake(UNIBAR_FINISHED_X, UNIBAR_FINISHED_Y, UNIBAR_FINISHED_WIDTH, UNIBAR_FINISHED_HEIGHT);
        _addressTextField.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:11];
        ((UIView *)_addressTextField.subviews[0]).alpha = 0;
        _addressTextField.refreshButton.alpha = 0.0;
        _addressTextField.refreshButton.frame = CGRectMake(179, -5, 29, 29);
        _addressTextField.tlsButton.alpha = 0.0;
        _webViewObject.frame = CGRectMake(0, minNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - minNavbarSize);
    }
    
    if (scrollView.contentOffset.y <= 0) {
        self.tabView.navigationBar.frame = CGRectMake(0, 0, SCREEN_WIDTH, maxNavbarSize);
        _addressTextField.frame = CGRectMake(UNIBAR_DEFAULT_X, UNIBAR_DEFAULT_Y, UNIBAR_DEFAULT_WIDTH, UNIBAR_DEFAULT_HEIGHT);
        _addressTextField.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];
        ((UIView *)_addressTextField.subviews[0]).alpha = 1;
        _webViewObject.frame = CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
    }
    
    // Toolbar
    if (scrollView.contentOffset.y >= 0 && scrollView.contentOffset.y <= 44) {
        if (scrollView.contentOffset.y < _previousScrollOffset.y && self.selectedToolbar.frame.origin.y == SCREEN_HEIGHT - 44) {
            // Up
            return;
        }
        _toolbarUpInMiddleOfPageNowScrollingDown = NO;
        // Scrolling near the top
        CGRect toolbarFrame = self.selectedToolbar.frame;
        toolbarFrame.origin.y = (SCREEN_HEIGHT - 44) + scrollView.contentOffset.y;
        self.selectedToolbar.frame = toolbarFrame;
        
        CGFloat bottomInset = 44 - scrollView.contentOffset.y;
        if (bottomInset > 0 && bottomInset <= maxNavbarSize) {
            //[[webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, bottomInset+((webViewObject.frame.origin.y+528)-SCREEN_HEIGHT), 0)];
            [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, bottomInset, 0)];
        }
    }
    else if ((scrollView.contentOffset.y >= 45 && self.selectedToolbar.frame.origin.y == SCREEN_HEIGHT - 44) || _toolbarUpInMiddleOfPageNowScrollingDown) {
        if (scrollView.contentOffset.y < _previousScrollOffset.y) {
            // Up
        }
        else {
            // Down
            _toolbarUpInMiddleOfPageNowScrollingDown = YES;
            CGRect toolbarFrame = self.selectedToolbar.frame;
            toolbarFrame.origin.y = (SCREEN_HEIGHT - 44) + contentOffset;
            self.selectedToolbar.frame = toolbarFrame;
            if (toolbarFrame.origin.y == SCREEN_HEIGHT) {
                _toolbarUpInMiddleOfPageNowScrollingDown = NO;
            }
            
        }
    }
    else if (scrollView.contentOffset.y >= 45) {
        if (scrollView.contentOffset.y >= _previousScrollOffset.y) {
            // Down
            self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 44);
            [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
        }
    }
    else if (scrollView.contentOffset.y < 0) {
        [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 44, 0)];
    }
    
    // Bottom of page
    CGFloat fromBottomOffset = ((scrollView.contentOffset.y + _webViewObject.frame.size.height) - scrollView.contentSize.height);
    if (scrollView.contentOffset.y + _webViewObject.frame.size.height >= scrollView.contentSize.height && fromBottomOffset <= 44) {
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - fromBottomOffset, SCREEN_WIDTH, 44);
        [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, fromBottomOffset, 0)];
    }
    else if (fromBottomOffset > 44) {
        self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
        [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 44, 0)];
    }
    
    if (scrollView.contentOffset.y + scrollView.frame.size.height <= scrollView.contentSize.height) {
        _previousScrollOffset = scrollView.contentOffset;
    }
    
    _skipScrolling = NO;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    int minNavbarSize = 20 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    int maxNavbarSize = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    if (velocity.y < -1.5) {
        _userScrolling = NO;
        if (self.tabView.navigationBar.frame.size.height == minNavbarSize) {
            [UIView animateWithDuration:kNavigationBarAnimationTime animations:^{
                [self showNavigationBarAtFullHeight];
                self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
                _webViewObject.frame = CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
            }];
        }
    } else {
        if (self.tabView.navigationBar.frame.size.height < maxNavbarSize - 10 && self.selectedToolbar.frame.origin.y > SCREEN_HEIGHT - 44) {
            // If self.selectedToolbar.frame.origin.y == SCREEN_HEIGHT - 44, we are at the bottom of the page so we shouldn't hide the toolbar
            [UIView animateWithDuration:0.2 animations:^{
                self.tabView.navigationBar.frame = CGRectMake(0, 0, SCREEN_WIDTH, minNavbarSize);
                
                _addressTextField.frame = CGRectMake(UNIBAR_FINISHED_X, UNIBAR_FINISHED_Y, UNIBAR_FINISHED_WIDTH, UNIBAR_FINISHED_HEIGHT);
                _addressTextField.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:11];
                ((UIView *)_addressTextField.subviews[0]).alpha = 0;
                _addressTextField.refreshButton.alpha = 0.0;
                _addressTextField.refreshButton.frame = CGRectMake(179, -5, 29, 29);
                _addressTextField.tlsButton.alpha = 0.0;
                self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 44);
                _webViewObject.frame = CGRectMake(0, minNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - minNavbarSize);
                [[_webViewObject scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
            }];
        } else if (self.tabView.navigationBar.frame.size.height < maxNavbarSize - 10) {
            [UIView animateWithDuration:0.2 animations:^{
                self.tabView.navigationBar.frame = CGRectMake(0, 0, SCREEN_WIDTH, minNavbarSize);
                _addressTextField.frame = CGRectMake(UNIBAR_FINISHED_X, UNIBAR_FINISHED_Y, UNIBAR_FINISHED_WIDTH, UNIBAR_FINISHED_HEIGHT);
                _addressTextField.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:11];
                ((UIView *)_addressTextField.subviews[0]).alpha = 0;
                _addressTextField.refreshButton.alpha = 0.0;
                _addressTextField.refreshButton.frame = CGRectMake(179, -5, 29, 29);
                _addressTextField.tlsButton.alpha = 0.0;
                _webViewObject.frame = CGRectMake(0, minNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - minNavbarSize);
            }];
        } else  if (self.tabView.navigationBar.frame.size.height < maxNavbarSize) {
            [UIView animateWithDuration:0.2 animations:^{
                [self showNavigationBarAtFullHeight];
                self.selectedToolbar.frame = CGRectMake(0, SCREEN_HEIGHT - 44, SCREEN_WIDTH, 44);
                _webViewObject.frame = CGRectMake(0, maxNavbarSize, SCREEN_WIDTH, SCREEN_HEIGHT - maxNavbarSize);
            }];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _userScrolling = NO;
    _initialScrollOffset = CGPointMake(0, 0);
}

@end
