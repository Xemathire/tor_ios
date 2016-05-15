//
//  WebViewTab.h
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TabsViewController.h"

@interface WebViewTab : UIWebView <UIWebViewDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate> {
    NSMutableDictionary *_progressDictionary;
    float _progress;
}

@property (nonatomic, strong) NSURL *url;
@property (nonatomic) BOOL needsForceRefresh;

- (NSMutableDictionary *)progressDictionary;

- (void)setIndex:(NSInteger)index;
- (void)setParent:(TabsViewController *)parent;
- (void)updateTLSStatus:(Byte)newStatus;

@end
