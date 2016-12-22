//
//  BridgesTableViewController.m
//  Tob
//
//  Created by Jean-Romain on 17/12/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import "AppDelegate.h"
#import "Bridge.h"
#import "BridgesTableViewController.h"
#import "BridgeViewController.h"
#import "Ipv6Tester.h"

@interface BridgesTableViewController ()

@end

@implementation BridgesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Bridges", nil);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];;
    [appDelegate.tor disableNetwork];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];;
    [appDelegate recheckObfsproxy];
    [appDelegate.tor enableNetwork];
    [appDelegate.tor hupTor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Data saving

- (void)save:(NSString *)bridgeLines {
    [Bridge updateBridgeLines:bridgeLines];
    [self.tableView reloadData];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate updateTorrc];
}

- (void)finishSave:(NSString *)extraMsg {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSUInteger numBridges = [appDelegate numBridgesConfigured];
    
    if (![appDelegate.tor didFirstConnect]) {
        NSString *msg = NSLocalizedString(@"Tob will now close. Please start the app again to retry the Tor connection with the newly-configured bridges.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", nil);
        if (extraMsg != nil) {
            msg = [msg stringByAppendingString:@"\n\n"];
            msg = [msg stringByAppendingString:extraMsg];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bridges saved", nil) message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Restart app", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [appDelegate wipeAppData];
            exit(0);
        }]];
        [self presentViewController:alert animated:YES completion:NULL];
    } else {        
        NSString *pluralize = NSLocalizedString(@" is", nil);
        if (numBridges > 1)
            pluralize = NSLocalizedString(@"s are", nil);
        
        NSString *msg;
        if (numBridges == 0) {
            msg = NSLocalizedString(@"No bridges are configured, so bridge connection mode is disabled. If you previously had bridges, you may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", nil);
        } else {
            msg = [NSString stringWithFormat:NSLocalizedString(@"%ld bridge%@ configured.You may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", nil), (unsigned long)numBridges, pluralize];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bridges saved", nil) message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Continue anyway", nil) style:UIAlertActionStyleCancel handler:nil]];
        UIAlertAction *restartAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Restart app", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [appDelegate wipeAppData];
            exit(0);
        }];
        
        [alert addAction:restartAction];
        [alert setPreferredAction:restartAction];
        [self presentViewController:alert animated:YES completion:NULL];
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"Bridges", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return NSLocalizedString(@"Bridges are Tor relays that help circumvent censorship. You can try bridges if Tor is blocked by your ISP; each type of bridge uses a different method to avoid censorship: if one type does not work, try using a different one.\n\nYou may use the provided bridges below or obtain bridges at bridges.torproject.org.", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"Cell";
    
    if (indexPath.row == 3)
        cellIdentifier = @"Custom cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSUInteger numBridges = [appDelegate numBridgesConfigured];
    NSMutableDictionary *settings = appDelegate.getSettings;
    NSInteger bridgeSetting = [[settings valueForKey:@"bridges"] integerValue];

    if (indexPath.row == 0) {
        cell.textLabel.text = NSLocalizedString(@"Disable bridges", nil);
        
        if (bridgeSetting == TOR_BRIDGES_NONE || ((bridgeSetting == TOR_BRIDGES_CUSTOM) && numBridges == 0))
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = NSLocalizedString(@"Provided bridges: obfs4", nil);
        
        if (bridgeSetting == TOR_BRIDGES_OBFS4)
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if (indexPath.row == 2) {
        cell.textLabel.text = NSLocalizedString(@"Provided bridges: meek-amazon", nil);
        
        if (bridgeSetting == TOR_BRIDGES_MEEKAMAZON)
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } if (indexPath.row == 3) {
        cell.textLabel.text = NSLocalizedString(@"Provided bridges: meek-azure", nil);
        
        if (bridgeSetting == TOR_BRIDGES_MEEKAZURE)
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if (indexPath.row == 4) {
        cell.textLabel.text = NSLocalizedString(@"Custom bridges", nil);
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = self.view.tintColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        
        if (bridgeSetting == TOR_BRIDGES_CUSTOM  && numBridges > 0) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%ld bridges configured", nil), (unsigned long)numBridges];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;
    if (indexPath.row == 0) {
        [Bridge clearBridges];
        [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_NONE] forKey:@"bridges"];
        [appDelegate saveSettings:settings];
        [self finishSave:nil];
    } else if (indexPath.row == 1) {
        [self save:[Bridge defaultObfs4]];
        [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_OBFS4] forKey:@"bridges"];
        [appDelegate saveSettings:settings];
        [self finishSave:nil];
    } else if (indexPath.row == 2) {
        [self save:[Bridge defaultMeekAmazon]];
        [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_MEEKAMAZON] forKey:@"bridges"];
        [appDelegate saveSettings:settings];
        [self finishSave:nil];
    } else if (indexPath.row == 3) {
        [self save:[Bridge defaultMeekAzure]];
        [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_MEEKAZURE] forKey:@"bridges"];
        [appDelegate saveSettings:settings];
        [self finishSave:nil];
    } else if (indexPath.row == 4) {
        [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_CUSTOM] forKey:@"bridges"];
        [appDelegate saveSettings:settings];
        BridgeViewController *bridgeViewController = [[BridgeViewController alloc] init];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:bridgeViewController];
        [self.navigationController presentViewController:navigationController animated:YES completion:nil];
    }
    
    [tableView reloadData];
}

@end
