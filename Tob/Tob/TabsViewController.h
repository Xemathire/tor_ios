//
//  ViewController.h
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MOTabViewController.h"

#define TLSSTATUS_HIDDEN 0
#define TLSSTATUS_SECURE 1
#define TLSSTATUS_INSECURE 2

extern const char AlertViewExternProtoUrl;
extern const char AlertViewIncomingUrl;

@interface TabsViewController : MOTabViewController

// @property (nonatomic, strong) NSArray *restoredURLs;
@property (nonatomic, strong) UIProgressView *progressView;

- (NSMutableArray *)titles;
- (NSMutableArray *)subtitles;
- (NSMutableArray *)tlsStatuses;
- (NSMutableArray *)progressValues;
- (NSMutableArray *)contentViews;

- (void)loadURL:(NSURL *)url;
- (void)askToLoadURL:(NSURL *)url;
- (void)addNewTabForURL:(NSURL *)url;
- (void)stopLoading;

- (void)updateNavigationItems;
- (void)showNavigationBarAtFullHeight;
- (void)updateProgress:(float)progress animated:(BOOL)animated;
- (void)hideProgressBarAnimated:(BOOL)animated;
- (void)showProgressBarAnimated:(BOOL)animated;

- (void)webViewDidStartLoading;
- (void)webViewDidFinishLoading;

- (void)renderTorStatus:(NSString *)statusLine;
- (void)showTLSStatus;

- (void)saveAppState;
- (void)getRestorableData;

@end

