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
@property (nonatomic, strong) NSMutableArray *collections;
@property (nonatomic, strong) NSMutableArray *collectionTitles;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@end

@implementation ImagePickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView setRowHeight:80];
    self.collections = nil;
    self.collectionTitles = nil;
    
    void (^block)(void) = ^{
        PHFetchOptions *options = [PHFetchOptions new];
        [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]]];
        PHFetchResult * collections = [PHCollectionList fetchMomentListsWithSubtype:PHCollectionListSubtypeMomentListCluster options:options];
        self.collections = [NSMutableArray arrayWithCapacity:collections.count];
        self.collectionTitles = [NSMutableArray arrayWithCapacity:collections.count];
        
        for (PHCollectionList * collection in collections) {
            NSMutableArray *momentAssets = [NSMutableArray new];
            PHFetchOptions *options = [PHFetchOptions new];
            [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]]];
            PHFetchResult * momentsInCollection = [PHCollection fetchCollectionsInCollectionList:collection options:options];
            
            [momentsInCollection enumerateObjectsUsingBlock:^(PHAssetCollection * obj, NSUInteger idx, BOOL *stop) {
               
                PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:obj options:nil];
                [momentAssets addObject:result];
            }];
            [self.collections addObject:momentAssets];
            [self.collectionTitles addObject:collection.localizedTitle?:@""];
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
    return self.collections.count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.collections[section] count];
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PHFetchResult *moment = self.collections[indexPath.section][indexPath.row];
    ImagePickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    [cell setAssets:moment];
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 50;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.collectionTitles[section];
}

@end
