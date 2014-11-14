/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import <CoreGraphics/CoreGraphics.h>

#import "KalGridView.h"
#import "KalView.h"
#import "KalMonthView.h"
#import "KalTileView.h"
#import "KalLogic.h"
#import "KalPrivate.h"

#define SLIDE_NONE 0
#define SLIDE_UP 1
#define SLIDE_DOWN 2

const CGSize kTileSize = { 46.f, 48.f };

static NSString *kSlideAnimationId = @"KalSwitchMonths";

@interface KalGridView ()

@property (nonatomic, strong) NSMutableArray *rangeTiles;

- (void)swapMonthViews;

@end

@implementation KalGridView
{
    BOOL _needRemoveRanges;
}

- (void)setBeginDate:(NSDate *)beginDate
{
    KalTileView *preTile = [frontMonthView tileForDate:_beginDate];
    preTile.state = KalTileStateNone;
    _beginDate = beginDate;
    KalTileView *currentTile = [frontMonthView tileForDate:_beginDate];
    currentTile.state = KalTileStateSelected;
    [self removeRanges];
    self.endDate = nil;
}

- (void)setEndDate:(NSDate *)endDate
{
    KalTileView *beginTile = [frontMonthView tileForDate:self.beginDate];
    
    KalTileView *preTile = [frontMonthView tileForDate:_endDate];
    preTile.state = KalTileStateNone;
    beginTile.state = KalTileStateSelected;
    _endDate = endDate;
    
    KalTileView *currentTile = [frontMonthView tileForDate:_endDate];
    
    NSDate *realBeginDate;
    NSDate *realEndDate;
    
    [self removeRanges];
    
    if (!_endDate || [_endDate isEqualToDate:self.beginDate]) {
        return;
        
    } else if ([self.beginDate compare:self.endDate] == NSOrderedAscending) {
        realBeginDate = self.beginDate;
        realEndDate = self.endDate;
        beginTile.state = KalTileStateLeftEnd;
        currentTile.state = KalTileStateRightEnd;
    } else {
        realBeginDate = self.endDate;
        realEndDate = self.beginDate;
        beginTile.state = KalTileStateRightEnd;
        currentTile.state = KalTileStateLeftEnd;
    }
    
    NSInteger dayCount = [NSDate dayBetweenStartDate:realBeginDate endDate:realEndDate];
    for (int i=1; i<dayCount; i++) {
        NSDate *nextDay = [realBeginDate offsetDay:i];
        KalTileView *nextTile = [frontMonthView tileForDate:nextDay];
        if (nextTile) {
            nextTile.state = KalTileStateInRange;
            [self.rangeTiles addObject:nextTile];
        }
    }
}

- (void)removeRanges
{
    if (_needRemoveRanges) {
        for (KalTileView *tile in self.rangeTiles) {
            tile.state = KalTileStateNone;
        }
        [self.rangeTiles removeAllObjects];
    }
}

- (id)initWithFrame:(CGRect)frame logic:(KalLogic *)theLogic delegate:(id<KalViewDelegate>)theDelegate
{
    // MobileCal uses 46px wide tiles, with a 2px inner stroke
    // along the top and right edges. Since there are 7 columns,
    // the width needs to be 46*7 (322px). But the iPhone's screen
    // is only 320px wide, so we need to make the
    // frame extend just beyond the right edge of the screen
    // to accomodate all 7 columns. The 7th day's 2px inner stroke
    // will be clipped off the screen, but that's fine because
    // MobileCal does the same thing.
    frame.size.width = 7 * kTileSize.width;
    
    if (self = [super initWithFrame:frame]) {
        _needRemoveRanges = YES;
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor whiteColor];
        logic = theLogic;
        delegate = theDelegate;
        
        CGRect monthRect = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height);
        frontMonthView = [[KalMonthView alloc] initWithFrame:monthRect];
        backMonthView = [[KalMonthView alloc] initWithFrame:monthRect];
        backMonthView.hidden = YES;
        [self addSubview:backMonthView];
        [self addSubview:frontMonthView];
        
        self.selectionMode = KalSelectionModeSingle;
        _rangeTiles = [[NSMutableArray alloc] init];
        
        [self jumpToSelectedMonth];
    }
    return self;
}

- (void)sizeToFit
{
    self.height = frontMonthView.height;
}

#pragma mark -
#pragma mark Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    UIView *hitView = [self hitTest:location withEvent:event];
    
    if (!hitView)
        return;
    
    if ([hitView isKindOfClass:[KalTileView class]]) {
        KalTileView *tile = (KalTileView*)hitView;
        if (tile.type & KalTileTypeDisable)
            return;
        
        NSDate *date = tile.date;
        if ([date isEqualToDate:self.beginDate]) {
            if (self.selectionMode == KalSelectionModeSingle) return;

            date = self.beginDate;
            _beginDate = _endDate;
            _endDate = date;
        } else if ([date isEqualToDate:self.endDate]) {
            
        } else {
            self.beginDate = date;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.selectionMode == KalSelectionModeSingle)
        return;
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    UIView *hitView = [self hitTest:location withEvent:event];
    
    if (!hitView)
        return;
    
    if ([hitView isKindOfClass:[KalTileView class]]) {
        KalTileView *tile = (KalTileView*)hitView;
        if (tile.type & KalTileTypeDisable)
            return;
        
        NSDate *endDate = tile.date;
        if ([endDate isEqualToDate:self.beginDate]) {
            self.endDate = nil;
            return;
        }
        if (!endDate || [endDate isEqualToDate:self.endDate]) {
            return;
        }

        if (tile.isFirst || tile.isLast) {
            if ([tile.date compare:logic.baseDate] == NSOrderedDescending) {
                [delegate showFollowingMonth];
            } else {
                [delegate showPreviousMonth];
            }
        }
        self.endDate = endDate;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    UIView *hitView = [self hitTest:location withEvent:event];
    
    if ([hitView isKindOfClass:[KalTileView class]]) {
        KalTileView *tile = (KalTileView*)hitView;
        if (tile.type & KalTileTypeDisable)
            return;
        
        if ((self.selectionMode == KalSelectionModeSingle && tile.belongsToAdjacentMonth) ||
            (self.selectionMode == KalSelectionModeRange && (tile.isFirst || tile.isLast))) {
            if ([tile.date compare:logic.baseDate] == NSOrderedDescending) {
                [delegate showFollowingMonth];
            } else {
                [delegate showPreviousMonth];
            }
        }
        if (self.selectionMode == KalSelectionModeRange) {
            NSDate *endDate = tile.date;
            if ([tile.date isEqualToDate:self.beginDate]) {
//                if ([[endDate offsetDay:1] compare:self.maxAVailableDate] == NSOrderedDescending) {
//                    endDate = [endDate offsetDay:-1];
//                } else {
//                    endDate = [endDate offsetDay:1];
//                }
                [self removeRanges];
            }
            self.endDate = endDate;
            
            NSDate *realBeginDate = self.beginDate;
            NSDate *realEndDate = self.endDate;
            if ([self.beginDate compare:self.endDate] == NSOrderedDescending) {
                realBeginDate = self.endDate;
                realEndDate = self.beginDate;
            }
            if ([(id)delegate respondsToSelector:@selector(didSelectBeginDate:endDate:)]) {
                [delegate didSelectBeginDate:realBeginDate endDate:realEndDate];
            }
        } else {
            if ([(id)delegate respondsToSelector:@selector(didSelectDate:)]) {
                [delegate didSelectDate:self.beginDate];
            }
        }
    }
}

#pragma mark -
#pragma mark Slide Animation

- (void)swapMonthsAndSlide:(int)direction keepOneRow:(BOOL)keepOneRow
{
    backMonthView.hidden = NO;
    
    // set initial positions before the slide
    if (direction == SLIDE_UP) {
        backMonthView.top = keepOneRow
        ? frontMonthView.bottom - kTileSize.height
        : frontMonthView.bottom;
    } else if (direction == SLIDE_DOWN) {
        NSUInteger numWeeksToKeep = keepOneRow ? 1 : 0;
        NSInteger numWeeksToSlide = [backMonthView numWeeks] - numWeeksToKeep;
        backMonthView.top = -numWeeksToSlide * kTileSize.height;
    } else {
        backMonthView.top = 0.f;
    }
    
    // trigger the slide animation
    [UIView beginAnimations:kSlideAnimationId context:NULL]; {
        [UIView setAnimationsEnabled:direction!=SLIDE_NONE];
        [UIView setAnimationDuration:0.5];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
        
        frontMonthView.top = -backMonthView.top;
        backMonthView.top = 0.f;
        
        frontMonthView.alpha = 0.f;
        backMonthView.alpha = 1.f;
        
        self.height = backMonthView.height;
        
        [self swapMonthViews];
    } [UIView commitAnimations];
    [UIView setAnimationsEnabled:YES];
}

- (void)slide:(int)direction
{
    self.transitioning = YES;
    
    [backMonthView showDates:logic.daysInSelectedMonth
        leadingAdjacentDates:logic.daysInFinalWeekOfPreviousMonth
       trailingAdjacentDates:logic.daysInFirstWeekOfFollowingMonth
            minAvailableDate:self.minAvailableDate
            maxAvailableDate:self.maxAVailableDate];
    
    // At this point, the calendar logic has already been advanced or retreated to the
    // following/previous month, so in order to determine whether there are
    // any cells to keep, we need to check for a partial week in the month
    // that is sliding offscreen.
    
    BOOL keepOneRow = (direction == SLIDE_UP && [logic.daysInFinalWeekOfPreviousMonth count] > 0)
    || (direction == SLIDE_DOWN && [logic.daysInFirstWeekOfFollowingMonth count] > 0);
    
    [self swapMonthsAndSlide:direction keepOneRow:keepOneRow];
    
    if (self.selectionMode == KalSelectionModeSingle) {
        self.beginDate = _beginDate;
    } else {
        _needRemoveRanges = NO;
        self.endDate = _endDate;
        _needRemoveRanges = YES;
    }
}

- (void)slideUp { [self slide:SLIDE_UP]; }
- (void)slideDown { [self slide:SLIDE_DOWN]; }

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
    self.transitioning = NO;
    backMonthView.hidden = YES;
}

#pragma mark -

- (void)swapMonthViews
{
    KalMonthView *tmp = backMonthView;
    backMonthView = frontMonthView;
    frontMonthView = tmp;
    [self exchangeSubviewAtIndex:[self.subviews indexOfObject:frontMonthView] withSubviewAtIndex:[self.subviews indexOfObject:backMonthView]];
}

- (void)jumpToSelectedMonth
{
    [self slide:SLIDE_NONE];
}

- (void)markTilesForDates:(NSArray *)dates { [frontMonthView markTilesForDates:dates]; }

#pragma mark -


@end
