//
//  SettingsTableViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 5/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "AppDelegate.h"
#import "BridgeViewController.h"
#import "Bridge.h"
#import "BookmarkTableViewController.h"
#import "BookmarkEditViewController.h"
#import "Bookmark.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController
@synthesize backButton;

- (void)viewDidLoad
{
    [super viewDidLoad];

    backButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(goBack)];
    self.navigationItem.rightBarButtonItem = backButton;
    self.navigationItem.title = @"Settings";
    
    if([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (IS_IPAD) || (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)goBack {
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return 1;
    else if (section == 1)
        // Bookmarks
        return 2;
    else if (section == 2)
        // Active Content
        return 3;
    else if (section == 3)
        // Cookies
        return 3;
    else if (section == 4)
        // UA Spoofing
        return 5;
    else if (section == 5)
        // DNT header
        return 2;
    else if (section == 6)
        // SSL
        return 3;
    else if (section == 7)
        // Bridges
        return 1;

    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if (section == 0)
        return @"Home Page";
    else if (section == 1)
        return @"Bookmarks";
    else if (section == 2)
        return @"Active Content Blocking (Scripts, Media, Ajax, WebSockets, etc)";
    else if (section == 3)
        return @"Cookies";
    else if (section == 4) {
        NSString *devicename;
        if (IS_IPAD) {
            devicename = @"iPad";
        } else {
            devicename = @"iPhone";
        }
        return [NSString stringWithFormat:@"User-Agent Spoofing"];
    } else if (section == 5)
        return @"Do Not Track (DNT) Header";
    else if (section == 6)
        return @"Minimum SSL/TLS protocol";
    else if (section == 7)
        return @"Tor Bridges\nClick below to configure bridges if your ISP normally blocks connections to Tor.";
    else
        return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
    }
    
    if(indexPath.section == 0) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings2 = appDelegate.getSettings;
        cell.textLabel.text = [settings2 objectForKey:@"homepage"];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.textLabel.text = @"Bookmark current URL";
        } else {
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.textLabel.text = @"Edit bookmarks";
        }
    } else if (indexPath.section == 2) {
        // Active Content
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger csp_setting = [[settings valueForKey:@"javascript"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Block Ajax/Media/WebSockets";
            if (csp_setting == CONTENTPOLICY_BLOCK_CONNECT) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Block All Active Content";
            if (csp_setting == CONTENTPOLICY_STRICT) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Allow All (DANGEROUS)";
            if (csp_setting == CONTENTPOLICY_PERMISSIVE) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if(indexPath.section == 3) {
        // Cookies
        NSHTTPCookie *cookie;
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (cookie in [storage cookies]) {
            [storage deleteCookie:cookie];
        }

        NSHTTPCookieAcceptPolicy currentCookieStatus = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy];
        NSUInteger cookieStatusSection = 0;
        if (currentCookieStatus == NSHTTPCookieAcceptPolicyAlways) {
            cookieStatusSection = 0;
        } else if (currentCookieStatus == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain) {
            cookieStatusSection = 1;
        } else {
            cookieStatusSection = 2;
        }

        if (indexPath.row == cookieStatusSection) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Allow All";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Block Third-Party";
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Block All";
        }
    } else if (indexPath.section == 4) {
        // User-Agent
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger spoofUserAgent = [[settings valueForKey:@"uaspoof"] integerValue];
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Standard";
            if (spoofUserAgent == UA_SPOOF_NO) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Normalized iPhone (iOS Safari)";
            if (spoofUserAgent == UA_SPOOF_IPHONE) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Normalized iPad (iOS Safari)";
            if (spoofUserAgent == UA_SPOOF_IPAD) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"Windows 7 (NT 6.1), Firefox 24";
            if (spoofUserAgent == UA_SPOOF_WIN7_TORBROWSER) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 4) {
            cell.textLabel.text = @"Mac OS X 10.9.2, Safari 7.0.3";
            if (spoofUserAgent == UA_SPOOF_SAFARI_MAC) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 5) {
        // DNT
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger dntHeader = [[settings valueForKey:@"dnt"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"No Preference Sent";
            if (dntHeader == DNT_HEADER_UNSET) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Tell Websites Not To Track";
            if (dntHeader == DNT_HEADER_NOTRACK) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 6) {
        // SSL
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger dntHeader = [[settings valueForKey:@"tlsver"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"SSL v3 (INSECURE)";
            if (dntHeader == X_TLSVER_ANY) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"TLS 1.0+";
            if (dntHeader == X_TLSVER_TLS1) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"TLS 1.2 only";
            if (dntHeader == X_TLSVER_TLS1_2_ONLY) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 7) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:appDelegate.managedObjectContext];
        [request setEntity:entity];
        
        NSError *error = nil;
        NSMutableArray *mutableFetchResults = [[appDelegate.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
        if (mutableFetchResults == nil) {
            // Handle the error.
        }

        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        NSUInteger numBridges = [mutableFetchResults count];
        if (numBridges == 0) {
            cell.textLabel.text = @"Not Using Bridges";
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%ld Bridges Configured",
                                   (unsigned long)numBridges];
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings2 = appDelegate.getSettings;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Home Page" message:@"Leave blank to use default Tob home page." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            NSMutableDictionary *settings = appDelegate.getSettings;

            if ([[alert.textFields.firstObject text] length] == 0) {
                [settings setValue:@"https://duckduckgo.com" forKey:@"homepage"]; // DEFAULT HOMEPAGE
            } else {
                NSString *h = [alert.textFields.firstObject text];
                if ( (![h hasPrefix:@"http:"]) && (![h hasPrefix:@"https:"]) && (![h hasPrefix:@"tob:"]) && (![h hasPrefix:@"about:"]) )
                    h = [NSString stringWithFormat:@"http://%@", h];
                [settings setValue:h forKey:@"homepage"];
            }
            [appDelegate saveSettings:settings];
            [self.tableView reloadData];
        }]];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
          textField.autocorrectionType = UITextAutocorrectionTypeNo;
          [textField setKeyboardType:UIKeyboardTypeURL];
          textField.text = [settings2 objectForKey:@"homepage"];
        }];


        [self presentViewController:alert animated:YES completion:NULL];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
            Bookmark *bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:managedObjectContext];

            [bookmark setTitle:[[appDelegate.tabsViewController subtitles] objectAtIndex:appDelegate.tabsViewController.tabView.currentIndex]];
            [bookmark setUrl:[[appDelegate.tabsViewController titles] objectAtIndex:appDelegate.tabsViewController.tabView.currentIndex]];

            BookmarkEditViewController *editController = [[BookmarkEditViewController alloc] initWithBookmark:bookmark];
            [self presentViewController:editController animated:YES completion:nil];
        } else {
            BookmarkTableViewController *bookmarksVC = [[BookmarkTableViewController alloc] initWithStyle:UITableViewStylePlain];
            UINavigationController *bookmarkNavController = [[UINavigationController alloc]
                                                             initWithRootViewController:bookmarksVC];
            
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            
            NSManagedObjectContext *context = [appDelegate managedObjectContext];
            
            bookmarksVC.managedObjectContext = context;
            
            [self presentViewController:bookmarkNavController animated:YES completion:nil];
        }
    } else if (indexPath.section == 2) {
        // Active Content
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:CONTENTPOLICY_BLOCK_CONNECT] forKey:@"javascript"];
            [appDelegate saveSettings:settings];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Experimental Feature" message:@"Blocking of Ajax/XHR/WebSocket requests is experimental. Some websites may not work if these dynamic requests are blocked; but these dynamic requests can leak your identity." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:CONTENTPOLICY_STRICT] forKey:@"javascript"];
            [appDelegate saveSettings:settings];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Experimental Feature" message:@"Blocking all active content is an experimental feature.\n\nDisabling active content makes it harder for websites to identify your device, but websites will be able to tell that you are blocking scripts. This may be identifying information if you are the only user that blocks scripts.\n\nSome websites may not work if active content is blocked.\n\nBlocking may cause Tob to crash when loading script-heavy websites." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:CONTENTPOLICY_PERMISSIVE] forKey:@"javascript"];
            [appDelegate saveSettings:settings];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Security Warning" message:@"The 'Allow All' setting is UNSAFE and only recommended if a trusted site requires Ajax or WebSockets.\n\nWebSocket requests happen outside of Tor and will unmask your real IP address." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        }
    } else if(indexPath.section == 3) {
        // Cookies
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_ALLOW_ALL] forKey:@"cookies"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_THIRDPARTY] forKey:@"cookies"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_ALL] forKey:@"cookies"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
        }
    } else if (indexPath.section == 4) {
        // User-Agent
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        
        //NSString* secretAgent = [appDelegate.appWebView.myWebView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        //NSLog(@"%@", secretAgent);

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_NO] forKey:@"uaspoof"];
            [appDelegate saveSettings:settings];
        } else {
            if (indexPath.row == 1) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_IPHONE] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 2) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_IPAD] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 3) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_WIN7_TORBROWSER] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 4) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_SAFARI_MAC] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            }
        }
    } else if (indexPath.section == 5) {
        // DNT
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:DNT_HEADER_UNSET] forKey:@"dnt"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:DNT_HEADER_NOTRACK] forKey:@"dnt"];
            [appDelegate saveSettings:settings];
        }
    } else if (indexPath.section == 6) {
        // TLS
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:X_TLSVER_ANY] forKey:@"tlsver"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1] forKey:@"tlsver"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1_2_ONLY] forKey:@"tlsver"];
            [appDelegate saveSettings:settings];
        }
    } else if (indexPath.section == 7) {
        BridgeViewController *bridgesVC = [[BridgeViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:navController animated:YES completion:nil];
    }
    [tableView reloadData];
}



@end
