//
//  ImagePickerTableViewCell.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/17/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ImagePickerTableViewCell.h"
#import "UIImageView+Additions.h"

@import Photos;

@interface ImagePickerTableViewCell () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong) PHCachingImageManager *cachingManager;

@end

@implementation ImagePickerTableViewCell

-(void)setAssets:(NSArray *)assets {
    _assets = assets;
    [self.collectionView reloadData];
    [self.cachingManager startCachingImagesForAssets:_assets targetSize:CGSizeMake(80, 80) contentMode:PHImageContentModeAspectFit options:nil];
}

-(void)prepareForReuse {
    [super prepareForReuse];
    [self setAssets:nil];
    [self.collectionView reloadData];
    [self.cachingManager stopCachingImagesForAllAssets];
}

- (void)awakeFromNib {
    // Initialization code
    self.cachingManager = [PHCachingImageManager new];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
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
    return self.assets.count;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    UIImageView *imgView = (UIImageView *)[cell viewWithTag:1];
    [imgView setImage:nil];
    PHAsset *asset = self.assets[indexPath.row];
    [self.cachingManager requestImageForAsset:asset targetSize:CGSizeMake(80, 80) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
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
    PHAsset *asset = [self.assets firstObject];
    titleLabel.attributedText = [self headerDayStringForDate:asset.creationDate];
    return header;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 3;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section; {
    return UIEdgeInsetsMake(0, 3, 0, 3);
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(78, 78);
}


@end
