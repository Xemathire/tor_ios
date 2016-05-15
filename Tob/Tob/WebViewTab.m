//
//  WebViewTab.m
//  Tob
//
//  Created by Jean-Romain on 26/04/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import "WebViewTab.h"
#import "AppDelegate.h"
#import "JFMinimalNotification.h"
#import "iRate.h"
#import <objc/runtime.h>

#define ALERTVIEW_SSL_WARNING 1
#define MAX_REFRESH_ON_FRAME_LOAD_INTERRUPTED 5

static char SSLWarningKey;

@implementation WebViewTab {
    NSInteger _index;
    NSInteger _frameLoadInterruptedCount;
    TabsViewController *_parent; // The index of this webview in the tab page
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        
        self.clipsToBounds = YES;
        self.scrollView.clipsToBounds = YES;
        [[self scrollView] setContentInset:UIEdgeInsetsMake(0, 0, 44, 0)];
        [[self scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 44, 0)];
        self.scalesPageToFit = YES;
        
        self.delegate = self;

        [(UIScrollView *)[self.subviews objectAtIndex:0] setScrollsToTop:NO];
        
        self.url = [[NSURL alloc] init];
        _frameLoadInterruptedCount = 0;
        
        _needsForceRefresh = NO;
        
        UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(displayLongPressMenu:)];
        [gestureRecognizer setDelegate:self];
        [self addGestureRecognizer:gestureRecognizer];
    }
    return self;
}

- (NSMutableDictionary *)progressDictionary {
    if (!_progressDictionary) {
        _progressDictionary = [[NSMutableDictionary alloc] initWithObjects:@[@0, @0] forKeys:@[@"requestCount", @"doneCount"]];
    }
    
    if (_progressDictionary && [[_progressDictionary objectForKey:@"requestCount"] intValue] != 0) {
        float progress = [[_progressDictionary objectForKey:@"doneCount"] floatValue] / [[_progressDictionary objectForKey:@"requestCount"] floatValue];
        // When the request count is small, the progress isn't very precise, so assume it's smaller than the value we found.
        // Plus this makes the bar move a bit when sending more requests.
        // Multiply by 0.95 to make sure the bar never reaches 1 before the end of the requests
        progress = 0.95 * (progress - (1 / (5 * [[_progressDictionary objectForKey:@"requestCount"] intValue])));
        if (progress >= 0.05f && fabsf(progress - _progress) > 0.1) {
            [_parent.progressValues replaceObjectAtIndex:_index withObject:[NSNumber numberWithFloat:progress]];
            if (_index == _parent.tabView.currentIndex) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                    [_parent updateProgress:progress animated:YES];
                    [_parent updateNavigationItems];
                }];
            }
            _progress = progress;
        }
    }
    
    return _progressDictionary;
}

- (void)setIndex:(NSInteger)index {
    _index = index;
}

- (void)setParent:(TabsViewController *)parent {
    _parent = parent;
}

- (void)informError:(NSError *)error {
    NSString *errorTitle = @"";
    NSString *errorMessage = @"";
    
    // Skip NSURLErrorDomain:kCFURLErrorCancelled because that's just "Cancel"
    // (user pressing stop button). Likewise with WebKitErrorFrameLoadInterrupted
    if ([error.domain isEqualToString:NSURLErrorDomain] && (error.code == kCFURLErrorCancelled)){
        return;
    }
    
    if ([error.domain isEqualToString:(NSString *)@"WebKitErrorDomain"] && (error.code == 102)) {
        // Frame load interrupted
        if (_frameLoadInterruptedCount < MAX_REFRESH_ON_FRAME_LOAD_INTERRUPTED) {
            [self stopLoading];
            
            if (self.url)
                [self loadRequest:[NSURLRequest requestWithURL:self.url]];
            else
                [self reload];
            _frameLoadInterruptedCount ++;
            
            JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleDefault title:NSLocalizedString(@"Frame load interrupted", nil) subTitle:[NSString stringWithFormat:NSLocalizedString(@"Refreshing tab n°%ld.", nil), (long)(_index + 1)] dismissalDelay:3.0];
            minimalNotification.layer.zPosition = MAXFLOAT;
            [_parent.view addSubview:minimalNotification];
            [minimalNotification show];
            
            return;
        } else {
            JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleError title:NSLocalizedString(@"Frame load interrupted", nil) subTitle:[NSString stringWithFormat:NSLocalizedString(@"The page in tab n°%d couldn't load properly", nil), (long)(_index + 1)] dismissalDelay:5.0];
            minimalNotification.layer.zPosition = MAXFLOAT;
            [_parent.view addSubview:minimalNotification];
            [minimalNotification show];
            
            return;
        }
    }
    
    
    if ([error.domain isEqualToString:NSPOSIXErrorDomain] && (error.code == 61)) {
        /* Tor died */
        
#ifdef DEBUG
        NSLog(@"Tor socket failure: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
#endif
        
        errorTitle = NSLocalizedString(@"Tor connection failure", nil);
        errorMessage = NSLocalizedString(@"Tob lost connection to the Tor anonymity network and is unable to reconnect. This may occur if Tob went to the background or if device went to sleep while Tob was active.\n\nPlease quit the app and try again.", nil);
    } else if ([error.domain isEqualToString:@"NSOSStatusErrorDomain"] &&
               (error.code == -9807 || error.code == -9812)) {
        /* INVALID CERT */
        // Invalid certificate chain; valid cert chain, untrusted root
        
#ifdef DEBUG
        NSLog(@"Certificate error: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
#endif
        
        NSURL *url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        
        NSURL *failingURL = [error.userInfo objectForKey:@"NSErrorFailingURLKey"];
        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"Cannot Verify Website Identity", nil)
                                  message:[NSString stringWithFormat:NSLocalizedString(@"Either the SSL certificate for '%@' is self-signed or the certificate was signed by an untrusted authority.\n\nFor normal websites, it is generally unsafe to proceed.\n\nFor .onion websites (or sites using CACert or self-signed certificates), you may proceed if you think you can trust this website's URL.", nil), url.host]
                                  delegate:nil
                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                  otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
        alertView.delegate = self;
        alertView.tag = ALERTVIEW_SSL_WARNING;
        
        objc_setAssociatedObject(alertView, &SSLWarningKey, failingURL, OBJC_ASSOCIATION_RETAIN);
        
        [alertView show];
    } else {
        // ALL other error types are just notices (so no Cancel vs Continue stuff)
        
#ifdef DEBUG
        NSLog(@"Displayed Error: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
#endif
        
        if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork] &&
            ([error.domain isEqualToString:@"NSOSStatusErrorDomain"] &&
             (error.code == -9800 || error.code == -9801 || error.code == -9809 || error.code == -9818))) {
                /* SSL/TLS ERROR */
                // https://www.opensource.apple.com/source/Security/Security-55179.13/libsecurity_ssl/Security/SecureTransport.h
                
                NSURL *url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
                errorTitle = NSLocalizedString(@"HTTPS Connection Failed", nil);
                errorMessage = [NSString stringWithFormat:NSLocalizedString(@"A secure connection to '%@' could not be made.\nThe site might be down, there could be a Tor network outage, or your 'minimum SSL/TLS' setting might want stronger security than the website provides.\n\nFull error: '%@'", nil),
                                url.host, error.localizedDescription];
                
                
            } else if ([error.domain isEqualToString:NSURLErrorDomain]) {
                /* HTTP ERRORS */
                // https://www.opensource.apple.com/source/Security/Security-55179.13/libsecurity_ssl/Security/SecureTransport.h
                
                if (error.code == kCFURLErrorHTTPTooManyRedirects) {
                    errorMessage = NSLocalizedString(@"This website is stuck in a redirect loop. The web page you tried to access redirected you to another web page, which, in turn, is redirecting you (and so on).\n\nPlease contact the site operator to fix this problem.", nil);
                } else if ((error.code == kCFURLErrorCannotFindHost) || (error.code == kCFURLErrorDNSLookupFailed)) {
                    errorMessage = NSLocalizedString(@"The website you tried to access could not be found.", nil);
                } else if (error.code == kCFURLErrorResourceUnavailable) {
                    errorMessage = NSLocalizedString(@"The web page you tried to access is currently unavailable.", nil);
                }
            } else if ([error.domain isEqualToString:(NSString *)@"WebKitErrorDomain"]) {
                if ((error.code == 100) || (error.code == 101)) {
                    errorMessage = NSLocalizedString(@"Tob cannot display this type of content.", nil);
                }
            } else if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork] ||
                       [error.domain isEqualToString:@"NSOSStatusErrorDomain"]) {
                if (error.code == kCFSOCKS5ErrorBadState) {
                    errorMessage = NSLocalizedString(@"Could not connect to the server. Either the domain name is incorrect, the server is inaccessible, or the Tor circuit was broken.", nil);
                } else if (error.code == kCFHostErrorHostNotFound) {
                    errorMessage = NSLocalizedString(@"The website you tried to access could not be found.", nil);
                }
            }
        
        // default
        if ([errorTitle isEqualToString:@""]) {
            errorTitle = NSLocalizedString(@"Cannot Open Page", nil);
        }
        if ([errorMessage isEqualToString:@""]) {
            errorMessage = [NSString stringWithFormat:NSLocalizedString(@"An error occurred: %@\n(Error \"%@: %li)\"", nil),
                                error.localizedDescription, error.domain, (long)error.code];
        }
    }
    
    if (errorTitle && errorMessage) {
        // report the error inside the webview
        NSString *errorString = [NSString stringWithFormat:@"<div><div><div><div style=\"padding: 40px 15px;text-align: center;\"><h1>%@</h1><div style=\"font-size: 2em;\">%@</div></div></div></div></div>", errorTitle, errorMessage];
        
        [self loadHTMLString:errorString baseURL:self.url];
    }
}

- (void)displayLongPressMenu:(UILongPressGestureRecognizer *)sender {
    NSString *href, *img;
    
    if (sender.state != UIGestureRecognizerStateBegan)
        return;
    
#ifdef TRACE
    NSLog(@"[Tab %@] long-press gesture recognized", self.tabIndex);
#endif
    
    NSArray *elements = [self elementsAtLocationFromGestureRecognizer:sender];
    
#ifdef TRACE
    NSLog(@"[Tab %@] context menu href:%@, img:%@, alt:%@", self.tabIndex, href, img, alt);
#endif
    
    if (![elements[2] isEqualToString:@"A"] && ![elements[2] isEqualToString:@"IMG"]) {
        sender.enabled = false;
        sender.enabled = true;
        return;
    }
    
    href = elements[1];
    
    if ([elements[2] isEqualToString:@"IMG"]) {
        img = href;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:href message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *openAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [_parent loadURL:[NSURL URLWithString:href]];
    }];
    
    UIAlertAction *openNewTabAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in a New Tab", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [_parent addNewTabForURL:[NSURL URLWithString:href]];
    }];
    
    UIAlertAction *openSafariAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in Safari", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:href]];
    }];
    
    UIAlertAction *saveImageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Save Image", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSURL *imgurl = [NSURL URLWithString:img];
        
        NSData *imgdata = [NSData dataWithContentsOfURL:imgurl];
        if (imgdata) {
            UIImage *i = [UIImage imageWithData:imgdata];
            UIImageWriteToSavedPhotosAlbum(i, self,  @selector(image:didFinishSavingWithError:contextInfo:), nil);
        } else {
            JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleError title:NSLocalizedString(@"Failed to download image", nil) subTitle:NSLocalizedString(@"Couldn't retrieve the image's data", nil) dismissalDelay:5.0];
            minimalNotification.layer.zPosition = MAXFLOAT;
            [_parent.view addSubview:minimalNotification];
            [minimalNotification show];
        }
    }];
    
    UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy URL", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIPasteboard generalPasteboard] setString:(href ? href : img)];
    }];
    
    if (href) {
        [alertController addAction:openAction];
        [alertController addAction:openNewTabAction];
        [alertController addAction:openSafariAction];
    }
    
    if (img)
        [alertController addAction:saveImageAction];
    
    [alertController addAction:copyURLAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    
    UIPopoverPresentationController *popover = alertController.popoverPresentationController;
    
    if (popover) {
        popover.sourceView = [_parent view];
        // popover.sourceRect = [[_parent view] bounds];
        CGPoint tap = [sender locationInView:[_parent view]];
        popover.sourceRect = CGRectMake(tap.x, tap.y, 10, 10);
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    
    [_parent presentViewController:alertController animated:YES completion:nil];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleError title:NSLocalizedString(@"Failed to download image", nil) subTitle:[error localizedDescription] dismissalDelay:5.0];
        minimalNotification.layer.zPosition = MAXFLOAT;
        [_parent.view addSubview:minimalNotification];
        [minimalNotification show];
    } else {
        JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleSuccess title:NSLocalizedString(@"Saved image", nil) subTitle:NSLocalizedString(@"Added the image to the camera roll", nil) dismissalDelay:3.0];
        minimalNotification.layer.zPosition = MAXFLOAT;
        [_parent.view addSubview:minimalNotification];
        [minimalNotification show];
    }
}

- (void)updateTLSStatus:(Byte)newStatus {
    _parent.tlsStatuses[_index] = [NSNumber numberWithInt:newStatus];
    
    if (_index == _parent.tabView.currentIndex) {
        [_parent performSelectorOnMainThread:@selector(showTLSStatus) withObject:nil waitUntilDone:NO];
    }
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ((alertView.tag == ALERTVIEW_SSL_WARNING) && (buttonIndex == 1)) {
        // "Continue anyway" for SSL cert error
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        // Assuming URL in address bar is the one that caused this error.
        NSURL *url = objc_getAssociatedObject(alertView, &SSLWarningKey);
        NSString *hostname = url.host;
        [appDelegate.sslWhitelistedDomains addObject:hostname];
        
        JFMinimalNotification *minimalNotification = [JFMinimalNotification notificationWithStyle:JFMinimalNotificationStyleDefault title:NSLocalizedString(@"Whitelisted Domain", nil) subTitle:[NSString stringWithFormat:NSLocalizedString(@"SSL certificate errors for '%@' will be ignored for the rest of this session.", nil), hostname] dismissalDelay:3.0];
        minimalNotification.layer.zPosition = MAXFLOAT;
        [_parent.view addSubview:minimalNotification];
        [minimalNotification show];

        // Reload (now that we have added host to whitelist)
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
        [self loadRequest:request];
    } else if ((alertView.tag == ALERTVIEW_SSL_WARNING) && (buttonIndex == 0)) {
        NSURL *url = objc_getAssociatedObject(alertView, &SSLWarningKey);
        
        NSString *errorTitle = NSLocalizedString(@"Cannot Verify Website Identity", nil);
        NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Either the SSL certificate for '%@' is self-signed or the certificate was signed by an untrusted authority.\n\nFor normal websites, it is generally unsafe to proceed.\n\nFor .onion websites (or sites using CACert or self-signed certificates), you may proceed if you think you can trust this website's URL.", nil), url.host];
        
        NSString *errorString = [NSString stringWithFormat:@"<div><div><div><div style=\"padding: 40px 15px;text-align: center;\"><h1>%@</h1><div style=\"font-size: 2em;\">%@</div></div></div></div></div>", errorTitle, errorMessage];
        
        [self loadHTMLString:errorString baseURL:url];

    }
}



#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (_index == _parent.tabView.currentIndex) {
        [_parent updateNavigationItems];
        [_parent webViewDidStartLoading];
        [_parent showProgressBarAnimated:YES];
    }
        
    if ([[[[[webView request] URL] scheme] lowercaseString] isEqualToString:@"https"]) {
        [self updateTLSStatus:TLSSTATUS_SECURE];
    } else if ([[[[webView request] URL] scheme] isEqualToString:@""]){
        [self updateTLSStatus:TLSSTATUS_INSECURE];
    }
}


- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _frameLoadInterruptedCount = 0;

    if ([[[webView request] mainDocumentURL] absoluteString] && _index < [_parent.titles count])
        [_parent.titles replaceObjectAtIndex:_index withObject:[[[webView request] mainDocumentURL] absoluteString]];
    
    if (![[webView stringByEvaluatingJavaScriptFromString:@"document.title"] isEqualToString:@""] && _index < [_parent.subtitles count])
        [_parent.subtitles replaceObjectAtIndex:_index withObject:[webView stringByEvaluatingJavaScriptFromString:@"document.title"]];
    
    if (_index == _parent.tabView.currentIndex) {
        [_parent.progressValues replaceObjectAtIndex:_index withObject:[NSNumber numberWithFloat:1.0f]];
        _progress = 1.0f;
        [_parent performSelector:@selector(hideProgressBarAnimated:) withObject:@YES afterDelay:0.8];
        [_parent updateProgress:1.0f animated:YES];
        [_parent updateNavigationItems];
        [_parent webViewDidFinishLoading];
    }
    
    _progressDictionary = nil;
    
    // Increment the rating counter, but don't show the notification as it will interrupt the browsing experience
    [[iRate sharedInstance] logEvent:YES];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self informError:error];
    
    if (_index == _parent.tabView.currentIndex) {
        [_parent.progressValues replaceObjectAtIndex:_index withObject:[NSNumber numberWithFloat:1.0f]];
        _progress = 1.0f;
        [_parent updateProgress:1.0f animated:YES];
        [_parent hideProgressBarAnimated:YES];
        [_parent updateNavigationItems];
    }
    
    _progressDictionary = nil;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *title = [[request mainDocumentURL] absoluteString];
    NSString *subtitle = [[[request URL] host] stringByAppendingString:[[request URL] path]];
    
    if ([request URL]) {
        self.url = [request mainDocumentURL];
    }
    
    // If the last character is a /, remove it
    if ([title length] > 1 && [[title substringFromIndex:[title length] - 1] isEqualToString:@"/"])
        title = [title substringToIndex:[title length] - 1];
    
    if ([subtitle length] > 1 && [[subtitle substringFromIndex:[subtitle length] - 1] isEqualToString:@"/"])
        subtitle = [subtitle substringToIndex:[subtitle length] - 1];
    
    if (title && _index < [_parent.titles count])
        [_parent.titles replaceObjectAtIndex:_index withObject:title];
    
    if (subtitle && _index < [_parent.subtitles count])
        [_parent.subtitles replaceObjectAtIndex:_index withObject:subtitle];
    
    [_parent.progressValues replaceObjectAtIndex:_index withObject:[NSNumber numberWithFloat:0.05f]];
    _progress = 0.05f;
    if (_index == _parent.tabView.currentIndex) {
        [_parent updateProgress:0.05f animated:NO];
        [_parent showProgressBarAnimated:YES];
        [_parent updateNavigationItems];
    }
    
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        // We no longer are refreshing the page to "fix" a frame load interrupted error, so reset the counter
        _frameLoadInterruptedCount = 0;
    }
        
    return YES;
}

- (NSArray *)elementsAtLocationFromGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint tap = [gestureRecognizer locationInView:self];
    tap.y -= [[self scrollView] contentInset].top;
    
    /* translate tap coordinates from view to scale of page */
    CGSize windowSize = CGSizeMake(
                                   [[self stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] intValue],
                                   [[self stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] intValue]
                                   );
    CGSize viewSize = [self frame].size;
    float ratio = windowSize.width / viewSize.width;
    CGPoint tapOnPage = CGPointMake(tap.x * ratio, tap.y * ratio);
    
    /* now find if there are usable elements at those coordinates and extract their attributes */
    // Load the JavaScript code from the Resources and inject it into the web page
    NSString *path = [[NSBundle mainBundle] pathForResource:@"JSTools" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self stringByEvaluatingJavaScriptFromString:jsCode];
    
    // Get the tags at the touch location
    NSString *tags = [self stringByEvaluatingJavaScriptFromString:
                      [NSString stringWithFormat:@"__TobGetHTMLElementsAtPoint(%li,%li);",(long)tapOnPage.x,(long)tapOnPage.y]];
    
    // Get the link info at the touch location
    NSString *jsonString = [self stringByEvaluatingJavaScriptFromString:
                            [NSString stringWithFormat:@"__TobGetLinkInfoAtPoint(%li,%li);",(long)tapOnPage.x,(long)tapOnPage.y]];
    
    if (!jsonString) {
        return @[@"", @"", @"", @""];
    }
    
    // Convert the jason string to an array
    NSArray *json = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    
    NSString *source = @"";
    NSString *tag = @"";
    
    if ([json count] != 2) {
        return @[@"", @"", @"", @""];
    }
    
    source = [json objectAtIndex:0]; // Contains the URL
    tag = [json objectAtIndex:1]; // Contains A or IMG (or nothing) depending on what the user clicked
    
    // If no proper link or image has been found
    if (([source  isEqualToString:@""] || [source  isEqualToString:@"undefined"]) || ([tag isEqualToString:@""] && [tags isEqualToString:@""])) {
        return @[@"", @"", @""];
    }
    
    tags = [NSString stringWithFormat:@"%@, %@", tag, tags]; // If the user clicked slightly next to the URL, the fuzz will still detect it but won't add it to the tags list, so we add it here
    
    return @[tags, source, tag];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]])
        return YES;
    
    if (![gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
        return NO;
    
    if ([gestureRecognizer state] != UIGestureRecognizerStateBegan)
        return YES;
    
    NSString *tags = [self elementsAtLocationFromGestureRecognizer:gestureRecognizer][0];
    
    if ([tags rangeOfString:@"A"].location != NSNotFound || [tags rangeOfString:@"IMG"].location != NSNotFound) {
        /* this is enough to cancel the touch when the long press gesture fires, so that the link being held down doesn't activate as a click once the finger is let up */
        if ([otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            otherGestureRecognizer.enabled = NO;
            otherGestureRecognizer.enabled = YES;
        }
        
        return YES;
    }
    
    return NO;
}



@end
