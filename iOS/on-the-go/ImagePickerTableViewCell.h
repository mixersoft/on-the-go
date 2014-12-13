//
//  ImagePickerTableViewCell.h
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/17/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <UIKit/UIKit.h>
@class PHFetchResult;
@interface ImagePickerTableViewCell : UITableViewCell

@property (nonatomic, strong) PHFetchResult *assets;
@property (nonatomic, strong) NSDate *date;

@end
