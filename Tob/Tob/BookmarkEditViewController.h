//
//  BookmarkEditViewController.h
//  OnionBrowser
//
//  Created by Mike Tigas on 9/7/12.
//
//

#import <UIKit/UIKit.h>
#import "Bookmark.h"

@interface BookmarkEditViewController : UITableViewController <UITextFieldDelegate>

-(id)initWithBookmark:(Bookmark*)bookmarkToEdit;
-(id)initWithBookmark:(Bookmark*)bookmarkToEdit isEditing:(BOOL)isEditing;

@property (nonatomic, retain) Bookmark *bookmark;
@property (nonatomic) BOOL userIsEditing;

@end
