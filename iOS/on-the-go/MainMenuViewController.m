//
//  MainMenuViewController.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "MainMenuViewController.h"
#import "CordovaViewController.h"

NSString *cordovaPages[] = {@"top-picks",@"choose/camera-roll", @"orders", @"uploader", @"settings", @"help"};
NSString *tableViewRowNames[] = {@"Top Picks",@"Choose Your Days",@"My Orders",@"Uploader",@"Settings",@"Help",};

typedef NS_ENUM(uint8_t, CordovaPage) {
    CordovaPageTopPicks,
};

@interface MainMenuViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation MainMenuViewController

-(void)drawerContainerViewDidLoad {
    [super drawerContainerViewDidLoad];
    [self performSegueWithIdentifier:@"CordovaViewControllerSegue" sender:@(CordovaPageTopPicks)];
}


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (![sender isKindOfClass:[NSIndexPath class]])
        return;
    
    CordovaPage page = [sender integerValue];
    static NSString *urlBasePath = @"index.html#/app/";
    NSString *path = [urlBasePath stringByAppendingPathComponent:cordovaPages[page]];
    
    CordovaViewController *cordova = [segue destinationViewController];
    [cordova setWwwFolderName:@"www"];
    [cordova setStartPage:path];
    
    [cordova setTitle:tableViewRowNames[page]];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 6;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.textLabel.text = tableViewRowNames[indexPath.row];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 1) {
        [self performSegueWithIdentifier:@"ChooseYourDaysSegue" sender:self];
        return;
    }
    
    [self performSegueWithIdentifier:@"CordovaViewControllerSegue" sender:@(indexPath.row)];
}

@end
