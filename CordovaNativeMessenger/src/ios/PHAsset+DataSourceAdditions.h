//
//  PHAsset+DataSourceAdditions.h
//  On-the-Go
//
//  Created by Dimitar Ostoich on 2/3/15.
//
//

#import <Photos/Photos.h>

@interface PHAsset (DataSourceAdditions)

+(void)fetchAssetsWithLocalIdentifiers:(NSArray *)assetIdentifiers includeBurstPhotos:(BOOL)includeBurstPhotos completion:(void(^)(PHFetchResult *result))result;

+(void)setFavorite:(BOOL)isFavorite forAsserIdentifier:(NSString *)identifier completion:(void(^)(BOOL success, NSError *error))completion;

@end
