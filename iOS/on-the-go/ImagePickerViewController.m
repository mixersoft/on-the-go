//
//  ImagePickerViewController.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/17/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ImagePickerViewController.h"
#import "ImagePickerTableViewCell.h"
#import "PhotosSource.h"

@import Photos;


@interface ImagePickerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;



@end

@implementation ImagePickerViewController {
    PhotosSource *_source;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView setRowHeight:80];
    _source = [PhotosSource sharedInstance];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UITableView

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count = [_source numberOfCollections];
    return count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger count = [_source numberOfMomentsInCollectionAtIndex:section];
    return count;
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PHFetchResult *assets = [_source assetsForIndexPath:indexPath];
    ImagePickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    [cell setAssets:assets];
    [cell setDate:[assets.firstObject creationDate]];
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 50;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    PHCollectionList *list = [_source collectionListAtIndex:section];
    return list.localizedTitle;
}

@end
