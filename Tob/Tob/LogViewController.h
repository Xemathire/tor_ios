//
//  LogViewController.h
//  Tob
//
//  Created by Jean-Romain on 03/07/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LogViewController : UIViewController

@property UITextView *logTextView;
@property UINavigationBar *navbar;
@property UIButton *doneButton;
@property UILabel *titleLabel;

- (void)logInfo:(NSString *)info;

@end
