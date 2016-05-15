//
//  CustomTextField.m
//  Safari Scrolling
//
//  Created by Maximilian Litteral on 9/4/13.
//  Copyright (c) 2013 Maximilian Litteral. All rights reserved.
//

#import "CustomTextField.h"

@implementation CustomTextField
{
    UIButton *_refreshButton;
    UIButton *_cancelButton;
}

#pragma mark - Setup

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        self.borderStyle = UITextBorderStyleRoundedRect;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.textAlignment = NSTextAlignmentCenter;
        self.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];
        _refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _refreshButton.frame = CGRectMake(_refreshButton.frame.origin.x, _refreshButton.frame.origin.y, 29, 29);
        _refreshButton.backgroundColor = [UIColor clearColor];
        [_refreshButton setImage:[[UIImage imageNamed:@"Reload"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        self.rightView = _refreshButton;
        
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _cancelButton.frame = CGRectMake(_cancelButton.frame.origin.x, _cancelButton.frame.origin.y, 29, 29);
        _cancelButton.backgroundColor = [UIColor clearColor];
        [_cancelButton setImage:[[UIImage imageNamed:@"StopLoading"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        
        _tlsButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _tlsButton.frame = CGRectMake(_tlsButton.frame.origin.x, _tlsButton.frame.origin.y, 29, 29);
        _tlsButton.backgroundColor = [UIColor clearColor];
        [_tlsButton setImage:[[UIImage imageNamed:@"BrokenLock"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [_tlsButton setUserInteractionEnabled:NO];
        self.leftView = _tlsButton;
        [self setLeftViewMode:UITextFieldViewModeNever];
        
        self.rightView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        self.leftView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    }
    return self;
}


- (CGRect)textRectForBounds:(CGRect)bounds {
    int margin = 29;

    if (self.textAlignment == NSTextAlignmentCenter) {
        CGRect inset = CGRectMake(bounds.origin.x + margin, bounds.origin.y, bounds.size.width - (margin * 2), bounds.size.height);
        return inset;
    }
    else {
        CGRect inset = CGRectMake(bounds.origin.x + 5, bounds.origin.y, (bounds.size.width - margin) - 5, bounds.size.height);
        return inset;
    }
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    int margin = 29;
    CGRect inset = CGRectMake(bounds.origin.x + 5, bounds.origin.y, (bounds.size.width - margin) - 5, bounds.size.height);
    return inset;
}

@end
