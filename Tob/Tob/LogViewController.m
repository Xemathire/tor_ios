//
//  LogViewController.m
//  Tob
//
//  Created by Jean-Romain on 03/07/2016.
//  Copyright © 2016 JustKodding. All rights reserved.
//

#import "LogViewController.h"

@interface LogViewController ()

@end

@implementation LogViewController

- (id)init {
    self = [super init];
    if (self) {
        [self initUI];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGSize viewSize = CGSizeMake(MIN(self.view.frame.size.height, self.view.frame.size.width), MAX(self.view.frame.size.height, self.view.frame.size.width));
    
    // Update the UI (when the view isn't displayed, viewWillTransitionToSize is not fired)
    // Find the size ourselves in case the view size isn't adapted to the screen orientation yet
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
        viewSize = CGSizeMake(MAX(self.view.frame.size.height, self.view.frame.size.width), MIN(self.view.frame.size.height, self.view.frame.size.width));

    CGRect navbarFrame = self.view.frame;
    navbarFrame.size = viewSize;
    navbarFrame.size.height = 44 + [UIApplication sharedApplication].statusBarFrame.size.height;
    
    CGRect logTextViewFrame = self.view.frame;
    logTextViewFrame.size = viewSize;
    logTextViewFrame.size.height -= navbarFrame.size.height;
    logTextViewFrame.origin.y += navbarFrame.size.height;
    
    [_logTextView setFrame:logTextViewFrame];
    [_navbar setFrame:navbarFrame];
    [_titleLabel setFrame:CGRectMake(navbarFrame.origin.x, [UIApplication sharedApplication].statusBarFrame.size.height, navbarFrame.size.width, navbarFrame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height)];
    [_doneButton setFrame:CGRectMake(10, [UIApplication sharedApplication].statusBarFrame.size.height, 100, navbarFrame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height)];
    
    // Prevent the text from being cut when changing the frame
    _logTextView.scrollEnabled = NO;
    _logTextView.scrollEnabled = YES;
}

- (void)initUI {
    CGRect navbarFrame = self.view.frame;
    navbarFrame.size.height = 44 + [UIApplication sharedApplication].statusBarFrame.size.height;
    
    CGRect logTextViewFrame = self.view.frame;
    logTextViewFrame.size.height -= navbarFrame.size.height;
    logTextViewFrame.origin.y += navbarFrame.size.height;
    
    _navbar = [[UINavigationBar alloc] initWithFrame:navbarFrame];
    _navbar.translucent = NO;
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(navbarFrame.origin.x, [UIApplication sharedApplication].statusBarFrame.size.height, navbarFrame.size.width, navbarFrame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height)];
    _titleLabel.text = @"Tor log";
    _titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_navbar addSubview:_titleLabel];
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_doneButton.titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
    _doneButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _doneButton.frame = CGRectMake(10, [UIApplication sharedApplication].statusBarFrame.size.height, 100, navbarFrame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height);
    [_doneButton addTarget:self action:@selector(hideLogViewController) forControlEvents:UIControlEventTouchUpInside];
    [_doneButton setTitle:NSLocalizedString(@"Back", nil) forState:UIControlStateNormal];
    [_navbar addSubview:_doneButton];
    
    _logTextView = [[UITextView alloc] initWithFrame:logTextViewFrame];
    _logTextView.editable = NO;
    _logTextView.font = [UIFont systemFontOfSize:17];
    
    [self.view addSubview:_logTextView];
    [self.view addSubview:_navbar];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        CGRect navbarFrame = self.view.frame;
        navbarFrame.size = size;
        navbarFrame.size.height = 44 + [UIApplication sharedApplication].statusBarFrame.size.height;
        
        CGRect logTextViewFrame = self.view.frame;
        logTextViewFrame.size = size;
        logTextViewFrame.size.height -= navbarFrame.size.height;
        logTextViewFrame.origin.y += navbarFrame.size.height;
        
        [_logTextView setFrame:logTextViewFrame];
        [_navbar setFrame:navbarFrame];
        [_titleLabel setFrame:CGRectMake(navbarFrame.origin.x, [UIApplication sharedApplication].statusBarFrame.size.height, navbarFrame.size.width, navbarFrame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height)];
        [_doneButton setFrame:CGRectMake(10, [UIApplication sharedApplication].statusBarFrame.size.height, 100, navbarFrame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height)];
    } completion:nil];
}

- (void)hideLogViewController {
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionPush;
    transition.subtype = kCATransitionFromLeft;
    [self.view.window.layer addAnimation:transition forKey:nil];
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)logInfo:(NSString *)info {
    _logTextView.text = [_logTextView.text stringByAppendingString:info];
    _logTextView.text = [_logTextView.text stringByAppendingString:@"\n"];
    [self scrollTextViewToBottom:_logTextView];
}

-(void)scrollTextViewToBottom:(UITextView *)textView {
    if(textView.text.length > 0 ) {
        NSRange bottom = NSMakeRange(textView.text.length -1, 1);
        [textView scrollRangeToVisible:bottom];
    }
}

@end
