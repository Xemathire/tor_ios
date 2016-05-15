//
//  MOTabContentView.m
//  MOTabView
//
//  Created by Jan Christiansen on 6/20/12.
//  Copyright (c) 2012, Monoid - Development and Consulting - Jan Christiansen
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following
//  disclaimer in the documentation and/or other materials provided
//  with the distribution.
//
//  * Neither the name of Monoid - Development and Consulting - 
//  Jan Christiansen nor the names of other
//  contributors may be used to endorse or promote products derived
//  from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <QuartzCore/QuartzCore.h>

#import "MOTabContentView.h"
#import "MOShadowView.h"


static const CGFloat kDeselectedScalePortrait = 0.73f;
static const CGFloat kDeselectedOriginYPortrait = -10;

static const CGFloat kDeselectedScaleLandscape = 0.65f;
static const CGFloat kDeselectedOriginYLandscape = -20;

static const CGFloat kDeleteViewHeight = 20;
static const int kTitleFontSize = 13;



@implementation MOTabContentView {

    UIView *_containerView;
    UIView *_contentView;
    UIView *_deleteView;

    UIButton *_deleteButton;
    
    UILabel *_viewTitle;

    float _visibility;

    UITapGestureRecognizer *_tapRecognizer;
}


#pragma mark - Intialization

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        
        // a container which is scaled
        _containerView = [[MOShadowView alloc] initWithFrame:self.bounds];
        // _containerView = [[UIView alloc] initWithFrame:self.bounds];
        _containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_containerView];
        
        _tapRecognizer = [[UITapGestureRecognizer alloc]
                          initWithTarget:self
                          action:@selector(handleTap)];
        [_containerView addGestureRecognizer:_tapRecognizer];
        _containerView.clipsToBounds = NO;
        
        _deleteView = [[UIView alloc] init];
        CGRect deleteViewFrame = _containerView.frame;
        deleteViewFrame.size.height = kDeleteViewHeight;
        deleteViewFrame.origin.y = _containerView.frame.origin.y;
        _deleteView.frame = deleteViewFrame;
        _deleteView.backgroundColor = [UIColor blackColor];
        _deleteView.alpha = 0;
        [self insertSubview:_deleteView aboveSubview:_containerView];
        
        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.frame = CGRectMake(0, 0, kDeleteViewHeight, kDeleteViewHeight);
        [_deleteButton setTitle:[NSString stringWithFormat:@"%C", 0x2715] forState:UIControlStateNormal];
        [_deleteButton.titleLabel setFont:[UIFont systemFontOfSize:15]];
        _deleteButton.titleLabel.numberOfLines = 1;
        _deleteButton.titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        [_deleteButton addTarget:self
                          action:@selector(handleClose)
                forControlEvents:UIControlEventTouchUpInside];
        [_deleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_deleteView addSubview:_deleteButton];
        
        _viewTitle = [[UILabel alloc] init];
        // 10 points for spacing
        
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
            _viewTitle.frame = CGRectMake(kDeleteViewHeight, 0, kDeselectedScalePortrait * _containerView.frame.size.width - (kDeleteViewHeight + 10), kDeleteViewHeight);
        else
            _viewTitle.frame = CGRectMake(kDeleteViewHeight, 0, kDeselectedScaleLandscape * _containerView.frame.size.width - (kDeleteViewHeight + 10), kDeleteViewHeight);

        [_viewTitle setText:@"New tab"];
        [_viewTitle setTextColor:[UIColor whiteColor]];
        [_viewTitle setFont:[UIFont boldSystemFontOfSize:kTitleFontSize]];
        [_viewTitle setLineBreakMode:NSLineBreakByTruncatingTail];
        _viewTitle.textAlignment = NSTextAlignmentCenter;
        _viewTitle.numberOfLines = 1;
        [_deleteView addSubview:_viewTitle];
        
        [self deselectNonAnimated];
    }
    return self;
}

#pragma mark - Getting and Setting Properties

- (CGRect)frame {
    
    return super.frame;
}

- (void)setFrame:(CGRect)frame {

    _containerView.transform = CGAffineTransformIdentity;
    
    super.frame = frame;
    
    if (!_isSelected) {
        float deselectedTranslation = (float)(kDeselectedOriginYPortrait - frame.origin.y);
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
            deselectedTranslation = (float)(kDeselectedOriginYLandscape - frame.origin.y);
        
        CGAffineTransform translation = CGAffineTransformMakeTranslation(0, deselectedTranslation);
        CGAffineTransform transform = CGAffineTransformScale(translation, kDeselectedScalePortrait, kDeselectedScalePortrait);
        
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
            transform = CGAffineTransformScale(translation, kDeselectedScaleLandscape, kDeselectedScaleLandscape);
        
        _containerView.transform = transform;
        
        _viewTitle.frame = CGRectMake(kDeleteViewHeight, 0, _containerView.frame.size.width - (kDeleteViewHeight + 10), kDeleteViewHeight);
    } else {
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
            _viewTitle.frame = CGRectMake(kDeleteViewHeight, 0, kDeselectedScalePortrait * _containerView.frame.size.width - (kDeleteViewHeight + 10), kDeleteViewHeight);
        else
            _viewTitle.frame = CGRectMake(kDeleteViewHeight, 0, kDeselectedScaleLandscape * _containerView.frame.size.width - (kDeleteViewHeight + 10), kDeleteViewHeight);
    }
    
    [self recenterDeleteView];
}

- (float)visibility {
    
    return _visibility;
}

- (void)setVisibility:(float)visibility {
    /*****
     EDITED: Changed delete button to delete view
     *****/
    
    _visibility = visibility;
    if (!_isSelected) {
        _deleteView.alpha = visibility;
    }
    self.alpha = MAX(visibility, 0.5f);
}

- (UIView *)contentView {
    
    return _contentView;
}

- (void)setContentView:(UIView *)contentView {
    
    // if user interactions are disabled (because the view is minimized/deselected)
    // we have to disable the interactions of the new content view as well
    contentView.userInteractionEnabled = _contentView.userInteractionEnabled;
    
    // we remove the old content view  and add the new one
    [_contentView removeFromSuperview];
    _contentView = contentView;
    [_containerView addSubview:_contentView];
}

- (void)setViewTitle:(NSString *)title {
    [_viewTitle setText:title];
}


#pragma mark - Handling Actions

- (void)handleTap {
    
    [_delegate tabContentViewDidTapView:self];
}

- (void)handleClose {
    
    [self.delegate tabContentViewDidTapDelete:self];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event {
    /*****
     EDITED: Changed delete button to delete view
     *****/
    
    return ((CGRectContainsPoint(_deleteView.frame, point)
             || CGRectContainsPoint(_containerView.frame, point)));
}


#pragma mark - Utility Methods

- (void)recenterDeleteView {
    /*****
     EDITED: Changed delete button to delete view, changed method name and add viewTitle frame editing
     *****/
    
    CGRect deleteViewFrame = _containerView.frame;
    deleteViewFrame.size.height = kDeleteViewHeight;
    deleteViewFrame.origin.y = _containerView.frame.origin.y;
    _deleteView.frame = deleteViewFrame;
}


#pragma mark - Selecting and Deselecting

- (void)selectAnimated:(BOOL)animated {
    /*****
     EDITED: Changed recenterDeleteButton to recenterDeleteView
     *****/
    
    [self recenterDeleteView];
    
    if (animated) {
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self selectNonAnimated];
                         }
                         completion:^(BOOL __unused finished) {
                             [_delegate tabContentViewDidSelect:self];
                         }];
    } else {
        [self selectNonAnimated];
        [_delegate tabContentViewDidSelect:self];
    }
    
    _tapRecognizer.enabled = NO;
    _contentView.userInteractionEnabled = YES;
    _isSelected = YES;
}

- (void)selectNonAnimated {
    /*****
     EDITED: Changed delete button to delete view
     *****/
    
    _containerView.transform = CGAffineTransformIdentity;
    
    [self recenterDeleteView];
    _deleteView.alpha = 0;
}

- (void)deselectAnimated:(BOOL)animated {
    /*****
     EDITED: Changed recenterDeleteButton to recenterDeleteView
     *****/
    
    [self recenterDeleteView];
    
    if (animated) {
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self deselectNonAnimated];
                         }
                         completion:^(BOOL __unused finished){
                             [_delegate tabContentViewDidDeselect:self];
                         }];
    } else {
        [self deselectNonAnimated];
        [_delegate tabContentViewDidDeselect:self];
    }
    
    _tapRecognizer.enabled = YES;
    _contentView.userInteractionEnabled = NO;
    _isSelected = NO;
}

- (void)deselectNonAnimated {
    /*****
     EDITED: Changed delete button to delete view and changed recenterDeleteButton to recenterDeleteView
     *****/
    
    float deselectedTranslation = (float)(kDeselectedOriginYPortrait - self.frame.origin.y);
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        deselectedTranslation = (float)(kDeselectedOriginYLandscape - self.frame.origin.y);

    CGAffineTransform translation = CGAffineTransformMakeTranslation(0, deselectedTranslation);
    CGAffineTransform transform = CGAffineTransformScale(translation, kDeselectedScalePortrait, kDeselectedScalePortrait);
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        transform = CGAffineTransformScale(translation, kDeselectedScaleLandscape, kDeselectedScaleLandscape);
    
    _containerView.transform = transform;
    
    [self recenterDeleteView];
    _deleteView.alpha = 1;
}


@end
