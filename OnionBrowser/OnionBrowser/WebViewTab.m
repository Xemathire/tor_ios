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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
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
//#import "URLInterceptor.h"
#import "WebViewTab.h"
#import "WebViewController.h"
#import "ALToastView.h"
#import <objc/runtime.h>

//#import "NSString+JavascriptEscape.h"

#define ALERTVIEW_SSL_WARNING 1
#define ALERTVIEW_EXTERN_PROTO 2
#define ALERTVIEW_INCOMING_URL 3
#define ALERTVIEW_TORFAIL 4

const char AlertViewExternProtoUrl;
const char AlertViewIncomingUrl;

static char SSLWarningKey;

static const NSInteger kLoadingStatusTag = 1003;

@import WebKit;

@implementation WebViewTab

AppDelegate *appDelegate;

+ (WebViewTab *)openedWebViewTabByRandID:(NSString *)randID
{
	for (WebViewTab *wvt in [[appDelegate appWebView] webViewTabs]) {
		if ([wvt randID] != nil && [[wvt randID] isEqualToString:randID]) {
			return wvt;
		}
	}
	
	return nil;
}

- (id)initWithFrame:(CGRect)frame
{
    _tlsStatus = TLSSTATUS_NO;
	return [self initWithFrame:frame withRestorationIdentifier:nil];
}

- (id)initWithFrame:(CGRect)frame withRestorationIdentifier:(NSString *)rid
{
	self = [super init];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	_viewHolder = [[UIView alloc] initWithFrame:frame];

	/* re-register user agent with our hash, which should only affect this UIWebView */
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"UserAgent": [NSString stringWithFormat:@"%@/%lu", [appDelegate defaultUserAgent], (unsigned long)self.hash] }];
	
	_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	_needsRefresh = FALSE;
	if (rid != nil) {
		[_webView setRestorationIdentifier:rid];
		_needsRefresh = TRUE;
	}
	[_webView setDelegate:self];
	[_webView setScalesPageToFit:YES];
	[_webView setAutoresizesSubviews:YES];
	[_webView setAllowsInlineMediaPlayback:YES];
	
	[_webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
	[_webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webKitprogressEstimateChanged:) name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];
	
	/* swiping goes back and forward in current webview */
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRightAction:)];
	[swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
	[swipeRight setDelegate:self];
	[self.webView addGestureRecognizer:swipeRight];
 
	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftAction:)];
	[swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
	[swipeLeft setDelegate:self];
	[self.webView addGestureRecognizer:swipeLeft];
	
	_titleHolder = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_titleHolder setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.75]];

	_title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_title setTextColor:[UIColor whiteColor]];
	[_title setFont:[UIFont boldSystemFontOfSize:16.0]];
	[_title setLineBreakMode:NSLineBreakByTruncatingTail];
	[_title setTextAlignment:NSTextAlignmentCenter];
	[_title setText:@"New Tab"];
	
	_closer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_closer setTextColor:[UIColor whiteColor]];
	[_closer setFont:[UIFont systemFontOfSize:24.0]];
	[_closer setText:[NSString stringWithFormat:@"%C", 0x2715]];

	[_viewHolder addSubview:_titleHolder];
	[_viewHolder addSubview:_title];
	[_viewHolder addSubview:_closer];
	[_viewHolder addSubview:_webView];
	
	/* setup shadow that will be shown when zooming out */
	[[_viewHolder layer] setMasksToBounds:NO];
	[[_viewHolder layer] setShadowOffset:CGSizeMake(0, 0)];
	[[_viewHolder layer] setShadowRadius:8];
	[[_viewHolder layer] setShadowOpacity:0];
	
	_progress = @0.0;
	
	[self updateFrame:frame];

	[self zoomNormal];
	
	[self setSecureMode:WebViewTabSecureModeInsecure];
	[self setApplicableHTTPSEverywhereRules:[[NSMutableDictionary alloc] initWithCapacity:6]];
	
	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressMenu:)];
	[lpgr setDelegate:self];
	[_webView addGestureRecognizer:lpgr];

	for (UIView *_view in _webView.subviews) {
		for (UIGestureRecognizer *recognizer in _view.gestureRecognizers) {
			[recognizer addTarget:self action:@selector(webViewTouched:)];
		}
		for (UIView *_sview in _view.subviews) {
			for (UIGestureRecognizer *recognizer in _sview.gestureRecognizers) {
				[recognizer addTarget:self action:@selector(webViewTouched:)];
			}
		}
	}
	
	/* this doubles as a way to force the webview to initialize itself, otherwise the UA doesn't seem to set right before refreshing a previous restoration state */
	NSString *ua = [_webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
	NSArray *uap = [ua componentsSeparatedByString:@"/"];
	NSString *wvthash = uap[uap.count - 1];
	if (![[NSString stringWithFormat:@"%lu", (unsigned long)[self hash]] isEqualToString:wvthash])
		abort();
	
	return self;
}

/* for long press gesture recognizer to work properly */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    
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

- (void)addressBarCancel {
    // Does nothing
}

- (void)close
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];
	[_webView stopLoading];
	_webView = nil;
}

- (void)webKitprogressEstimateChanged:(NSNotification*)notification
{
	[self setProgress:[NSNumber numberWithFloat:[[notification object] estimatedProgress]]];
}

- (void)updateFrame:(CGRect)frame
{
	[self.viewHolder setFrame:frame];
	[self.webView setFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
	
	if ([[appDelegate appWebView] toolbarOnBottom]) {
		[self.titleHolder setFrame:CGRectMake(0, frame.size.height, frame.size.width, 32)];
		[self.closer setFrame:CGRectMake(3, frame.size.height + 8, 18, 18)];
		[self.title setFrame:CGRectMake(22, frame.size.height + 8, frame.size.width - 22 - 22, 18)];
	}
	else {
		[self.titleHolder setFrame:CGRectMake(0, -26, frame.size.width, 32)];
		[self.closer setFrame:CGRectMake(3, -22, 18, 18)];
		[self.title setFrame:CGRectMake(22, -22, frame.size.width - 22 - 22, 18)];
	}
}

- (void)renderTorStatus: (NSArray *)statusArray {
    //UIWebView *loadingStatus = (UIWebView *)[self.view viewWithTag:kLoadingStatusTag];
    UIWebView *loadingStatus = (UIWebView *)self.webView;
    
    NSString *statusLine = statusArray[0];
    
    _torStatus = [NSString stringWithFormat:@"%@\n%@",
                  _torStatus, statusLine];
    NSRange progress_loc = [statusLine rangeOfString:@"BOOTSTRAP PROGRESS="];
    NSRange progress_r = {
        progress_loc.location+progress_loc.length,
        2
    };
    NSString *progress_str = @"";
    NSString *previous_progress_str = @"";
    if (progress_loc.location != NSNotFound) {
        progress_str = [statusLine substringWithRange:progress_r];
        previous_progress_str = [statusArray[1] substringWithRange:progress_r];
    }
    
    NSRange summary_loc = [statusLine rangeOfString:@" SUMMARY="];
    NSString *summary_str = @"";
    if (summary_loc.location != NSNotFound)
        summary_str = [statusLine substringFromIndex:summary_loc.location+summary_loc.length+1];
    NSRange summary_loc2 = [summary_str rangeOfString:@"\""];
    if (summary_loc2.location != NSNotFound)
        summary_str = [summary_str substringToIndex:summary_loc2.location];
    
    progress_str = [progress_str stringByReplacingOccurrencesOfString:@" " withString:@""];
    previous_progress_str = [previous_progress_str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSString *status = [NSString stringWithFormat:@""
                        "<!DOCTYPE html>"
                        "<html>"
                        "    <head>"
                        "        <style>"
                        "body {"
                        "    text-align: center;"
                        "    font-family: sans-serif;"
                        "}"
                        ""
                        "#onion {"
                        "    width: 40vw;"
                        "    margin: 1vw;"
                        "    padding: 2vw;"
                        "    border-radius: 50%%;"
                        "    border: 1vw solid white;"
                        "    background-repeat: no-repeat;"
                        "    box-shadow: 0 0 0 1vw rgb(81, 54, 96);"
                        "    background-position: 0 calc(44vw - (%@vw * 44) / 100);"
                        "    background-image: linear-gradient(rgb(81, 54, 96), rgb(81, 54, 96));"
                        "    -webkit-animation: trans 300ms linear;"
                        "}"
                        ""
                        "@-webkit-keyframes trans {"
                        "    0%% {   background-position: 0 calc(44vw - (%@vw * 44) / 100); /* previous */ }"
                        "    100%% { background-position: 0 calc(44vw - (%@vw * 44) / 100); /* new */      }"
                        "}"
                        ""
                        "i {"
                        "    display: block;"
                        "    font-size: 10vw;"
                        "    font-style: normal;"
                        "}"
                        ""
                        "a {"
                        "    color: black;"
                        "}"
                        ""
                        "p {"
                        "    font-size: 6vw;"
                        "}"
                        ""
                        "div {"
                        "    font-size: 4vw;"
                        "}"
                        ""
                        "</style>"
                        "</head>"
                        ""
                        "<body>"
                        "    <img id='onion' src='data:image/png;base64,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' />"
                        "<p>"
                        "    <i>%@%%</i> %@"
                        "</p>"
                        "<div>"
                        "    After a few minutes, re-launch the app.<br/>"
                        "    If your ISP blocks Tor connections, you can configure bridges by pressing the settings button.<br/>"
                        "    If you continue to have issues, go to <a target='_blank' href='theonionbrowser:help'>the help page</a>."
                        "</div>"
                        "</body>"
                        "</html>",
                        progress_str,
                        previous_progress_str,
                        progress_str,
                        progress_str,
                        summary_str];
        
    [loadingStatus loadHTMLString:[status description] baseURL:nil];
}

-(void)askToLoadURL: (NSURL *)navigationURL {
    /* Used on startup, if we opened the app from an outside source.
     * Will ask for user permission and display requested URL so that
     * the user isn't tricked into visiting a URL that includes their
     * IP address (or other info) that an attack site included when the user
     * was on the attack site outside of Tor.
     */
    NSString *msg = [NSString stringWithFormat: @"Another app has requested that The Onion Browser load the following link. Because the link is generated outside of Tor, please ensure that you trust the link & that the URL does not contain identifying information. Canceling will open the normal homepage.\n\n%@", navigationURL.absoluteString, nil];
    UIAlertView* alertView = [[UIAlertView alloc]
                              initWithTitle:@"Open This URL?"
                              message:msg
                              delegate:nil
                              cancelButtonTitle:@"Cancel"
                              otherButtonTitles:@"Open This Link",nil];
    alertView.delegate = self;
    alertView.tag = ALERTVIEW_INCOMING_URL;
    [alertView show];
    objc_setAssociatedObject(alertView, &AlertViewIncomingUrl, navigationURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/*
 - (void)loadURL:(NSURL *)u withForce:(BOOL)force
 {
	[self.webView stopLoading];
	[self prepareForNewURL:u];
	
	NSMutableURLRequest *ur = [NSMutableURLRequest requestWithURL:u];
	if (force)
 [ur setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
 
	[self.webView loadRequest:ur];
 }
 */

-(void)loadURL: (NSURL *)navigationURL {
    NSString *urlProto = [[navigationURL scheme] lowercaseString];
    if ([urlProto isEqualToString:@"theonionbrowser"]||[urlProto isEqualToString:@"theonionbrowsers"]||[urlProto isEqualToString:@"about"]||[urlProto isEqualToString:@"http"]||[urlProto isEqualToString:@"https"]) {
        /***** One of our supported protocols *****/

        // Update URL
        [self prepareForNewURL:navigationURL];
        
        // Cancel any existing nav
        [self.webView stopLoading];
        
        // Remove the "connecting..." (initial tor load) overlay if it still exists.
        UIView *loadingStatus = [self.viewHolder viewWithTag:kLoadingStatusTag];
        if (loadingStatus != nil) {
            [loadingStatus removeFromSuperview];
        }
        
        // Build request and go.
        _webView.scalesPageToFit = YES;
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:navigationURL];
        [req setHTTPShouldUsePipelining:YES];
        [_webView loadRequest:req];
        
        if ([urlProto isEqualToString:@"https"]) {
            [self updateTLSStatus:TLSSTATUS_YES];
        } else {
            [self updateTLSStatus:TLSSTATUS_NO];
        }
    } else {
        /***** NOT a protocol that this app speaks, check with the OS if the user wants to *****/
        if ([[UIApplication sharedApplication] canOpenURL:navigationURL]) {
            //NSLog(@"can open %@", [navigationURL absoluteString]);
            NSString *msg = [NSString stringWithFormat: @"The Onion Browser cannot load a '%@' link, but another app you have installed can.\n\nNote that the other app will not load data over Tor, which could leak identifying information.\n\nDo you wish to proceed?", navigationURL.scheme, nil];
            UIAlertView* alertView = [[UIAlertView alloc]
                                      initWithTitle:@"Open Other App?"
                                      message:msg
                                      delegate:nil
                                      cancelButtonTitle:@"Cancel"
                                      otherButtonTitles:@"Open",nil];
            alertView.delegate = self;
            alertView.tag = ALERTVIEW_EXTERN_PROTO;
            [alertView show];
            objc_setAssociatedObject(alertView, &AlertViewExternProtoUrl, navigationURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        } else {
            NSMutableDictionary *details = [NSMutableDictionary dictionary];
            [details setValue:@"Invalid input URL" forKey:NSLocalizedDescriptionKey];
            NSError *error = [NSError errorWithDomain:@"NSURLErrorUnsupportedURL" code:-1002 userInfo:details];
            [self informError:error withMessage:[NSString stringWithFormat:@"Failed to open URL: \"%@\"", [navigationURL absoluteString]]];
            
            self.url = navigationURL;
            [self addressBarCancel];
            return;
        }
    }
}

- (void)prepareForNewURL:(NSURL *)URL
{
	[[self applicableHTTPSEverywhereRules] removeAllObjects];
	[self setSSLCertificate:nil];
	[self setUrl:URL];
    [[appDelegate appWebView] updateSearchBarDetails];
}

- (void)searchFor:(NSString *)query
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
	
	if (se == nil)
		/* just pick the first search engine */
		se = [[appDelegate searchEngines] objectForKey:[[[appDelegate searchEngines] allKeys] firstObject]];
	
	NSDictionary *pp = [se objectForKey:@"post_params"];
	NSString *urls;
	if (pp == nil)
		urls = [[NSString stringWithFormat:[se objectForKey:@"search_url"], query] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	else
		urls = [se objectForKey:@"search_url"];
	
	NSURL *url = [NSURL URLWithString:urls];
	if (pp == nil) {
#ifdef TRACE
		NSLog(@"[Tab %@] searching via %@", self.tabIndex, url);
#endif
        
        [self loadURL:url];
	}
	else {
		/* need to send this as a POST, so build our key val pairs */
		NSMutableString *params = [NSMutableString stringWithFormat:@""];
		for (NSString *key in [pp allKeys]) {
			if (![params isEqualToString:@""])
				[params appendString:@"&"];
			
			[params appendString:[key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
			[params appendString:@"="];
			
			NSString *val = [pp objectForKey:key];
			if ([val isEqualToString:@"%@"])
				val = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[params appendString:val];
		}
		
		[self.webView stopLoading];
		[self prepareForNewURL:url];
		
#ifdef TRACE
		NSLog(@"[Tab %@] searching via POST to %@ (with params %@)", self.tabIndex, url, params);
#endif
        
		NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
		[self.webView loadRequest:request];
	}
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([[[[request URL] scheme] lowercaseString] isEqualToString:@"data"]) {
        NSString *url = [[request URL] absoluteString];
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"\\Adata:image/(?:jpe?g|gif|png)"
                                      options:NSRegularExpressionCaseInsensitive
                                      error:nil];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:url
                                                            options:0
                                                              range:NSMakeRange(0, [url length])];
        if (numberOfMatches == 0) {
            // This is a "data:" URI that isn't an image. Since this could be an HTML page,
            // PDF file, or other dynamic document, we should block it.
            // TODO: for now, this is silent
            return NO;
        }
    }
    
    [self setUrl:[request URL]];
    [[appDelegate appWebView] updateSearchBarDetails];

    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)__webView
{
    /* reset and then let WebViewController animate to our actual progress */
    [self setProgress:@0.0];
    [self setProgress:@0.1];
    
    if (self.url == nil)
        self.url = [[__webView request] URL];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
#ifdef TRACE
    NSLog(@"[Tab %@] finished loading page/iframe %@, security level is %lu", self.tabIndex, [[[__webView request] URL] absoluteString], self.secureMode);
#endif
    [self setProgress:@1.0];
    
    // Disable default long press menu
    [webView stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
    
    [self.title setText:[_webView stringByEvaluatingJavaScriptFromString:@"document.title"]];
    self.url = [NSURL URLWithString:[_webView stringByEvaluatingJavaScriptFromString:@"window.location.href"]];
}

- (void)webView:(UIWebView *)__webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"error: %@", error);
    
    // self.url = self.webView.request.URL;
    [self setProgress:@0];
    
    // For the user's sake, display every possible error
    /*
    if ([[error domain] isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
        return;
     
    // "The operation couldn't be completed. (Cocoa error 3072.)" - useless
    if ([[error domain] isEqualToString:NSCocoaErrorDomain] && error.code == NSUserCancelledError)
        return;
     */
     
    NSString *msg = [error localizedDescription];
    
    // https://opensource.apple.com/source/libsecurity_ssl/libsecurity_ssl-36800/lib/SecureTransport.h
    if ([[error domain] isEqualToString:NSOSStatusErrorDomain]) {
        switch (error.code) {
            case errSSLProtocol: // -9800
                msg = @"SSL protocol error";
                break;
            case errSSLNegotiation: // -9801
                msg = @"SSL handshake failed";
                break;
            case errSSLXCertChainInvalid: // -9807
                msg = @"SSL certificate chain verification error (self-signed certificate?)";
                break;
        }
    }
    
    NSString *u;
    if ((u = [[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]) != nil)
        msg = [NSString stringWithFormat:@"%@\n%@", msg, u];
    
#ifdef TRACE
    NSLog(@"[Tab %@] showing error dialog: %@ (%@)", self.tabIndex, msg, error);
#endif
    
    [self informError:error withMessage:msg];
}

- (void)webView:(UIWebView *)__webView callbackWith:(NSString *)callback
{
    NSString *finalcb = [NSString stringWithFormat:@"(function() { %@; __endless.ipcDone = (new Date()).getTime(); })();", callback];
    
#ifdef TRACE_IPC
    NSLog(@"[Javascript IPC]: calling back with: %@", finalcb);
#endif
    
    [__webView stringByEvaluatingJavaScriptFromString:finalcb];
}

- (void)informError:(NSError *)error withMessage:(NSString *)message {
    NSLog(@"message: %@", message);

    // Skip NSURLErrorDomain:kCFURLErrorCancelled because that's just "Cancel"
    // (user pressing stop button). Likewise with WebKitErrorFrameLoadInterrupted
    if (([error.domain isEqualToString:NSURLErrorDomain] && (error.code == kCFURLErrorCancelled))) {
        return;
    }
    
    if ((([error.domain isEqualToString:(NSString *)@"WebKitErrorDomain"]) && (error.code == 102))) {
        [ALToastView toastInView:self.viewHolder withText:@"Frame load interrupted" andBackgroundColor:[UIColor colorWithRed:1 green:0.231 blue:0.188 alpha:1]];
        
        return;
    }
    
    if ([error.domain isEqualToString:NSPOSIXErrorDomain] && (error.code == 61)) {
        /* Tor died */
        
#ifdef DEBUG
        NSLog(@"Tor socket failure: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
#endif
        
        NSString *errorTitle = @"Tor connection failure";
        NSString *errorDescription = @"\nThe Onion Browser lost connection to the Tor anonymity network and is unable to reconnect. This may occur if The Onion Browser went to the background or if the device went to sleep while The Onion Browser was active.\n\nPlease quit the app and try again.";

        // report the error inside the webview
        NSString *errorString = [NSString stringWithFormat:@"<div><div><div><div style=\"padding: 40px 15px;text-align: center;\"><h1>%@</h1><div style=\"font-size: 2em;\">%@</div><div style=\"font-size: 2em;\">%@</div></div></div></div></div>", errorTitle, errorDescription, message];
        
        [self.webView loadHTMLString:errorString baseURL:self.url];
        
    } else if ([error.domain isEqualToString:@"NSOSStatusErrorDomain"] && (error.code == -9807 || error.code == -9812)) {
        /* INVALID CERT */
        // Invalid certificate chain; valid cert chain, untrusted root
        
#ifdef DEBUG
        NSLog(@"Certificate error: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
#endif
        
        NSURL *url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        NSURL *failingURL = [error.userInfo objectForKey:@"NSErrorFailingURLKey"];
        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Cannot Verify Website Identity"
                                  message:[NSString stringWithFormat:@"Either the SSL certificate for '%@' is self-signed or the certificate was signed by an untrusted authority.\n\nFor normal websites, it is generally unsafe to proceed.\n\nFor .onion websites (or sites using CACert or self-signed certificates), you may proceed if you think you can trust this website's URL.", url.host]
                                  delegate:nil
                                  cancelButtonTitle:@"Cancel"
                                  otherButtonTitles:@"Continue",nil];
        alertView.delegate = self;
        alertView.tag = ALERTVIEW_SSL_WARNING;
        
        objc_setAssociatedObject(alertView, &SSLWarningKey, failingURL, OBJC_ASSOCIATION_RETAIN);
        
        [alertView show];
        
    } else {
        // ALL other error types are just notices (so no Cancel vs Continue stuff)
        NSString* errorTitle;
        NSString* errorDescription;
        
#ifdef DEBUG
        NSLog(@"Displayed Error: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
#endif
        
        if (([error.domain isEqualToString:@"NSOSStatusErrorDomain"] && (error.code == -9800 || error.code == -9801 || error.code == -9809 || error.code == -9818))) {
                /* SSL/TLS ERROR */
                // https://www.opensource.apple.com/source/Security/Security-55179.13/libsecurity_ssl/Security/SecureTransport.h
                
                NSURL *url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
                errorTitle = @"HTTPS Connection Failed";
                errorDescription = [NSString stringWithFormat:@"A secure connection to '%@' could not be made.\nThe site might be down, there could be a Tor network outage, or your 'minimum SSL/TLS' setting might want stronger security than the website provides.\n\nFull error: '%@'",
                                    url.host, error.localizedDescription];
            } else if ([error.domain isEqualToString:NSURLErrorDomain]) {
                /* HTTP ERRORS */
                // https://www.opensource.apple.com/source/Security/Security-55179.13/libsecurity_ssl/Security/SecureTransport.h
                
                if (error.code == kCFURLErrorHTTPTooManyRedirects) {
                    errorDescription = @"This website is stuck in a redirect loop. The web page you tried to access redirected you to another web page, which, in turn, is redirecting you (and so on).\n\nPlease contact the site operator to fix this problem.";
                } else if ((error.code == kCFURLErrorCannotFindHost) || (error.code == kCFURLErrorDNSLookupFailed)) {
                    errorDescription = @"The website you tried to access could not be found.";
                } else if (error.code == kCFURLErrorResourceUnavailable) {
                    errorDescription = @"The web page you tried to access is currently unavailable.";
                }
            } else if ([error.domain isEqualToString:(NSString *)@"WebKitErrorDomain"]) {
                if ((error.code == 100) || (error.code == 101)) {
                    errorDescription = @"The Onion Browser cannot display this type of content.";
                }
            } else if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork] ||
                       [error.domain isEqualToString:@"NSOSStatusErrorDomain"]) {
                if (error.code == kCFSOCKS5ErrorBadState) {
                    errorDescription = @"Could not connect to the server. Either the domain name is incorrect, the server is inaccessible, or the Tor circuit was broken.";
                } else if (error.code == kCFHostErrorHostNotFound) {
                    errorDescription = @"The website you tried to access could not be found.";
                }
            }
        
        // default
        if (errorTitle == nil) {
            errorTitle = @"Cannot Open Page";
        }
        if (errorDescription == nil) {
            errorDescription = [NSString stringWithFormat:@"An error occurred: %@\n(Error \"%@: %li)\"\nYou can try refreshing the page.",
                                error.localizedDescription, error.domain, (long)error.code];
        }
        
        // report the error inside the webview
        NSString *errorString = [NSString stringWithFormat:@"<div><div><div><div style=\"padding: 40px 15px;text-align: center;\"><h1>%@</h1><div style=\"font-size: 2em;\">%@</div><div style=\"font-size: 2em;\">%@</div></div></div></div></div>", errorTitle, errorDescription, message];
        
        [self.webView loadHTMLString:errorString baseURL:self.url];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ((alertView.tag == ALERTVIEW_TORFAIL) && (buttonIndex == 1)) {
        // Tor failed, user says we can quit app.
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate wipeAppData];
        exit(0);
    }
    
    if ((alertView.tag == ALERTVIEW_SSL_WARNING) && (buttonIndex == 1)) {
        // "Continue anyway" for SSL cert error
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        // Assumung URL in address bar is the one that caused this error.
        NSURL *url = objc_getAssociatedObject(alertView, &SSLWarningKey);
        NSString *hostname = url.host;
        [appDelegate.sslWhitelistedDomains addObject:hostname];
        
        [ALToastView toastInView:self.viewHolder withText:@"This website's SSL certificate errors will be\n ignored for the rest of this session." andDuration:5];
        
        // Reload (now that we have added host to whitelist)
        [self loadURL:url];
    } else if ((alertView.tag == ALERTVIEW_EXTERN_PROTO)) {
        if (buttonIndex == 1) {
            // Warned user about opening URL in external app and they said it's OK.
            NSURL *navigationURL = objc_getAssociatedObject(alertView, &AlertViewExternProtoUrl);
            //NSLog(@"launching URL: %@", [navigationURL absoluteString]);
            [[UIApplication sharedApplication] openURL:navigationURL];
        } else {
            [self addressBarCancel];
        }
    } else if ((alertView.tag == ALERTVIEW_INCOMING_URL)) {
        if (buttonIndex == 1) {
            // Warned user about opening this incoming URL and they said it's OK.
            NSURL *navigationURL = objc_getAssociatedObject(alertView, &AlertViewIncomingUrl);
            //NSLog(@"launching URL: %@", [navigationURL absoluteString]);
            [self loadURL:navigationURL];
        } else {
            // Otherwise, open default homepage.
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [self loadURL:[NSURL URLWithString:appDelegate.homepage]];
        }
    }
}

- (void)loadAddress:(id)sender event:(UIEvent *)event {
    NSURL* url = [self url];
    NSString *urlString = [NSString stringWithFormat:@"%@", [self url]];
    
    if(!url.scheme)
    {
        NSString *absUrl = [NSString stringWithFormat:@"http://%@", urlString];
        url = [NSURL URLWithString:absUrl];
    }
    _currentURL = [url absoluteString];
    
    self.url = url;
    [self loadURL:url];
}

- (void)updateTLSStatus:(Byte)newStatus {
    if (newStatus != TLSSTATUS_PREVIOUS) {
        _tlsStatus = newStatus;
    }
    /*
    UIView *uivSecure = [self.view viewWithTag:kTLSSecurePadlockTag];
    if (uivSecure == nil) {
        NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"secure.png" ofType:nil];
        uivSecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
        UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
        
        uivSecure.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        uivSecure.tag = kTLSSecurePadlockTag;
        uivSecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
        [navBar addSubview:uivSecure];
    }
    UIView *uivInsecure = [self.view viewWithTag:kTLSInsecurePadlockTag];
    if (uivInsecure == nil) {
        NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"insecure.png" ofType:nil];
        uivInsecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
        UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
        
        uivInsecure.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        uivInsecure.tag = kTLSInsecurePadlockTag;
        uivInsecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
        [navBar addSubview:uivInsecure];
    }
    
    if (_tlsStatus == TLSSTATUS_NO) {
        [uivSecure setHidden:YES];
        [uivInsecure setHidden:YES];
    } else if (_tlsStatus == TLSSTATUS_YES) {
        [uivSecure setHidden:NO];
        [uivInsecure setHidden:YES];
    } else {
        [uivSecure setHidden:YES];
        [uivInsecure setHidden:NO];
    }
     */
}

- (void)hideTLSStatus {
    /*
    UIView *uivSecure = [self.view viewWithTag:kTLSSecurePadlockTag];
    if (uivSecure == nil) {
        NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"secure.png" ofType:nil];
        uivSecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
        UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
        
        uivSecure.tag = kTLSSecurePadlockTag;
        uivSecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
        [navBar addSubview:uivSecure];
    }
    UIView *uivInsecure = [self.view viewWithTag:kTLSInsecurePadlockTag];
    if (uivInsecure == nil) {
        NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"insecure.png" ofType:nil];
        uivInsecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
        UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
        
        uivInsecure.tag = kTLSInsecurePadlockTag;
        uivInsecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
        [navBar addSubview:uivInsecure];
    }
    
    [uivSecure setHidden:YES];
    [uivInsecure setHidden:YES];
     */
}

- (void)setSSLCertificate:(SSLCertificate *)SSLCertificate
{
	_SSLCertificate = SSLCertificate;
	
	if (_SSLCertificate == nil) {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to insecure", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeInsecure];
	}
	else if ([[self SSLCertificate] isEV]) {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to ev", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeSecureEV];
	}
	else {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to secure", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeSecure];
	}
}

- (void)setProgress:(NSNumber *)pr
{
	_progress = pr;
	[[appDelegate appWebView] updateProgress];
}

- (void)swipeRightAction:(UISwipeGestureRecognizer *)gesture
{
	[self goBack];
}

- (void)swipeLeftAction:(UISwipeGestureRecognizer *)gesture
{
	[self goForward];
}

- (void)webViewTouched:(UIEvent *)event
{
	[[appDelegate appWebView] webViewTouched];
}

- (void)longPressMenu:(UILongPressGestureRecognizer *)sender {
	UIAlertController *alertController;
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
    
	alertController = [UIAlertController alertControllerWithTitle:href message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	
	UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self loadURL:[NSURL URLWithString:href]];
	}];
	
	UIAlertAction *openNewTabAction = [UIAlertAction actionWithTitle:@"Open in a New Tab" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[appDelegate appWebView] addNewTabForURL:[NSURL URLWithString:href]];
	}];
	
	UIAlertAction *openSafariAction = [UIAlertAction actionWithTitle:@"Open in Safari" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:href]];
	}];

	UIAlertAction *saveImageAction = [UIAlertAction actionWithTitle:@"Save Image" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSURL *imgurl = [NSURL URLWithString:img];

        NSData *imgdata = [NSData dataWithContentsOfURL:imgurl];
		if (imgdata) {
			UIImage *i = [UIImage imageWithData:imgdata];
			UIImageWriteToSavedPhotosAlbum(i, self,  @selector(image:didFinishSavingWithError:contextInfo:), nil);
		} else {
            [ALToastView toastInView:self.viewHolder withText:@"Failed to download image:\nCouldn't retrieve the image's data" andBackgroundColor:[UIColor colorWithRed:1 green:0.231 blue:0.188 alpha:1] andDuration:3];
		}
	}];
	
	UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:@"Copy URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
		popover.sourceView = [[appDelegate appWebView] view];
		popover.sourceRect = [[[appDelegate appWebView] view] bounds];
		popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
	}
    	
	[[appDelegate appWebView] presentViewController:alertController animated:YES completion:nil];
}

- (BOOL)canGoBack
{
	return ((self.webView && [self.webView canGoBack]) || self.openedByTabHash != nil);
}

- (BOOL)canGoForward
{
	return !!(self.webView && [self.webView canGoForward]);
}

- (void)goBack
{
	if ([self.webView canGoBack]) {
		[[self webView] goBack];
	}
	else if (self.openedByTabHash) {
		for (WebViewTab *wvt in [[appDelegate appWebView] webViewTabs]) {
			if ([wvt hash] == [self.openedByTabHash longValue]) {
				[[appDelegate appWebView] removeTab:self.tabIndex andFocusTab:[wvt tabIndex]];
				return;
			}
		}
		
		[[appDelegate appWebView] removeTab:self.tabIndex];
	}
}

- (void)goForward
{
	if ([[self webView] canGoForward])
		[[self webView] goForward];
}

- (void)refresh
{
	[self setNeedsRefresh:FALSE];
	[[self webView] reload];
}

- (void)forceRefresh
{
	[self loadURL:[self url]];
}

- (void)zoomOut
{
	[[self webView] setUserInteractionEnabled:NO];

	[_titleHolder setHidden:false];
	[_title setHidden:false];
	[_closer setHidden:false];
	[[[self viewHolder] layer] setShadowOpacity:0.3];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE)];
}

- (void)zoomNormal
{
	[[self webView] setUserInteractionEnabled:YES];

	[_titleHolder setHidden:true];
	[_title setHidden:true];
	[_closer setHidden:true];
	[[[self viewHolder] layer] setShadowOpacity:0];
	[[self viewHolder] setTransform:CGAffineTransformIdentity];
}

- (CGSize)windowSize
{
    CGSize size;
    size.width = [[self.webView stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] integerValue];
    size.height = [[self.webView stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] integerValue];
    return size;
}

- (CGPoint)scrollOffset
{
    CGPoint pt;
    pt.x = [[self.webView stringByEvaluatingJavaScriptFromString:@"window.pageXOffset"] integerValue];
    pt.y = [[self.webView stringByEvaluatingJavaScriptFromString:@"window.pageYOffset"] integerValue];
    return pt;
}

- (NSArray *)elementsAtLocationFromGestureRecognizer:(UIGestureRecognizer *)uigr
{
    /*
     CGPoint tap = [uigr locationInView:[self webView]];
     tap.y -= [[[self webView] scrollView] contentInset].top;
     
     // translate tap coordinates from view to scale of page
    CGSize windowSize = CGSizeMake(
                                   [[[self webView] stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] intValue],
                                   [[[self webView] stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] intValue]
                                   );
    CGSize viewSize = [[self webView] frame].size;
    float ratio = windowSize.width / viewSize.width;
    CGPoint tapOnPage = CGPointMake(tap.x * ratio, tap.y * ratio);
     */

    CGPoint tap = [uigr locationInView:[self webView]];
    
    // convert point from window to view coordinate system, and remove status bar and toolbar's height
    tap = [self.webView convertPoint:tap fromView:nil];
    tap.y += [UIApplication sharedApplication].statusBarFrame.size.height;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (![userDefaults boolForKey:@"toolbar_on_bottom"]) {
        tap.y += TOOLBAR_HEIGHT;
    }
    
    // convert point from view to HTML coordinate system
    CGPoint offset  = [self scrollOffset];
    CGSize viewSize = [[self webView] frame].size;
    CGSize windowSize = [self windowSize];
    
    CGFloat f = windowSize.width / viewSize.width;
    tap.x = tap.x * f + offset.x;
    tap.y = tap.y * f + offset.y;
    
	/* now find if there are usable elements at those coordinates and extract their attributes */
    // Load the JavaScript code from the Resources and inject it into the web page
    NSString *path = [[NSBundle mainBundle] pathForResource:@"JSTools" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [[self webView] stringByEvaluatingJavaScriptFromString:jsCode];
    
    // Get the tags at the touch location
    NSString *tags = [[self webView] stringByEvaluatingJavaScriptFromString:
                      [NSString stringWithFormat:@"__TheOnionBrowerGetHTMLElementsAtPoint(%li,%li);",(long)tap.x,(long)tap.y]];
    
    // Get the link info at the touch location
    NSString *jsonString = [[self webView] stringByEvaluatingJavaScriptFromString:
                         [NSString stringWithFormat:@"__TheOnionBrowerGetLinkInfoAtPoint(%li,%li);",(long)tap.x,(long)tap.y]];
    
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
	if ([source  isEqualToString:@""] || ([tag isEqualToString:@""] && [tags isEqualToString:@""])) {
		return @[@"", @"", @""];
	}
        
    tags = [NSString stringWithFormat:@"%@, %@", tag, tags]; // If the user clicked slightly next to the URL, the fuzz will still detect it but won't add it to the tags list, so we add it here
    
    return @[tags, source, tag];
}

- (void)image:(UIImage*)image didFinishSavingWithError:(NSError *)error contextInfo:(void*)contextInfo
{
    if (error) {
        [ALToastView toastInView:self.viewHolder withText:[NSString stringWithFormat:@"Failed to download image:\n%@", [error localizedDescription]] andBackgroundColor:[UIColor colorWithRed:1 green:0.231 blue:0.188 alpha:1] andDuration:3];
    } else {
        [ALToastView toastInView:self.viewHolder withText:@"Successfully saved image"];
    }
}

-(void)openSettingsView {
    /*
    SettingsTableViewController *settingsController = [[SettingsTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *settingsNavController = [[UINavigationController alloc]
                                                     initWithRootViewController:settingsController];
    
    [self presentViewController:settingsNavController animated:YES completion:nil];
     */
}

@end
