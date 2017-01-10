//
//  BookmarkListViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 9/7/12.
//
//

#import "BookmarkTableViewController.h"
#import "Bookmark.h"
#import "BookmarkEditViewController.h"
#import "AppDelegate.h"

@interface BookmarkTableViewController ()

@end

@implementation BookmarkTableViewController
@synthesize bookmarksArray;
@synthesize managedObjectContext;
@synthesize addButton;
@synthesize editButton;
@synthesize backButton;
@synthesize editDoneButton;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        _embedded = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView setAllowsSelectionDuringEditing:YES];
    
    self.title = NSLocalizedString(@"Bookmarks", nil);
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                              target:self action:@selector(addBookmark)];
    editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                               target:self action:@selector(startEditing)];
    editDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                   target:self action:@selector(stopEditing)];
    backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self action:@selector(goBack)];
    self.navigationItem.leftBarButtonItem = editButton;
    self.navigationItem.rightBarButtonItem = backButton;
    
    if([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    
    darkMode = false;
    [self reload];
}

- (void)setDarkMode {
    [[self tableView] setBackgroundColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0]];
    [[UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil] setTextColor:[UIColor whiteColor]];
    darkMode = true;
}

- (void)setLightMode {
    [[self tableView] setBackgroundColor:[UIColor whiteColor]];
    [[UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil] setTextColor:[UIColor blackColor]];
    darkMode = false;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self setLightMode];
    _embedded = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

-(void)reload {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bookmark" inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [request setSortDescriptors:sortDescriptors];
    
    NSError *error = nil;
    NSMutableArray *mutableFetchResults = [[managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (mutableFetchResults == nil) {
        // Handle the error.
    }
    [self setBookmarksArray:mutableFetchResults];
    [self.tableView reloadData];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.bookmarksArray = nil;
    self.addButton = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (IS_IPAD) || (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1)
        return NSLocalizedString(@"Bookmarks", nil);
    else
        return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return 1;
    else if (section == 1)
        return [bookmarksArray count];
    else
        return 0;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    // Dequeue or create a new cell.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        [cell setEditingAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    
    if (indexPath.section == 0) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        cell.textLabel.text = NSLocalizedString(@"Homepage", nil);
        cell.detailTextLabel.text = appDelegate.homepage;
    } else {
        Bookmark *bookmark = (Bookmark *)[bookmarksArray objectAtIndex:indexPath.row];
        cell.textLabel.text = bookmark.title;
        cell.detailTextLabel.text = bookmark.url;
    }
    
    [cell setBackgroundColor:[UIColor clearColor]];

    if (darkMode) {
        [[cell textLabel] setTextColor:[UIColor whiteColor]];
        [[cell detailTextLabel] setTextColor:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0]];
    } else {
        [[cell textLabel] setTextColor:[UIColor blackColor]];
        [[cell detailTextLabel] setTextColor:[UIColor grayColor]];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the managed object at the given index path.
        NSManagedObject *bookmarkToDelete = [bookmarksArray objectAtIndex:indexPath.row];
        [managedObjectContext deleteObject:bookmarkToDelete];
        
        // Update the array and table view.
        [bookmarksArray removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        // Commit the change.
        NSError *error = nil;
        if (![managedObjectContext save:&error]) {
            // Handle the error.
        }
        [self saveBookmarkOrder];
    }
}

- (void)saveBookmarkOrder {
    int16_t i = 0;
    for (Bookmark *bookmark in bookmarksArray) {
        [bookmark setOrder:i];
        i++;
    }
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
        NSLog(@"Error updating bookmark order: %@", error);
    }
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    id object = [bookmarksArray objectAtIndex:fromIndexPath.row];
    [bookmarksArray removeObjectAtIndex:fromIndexPath.row];
    [bookmarksArray insertObject:object atIndex:toIndexPath.row];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!_embedded) {
        // Open an editing pane
        if (indexPath.section == 0) {
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            NSMutableDictionary *settings2 = appDelegate.getSettings;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Homepage", nil) message:NSLocalizedString(@"Leave blank to use default Tob home page.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
            
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
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
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        } else {
            Bookmark *bookmark = (Bookmark *)[bookmarksArray objectAtIndex:indexPath.row];
            BookmarkEditViewController *editController = [[BookmarkEditViewController alloc] initWithBookmark:bookmark isEditing:YES];
            [self presentViewController:editController animated:YES completion:nil];
        }
    } else {
        if (indexPath.section == 0) {
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            NSString *urlString = appDelegate.homepage;
            NSURL *url = [NSURL URLWithString:urlString];
            
            [appDelegate.tabsViewController loadURL:url];
            [appDelegate.tabsViewController.titles replaceObjectAtIndex:appDelegate.tabsViewController.tabView.currentIndex withObject:urlString];
            [self goBack];
            
        } else {
            NSURL *url;
            NSString *urlString;
            Bookmark *bookmark = (Bookmark *)[bookmarksArray objectAtIndex:indexPath.row];
            urlString = bookmark.url;
            
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            url = [NSURL URLWithString:urlString];
            [appDelegate.tabsViewController loadURL:url];
            [appDelegate.tabsViewController.titles replaceObjectAtIndex:appDelegate.tabsViewController.tabView.currentIndex withObject:urlString];
            [self goBack];
        }
    }
}

- (void)addBookmark {
    Bookmark *bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:managedObjectContext];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [bookmark setTitle:[[appDelegate.tabsViewController subtitles] objectAtIndex:appDelegate.tabsViewController.tabView.currentIndex]];
    [bookmark setUrl:[[appDelegate.tabsViewController titles] objectAtIndex:appDelegate.tabsViewController.tabView.currentIndex]];
    
    int16_t order = [bookmarksArray count];
    [bookmark setOrder:order];
    
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
        NSLog(@"Error adding bookmark: %@", error);
    }
    [bookmarksArray addObject:bookmark];
    [self saveBookmarkOrder];
    
    BookmarkEditViewController *editController = [[BookmarkEditViewController alloc] initWithBookmark:bookmark isEditing:NO];
    [self presentViewController:editController animated:YES completion:nil];
    /*
     NSIndexPath *indexPath = [NSIndexPath indexPathForRow:order inSection:0];
     [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
     withRowAnimation:UITableViewRowAnimationFade];
     [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:order inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
     */
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    if (editing) {
        self.navigationItem.leftBarButtonItem = editDoneButton;
        self.navigationItem.rightBarButtonItem = addButton;
    } else {
        [self saveBookmarkOrder];
        self.navigationItem.leftBarButtonItem = editButton;
        self.navigationItem.rightBarButtonItem = backButton;
    }
    [super setEditing:editing animated:animated];
}

- (void)startEditing {
    [self setEditing:YES];
}
- (void)stopEditing {
    [self setEditing:NO];
}
- (void)goBack {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
