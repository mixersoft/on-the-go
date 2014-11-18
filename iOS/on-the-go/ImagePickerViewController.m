//
//  ImagePickerViewController.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/17/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ImagePickerViewController.h"
#import "ImagePickerTableViewCell.h"

@import Photos;


@interface ImagePickerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSMutableArray *moments;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@end

@implementation ImagePickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView setContentInset:UIEdgeInsetsMake(16, 0, 16, 0)];
    self.moments = nil;
    
    void (^block)(void) = ^{
        PHFetchResult * allMoments = [PHAssetCollection fetchMomentsWithOptions:nil];
        self.moments = [NSMutableArray arrayWithCapacity:allMoments.count];
        for (PHAssetCollection * moment in allMoments) {
            NSMutableArray *momentAssets = [NSMutableArray new];
            PHFetchOptions *options = [PHFetchOptions new];
            [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]]];
            PHFetchResult * assetsFetchResults = [PHAsset fetchAssetsInAssetCollection:moment options:options];
            __block NSDate *currentDateFromComponents = nil;
            [assetsFetchResults enumerateObjectsUsingBlock:^(PHAsset *obj, NSUInteger idx, BOOL *stop) {
                if (!currentDateFromComponents) {
                    NSDateComponents *currentComponents = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:[obj creationDate]];
                    currentDateFromComponents = [NSCalendar.currentCalendar dateFromComponents:currentComponents];
                    [momentAssets addObject:[NSMutableArray arrayWithObject:obj]];
                    return;
                }
                NSDate * assetDate = obj.creationDate;
                NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:assetDate];
                NSComparisonResult result = [[NSCalendar.currentCalendar dateFromComponents:components]
                                             compare:currentDateFromComponents];
                if (result == NSOrderedSame) {
                    //
                    [[momentAssets lastObject] addObject:obj];
                }
                else {
                    NSDateComponents *currentComponents = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:[obj creationDate]];
                    currentDateFromComponents = [NSCalendar.currentCalendar dateFromComponents:currentComponents];
                    [momentAssets addObject:[NSMutableArray arrayWithObject:obj]];
                }
            }];
            [self.moments addObject:momentAssets];
        }
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.tableView reloadData];
        }];
    };
    
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        switch (status) {
            case PHAuthorizationStatusAuthorized: {
                block();
                break;
            }
            case PHAuthorizationStatusRestricted:
                break;
            case PHAuthorizationStatusDenied:
                break;
            default:
                break;
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UITableView

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.moments.count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.moments[section] count];
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *assetsPerDay = self.moments[indexPath.section][indexPath.row];
    ImagePickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    [cell setAssets:assetsPerDay];
    return cell;
}

@end
