//
//  WebViewTab.h
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TabsViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface WebViewTab : UIWebView <UIWebViewDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate> {
    NSMutableDictionary *_progressDictionary;
    UIDocumentInteractionController *_docController;
    UIView *_openPdfView;
    UIButton *_openPDFButton;
    float _progress;
}

@property (nonatomic, strong) NSURL *url;
@property (nonatomic) BOOL needsForceRefresh;

- (NSMutableDictionary *)progressDictionary;

- (void)setIndex:(NSInteger)index;
- (void)setParent:(TabsViewController *)parent;
- (void)updateTLSStatus:(Byte)newStatus;

@end
