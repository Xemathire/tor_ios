//
//  BridgeViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 3/10/15.
//
//

#import "BridgeViewController.h"
#import "AppDelegate.h"
#import "UIPlaceHolderTextView.h"
#import "Bridge.h"

@interface BridgeViewController ()

@end

@implementation BridgeViewController

- (void)viewDidLoad {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];;
    [appDelegate.tor disableNetwork];
    
    
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Bridges", nil);
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveAndExit)];
    UIBarButtonItem *qrButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(qrscan)];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:saveButton, qrButton, nil]];
    
    self.navigationController.toolbarHidden = NO;
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *providedBridgesItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Presets", nil) style:UIBarButtonItemStylePlain target:self action:@selector(selectPresetBridges)];
    UIBarButtonItem *resetBridgesItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Clear", nil) style:UIBarButtonItemStylePlain target:self action:@selector(resetBridges)];
    NSArray *items = [NSArray arrayWithObjects:providedBridgesItem, flexibleItem, resetBridgesItem, nil];
    self.toolbarItems = items;
    
    CGSize size = [UIScreen mainScreen].bounds.size;
    CGRect txtFrame = [UIScreen mainScreen].bounds;
    txtFrame.origin.y = 0;
    txtFrame.origin.x = 0;
    txtFrame.size = size;
    
    UIPlaceHolderTextView *txtView = [[UIPlaceHolderTextView alloc] initWithFrame:txtFrame];
    txtView.font = [UIFont systemFontOfSize:11];
    txtView.text = [self bridgesToBridgeLines];
    if ([QRCodeReader isAvailable]) {
        txtView.placeholder = NSLocalizedString(@"You can configure bridges here if your ISP normally blocks access to Tor.\n\nSelect a preset or visit https://bridges.torproject.org/ to get bridges and then tap the 'camera' icon above to scan the QR code, or manually copy-and-paste the \"bridge lines\" here.", nil);
    } else {
        txtView.placeholder = NSLocalizedString(@"You can configure bridges here if your ISP normally blocks access to Tor.\n\nSelect a preset or visit https://bridges.torproject.org/ to get bridges and copy-and-paste the \"bridge lines\" here.", nil);
    }
    txtView.placeholderColor = [UIColor grayColor];
    txtView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    txtView.tag = 50;
    [self.view addSubview: txtView];
}

- (NSString *)bridgesToBridgeLines {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];;
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
    [request setEntity:entity];
    
    NSError *err = nil;
    NSArray *results = [ctx executeFetchRequest:request error:&err];
    if (results == nil) {
        NSLog(@"Data load did not complete successfully. Error: %@", [err localizedDescription]);
        return nil;
    } else if ([results count] < 1) {
        NSLog(@"Zero results");
        return nil;
    } else {
        NSLog(@"%lu results", (unsigned long)[results count]);
        NSMutableString *output = [[NSMutableString alloc] init];
        for (Bridge *bridge in results) {
            [output appendFormat:@"%@\n", bridge.conf];
        }
        return [NSString stringWithString:output];
    }
}

- (NSString *)defaultObfs4 {
    NSString *defaultLines = @"obfs4 154.35.22.10:41835 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
    obfs4 198.245.60.50:443 752CF7825B3B9EA6A98C83AC41F7099D67007EA5 cert=xpmQtKUqQ/6v5X7ijgYE/f03+l2/EuQ1dexjyUhh16wQlu/cpXUGalmhDIlhuiQPNEKmKw iat-mode=0\n\
    obfs4 192.99.11.54:443 7B126FAB960E5AC6A629C729434FF84FB5074EC2 cert=VW5f8+IBUWpPFxF+rsiVy2wXkyTQG7vEd+rHeN2jV5LIDNu8wMNEOqZXPwHdwMVEBdqXEw iat-mode=0\n\
    obfs4 109.105.109.165:10527 8DFCD8FB3285E855F5A55EDDA35696C743ABFC4E cert=Bvg/itxeL4TWKLP6N1MaQzSOC6tcRIBv6q57DYAZc3b2AzuM+/TfB7mqTFEfXILCjEwzVA iat-mode=0\n\
    obfs4 83.212.101.3:41213 A09D536DD1752D542E1FBB3C9CE4449D51298239 cert=lPRQ/MXdD1t5SRZ9MquYQNT9m5DV757jtdXdlePmRCudUU9CFUOX1Tm7/meFSyPOsud7Cw iat-mode=0\n\
    obfs4 109.105.109.147:13764 BBB28DF0F201E706BE564EFE690FE9577DD8386D cert=KfMQN/tNMFdda61hMgpiMI7pbwU1T+wxjTulYnfw+4sgvG0zSH7N7fwT10BI8MUdAD7iJA iat-mode=0\n\
    obfs4 154.35.22.11:49868 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
    obfs4 154.35.22.12:80 00DC6C4FA49A65BD1472993CF6730D54F11E0DBB cert=N86E9hKXXXVz6G7w2z8wFfhIDztDAzZ/3poxVePHEYjbKDWzjkRDccFMAnhK75fc65pYSg iat-mode=0\n\
    obfs4 154.35.22.13:443 FE7840FE1E21FE0A0639ED176EDA00A3ECA1E34D cert=fKnzxr+m+jWXXQGCaXe4f2gGoPXMzbL+bTBbXMYXuK0tMotd+nXyS33y2mONZWU29l81CA iat-mode=0\n\
    obfs4 154.35.22.10:80 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
    obfs4 154.35.22.10:443 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
    obfs4 154.35.22.11:443 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
    obfs4 154.35.22.11:80 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
    obfs4 154.35.22.9:60873 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
    obfs4 154.35.22.9:80 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
    obfs4 154.35.22.9:443 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0";
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[defaultLines componentsSeparatedByCharactersInSet:
                                                            [NSCharacterSet characterSetWithCharactersInString:@"\n"]
                                                            ]];
    
    // Randomize order of the bridge lines.
    for (int x = 0; x < [lines count]; x++) {
        int randInt = (arc4random() % ([lines count] - x)) + x;
        [lines exchangeObjectAtIndex:x withObjectAtIndex:randInt];
    }
    return [lines componentsJoinedByString:@"\n"];
    // Take a subset of the randomized lines and return it as a new string of bridge lines.
    //NSArray *subset = [lines subarrayWithRange:(NSRange){0, 5}];
    //return [subset componentsJoinedByString:@"\n"];
}

- (NSString *)defaultMeekAmazon {
    return @"meek_lite 0.0.2.0:2 B9E7141C594AF25699E0079C1F0146F409495296 url=https://d2zfqthxsdq309.cloudfront.net/ front=a0.awsstatic.com";
}

- (NSString *)defaultMeekAzure {
    return @"meek_lite 0.0.2.0:3 A2C13B7DFCAB1CBF3A884B6EB99A98067AB6EF44 url=https://az786092.vo.msecnd.net/ front=ajax.aspnetcdn.com";
}

- (void)qrscan {
    if ([QRCodeReader supportsMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]]) {
        static QRCodeReaderViewController *reader = nil;
        static dispatch_once_t onceToken;
        
        dispatch_once(&onceToken, ^{
            reader                        = [QRCodeReaderViewController new];
            reader.modalPresentationStyle = UIModalPresentationFormSheet;
        });
        reader.delegate = self;
        
        [reader setCompletionWithBlock:^(NSString *resultAsString) {
            NSLog(@"Completion with result: %@", resultAsString);
        }];
        
        [self presentViewController:reader animated:YES completion:NULL];
    }
    else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Camera access was not granted or QRCode scanning is not supported by your device.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:NULL];
    }
}
#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result {
    [self dismissViewControllerAnimated:YES completion:^{
        NSString *realResult = result;
        
        // I think QRCode used to return the exact string we wanted (newline delimited),
        // but now it returns a JSON-like array ['bridge1', 'bridge2'...] so parse that out.
        if ([result containsString:@"['"] || [result containsString:@"[\""]) {
            // Actually, the QRCode is json-like. It uses single-quote string array, where JSON only
            // allows double-quote.
            realResult = [realResult stringByReplacingOccurrencesOfString:@"['" withString:@"[\""];
            realResult = [realResult stringByReplacingOccurrencesOfString:@"', '" withString:@"\", \""];
            realResult = [realResult stringByReplacingOccurrencesOfString:@"','" withString:@"\",\""];
            realResult = [realResult stringByReplacingOccurrencesOfString:@"']" withString:@"\"]"];
            
#ifdef DEBUG
            NSLog(@"realResult: %@", realResult);
#endif
            
            NSError *e = nil;
            NSArray *resultLines = [NSJSONSerialization JSONObjectWithData:[realResult dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&e];
            
#ifdef DEBUG
            NSLog(@"resultLines: %@", resultLines);
#endif
            
            if (resultLines) {
                realResult = [resultLines componentsJoinedByString:@"\n"];
            } else {
                NSLog(@"%@", e);
                NSLog(@"%@", realResult);
            }
        }
        
        UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
        txtView.text = realResult;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bridges Scanned", nil) message:NSLocalizedString(@"Successfully scanned bridges. Please press 'Save' and restart the app for these changes to take effect.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:NULL];
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)selectPresetBridges {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select provided bridges", nil) message:NSLocalizedString(@"This will replace all your current bridges with the selected preset.", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"obfs4" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
        txtView.text = [self defaultObfs4];
        [self saveAndExit:NO];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"meek-amazon" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
        txtView.text = [self defaultMeekAmazon];
        [self saveAndExit:NO];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"meek-azure" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
        txtView.text = [self defaultMeekAzure];
        [self saveAndExit:NO];
    }]];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    [alert setPreferredAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:NULL];
}

- (void)resetBridges {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Reset bridges", nil) message:NSLocalizedString(@"Are you sure you cant to reset all your bridges? This action cannot be canceled.", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Reset", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
        txtView.text = @"";
        [self clearBridges];
    }]];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    [alert setPreferredAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:NULL];
}

- (void)clearBridges {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];;
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
    [request setEntity:entity];
    
    NSArray *results = [ctx executeFetchRequest:request error:nil];
    if (results == nil) {}
    for (Bridge *bridge in results) {
        [ctx deleteObject:bridge];
    }
    [ctx save:nil];
}

- (void)saveAndExit {
    [self saveAndExit:YES];
}

- (void)saveAndExit:(Boolean)shouldSaveAndExit {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
    [request setEntity:entity];
    
    NSArray *results = [ctx executeFetchRequest:request error:nil];
    if (results == nil) {}
    for (Bridge *bridge in results) {
        [ctx deleteObject:bridge];
    }
    [ctx save:nil];
    
    UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
    NSString *txt = [txtView.text stringByReplacingOccurrencesOfString:@"[ ]+"
                                                            withString:@" "
                                                               options:NSRegularExpressionSearch
                                                                 range:NSMakeRange(0, txtView.text.length)];
    
    for (NSString *line in [txt componentsSeparatedByString:@"\n"]) {
        NSString *newLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([newLine isEqualToString:@""]) {
            // skip empty lines
        } else {
            Bridge *newBridge = [NSEntityDescription insertNewObjectForEntityForName:@"Bridge" inManagedObjectContext:ctx];
            [newBridge setConf:newLine];
            NSError *err = nil;
            if (![ctx save:&err]) {
                NSLog(@"Save did not complete successfully. Error: %@", [err localizedDescription]);
            }
        }
    }
    
    [appDelegate updateTorrc];
    [appDelegate tabsViewController].newIdentityNumber += 1;
    [appDelegate tabsViewController].IPAddress = nil;
    
    if (shouldSaveAndExit) {
        [self exitModal];
    }
}

- (void)cancel {
    [self exitModal];
}

- (void)exitModal {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;
    
    if (![appDelegate.tor didFirstConnect]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please Restart App", nil) message:NSLocalizedString(@"Tob will now close. Please start the app again to retry the Tor connection with the newly-configured bridges.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate wipeAppData];
            exit(0);
        }]];
        [self presentViewController:alert animated:YES completion:NULL];
    } else {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
        [request setEntity:entity];
        
        NSArray *newResults = [ctx executeFetchRequest:request error:nil];
        if (newResults == nil) {}
        
        if ([newResults count] > 0) {
            NSString *pluralize = NSLocalizedString(@" is", nil);
            if ([newResults count] > 1) {
                pluralize = NSLocalizedString(@"s are", nil);
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bridges", nil) message:[NSString stringWithFormat:NSLocalizedString(@"%ld bridge%@ configured.You may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", nil), (unsigned long)[newResults count], pluralize] preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Continue anyway", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
                // User has opted to continue normally, so tell Tor to reconnect
                [appDelegate recheckObfsproxy];
                [appDelegate.tor enableNetwork];
                [appDelegate.tor hupTor];
                
                [self dismissViewControllerAnimated:YES completion:NULL];
            }]];
            UIAlertAction *restartAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Restart app", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate wipeAppData];
                exit(0);
            }];
            [alert addAction:restartAction];
            [alert setPreferredAction:restartAction];
            
            [self presentViewController:alert animated:YES completion:NULL];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bridges Disabled", nil) message:NSLocalizedString(@"No bridges are configured, so bridge connection mode is disabled. If you previously had bridges, you may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", nil) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Continue anyway", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
                // User has opted to continue normally, so tell Tor to reconnect
                [appDelegate recheckObfsproxy];
                [appDelegate.tor enableNetwork];
                [appDelegate.tor hupTor];
                
                [self dismissViewControllerAnimated:YES completion:NULL];
            }]];
            UIAlertAction *restartAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Restart app", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate wipeAppData];
                exit(0);
            }];
            [alert addAction:restartAction];
            [alert setPreferredAction:restartAction];
            
            [self presentViewController:alert animated:YES completion:NULL];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
