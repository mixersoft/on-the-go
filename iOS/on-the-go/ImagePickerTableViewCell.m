//
//  ImagePickerTableViewCell.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/17/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ImagePickerTableViewCell.h"
#import "UIImageView+Additions.h"
#import "ImagePickerFlowLayout.h"

static CGFloat heigh = 80.0;

@import Photos;

@interface ImagePickerTableViewCell () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *descriptionLabelTopConstraint;
@property (weak, nonatomic) IBOutlet UIView *descriptionView;
@property (nonatomic, strong) NSMutableArray *collectionViews;
@end

@implementation ImagePickerTableViewCell {
}

-(void)awakeFromNib {
    self.collectionViews = [NSMutableArray new];
}

-(void)setOffsetToTableView:(CGFloat)offsetToTableView {
    _offsetToTableView = offsetToTableView;
    self.descriptionLabelTopConstraint.constant = offsetToTableView;
    [self.descriptionView layoutIfNeeded];
}

-(void)setAssets:(NSArray *)assets {
    UINib *nib = [UINib nibWithNibName:@"ImagePickerCell" bundle:nil];
    _assets = assets;
    
    [assets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ImagePickerFlowLayout *layout = [ImagePickerFlowLayout new];
        [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
        UICollectionView *v = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        [v setDelegate:(id<UICollectionViewDelegate>)self];
        [v setDataSource:(id<UICollectionViewDataSource>)self];
        [v setTag:idx];
        [v setTranslatesAutoresizingMaskIntoConstraints:NO];
        [v registerNib:nib forCellWithReuseIdentifier:@"Cell"];
        [v setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
        [self.contentView addSubview:v];
        [self.collectionViews addObject:v];
    }];
    
    NSDictionary *metrics = @{@"height":@(heigh)};

    NSMutableDictionary *views = [NSMutableDictionary new];
    NSMutableString *verticalConstraint = [NSMutableString stringWithString:@"V:|"];
    
    [self.collectionViews enumerateObjectsUsingBlock:^(UICollectionView *obj, NSUInteger idx, BOOL *stop) {
        [views setObject:obj forKey:[NSString stringWithFormat:@"view%d", obj.tag]];
        NSString *horizontalConstraint = [NSString stringWithFormat:@"H:|-height-[view%d]-0-|", obj.tag];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalConstraint options:0 metrics:metrics views:views]];
        [verticalConstraint appendFormat:@"-0-[view%d(height)]", obj.tag];
        
        [obj reloadData];
        [obj.collectionViewLayout invalidateLayout];
        PHFetchResult *result = _assets[idx];
        if (result.count) {
            [obj scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
        }
    }];
    
    [verticalConstraint appendString:@"-0-|"];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:verticalConstraint options:0 metrics:metrics views:views]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)prepareForReuse {
    [super prepareForReuse];
    [self.collectionViews enumerateObjectsUsingBlock:^(UICollectionView *obj, NSUInteger idx, BOOL *stop) {
        [self removeConstraints:obj.constraints];
        [obj removeFromSuperview];
    }];
    [self.collectionViews removeAllObjects];
}

-(NSAttributedString *)headerDayStringForDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setDateFormat:@"dd MMM\nEEE"];
    });
    
    NSString *dateFormat = [formatter stringFromDate:date];
    int index = (int)[dateFormat rangeOfString:@"\n"].location+1;
    
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:dateFormat];
    [str setAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName:[UIColor whiteColor]} range:NSMakeRange(index, str.length-index)];
    return str;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger idx = collectionView.tag;
    return [self.assets[idx] count];
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    UIImageView *imgView = (UIImageView *)[cell viewWithTag:1];
    [imgView setImage:nil];
    NSInteger idx = collectionView.tag;
    PHAsset *asset = _assets[idx][indexPath.row];
    CGFloat side = 80 * [UIScreen.mainScreen scale];
    [PHImageManager.defaultManager requestImageForAsset:asset targetSize:CGSizeMake(side, side) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        [imgView setImage:result];
    }];
    
    return cell;
}

-(UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind != UICollectionElementKindSectionHeader) {
        return nil;
    }
    
    UICollectionReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"Header" forIndexPath:indexPath];
    UILabel *titleLabel = (UILabel *)[header viewWithTag:1];
    titleLabel.attributedText = [self headerDayStringForDate:self.date];
    return header;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 3;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section; {
    return UIEdgeInsetsMake(0, 3, 0, 3);
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(heigh-2, heigh-2);
}


@end
