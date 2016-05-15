//
//  MOTabView.m
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
#import "AppDelegate.h"
#import "MOScrollView.h"
#import "MOTabView.h"
#import "MOTabContentView.h"
#import "MOGradientView.h"
#import "MOTitleTextField.h"
#import "WebViewTab.h"


// colors used for the gradient in the background
static const CGFloat kLightGrayRed = 0.57f;
static const CGFloat kLightGrayGreen = 0.63f;
static const CGFloat kLightGrayBlue = 0.68f;

static const CGFloat kDarkGrayRed = 0.31f;
static const CGFloat kDarkGrayGreen = 0.41f;
static const CGFloat kDarkGrayBlue = 0.48f;

static const CGFloat kWidthFactorPortrait = 0.8f;
static const CGFloat kWidthFactorLandscape = 0.7f;

static const int kPageControlMarginPortrait = 30;
static const int kPageControlMarginLandscape = 30;

static const int kTitleHeight = 0;
static const int kSubtitleHeight = 0;

// turns on/off a global debugging mode that show normally hidden views
static const BOOL kDebugMode = NO;


@implementation MOTabView {
    
    id _delegate;
    
    // cache whehter delegate responds to methods
    BOOL _delegateRespondsToWillSelect;
    BOOL _delegateRespondsToWillDeselect;
    BOOL _delegateRespondsToDidSelect;
    BOOL _delegateRespondsToDidDeselect;
    BOOL _delegateRespondsToWillEdit;
    BOOL _delegateRespondsToDidEdit;
    BOOL _delegateRespondsToDidEditTitle;
    BOOL _delegateRespondsToDidChange;
    BOOL _dataSourceRespondsToTitleForIndex;
    BOOL _dataSourceRespondsToSubtitleForIndex;
    
    id<MOTabViewDataSource> _dataSource;
    
    UIView *_backgroundView;
    
    // this scrollview always contains three views, some of these may be hidden,
    // if current only one or two content view are displayed
    // these views are reused when the user scrolls
    MOScrollView *_scrollView;
    //    UIScrollView *_scrollView;
    UITextField *_titleField;
    UITextField *_navigationBarField;
    UILabel *_subtitleLabel;
    
    MOTabContentView *_leftTabContentView;
    MOTabContentView *_centerTabContentView;
    MOTabContentView *_rightTabContentView;
    
    MOTabViewEditingStyle _editingStyle;
    
    // timing functions used for scrolling
    CAMediaTimingFunction *_easeInEaseOutTimingFunction;
    CAMediaTimingFunction *_easeOutTimingFunction;
    CAMediaTimingFunction *_easeInTimingFunction;
    
    // if true the last view is hidden when scrolling
    BOOL _hideLastTabContentView;
    
    BOOL _navigationBarHidden;
    
    NSMutableArray *_reusableContentViews;
    
    UIPanGestureRecognizer *tabSelectionPanGestureRecognizer;
    
    CGPoint originalPoint;
    CGPoint panGestureOriginPoint;
    int panGestureRecognizerType; // 0: None, 1: Remove tab, 2: Change page
}


#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeMOTabView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initializeMOTabView];
    }
    return self;
}

- (void)initializeMOTabView {
    
    // timing function used to scroll the MOScrollView
    _easeInEaseOutTimingFunction = [CAMediaTimingFunction
                                    functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    _easeOutTimingFunction = [CAMediaTimingFunction
                              functionWithName:kCAMediaTimingFunctionEaseOut];
    _easeInTimingFunction = [CAMediaTimingFunction
                             functionWithName:kCAMediaTimingFunctionEaseIn];
    
    // background view
    UIColor *lightGray = [UIColor colorWithRed:kLightGrayRed
                                         green:kLightGrayGreen
                                          blue:kLightGrayBlue
                                         alpha:1.0];
    UIColor *darkGray = [UIColor colorWithRed:kDarkGrayRed
                                        green:kDarkGrayGreen
                                         blue:kDarkGrayBlue
                                        alpha:1.0];
    _backgroundView = [[MOGradientView alloc] initWithFrame:self.bounds
                                                   topColor:lightGray
                                                bottomColor:darkGray];
    //    _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self addSubview:_backgroundView];
    
    // page control
    CGRect pageControlFrame = CGRectMake(0, 0, super.frame.size.width, 36);
    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
        pageControlFrame.origin.y = super.frame.size.height - (44 + kPageControlMarginPortrait);
    else
        pageControlFrame.origin.y = super.frame.size.height - (44 + kPageControlMarginLandscape);
    
    _pageControl = [[UIPageControl alloc] initWithFrame:pageControlFrame];
    _pageControl.numberOfPages = 2;
    _pageControl.hidesForSinglePage = YES;
    _pageControl.defersCurrentPageDisplay = YES;
    [_pageControl addTarget:self
                     action:@selector(changePage:)
           forControlEvents:UIControlEventValueChanged];
    [self insertSubview:_pageControl aboveSubview:_backgroundView];
    
    // scrollview
    _scrollView = [[MOScrollView alloc] initWithFrame:self.bounds];
    //    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.delegate = self;
    _scrollView.contentSize = self.bounds.size;
    _scrollView.scrollEnabled = NO;
    _scrollView.scrollsToTop = NO;
    
    
    // TODO: Remove this hack
    //    _scrollView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.01];
    // paging of the scrollview is implemented by using the delegate methods
    [self addSubview:_scrollView];
    
    // standard adding style is the one used by safari prior to iOS6
    _addingStyle = MOTabViewAddingAtLastIndex;
    
    _navigationBarHidden = YES;
    
    _reusableContentViews = @[].mutableCopy;
}

- (void)initializeTitles {
    float titleBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    if (_dataSourceRespondsToTitleForIndex) {
        // title label
        CGRect titleFrame = CGRectMake(10, kTitleHeight + titleBarHeight, self.bounds.size.width-20, 40);
        _titleField = [[UITextField alloc] initWithFrame:titleFrame];
        _titleField.delegate = self;
        _titleField.enabled = NO;
        _titleField.returnKeyType = UIReturnKeyDone;
        //    _titleField.lineBreakMode = UILineBreakModeMiddleTruncation;
        [self insertSubview:_titleField aboveSubview:_backgroundView];
    }
    
    if (_dataSourceRespondsToSubtitleForIndex) {
        // subtitle label
        CGRect subtitleFrame = CGRectMake(10, kSubtitleHeight + titleBarHeight, self.bounds.size.width-20, 40);
        _subtitleLabel = [[UILabel alloc] initWithFrame:subtitleFrame];
        UIColor *subtitleColor = [UIColor colorWithRed:0.76f
                                                 green:0.8f
                                                  blue:0.83f
                                                 alpha:1];
        _subtitleLabel.textColor = subtitleColor;
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        //    _subtitleLabel.shadowColor = shadowColor;
        _subtitleLabel.shadowOffset = CGSizeMake(0, -1);
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.font = [UIFont systemFontOfSize:14];
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self insertSubview:_subtitleLabel aboveSubview:_backgroundView];
    }
}


- (MOTabContentView *)tabContentView {
    
    CGRect contentViewFrame = self.frame;
    
    if (_navigationBarHidden && !_navigationBarScrolls) {
        UITableView *tableView = (UITableView *)_centerTabContentView.contentView;
        [self adapt:tableView];
    }
    
    return [[MOTabContentView alloc] initWithFrame:contentViewFrame];
}


#pragma mark - Getting and Setting Properties

- (void)setFrame:(CGRect)frame {
    
    BOOL scrollEnabled = _scrollView.scrollEnabled;
    _scrollView.scrollEnabled = NO;
    int index = _currentIndex;
    super.frame = frame;
    _backgroundView.frame = frame;
    _scrollView.frame = frame;
    
    CGFloat widthFactor = kWidthFactorPortrait;
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        widthFactor = kWidthFactorLandscape;
    
    float titleBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    if (_dataSourceRespondsToTitleForIndex) {
        CGRect titleFrame = CGRectMake(10, kTitleHeight + titleBarHeight, self.bounds.size.width-20, 40);
        [_titleField setFrame:titleFrame];
    }
    
    if (_dataSourceRespondsToSubtitleForIndex) {
        CGRect subtitleFrame = CGRectMake(10, kSubtitleHeight + titleBarHeight, self.bounds.size.width-20, 40);
        [_subtitleLabel setFrame:subtitleFrame];
    }
    
    // reposition page control
    CGRect newPageControlFrame = _pageControl.frame;
    newPageControlFrame.size.width = frame.size.width;
    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
        newPageControlFrame.origin.y = super.frame.size.height - (44 + kPageControlMarginPortrait);
    else
        newPageControlFrame.origin.y = super.frame.size.height - (44 + kPageControlMarginLandscape);
    
    _pageControl.frame = newPageControlFrame;
    
    // [self updateFrameForContainerViewsWithIndex:index];
    
    CGRect newNavigationFrame = _navigationBar.frame;
    newNavigationFrame.size.width = frame.size.width;
    newNavigationFrame.size.height = 44 + [[UIApplication sharedApplication] statusBarFrame].size.height;
    newNavigationFrame.origin = frame.origin;
    _navigationBar.frame = newNavigationFrame;
    
    // resize content views
    _leftTabContentView.frame = CGRectMake(frame.origin.x + (index - 1) * widthFactor * frame.size.width,
                                           0,
                                           frame.size.width,
                                           frame.size.height);
    
    _centerTabContentView.frame = CGRectMake(frame.origin.x + index * widthFactor * frame.size.width,
                                             0,
                                             frame.size.width,
                                             frame.size.height);
    
    _rightTabContentView.frame = CGRectMake(frame.origin.x + (index + 1) * widthFactor * frame.size.width,
                                            0,
                                            frame.size.width,
                                            frame.size.height);
    
    int numberOfViews = (int)[_dataSource numberOfViewsInTabView:self];
    
    CGSize newContentSize = CGSizeMake((1 + widthFactor * (numberOfViews - 1)) * frame.size.width, frame.size.height);
    CGPoint contentOffset = CGPointMake(_currentIndex * widthFactor * frame.size.width, 0);
    
    [_scrollView setContentSize:newContentSize];
    [_scrollView setContentOffset:contentOffset animated:NO];
    _currentIndex = index;
    _scrollView.scrollEnabled = scrollEnabled;
}

- (BOOL)navigationBarHidden {
    
    return _navigationBarHidden;
}

- (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    
    _navigationBarHidden = navigationBarHidden;
    
    if (!_navigationBarHidden) {
        
        CGRect navigationBarFrame = CGRectMake(0, 0, self.bounds.size.width, 44 + [[UIApplication sharedApplication] statusBarFrame].size.height);
        _navigationBar = [[UINavigationBar alloc] initWithFrame:navigationBarFrame];
        CGRect titleFrame = CGRectMake(0, 0, 200, 25);
        // _navigationBarField = [[MOTitleTextField alloc] initWithFrame:titleFrame];
        _navigationBarField = [[UITextField alloc] initWithFrame:titleFrame];
        _navigationBarField.delegate = self;
        _navigationBarField.enabled = self.editableTitles;
        _navigationBarField.returnKeyType = UIReturnKeyDone;
        
        if (_dataSourceRespondsToTitleForIndex) {
            _navigationBarField.text = [self.dataSource titleForIndex:_currentIndex];
            [_centerTabContentView setViewTitle:[self.dataSource titleForIndex:_currentIndex]];
        }
        [_navigationBar addSubview:_navigationBarField];
        [self addSubview:_navigationBar];
        
        /*
         // necessary if dataSource is not already set
         // existing content views are offset to the bottom by the height of the navigation bar
         CGRect newLeftFrame = _leftTabContentView.frame;
         newLeftFrame.origin.y += _navigationBar.bounds.size.height;
         _leftTabContentView.frame = newLeftFrame;
         
         CGRect newCenterFrame = _centerTabContentView.frame;
         newCenterFrame.origin.y += _navigationBar.bounds.size.height;
         _centerTabContentView.frame = newCenterFrame;
         
         CGRect newRightFrame = _rightTabContentView.frame;
         newRightFrame.origin.y += _navigationBar.bounds.size.height;
         _rightTabContentView.frame = newRightFrame;
         */
        
        //        if (_centerTabContentView.isSelected) {
        //            [self selectCurrentViewAnimated:NO];
        //        }
    }
}

- (id<MOTabViewDataSource>)dataSource {
    
    return _dataSource;
}

- (void)setDataSource:(id<MOTabViewDataSource>)dataSource {
    
    // when the data source is set, views are initialized
    _dataSource = dataSource;
    
    _dataSourceRespondsToTitleForIndex = [_dataSource respondsToSelector:@selector(titleForIndex:)];
    _dataSourceRespondsToSubtitleForIndex = [_dataSource respondsToSelector:@selector(subtitleForIndex:)];
    [self initializeTitles];
    
    [self updatePageControl];
    
    _currentIndex = 0;
    
    NSUInteger numberOfViews = [_dataSource numberOfViewsInTabView:self];
    
    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
        _scrollView.contentSize = CGSizeMake((1 + kWidthFactorPortrait * (numberOfViews-1)) * self.bounds.size.width,
                                             self.bounds.size.height);
    else
        _scrollView.contentSize = CGSizeMake((1 + kWidthFactorLandscape * (numberOfViews-1)) * self.bounds.size.width,
                                             self.bounds.size.height);
    
    
    
    // initialize the three views
    _centerTabContentView = [self tabContentView];
    _centerTabContentView.delegate = self;
    [_scrollView addSubview:_centerTabContentView];
    
    // initialize left view
    _leftTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex-1
                                        withReuseView:_leftTabContentView];
    
    // initialize right view
    _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex+1
                                         withReuseView:_rightTabContentView];
    
    if (numberOfViews > 0) {
        UIView *contentView = [_dataSource tabView:self viewForIndex:0];
        _centerTabContentView.contentView = contentView;
        [self selectCurrentViewAnimated:NO];
        [self updateTitles];
    }
}

- (id<MOTabViewDelegate>)delegate {
    
    return _delegate;
}

- (void)setDelegate:(id<MOTabViewDelegate>)delegate {
    
    _delegate = delegate;
    
    // save whether the delegate responds to the delegate methods
    _delegateRespondsToWillSelect = [_delegate respondsToSelector:@selector(tabView:willSelectViewAtIndex:)];
    _delegateRespondsToWillDeselect = [_delegate respondsToSelector:@selector(tabView:willDeselectViewAtIndex:)];
    _delegateRespondsToDidSelect = [_delegate respondsToSelector:@selector(tabView:didSelectViewAtIndex:)];
    _delegateRespondsToDidDeselect = [_delegate respondsToSelector:@selector(tabView:didDeselectViewAtIndex:)];
    _delegateRespondsToWillEdit = [_delegate respondsToSelector:@selector(tabView:willEditView:atIndex:)];
    _delegateRespondsToDidEdit = [_delegate respondsToSelector:@selector(tabView:didEditView:atIndex:)];
    _delegateRespondsToDidEditTitle = [_delegate respondsToSelector:@selector(tabView:didEditTitle:atIndex:)];
    _delegateRespondsToDidChange = [_delegate respondsToSelector:@selector(tabView:didChangeIndex:)];
    
    [self tabViewWillSelectView];
    [self tabViewDidDeselectView];
}

- (BOOL)editableTitles {
    
    return _titleField.enabled;
}

- (void)setEditableTitles:(BOOL)editableTitles {
    
    _titleField.enabled = editableTitles;
    _navigationBarField.enabled = editableTitles;
}

- (void)setBackgroundView:(UIView *)newBackgroundView {
    CGRect frame = _backgroundView.frame;
    NSUInteger index = [[self subviews] indexOfObject:_backgroundView];
    [_backgroundView removeFromSuperview];
    _backgroundView = newBackgroundView;
    _backgroundView.frame = frame;
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self addSubview:_backgroundView];
    [self insertSubview:_backgroundView atIndex:index];
}

- (void)setTitleField:(UITextField *)newTitle {
    CGRect frame = _titleField.frame;
    NSString *title = _titleField.text;
    [_titleField removeFromSuperview];
    _titleField = newTitle;
    _titleField.frame = frame;
    _titleField.text = title;
    [self insertSubview:_titleField aboveSubview:_backgroundView];
}

- (void)setNavigationBarField:(UITextField *)newField {
    [_navigationBarField removeFromSuperview];
    _navigationBarField = newField;
    
    if (_dataSourceRespondsToTitleForIndex) {
        _navigationBarField.text = [self.dataSource titleForIndex:_currentIndex];
    }
    
    [_navigationBar addSubview:_navigationBarField];
}

- (void)setSubtitleLabel:(UILabel *)newSubtitle {
    CGRect frame = _subtitleLabel.frame;
    NSString *subtitle = _subtitleLabel.text;
    [_subtitleLabel removeFromSuperview];
    _subtitleLabel = newSubtitle;
    _subtitleLabel.frame = frame;
    _subtitleLabel.text = subtitle;
    [self insertSubview:_subtitleLabel aboveSubview:_backgroundView];
}

- (NSString *)titlePlaceholder {
    
    return _titleField.placeholder;
}

- (void)setTitlePlaceholder:(NSString *)titlePlaceholder {
    
    _titleField.placeholder = titlePlaceholder;
    _navigationBarField.placeholder = titlePlaceholder;
}

- (UIPageControl *)pageControl {
    return _pageControl;
}

- (BOOL)isTabSelected {
    return _leftTabContentView.isSelected || _centerTabContentView.isSelected || _rightTabContentView.isSelected;
}

- (UIScrollView *)scrollView {
    return _scrollView;
}


#pragma mark - Informing the Delegate

- (void)tabViewWillSelectView {
    
    [self bringSubviewToFront:_navigationBar];
    
    if (_delegateRespondsToWillSelect) {
        [_delegate tabView:self willSelectViewAtIndex:_currentIndex];
    }
}

- (void)tabViewDidSelectView {
    
    if (_delegateRespondsToDidSelect) {
        [_delegate tabView:self didSelectViewAtIndex:_currentIndex];
    }
    
    // selecting the view may be the last step in inserting a new tab
    if (_editingStyle == MOTabViewEditingStyleUserInsert) {
        [self tabViewDidEditViewAtIndex:_currentIndex];
    }
}

- (void)tabViewWillDeselectView {
    
    if (_delegateRespondsToWillDeselect) {
        [_delegate tabView:self willDeselectViewAtIndex:_currentIndex];
    }
}

- (void)tabViewDidDeselectView {
    
    [self bringSubviewToFront:_titleField];
    [self bringSubviewToFront:_pageControl];
    
    if (_delegateRespondsToDidDeselect) {
        [_delegate tabView:self didDeselectViewAtIndex:_currentIndex];
    }
}

- (void)tabViewDidChange {
    
    if (_delegateRespondsToDidChange) {
        [_delegate tabView:self didChangeIndex:_currentIndex];
    }
    
    [self updatePageControl];
}

- (void)tabViewWillEditViewAtIndex:(NSUInteger)index {
    
    NSUInteger numberOfViewsBeforeEdit = [_delegate numberOfViewsInTabView:self];
    
    if (_delegateRespondsToWillEdit) {
        [_delegate tabView:self willEditView:_editingStyle atIndex:index];
    }
    
    NSUInteger numberOfViewsAfterEdit = [_delegate numberOfViewsInTabView:self];
    
    if (_editingStyle == MOTabViewEditingStyleUserInsert) {
        NSString *desc = [NSString stringWithFormat:@"Number of views before insertion %lu, after insertion %lu, should be %lu",
                          (unsigned long)numberOfViewsBeforeEdit,
                          (unsigned long)numberOfViewsAfterEdit,
                          (unsigned long)(numberOfViewsBeforeEdit+1)];
        NSAssert(numberOfViewsBeforeEdit + 1 == numberOfViewsAfterEdit, desc);
    } else if (_editingStyle == MOTabViewEditingStyleDelete) {
        NSString *desc = [NSString stringWithFormat:@"Number of views before deletion %lu, after deletion %lu, should be %lu",
                          (unsigned long)numberOfViewsBeforeEdit,
                          (unsigned long)numberOfViewsAfterEdit,
                          (unsigned long)(numberOfViewsBeforeEdit-1)];
        NSAssert(numberOfViewsBeforeEdit - 1 == numberOfViewsAfterEdit, desc);
    }
}

- (void)tabViewDidEditViewAtIndex:(NSUInteger)index {
    
    [self updateTitles];
    
    // if we have deleted a tab we have to adjust the content size
    if (_editingStyle == MOTabViewEditingStyleDelete) {
        CGSize newContentSize;
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
            newContentSize.width = _scrollView.contentSize.width - kWidthFactorPortrait * _scrollView.bounds.size.width;
        else
            newContentSize.width = _scrollView.contentSize.width - kWidthFactorLandscape * _scrollView.bounds.size.width;
        
        newContentSize.height = _scrollView.contentSize.height;
        _scrollView.contentSize = newContentSize;
        
        [self updatePageControl];
    }
    
    if (_delegateRespondsToDidEdit) {
        [_delegate tabView:self didEditView:_editingStyle atIndex:index];
    }
    _editingStyle = MOTabViewEditingStyleNone;
}

- (void)tabViewDidEditTitle:(NSString *)title {
    
    if (_delegateRespondsToDidEditTitle) {
        [_delegate tabView:self didEditTitle:title atIndex:_currentIndex];
    }
}


#pragma mark - Titles

- (void)updateTitles {
    
    if (_dataSourceRespondsToTitleForIndex) {
        NSString *title = [self.dataSource titleForIndex:_currentIndex];
        _titleField.text = title;
        [_centerTabContentView setViewTitle:title];
        if (!_navigationBarHidden) {
            _navigationBarField.text = title;
        }
    }
    if (_dataSourceRespondsToSubtitleForIndex) {
        _subtitleLabel.text = [_dataSource subtitleForIndex:_currentIndex];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [textField resignFirstResponder];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)__unused textField {
    
    [self tabViewDidEditTitle:textField.text];
    
    [self updateTitles];
}


#pragma mark - UIPageControl Methods

- (void)updatePageControl {
    
    NSUInteger numberOfViews = [self.dataSource numberOfViewsInTabView:self];
    _pageControl.numberOfPages = numberOfViews;
    _pageControl.currentPage = _currentIndex;
}

- (IBAction)changePage:(UIPageControl *)pageControl {
    
    [self scrollToViewAtIndex:(NSUInteger) pageControl.currentPage
           withTimingFunction:_easeInEaseOutTimingFunction
                     duration:0.5];
}


#pragma mark - TabContentViewDelegate Methods

// invoked when delete button is pressed
- (void)tabContentViewDidTapDelete:(MOTabContentView *)__unused tabContentView {
    
    [self deleteCurrentView];
}

// user tap on one of the three content views
- (void)tabContentViewDidTapView:(MOTabContentView *)tabContentView {
    
    //    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (tabContentView == _leftTabContentView) {
        [self scrollToViewAtIndex:_currentIndex-1
               withTimingFunction:_easeInEaseOutTimingFunction
                         duration:0.5];
    } else if (tabContentView == _centerTabContentView) {
        [self selectCurrentViewAnimated:YES];
    } else if (tabContentView == _rightTabContentView) {
        [self scrollToViewAtIndex:_currentIndex+1
               withTimingFunction:_easeInEaseOutTimingFunction
                         duration:0.5];
    }
}

- (void)tabContentViewDidSelect:(MOTabContentView *)__unused tabContentView {
    
    [self tabViewDidSelectView];
}

- (void)tabContentViewDidDeselect:(MOTabContentView *)__unused tabContentView {
    
    [self tabViewDidDeselectView];
}


#pragma mark - UIScrollViewDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    if (![self isTabSelected]) { // Just in case
        
        CGPoint vel = [gesture velocityInView:_scrollView];
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_NONE) {
            
            if (fabs(vel.x) > fabs(vel.y) && fabs(vel.x) > 50) {
                /* User is trying to change page */
                
                panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_SIDE;
            } else if (fabs(vel.y) > fabs(vel.x) && vel.y < -50) { // We only care about speed < 0 because the user needs to swipe up to close the tab
                /* User is trying to remove a tab */
                
                panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_UP;
                originalPoint = [_centerTabContentView center];
                [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
            }
        }
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_SIDE) {
            
            CGFloat xDistance = [gesture translationInView:_scrollView].x;
            CGFloat widthFactor = kWidthFactorPortrait;
            if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
                widthFactor = kWidthFactorLandscape;
            
            switch (gesture.state) {
                    
                case UIGestureRecognizerStateChanged: {
                    
                    CGRect frame = _scrollView.frame;
                    frame.origin.x = frame.size.width * _currentIndex * widthFactor;
                    frame.origin.y = 0;
                    
                    CGFloat visibility = fabs(xDistance / _scrollView.frame.size.width / widthFactor);
                    _leftTabContentView.visibility = visibility;
                    _centerTabContentView.visibility = 1 - visibility;
                    _rightTabContentView.visibility = visibility;
                    
                    [_scrollView setContentOffset:CGPointMake(frame.origin.x - xDistance, frame.origin.y) animated:NO];
                    break;
                };
                    
                    
                case UIGestureRecognizerStateEnded: {
                    
                    if ((xDistance <= -100 || vel.x <= -300) && _currentIndex < _pageControl.numberOfPages - 1) {
                        /* Moved enough to change page (go right), and there is at least 1 page on the right */
                        
                        // save left view for reuse
                        MOTabContentView *reuseTabContentView = _leftTabContentView;
                        
                        if (reuseTabContentView.contentView) {
                            [self storeReusableView:reuseTabContentView.contentView];
                            reuseTabContentView.contentView = nil;
                        }
                        
                        _leftTabContentView = _centerTabContentView;
                        _centerTabContentView = _rightTabContentView;
                        
                        // add additional view to the right
                        _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex + 2
                                                             withReuseView:reuseTabContentView];
                        
                        #warning Just in case (see other warnings)
                        _centerTabContentView.contentView = _centerTabContentView.contentView;
                        _leftTabContentView.contentView = _leftTabContentView.contentView;
                        
                        // if right view was just added by insert, hide it
                        if (_hideLastTabContentView && _currentIndex + 2 == _pageControl.numberOfPages-1) {
                            _rightTabContentView.hidden = YES;
                            _hideLastTabContentView = NO;
                        }
                        
                        [_pageControl setCurrentPage:_currentIndex + 1];
                        _currentIndex += 1;
                        
                        [self tabViewDidChange];
                        [self updateTitles];
                    } else if ((xDistance >= 100 || vel.x >= 300) && _currentIndex > 0) {
                        /* Moved enough to change page (go left), and there is at least 1 page on the left */
                        
                        // save right view for reuse
                        MOTabContentView *reuseTabContentView = _rightTabContentView;
                        if (reuseTabContentView.contentView) {
                            [self storeReusableView:reuseTabContentView.contentView];
                            reuseTabContentView.contentView = nil;
                        }
                        
                        _rightTabContentView = _centerTabContentView;
                        _centerTabContentView = _leftTabContentView;
                        _leftTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex - 2
                                                            withReuseView:reuseTabContentView];
                        
                        #warning Just in case (see other warnings)
                        _centerTabContentView.contentView = _centerTabContentView.contentView;
                        _leftTabContentView.contentView = _leftTabContentView.contentView;
                        
                        [_pageControl setCurrentPage:_currentIndex - 1];
                        _currentIndex -= 1;
                        
                        [self tabViewDidChange];
                        [self updateTitles];
                    }
                    
                    // If the page index wasn't changed, it will just scroll back to the page's original position
                    CGRect frame = _scrollView.frame;
                    frame.origin.x = _currentIndex * widthFactor * frame.size.width;
                    frame.origin.y = 0;
                    
                    [UIView animateWithDuration:0.3
                                     animations:^{
                                         _leftTabContentView.visibility = 0;
                                         _centerTabContentView.visibility = 1;
                                         _rightTabContentView.visibility = 0;
                                         [_scrollView setContentOffset:frame.origin animated:NO];
                                     }
                                     completion:^(BOOL finished){
                                         panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                                     }];
                    
                    break;
                };
                    
                default: break;
            }
            
        } else if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_UP) {
            
            CGFloat yDistance = [gesture translationInView:_scrollView].y;
            
            switch (gesture.state) {
                    
                case UIGestureRecognizerStateChanged: {
                    
                    if (yDistance <= 0) {
                        _centerTabContentView.center = CGPointMake(originalPoint.x, originalPoint.y + yDistance);
                    }
                    break;
                };
                    
                case UIGestureRecognizerStateEnded: {
                    
                    if (-yDistance <= self.frame.size.height/3 && vel.y >= -1500) {
                        // Moved the view less than 1/4th of the view height, or is moving fast enough to consider the user wants to close
                        
                        [UIView animateWithDuration:0.5 animations:^{
                            [_centerTabContentView setCenter:originalPoint];
                        } completion:^(BOOL finished) {}];
                    } else {
                        
                        [UIView animateWithDuration:0.2 animations:^{
                            _centerTabContentView.alpha = 0;
                            [_centerTabContentView setCenter:CGPointMake(originalPoint.x, - originalPoint.y)];
                        } completion:^(BOOL finished) {
                            [_centerTabContentView setCenter:originalPoint];
                            [self deleteCurrentView];
                        }];
                    }
                    
                    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    
                    break;
                };
                    
                default: break;
            }
        }
    }
}

- (void)handleTwoFingerDrag:(UIPanGestureRecognizer *)gesture {
    if ([self isTabSelected]) {
        CGPoint vel = [gesture velocityInView:_scrollView];
        
        if (CGPointEqualToPoint(panGestureOriginPoint, CGPointZero)) {
            panGestureOriginPoint = [gesture locationInView:_centerTabContentView];
        }
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_NONE && fabs(vel.x) > 50 && [_dataSource numberOfViewsInTabView:self] > 1) {
            // User is trying to change tab, and there are at least 2 tabs
            
            if (panGestureOriginPoint.x <= PAN_GESTURE_RECOGNIZER_EDGE_SIZE || panGestureOriginPoint.x >= (_centerTabContentView.bounds.size.width - PAN_GESTURE_RECOGNIZER_EDGE_SIZE)) {
                // User started from the edge of the screen
                panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_SIDE;
                // Prevent scrolling/zooming while the user is changing tab
                AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                WebViewTab *tab = (WebViewTab *)[appDelegate.tabsViewController.contentViews objectAtIndex:_currentIndex];
                
                [tab.scrollView.pinchGestureRecognizer setEnabled:NO];
                [tab.scrollView.panGestureRecognizer setEnabled:NO];
            }
        }
        
        if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_SIDE) {
            CGFloat xDistance = [gesture translationInView:_scrollView].x;
            
            switch (gesture.state) {
                case UIGestureRecognizerStateChanged: {
                    CGRect frame = _scrollView.frame;
                    frame.origin.x = frame.size.width * _currentIndex;
                    frame.origin.y = 0;
                    
                    // Disable "impossible" drags to remove ugly transitions
                    if (xDistance < 0 && _currentIndex == [_delegate numberOfViewsInTabView:self] - 1)
                        xDistance = 0;
                    else if (xDistance > 0 && _currentIndex == 0)
                        xDistance = 0;
                    
                    [_scrollView setContentOffset:CGPointMake(frame.origin.x - xDistance, frame.origin.y) animated:NO];
                    break;
                };
                    
                case UIGestureRecognizerStateCancelled: {
                    // Reset everything
                    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                    WebViewTab *tab = (WebViewTab *)[appDelegate.tabsViewController.contentViews objectAtIndex:_currentIndex];
                    [tab.scrollView.pinchGestureRecognizer setEnabled:YES];
                    [tab.scrollView.panGestureRecognizer setEnabled:YES];
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    panGestureOriginPoint = CGPointZero;
                }
                    
                case UIGestureRecognizerStateFailed: {
                    // Reset everything
                    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                    WebViewTab *tab = (WebViewTab *)[appDelegate.tabsViewController.contentViews objectAtIndex:_currentIndex];
                    [tab.scrollView.pinchGestureRecognizer setEnabled:YES];
                    [tab.scrollView.panGestureRecognizer setEnabled:YES];
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    panGestureOriginPoint = CGPointZero;
                }
                    
                case UIGestureRecognizerStateEnded: {
                    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                    WebViewTab *tab = (WebViewTab *)[appDelegate.tabsViewController.contentViews objectAtIndex:_currentIndex];
                    [tab.scrollView.pinchGestureRecognizer setEnabled:YES];
                    [tab.scrollView.panGestureRecognizer setEnabled:YES];
                    
                    if ((xDistance <= -100 || vel.x <= -300) && _currentIndex < [_delegate numberOfViewsInTabView:self] - 1) {
                        // Moved enough to change tab (go right), and there is at least 1 tab on the right
                        // save left view for reuse
                        MOTabContentView *reuseTabContentView = _leftTabContentView;
                        
                        if (reuseTabContentView.contentView) {
                            [self storeReusableView:reuseTabContentView.contentView];
                            reuseTabContentView.contentView = nil;
                        }
                        
                        _leftTabContentView = _centerTabContentView;
                        _centerTabContentView = _rightTabContentView;
                        
                        // add additional view to the right
                        _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex + 2
                                                             withReuseView:reuseTabContentView];
                        
                        // if right view was just added by insert, hide it
                        if (_hideLastTabContentView && _currentIndex + 2 == _pageControl.numberOfPages-1) {
                            _rightTabContentView.hidden = YES;
                            _hideLastTabContentView = NO;
                        }
                        
                        [_pageControl setCurrentPage:_currentIndex + 1];
                        _currentIndex += 1;
                        
                        [self tabViewDidChange];
                        [self updateTitles];
                    } else if ((xDistance >= 100 || vel.x >= 300) && _currentIndex > 0) {
                        // Moved enough to change tab (go left), and there is at least 1 tab on the left
                        // save right view for reuse
                        MOTabContentView *reuseTabContentView = _rightTabContentView;
                        if (reuseTabContentView.contentView) {
                            [self storeReusableView:reuseTabContentView.contentView];
                            reuseTabContentView.contentView = nil;
                        }
                        
                        _rightTabContentView = _centerTabContentView;
                        _centerTabContentView = _leftTabContentView;
                        _leftTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex - 2
                                                            withReuseView:reuseTabContentView];
                        
                        [_pageControl setCurrentPage:_currentIndex - 1];
                        _currentIndex -= 1;
                        
                        [self tabViewDidChange];
                        [self updateTitles];
                    }
                    
                    // If the page index wasn't changed, it will just scroll back to the page's original position
                    CGRect frame = _scrollView.frame;
                    frame.origin.x = frame.size.width * _currentIndex;
                    frame.origin.y = 0;
                    [_scrollView setContentOffset:frame.origin animated:YES];
                    
                    // Update the searchBar to match the selected tab
                    // [self updateSearchBarDetails];
                    
                    /*
                    // Refresh/force refresh if necessary
                    if ([[self curWebViewTab] needsForceRefresh]) {
                        [[self curWebViewTab] forceRefresh];
                        [[self curWebViewTab] setNeedsForceRefresh:NO];
                    }
                    
                    if ([[self curWebViewTab] needsRefresh]) {
                        [[self curWebViewTab] refresh];
                        [[self curWebViewTab] setNeedsRefresh:NO];
                    }
                     */
                    
                    panGestureRecognizerType = PAN_GESTURE_RECOGNIZER_NONE;
                    panGestureOriginPoint = CGPointZero;
                    
                    break;
                };
                    
                default: break;
            }
            
        } else if (gesture.state == UIGestureRecognizerStateEnded) {
            // Reset the origin point for the gesture
            panGestureOriginPoint = CGPointZero;
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            WebViewTab *tab = (WebViewTab *)[appDelegate.tabsViewController.contentViews objectAtIndex:_currentIndex];
            [tab.scrollView.pinchGestureRecognizer setEnabled:YES];
            [tab.scrollView.panGestureRecognizer setEnabled:YES];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    //    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (panGestureRecognizerType == PAN_GESTURE_RECOGNIZER_NONE && self.scrollView.scrollEnabled) {
        // If this scroll isn't already being taken care of (a view is being added) and the scroll isn't triggered by a frame change
        
        CGFloat pageWidth = scrollView.frame.size.width;
        CGFloat fractionalIndex = scrollView.contentOffset.x / pageWidth / kWidthFactorPortrait;
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
            fractionalIndex = scrollView.contentOffset.x / pageWidth / kWidthFactorLandscape;
        
        NSInteger potentialIndex = (NSInteger) roundf(fractionalIndex);
        
        //
        NSUInteger numberOfViews = [_dataSource numberOfViewsInTabView:self];
        
        if (potentialIndex >= 0 && potentialIndex < (NSInteger) numberOfViews) {
            
            NSUInteger newIndex = (NSUInteger) potentialIndex;
            if (newIndex > _currentIndex || newIndex < _currentIndex) {
                
                if (newIndex > _currentIndex) {
                    
                    // save left view for reuse
                    MOTabContentView *reuseTabContentView = _leftTabContentView;
                    if (reuseTabContentView.contentView) {
                        [self storeReusableView:reuseTabContentView.contentView];
                        reuseTabContentView.contentView = nil;
                    }
                    
                    _leftTabContentView = _centerTabContentView;
                    _centerTabContentView = _rightTabContentView;
                    
                    // add additional view to the right
                    _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)newIndex+1
                                                         withReuseView:reuseTabContentView];
                    
                    // if right view was just added by insert, hide it
                    if (_hideLastTabContentView && newIndex+1 == numberOfViews-1) {
                        _rightTabContentView.hidden = YES;
                        _hideLastTabContentView = NO;
                    }
                    
                } else if (newIndex < _currentIndex) {
                    
                    // save right view for reuse
                    MOTabContentView *reuseTabContentView = _rightTabContentView;
                    if (reuseTabContentView.contentView) {
                        [self storeReusableView:reuseTabContentView.contentView];
                        reuseTabContentView.contentView = nil;
                    }
                    
                    _rightTabContentView = _centerTabContentView;
                    _centerTabContentView = _leftTabContentView;
                    
                    //
                    _leftTabContentView = [self tabContentViewAtIndex:(NSInteger)newIndex-1
                                                        withReuseView:reuseTabContentView];
                }
                
                _currentIndex = (int)newIndex;
                [self tabViewDidChange];
                
                [self updateTitles];
            }
        }
        
        CGFloat distance = fabs(roundf(fractionalIndex) - fractionalIndex);
        _leftTabContentView.visibility = distance;
        _centerTabContentView.visibility = 1-distance;
        _rightTabContentView.visibility = distance;
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    
    // user stoped draging and the view does not decelerate
    // case that view decelerates is handled in scrollViewWillBeginDecelerating
    if (!decelerate) {
        
        CGFloat pageWidth = scrollView.frame.size.width;
        CGFloat ratio = scrollView.contentOffset.x / pageWidth / kWidthFactorPortrait;
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
            ratio = scrollView.contentOffset.x / pageWidth / kWidthFactorLandscape;
        
        NSUInteger newIndex = (NSUInteger) roundf(ratio);
        
        [self scrollToViewAtIndex:newIndex
               withTimingFunction:_easeOutTimingFunction
                         duration:0.25];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    
    // adjust page control
    CGFloat pageWidth = scrollView.frame.size.width;
    float fractionalIndex = scrollView.contentOffset.x / pageWidth / kWidthFactorPortrait;
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        fractionalIndex = scrollView.contentOffset.x / pageWidth / kWidthFactorLandscape;
    
    NSInteger index = (NSInteger) roundf(fractionalIndex);
    
    NSInteger potentialIndex;
    if (fractionalIndex - _currentIndex > 0) {
        potentialIndex = index + 1;
    } else {
        potentialIndex = index - 1;
    }
    
    NSUInteger numberOfViews = [self.dataSource numberOfViewsInTabView:self];
    
    if (potentialIndex >= 0 && potentialIndex < (NSInteger) numberOfViews) {
        NSUInteger nextIndex = (NSUInteger) potentialIndex;
        // stop deceleration
        [scrollView setContentOffset:scrollView.contentOffset animated:YES];
        
        // scroll view to next index
        [self scrollToViewAtIndex:nextIndex
               withTimingFunction:_easeOutTimingFunction
                         duration:0.25];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)__unused scrollView {
    
    //    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.userInteractionEnabled = YES;
    
    if (_centerTabContentView.hidden) {
        
        _centerTabContentView.alpha = 0;
        _centerTabContentView.hidden = NO;
        [UIView animateWithDuration:0.3
                         animations:^{
                             _centerTabContentView.alpha = 1;
                         }
                         completion:^(BOOL __unused finished){
                             [self selectCurrentViewAnimated:YES];
                         }];
    }
    
    // after the deletion animation finished we inform the delegate
    if (_editingStyle == MOTabViewEditingStyleDelete) {
        [self tabViewDidEditViewAtIndex:_currentIndex];
    }
}


#pragma mark -

- (void)scrollToViewAtIndex:(NSUInteger)newIndex {
    [self scrollToViewAtIndex:newIndex withTimingFunction:_easeInTimingFunction duration:0.3];
}

- (void)scrollToViewAtIndex:(NSUInteger)newIndex
         withTimingFunction:(CAMediaTimingFunction *)timingFunction
                   duration:(CFTimeInterval)duration {
    
    self.userInteractionEnabled = NO;
    
    CGPoint contentOffset = CGPointMake(newIndex * kWidthFactorPortrait * self.bounds.size.width, 0);
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        contentOffset = CGPointMake(newIndex * kWidthFactorLandscape * self.bounds.size.width, 0);
    
    [_scrollView setContentOffset:contentOffset
               withTimingFunction:timingFunction
                         duration:duration];
    //    [_scrollView setContentOffset:contentOffset animated:YES];
}

- (void)insertNewView {
    
    _editingStyle = MOTabViewEditingStyleUserInsert;
    
    CGFloat widthFactor = kWidthFactorPortrait;
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        widthFactor = kWidthFactorLandscape;
    
    CGSize newContentSize;
    newContentSize.width = _scrollView.contentSize.width + widthFactor * _scrollView.bounds.size.width;
    newContentSize.height = _scrollView.contentSize.height;
    _scrollView.contentSize = newContentSize;
    
    // index where new tab is added
    NSUInteger newIndex = 0;
    NSUInteger numberOfViews = [self.dataSource numberOfViewsInTabView:self];
    if (_addingStyle == MOTabViewAddingAtLastIndex) {
        newIndex = numberOfViews;
    } else if (_addingStyle == MOTabViewAddingAtNextIndex) {
        newIndex = _currentIndex + 1;
    }
    
    // inform delegate to update model
    [_delegate tabView:self
          willEditView:_editingStyle
               atIndex:newIndex];
    
    if (_addingStyle == MOTabViewAddingAtNextIndex) {
        
        // move all three views to the right
        CGRect newLeftFrame = _leftTabContentView.frame;
        newLeftFrame.origin.x += widthFactor * self.bounds.size.width;
        _leftTabContentView.frame = newLeftFrame;
        CGRect newCenterFrame = _centerTabContentView.frame;
        newCenterFrame.origin.x += widthFactor * self.bounds.size.width;
        _centerTabContentView.frame = newCenterFrame;
        CGRect newRightFrame = _rightTabContentView.frame;
        newRightFrame.origin.x += widthFactor * self.bounds.size.width;
        _rightTabContentView.frame = newRightFrame;
        
        // and increase the offset by the same factor
        // we set the bounds of the scrollview and not the contentOffset to
        // not inform the delegate
        CGRect newBounds = _scrollView.bounds;
        newBounds.origin.x = _scrollView.bounds.origin.x + widthFactor * _scrollView.bounds.size.width;
        _scrollView.bounds = newBounds;
        
        // this way we can later move the left and the center view to the left
        // and make room for a new tab
        
        if (numberOfViews == 0) {
            _currentIndex = 0;
        } else {
            _currentIndex = _currentIndex + 1;
        }
        [self updatePageControl];
        
        [UIView animateWithDuration:0.3
                         animations:^{
                             CGRect newLeftFrame = _leftTabContentView.frame;
                             newLeftFrame.origin.x -= widthFactor * self.bounds.size.width;
                             _leftTabContentView.frame = newLeftFrame;
                             _leftTabContentView.visibility = 1;
                             CGRect newCenterFrame = _centerTabContentView.frame;
                             newCenterFrame.origin.x -= widthFactor * self.bounds.size.width;
                             _centerTabContentView.frame = newCenterFrame;
                             _centerTabContentView.visibility = 0;
                         }
                         completion:^(BOOL __unused finished) {
                             
                             // after changing frames the center view becomes
                             // the left view
                             [_leftTabContentView removeFromSuperview];
                             _leftTabContentView = _centerTabContentView;
                             _centerTabContentView = nil;
                             
                             // TODO: revise this code
                             MOTabView *temp = self;
                             [self addNewCenterViewAnimated:YES
                                                 completion:^(BOOL __unused finished) {
                                                     [temp selectCurrentViewAnimated:YES];
                                                 }];
                             
                         }];
        
    } else if (_addingStyle == MOTabViewAddingAtLastIndex) {
        
        if (_currentIndex + 1 == newIndex) {
            _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)newIndex withReuseView:_rightTabContentView];
            _rightTabContentView.hidden = YES;
            
            #warning Fixes a bug where the content view doesn't appear, perhaps a memory issue?
            _centerTabContentView.contentView = _centerTabContentView.contentView;
            _leftTabContentView.contentView = _leftTabContentView.contentView;
        } else {
            _hideLastTabContentView = YES;
        }
        
        CFTimeInterval duration;
        if (labs((NSInteger) (newIndex - _currentIndex)) > 3) {
            duration = 0.8;
        } else {
            duration = 0.3;
        }
        
        [self scrollToViewAtIndex:newIndex
               withTimingFunction:_easeInTimingFunction
                         duration:duration];
    }
}

- (void)insertViewAtIndex:(NSUInteger)newIndex {
    
    _editingStyle = MOTabViewEditingStyleInsert;
    
    [self privateInsertViewAtIndex:newIndex];
}

- (void)privateInsertViewAtIndex:(NSUInteger)newIndex {
    
    CGSize newContentSize;
    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
        newContentSize.width = _scrollView.contentSize.width + kWidthFactorPortrait * _scrollView.bounds.size.width;
    else
        newContentSize.width = _scrollView.contentSize.width + kWidthFactorLandscape * _scrollView.bounds.size.width;
    
    newContentSize.height = _scrollView.contentSize.height;
    _scrollView.contentSize = newContentSize;
    
    [self tabViewWillEditViewAtIndex:newIndex];
    
    if (_currentIndex + 1 == newIndex) {
        _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)newIndex
                                             withReuseView:_rightTabContentView];
        
    }
    
    [self tabViewDidEditViewAtIndex:newIndex];
}

- (CGRect)newFrame:(CGRect)frame forIndex:(NSInteger)index {
    
    CGRect newFrame = frame;
    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
        newFrame.origin.x = newFrame.origin.x + index * kWidthFactorPortrait * self.bounds.size.width;
    else
        newFrame.origin.x = newFrame.origin.x + index * kWidthFactorLandscape * self.bounds.size.width;
    
    return newFrame;
}

- (MOTabContentView *)tabContentViewAtIndex:(NSInteger)index
                              withReuseView:(MOTabContentView *)reuseView {
    
    // if the index is out of bounds, the view is hidden
    NSUInteger numberOfViews = [_dataSource numberOfViewsInTabView:self];
    MOTabContentView *tabContentView = nil;
    
    if (reuseView) {
        tabContentView = reuseView;
    } else {
        tabContentView = [[MOTabContentView alloc] initWithFrame:CGRectZero];
        tabContentView.delegate = self;
        tabContentView.visibility = 0;
        [_scrollView insertSubview:tabContentView belowSubview:_centerTabContentView];
    }
    
    if (0 <= index && index < (NSInteger)numberOfViews) {
        // the index is within the bounds
        UIView *contentView = [_dataSource tabView:self viewForIndex:(NSUInteger)index];
        CGRect newFrame = [self newFrame:self.bounds forIndex:index];
        tabContentView.frame = newFrame;
        tabContentView.contentView = contentView;
        tabContentView.hidden = NO;
        [_scrollView bringSubviewToFront:tabContentView];
        
        if (kDebugMode) {
            tabContentView.userInteractionEnabled = YES;
        }
        
    } else {
        
        // the view is out of bounds and, therefore, not dislayed
        tabContentView.hidden = YES;
        
        if (kDebugMode) {
            // code for debugging purposes, displays the hidden views
            UIView *debugContentView = [[UIView alloc] initWithFrame:self.bounds];
            debugContentView.backgroundColor = [UIColor redColor];
            tabContentView.hidden = NO;
            tabContentView.contentView = debugContentView;
            tabContentView.frame = [self newFrame:self.bounds forIndex:index];
            tabContentView.userInteractionEnabled = NO;
        }
    }
    
    return tabContentView;
}

// TODO: actually use this method
- (void)addNewCenterViewAnimated:(BOOL)__unused animated
                      completion:(void (^)(BOOL finished))completion {
    
    UIView *contentView = [_dataSource tabView:self
                                  viewForIndex:_currentIndex];
    if (_leftTabContentView) {
        CGRect centerFrame = _leftTabContentView.frame;
        
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
            centerFrame.origin.x += kWidthFactorPortrait * self.bounds.size.width;
        else
            centerFrame.origin.x += kWidthFactorLandscape * self.bounds.size.width;
        
        _centerTabContentView = [[MOTabContentView alloc] initWithFrame:centerFrame];
        _centerTabContentView.delegate = self;
        _centerTabContentView.contentView = contentView;
        _centerTabContentView.visibility = 1;
        _centerTabContentView.alpha = 0;
    } else {
        _centerTabContentView = [self tabContentView];
        _centerTabContentView.delegate = self;
        _centerTabContentView.contentView = contentView;
        //        [self selectCurrentViewAnimated:NO];
        //        [self updateTitles];
    }
    [_scrollView addSubview:_centerTabContentView];
    
    //    [UIView animateWithDuration:0.5
    //                     animations:^{
    //                         _centerTabContentView.alpha = 1;
    //                     }
    //                     completion:completion];
}


- (void)deleteCurrentView {
    
    // if we are about to delete the last remaining tab, we first add a new one
    NSUInteger numberOfViews = [_delegate numberOfViewsInTabView:self];
    if (numberOfViews == 1) {
        // editingStyle is user insert because it is caused by a user action
        _editingStyle = MOTabViewEditingStyleUserInsert;
        
        [self privateInsertViewAtIndex:1];
        
        // reset the number of view to correct value after adding a view
        numberOfViews++;
    }
    
    _editingStyle = MOTabViewEditingStyleDelete;
    CGFloat widthFactor = kWidthFactorPortrait;
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        widthFactor = kWidthFactorLandscape;
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         _centerTabContentView.alpha = 0;
                     }
                     completion:^(BOOL __unused finished) {
                         
                         // inform delegate that view will be deleted
                         [self tabViewWillEditViewAtIndex:_currentIndex];
                         
                         _centerTabContentView.alpha = _rightTabContentView.alpha;
                         _centerTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex
                                                               withReuseView:_centerTabContentView];
                         
                         if (_currentIndex == numberOfViews-1) {
                             
                             [self scrollToViewAtIndex:_currentIndex-1
                                    withTimingFunction:_easeInEaseOutTimingFunction
                                              duration:0.4];
                         } else {
                             
                             // the new center view moves in from the right,
                             // thus we set its position appropriately
                             CGPoint newCenterCenter = _centerTabContentView.center;
                             newCenterCenter.x += widthFactor * self.bounds.size.width;
                             _centerTabContentView.center = newCenterCenter;
                             
                             // add new right view
                             _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)_currentIndex+1 withReuseView:_rightTabContentView];
                             
                             // the new right center view moves in from the right, too
                             CGPoint newRightCenter = _rightTabContentView.center;
                             newRightCenter.x += widthFactor * self.bounds.size.width;
                             _rightTabContentView.center = newRightCenter;
                             
                             #warning Fixes a bug where the content view doesn't appear, perhaps a memory issue?
                             _centerTabContentView.contentView = _centerTabContentView.contentView;
                             
                             [UIView animateWithDuration:0.4
                                              animations:^{
                                                  // move the two view to their target position
                                                  CGPoint newCenterCenter = _centerTabContentView.center;
                                                  newCenterCenter.x -= widthFactor * self.bounds.size.width;
                                                  _centerTabContentView.center = newCenterCenter;
                                                  _centerTabContentView.visibility = 1;
                                                  CGPoint newRightCenter = _rightTabContentView.center;
                                                  newRightCenter.x -= widthFactor * self.bounds.size.width;
                                                  _rightTabContentView.center = newRightCenter;
                                              }
                                              completion:^(BOOL __unused finished){
                                                  [self tabViewDidEditViewAtIndex:_currentIndex];
                                              }];
                         }
                     }];
}

- (void)selectCurrentView {
    [self selectCurrentViewAnimated:YES];
}

- (void)selectCurrentViewAnimated:(BOOL)animated {
    
    [_scrollView removeGestureRecognizer:tabSelectionPanGestureRecognizer];
    tabSelectionPanGestureRecognizer = nil;
    
    if (!_navigationBarHidden
        && _navigationBarScrolls
        && [_centerTabContentView.contentView.class isSubclassOfClass:[UITableView class]]) {
        // set the navigation bar to the correct position
        CGRect newNavigationFrame = _navigationBar.frame;
        // because the view is transformed, we can simply check the frame to
        // determine where the origin will be when the view is expanded
        newNavigationFrame.origin.y = _centerTabContentView.frame.origin.y - _navigationBar.bounds.size.height;
        _navigationBar.frame = newNavigationFrame;
    }
    
    [self tabViewWillSelectView];
    
    if (!_navigationBarHidden) {
        [_scrollView bringSubviewToFront:_centerTabContentView];
        [self bringSubviewToFront:_scrollView];
        [self bringSubviewToFront:_navigationBar];
    } else {
        [_scrollView bringSubviewToFront:_centerTabContentView];
        [self bringSubviewToFront:_scrollView];
    }
    _scrollView.scrollEnabled = NO;
    
    [self updateTitles];
    
    if (animated && !_navigationBarHidden) {
        [UIView animateWithDuration:0.3
                         animations:^{
                             _navigationBar.alpha = 1;
                         }];
    }
    
#warning informs the delegate at the end of the animation, not guarenteed that navigationbar animation is finised
    [_centerTabContentView selectAnimated:animated];
}

- (void)deselectCurrentView {
    
    [self deselectCurrentViewAnimated:YES];
}

- (void)deselectCurrentViewAnimated:(BOOL)animated {
    
    tabSelectionPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [tabSelectionPanGestureRecognizer setMinimumNumberOfTouches:1];
    [tabSelectionPanGestureRecognizer setMaximumNumberOfTouches:1];
    [_scrollView addGestureRecognizer:tabSelectionPanGestureRecognizer];
    
    if (!_navigationBarHidden
        && _navigationBarScrolls
        && [_centerTabContentView.contentView.class isSubclassOfClass:[UITableView class]]) {
        
        UITableView *tableView = (UITableView *)_centerTabContentView.contentView;
        
        // careful, removing tableHeaderView changes contentOffset
        // therefore, we save it into a variable
        float contentOffsetY = tableView.contentOffset.y;
        tableView.tableHeaderView = nil;
        
        CGRect navigationFrame = _navigationBar.frame;
        navigationFrame.origin.y = -contentOffsetY;
        _navigationBar.frame = navigationFrame;
        [self addSubview:_navigationBar];
        
        CGRect contentFrame = _centerTabContentView.frame;
        contentFrame.origin.y = MAX(_navigationBar.bounds.size.height - contentOffsetY, 0);
        _centerTabContentView.frame = contentFrame;
        
        tableView.contentOffset = CGPointMake(0, MAX(contentOffsetY - _navigationBar.bounds.size.height, 0));
    }
    
    if (!_navigationBarHidden
        && !_navigationBarScrolls
        && [_centerTabContentView.contentView.class isSubclassOfClass:[UITableView class]]) {
        
        UITableView *tableView = (UITableView *)_centerTabContentView.contentView;
        
#warning ugly implementation, improve this!
        // if the user currenly touches the table view we don't deselect the view
        if (tableView.tracking) {
            return;
        }
        
        [self adapt:tableView];
    }
    
    [self tabViewWillDeselectView];
    
    [self updateTitles];
    _scrollView.scrollEnabled = YES;
    
    if (animated && !_navigationBarHidden) {
        [UIView animateWithDuration:0.3
                         animations:^{
                             _navigationBar.alpha = 0;
                         }];
    }
    
#warning informs the delegate at the end of the animation, not guarenteed that navigationbar animation is finised
    [_centerTabContentView deselectAnimated:animated];
}

- (void)adapt:(UITableView *)tableView {
    
    // check whether the inset at the bottom is visible
    CGFloat bottomBounceDist = tableView.bounds.size.height + tableView.contentOffset.y - tableView.contentSize.height;
    
    if (tableView.contentOffset.y < 0) {
        // scroll view bounces at the top
        // hide bouncing area
        CGPoint newContentOffset = tableView.contentOffset;
        newContentOffset.y = 0;
        [tableView setContentOffset:newContentOffset animated:YES];
    } else if (bottomBounceDist > 0) {
        
        CGFloat bottomBoundDistWithoutInset = bottomBounceDist - tableView.contentInset.bottom;
        
        // move view to the top by the amount the bottom inset is shown
        CGRect newCenterFrame = _centerTabContentView.frame;
        newCenterFrame.origin.y -= MIN(tableView.contentInset.bottom, bottomBounceDist);
        _centerTabContentView.frame = newCenterFrame;
        
        if (bottomBoundDistWithoutInset > 0) {
            // table view bounces at the bottom
            CGPoint newContentOffset = tableView.contentOffset;
            newContentOffset.y -= bottomBoundDistWithoutInset;
            // we don't have to adjust the contentOffset as setting the inset
            // adjust the offset as well
        } else {
            // table view does not bounce at the bottom
        }
        
        // remove insets
        UIEdgeInsets newContentInset = tableView.contentInset;
        newContentInset.bottom = 0;
        tableView.contentInset = newContentInset;
        UIEdgeInsets newScrollInsets = tableView.scrollIndicatorInsets;
        newScrollInsets.bottom = 0;
        tableView.scrollIndicatorInsets = newScrollInsets;
        
    }
}

- (UIView *)viewForIndex:(NSUInteger)index {
    
    if (index == _currentIndex) {
        return _centerTabContentView.contentView;
    } else if (index-1 == _currentIndex) {
        return _rightTabContentView.contentView;
    } else if (index+1 == _currentIndex) {
        return _leftTabContentView.contentView;
    } else {
        return nil;
    }
}

- (NSUInteger)indexOfContentView:(UIView *)view {
    
    if (view == _leftTabContentView.contentView) {
        return _currentIndex-1;
    } else if (view == _centerTabContentView.contentView) {
        return _currentIndex;
    } else if (view == _rightTabContentView.contentView) {
        return _currentIndex+1;
    } else {
        return 0;
    }
}

- (UIView *)selectedView {
    
    if (_centerTabContentView.isSelected) {
        return _centerTabContentView.contentView;
    } else {
        return nil;
    }
}

- (void)selectViewAtIndex:(NSUInteger)index {
    
    [self selectViewAtIndex:index animated:YES];
}

- (void)selectViewAtIndex:(NSUInteger)index animated:(BOOL)animated {
    
    if (!_navigationBarHidden
        && _navigationBarScrolls
        && [_centerTabContentView.contentView.class isSubclassOfClass:[UITableView class]]) {
        // set the navigation bar to the correct position
        CGRect newNavigationFrame = _navigationBar.frame;
        // because the view is transformed, we can simply check the frame to
        // determine where the origin will be when the view is expanded
        newNavigationFrame.origin.y = _centerTabContentView.frame.origin.y - _navigationBar.bounds.size.height;
        _navigationBar.frame = newNavigationFrame;
    }
    
    [self tabViewWillSelectView];
    
    if (!_navigationBarHidden) {
        [_scrollView bringSubviewToFront:_centerTabContentView];
        [self bringSubviewToFront:_scrollView];
        [self bringSubviewToFront:_navigationBar];
    } else {
        [_scrollView bringSubviewToFront:_centerTabContentView];
        [self bringSubviewToFront:_scrollView];
    }
    _scrollView.scrollEnabled = NO;
    
    [self updateTitles];
    
    if (animated
        && !_navigationBarHidden) {
        [UIView animateWithDuration:0.3
                         animations:^{
                             _navigationBar.alpha = 1;
                         }];
    }
    
    [_leftTabContentView removeFromSuperview];
    _leftTabContentView = nil;
    [_centerTabContentView removeFromSuperview];
    _centerTabContentView = nil;
    [_rightTabContentView removeFromSuperview];
    _rightTabContentView = nil;
    
    NSUInteger numberOfViews = [_dataSource numberOfViewsInTabView:self];
    
    NSString *desc = [NSString stringWithFormat:@"Index %lu is not a valid index", (unsigned long)index];
    NSAssert(index < numberOfViews, desc);
    
    _currentIndex = (int)index;
    [self updatePageControl];
    
    CGFloat widthFactor = kWidthFactorPortrait;
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        widthFactor = kWidthFactorLandscape;
    
    // initialize center view
    UIView *contentView = [_dataSource tabView:self viewForIndex:index];
    CGRect contentViewFrame = contentView.frame;
    // TODO: refactor this code
    CGRect temp = CGRectMake(contentViewFrame.origin.x + index * widthFactor * self.bounds.size.width, 0, contentViewFrame.size.width, contentViewFrame.size.height);
    _centerTabContentView = [[MOTabContentView alloc] initWithFrame:temp];
    
    _centerTabContentView.delegate = self;
    _centerTabContentView.contentView = contentView;
    [_scrollView addSubview:_centerTabContentView];
    [self updateTitles];
    
    // initialize left view
    _leftTabContentView = [self tabContentViewAtIndex:(NSInteger)index-1
                                        withReuseView:_leftTabContentView];
    
    // initialize right view
    _rightTabContentView = [self tabContentViewAtIndex:(NSInteger)index+1
                                         withReuseView:_rightTabContentView];
    
    CGPoint contentOffset = CGPointMake(index * widthFactor * self.bounds.size.width, 0);
    _scrollView.contentOffset = contentOffset;
    
    [_centerTabContentView selectAnimated:animated];
}

- (void)storeReusableView:(UIView *)contentView {
    
    if (_reusableContentViews.count < 3) {
        [_reusableContentViews addObject:contentView];
    }
}

- (UIView *)reusableView {
    
    UIView *reusableView = nil;
    if (_reusableContentViews.count > 0) {
        reusableView = [_reusableContentViews objectAtIndex:0];
        [_reusableContentViews removeObjectAtIndex:0];
    }
    return reusableView;
}


@end
