//
//  BookmarkEditViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 9/7/12.
//
//

#import "BookmarkEditViewController.h"
#import "BookmarkTableViewController.h"
#import "AppDelegate.h"

@interface BookmarkEditViewController ()

@end

@implementation BookmarkEditViewController
@synthesize bookmark;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithBookmark:(Bookmark *)bookmarkToEdit {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.bookmark = bookmarkToEdit;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section == 0)
        return NSLocalizedString(@"Bookmark Title", nil);
    else if (section == 1)
        return NSLocalizedString(@"Bookmark URL", nil);
    else
        return nil;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    if ((indexPath.section == 0)||(indexPath.section == 1)) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = [UIColor blackColor];

        CGRect textFrame;
        if (IS_IPAD) {
            textFrame = CGRectMake(50, 10,
                                   cell.contentView.frame.size.width-100, cell.contentView.frame.size.height-20);
        } else {
            textFrame = CGRectMake(20, 10,
                                   cell.contentView.frame.size.width-40, cell.contentView.frame.size.height-20);
        }
        UITextField *editField = [[UITextField alloc]
                                  initWithFrame:textFrame];
        editField.autocorrectionType = UITextAutocorrectionTypeNo;
        editField.adjustsFontSizeToFitWidth = YES;
        editField.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        editField.textAlignment = NSTextAlignmentLeft;
        editField.clearButtonMode = UITextFieldViewModeNever; // no clear 'x' button to the right
        [editField setEnabled: YES];
        editField.delegate = self;

        if (indexPath.section == 0) {
            editField.autocorrectionType = UITextAutocorrectionTypeYes;
            editField.text = bookmark.title;
            editField.returnKeyType = UIReturnKeyNext;
            editField.tag = 100;
            editField.keyboardType = UIKeyboardTypeDefault;
        } else {
            editField.autocorrectionType = UITextAutocorrectionTypeNo;
            editField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            editField.text = bookmark.url;
            editField.returnKeyType = UIReturnKeyDone;
            editField.tag = 101;
            editField.keyboardType = UIKeyboardTypeURL;
        }
        
        [cell addSubview:editField];

    } else {
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = self.view.tintColor;

        if (indexPath.section == 2)
            cell.textLabel.text = NSLocalizedString(@"Done", nil);
        else
            cell.textLabel.text = NSLocalizedString(@"Cancel", nil);
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 3)
        return 2.0;
    
    return [tableView sectionHeaderHeight];
}

- (CGFloat)tableView:(UITableView*)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 2)
        return 2.0;
    
    return [tableView sectionFooterHeight];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    if (textField.tag == 100)
        [[self.view viewWithTag:101] becomeFirstResponder];
    else if (textField.tag == 101) {
        [self saveAndGoBack];   
    }
    return YES;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        [self saveAndGoBack];
    } else if (indexPath.section == 3) {
        [self goBack];
    }
}

-(void)saveAndGoBack {
    NSUInteger titlePathInt[2] = {0,0};
    NSIndexPath* titlePath = [[NSIndexPath alloc] initWithIndexes:titlePathInt length:2];
    UITableViewCell *titleCell = [self.tableView cellForRowAtIndexPath:titlePath];
    UITextField *titleEditField = (UITextField*)[titleCell viewWithTag:100];
    titleEditField.autocorrectionType = UITextAutocorrectionTypeNo;
    bookmark.title = titleEditField.text;
    
    NSUInteger urlPathInt[2] = {1,0};
    NSIndexPath* urlPath = [[NSIndexPath alloc] initWithIndexes:urlPathInt length:2];
    UITableViewCell *urlCell = [self.tableView cellForRowAtIndexPath:urlPath];
    UITextField *urlEditField = (UITextField*)[urlCell viewWithTag:101];
    urlEditField.autocorrectionType = UITextAutocorrectionTypeNo;
    
    NSString *urlString = urlEditField.text;
    NSString *workingString;
    
    if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
        workingString = urlString;
    } else if ([urlString hasPrefix:@"www."]) {
        workingString = [@"http://" stringByAppendingString:urlString];
    } else if ([urlString hasPrefix:@"m."]) {
        workingString = [@"http://" stringByAppendingString:urlString];
    } else if ([urlString hasPrefix:@"mobile."]) {
        workingString = [@"http://" stringByAppendingString:urlString];
    } else {
        workingString = [@"http://www." stringByAppendingString:urlString];
    }
    
    bookmark.url = workingString;
    
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    NSError *error = nil;
    if (![appDelegate.managedObjectContext save:&error]) {
        NSLog(@"Error updating bookmark order: %@", error);
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)goBack {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSError *error = nil;

    [appDelegate.managedObjectContext deleteObject:bookmark];
    
    error = nil;
    if (![appDelegate.managedObjectContext save:&error]) {
        // Handle the error.
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
