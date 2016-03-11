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
#import "Bookmark.h"
#import "BookmarkController.h"
#import "IASKAppSettingsViewController.h"
#import "WebViewMenuController.h"
#import "BridgeViewController.h"
#import "IASKAppSettingsViewController.h"
#import "HTTPSEverywhereRuleController.h"
#define CELL_HEIGHT 35

@implementation WebViewMenuController

AppDelegate *appDelegate;
IASKAppSettingsViewController *appSettingsViewController;
NSMutableArray *buttons;

NSString * const FUNC = @"F";
NSString * const LABEL = @"L";

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	buttons = [[NSMutableArray alloc] initWithCapacity:10];
	
	[buttons addObject:@{ FUNC : @"menuRefresh", LABEL : @"Refresh" }];
	[buttons addObject:@{ FUNC : @"menuAddBookmark", LABEL : @"Add Bookmark" }];
    [buttons addObject:@{ FUNC : @"menuSetHomepage", LABEL : @"Set Homepage" }];
	[buttons addObject:@{ FUNC : @"menuOpenInSafari", LABEL : @"Open in Safari" }];
	[buttons addObject:@{ FUNC : @"menuManageBookmarks", LABEL : @"Manage Bookmarks" }];
	[buttons addObject:@{ FUNC : @"menuSettings", LABEL : @"Settings" }];
    [buttons addObject:@{ FUNC : @"menuOpenBridge", LABEL : @"Add Tor bridge" }];
    [buttons addObject:@{ FUNC : @"menuHTTPSEverywhere", LABEL : @"HTTPS Everywhere" }];
    [buttons addObject:@{ FUNC : @"menuNewIdentity", LABEL : @"New identity" }];

	[self.view setBackgroundColor:[UIColor clearColor]];
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
}

- (CGSize)preferredContentSize
{
	return CGSizeMake(250, CELL_HEIGHT * [buttons count]);
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [buttons count];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([cell respondsToSelector:@selector(setSeparatorInset:)])
		[cell setSeparatorInset:UIEdgeInsetsZero];

	if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)])
		[cell setPreservesSuperviewLayoutMargins:NO];

	if ([cell respondsToSelector:@selector(setLayoutMargins:)])
		[cell setLayoutMargins:UIEdgeInsetsZero];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"button"];
	
	NSDictionary *button = [buttons objectAtIndex:[indexPath row]];
	
	cell.backgroundColor = [UIColor clearColor];
	cell.textLabel.font = [UIFont systemFontOfSize:13];
	cell.textLabel.text = [button objectForKey:LABEL];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    
    UIImage *cellImage = [UIImage imageNamed:@"bookmark"];
	
	BOOL haveURL = ([[[appDelegate appWebView] curWebViewTab] url] != nil);

	NSString *func = [button objectForKey:FUNC];
	if ([func isEqualToString:@"menuAddBookmark"]) {
        cellImage = [UIImage imageNamed:@"bookmark"];

		if (haveURL) {
			if ([Bookmark isURLBookmarked:[[[appDelegate appWebView] curWebViewTab] url]]) {
				cell.textLabel.text = @"Bookmarked";
				cell.userInteractionEnabled = cell.textLabel.enabled = NO;
			}
		}
		else
			cell.userInteractionEnabled = cell.textLabel.enabled = NO;
	}
	else if ([func isEqualToString:@"menuRefresh"]) {
		cell.userInteractionEnabled = haveURL;
        cell.textLabel.enabled = haveURL;
        cellImage = [UIImage imageNamed:@"refreshImage"];
    } else if ([func isEqualToString:@"menuOpenInSafari"]) {
        cell.userInteractionEnabled = haveURL;
        cell.textLabel.enabled = haveURL;
        cellImage = [UIImage imageNamed:@"safari"];
    }
    else if ([func isEqualToString:@"menuManageBookmarks"])
        cellImage = [UIImage imageNamed:@"bookmarks"];
    else if ([func isEqualToString:@"menuSetHomepage"]) {
        cellImage = [UIImage imageNamed:@"homepage"];
        if (haveURL) { //[appDelegate homepage]
            // cell.userInteractionEnabled = cell.textLabel.enabled = YES;
            if ([[appDelegate homepage] isEqualToString:[NSString stringWithFormat:@"%@", [[[appDelegate appWebView] curWebViewTab] url]]]) {
                cell.userInteractionEnabled = cell.textLabel.enabled = NO;
            }
        }
        else
            cell.userInteractionEnabled = cell.textLabel.enabled = NO;
    } else if ([func isEqualToString:@"menuHTTPSEverywhere"] && haveURL) {
        cellImage = [UIImage imageNamed:@"httpsEverywhere"];
        long ruleCount = [[[[appDelegate appWebView] curWebViewTab] applicableHTTPSEverywhereRules] count];
        
        if (ruleCount > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld rule%@ in use", ruleCount, (ruleCount == 1 ? @"" : @"s")];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
        }
    }
    else if ([func isEqualToString:@"menuSettings"])
        cellImage = [UIImage imageNamed:@"settingsImage"];
    else if ([func isEqualToString:@"menuOpenBridge"])
        cellImage = [UIImage imageNamed:@"bridge"];
    else if ([func isEqualToString:@"menuNewIdentity"])
        cellImage = [UIImage imageNamed:@"identity"];
    
    cell.imageView.image = cellImage;
    
    CGFloat widthScale = 22 / cellImage.size.width;
    CGFloat heightScale = 22 / cellImage.size.height;
    cell.imageView.transform = CGAffineTransformMakeScale(widthScale, heightScale);
    
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return CELL_HEIGHT;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[appDelegate appWebView] dismissPopover];
	NSDictionary *button = [buttons objectAtIndex:[indexPath row]];

	SEL action = NSSelectorFromString([button objectForKey:FUNC]);
    
    if ([self respondsToSelector:action]) {
        IMP imp = [self methodForSelector:action];
        void (*func)(id, SEL) = (void *)imp;
        func(self, action);
    }
	else
		NSLog(@"can't call %@", NSStringFromSelector(action));
}

- (void)menuRefresh
{
	[[appDelegate appWebView] refresh];
}

- (void)menuSettings
{
	if (!appSettingsViewController) {
		appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
		appSettingsViewController.delegate = [appDelegate appWebView];
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.showCreditsFooter = YES;
	}
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[[appDelegate appWebView] presentViewController:navController animated:YES completion:nil];
}

/*
- (void)menuCookies
{
	CookieController *cc = [[CookieController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:cc];
	[[appDelegate appWebView] presentViewController:navController animated:YES completion:nil];
}
*/

- (void)menuHTTPSEverywhere
{
    HTTPSEverywhereRuleController *herc = [[HTTPSEverywhereRuleController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:herc];
    [[appDelegate appWebView] presentViewController:navController animated:YES completion:nil];
}


- (void)menuManageBookmarks
{
	BookmarkController *bc = [[BookmarkController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bc];
	[[appDelegate appWebView] presentViewController:navController animated:YES completion:nil];
}

- (void)menuAddBookmark
{
	[[appDelegate appWebView] presentViewController:[Bookmark addBookmarkDialogWithOkCallback:nil] animated:YES completion:nil];
}

- (void)menuSetHomepage
{
    [self updateHomepage:[NSString stringWithFormat:@"%@", [[[appDelegate appWebView] curWebViewTab] url]]];
}

- (void)menuOpenInSafari
{
	WebViewTab *wvt = [[appDelegate appWebView] curWebViewTab];
    NSLog(@"%@", [wvt url]);
    if (wvt && [wvt url] && [[UIApplication sharedApplication] canOpenURL:[wvt url]])
		[[UIApplication sharedApplication] openURL:[wvt url]];
    else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Cannot open link in safari: unsupported URL." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [[appDelegate appWebView] presentViewController:alert animated:YES completion:nil];
    }
}

- (void)menuOpenBridge {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bridge Configuration"
                                                    message:@"You can configure bridges here if your ISP normally blocks access to Tor.\n\nIf you did not mean to access the Bridge configuration, press \"Cancel\", then \"Restart App\", and then re-launch The Onion Browser."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    
    BridgeViewController *bridgesVC = [[BridgeViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [[appDelegate appWebView] presentViewController:navController animated:YES completion:nil];
}

- (void)menuNewIdentity {
    [appDelegate wipeAppData];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:@"Requesting a new IP address from Tor. Cache, non-whitelisted cookies, and browser history cleared.\n\nDue to an iOS limitation, visisted links still get the ':visited' CSS highlight state."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];

    // All tabs need to be refreshed
    for (WebViewTab *tab in [[appDelegate appWebView] webViewTabs]) {
        [tab setNeedsRefresh:YES];
    }
    
    // Refresh the current tab
    [[[appDelegate appWebView] curWebViewTab] setNeedsRefresh:NO];
    [[[appDelegate appWebView] curWebViewTab] refresh];
}

- (NSString *)settingsFile {
    return [[[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] path] stringByAppendingPathComponent:@"Settings.plist"];
}

- (void)updateHomepage:(NSString *)homepage {
    NSPropertyListFormat format;
    NSMutableDictionary *d;
    
    NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:self.settingsFile];
    d = (NSMutableDictionary *)[NSPropertyListSerialization propertyListWithData:plistXML options:NSPropertyListMutableContainersAndLeaves format:&format error:nil];
    
    [d setObject:homepage forKey:@"homepage"];
    [self saveSettings:d];
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

- (void) goHome {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    [[appDelegate appWebView] addNewTabForURL:[NSURL URLWithString:appDelegate.homepage]];
}

@end
