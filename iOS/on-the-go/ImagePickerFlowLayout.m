//
//  ImagePickerFlowLayout.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ImagePickerFlowLayout.h"

@implementation ImagePickerFlowLayout

-(UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [super layoutAttributesForItemAtIndexPath:indexPath];
}

-(UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewLayoutAttributes *attr = [super layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
    
    return attr;
    
}

-(UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

-(NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray *layoutAttributes = [[super layoutAttributesForElementsInRect:rect] mutableCopy];
    
    UICollectionViewLayoutAttributes *headerAttributes = [[layoutAttributes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"representedElementKind = %@", UICollectionElementKindSectionHeader]] lastObject];
    if (!headerAttributes) {
        headerAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathWithIndex:0]];
        [layoutAttributes addObject:headerAttributes];
    }
    CGRect cvBounds = self.collectionView.bounds;
    CGSize headerSize = headerAttributes.size;
    headerAttributes.center = CGPointMake(CGRectGetMinX(cvBounds)+headerSize.width/2.0, headerSize.height/2.0);
    headerAttributes.zIndex = 1000;
    return layoutAttributes;
}

-(BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

@end
