//
//  ChooseYourDaysViewController.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/14/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ChooseYourDaysViewController.h"
#import "Kal.h"

@interface ChooseYourDaysViewController () <UITableViewDelegate>

@end

@implementation ChooseYourDaysViewController {
    __weak KalViewController *_calendar;
    id _dataSource;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[KalViewController class]]) {
        _calendar = segue.destinationViewController;
        [_calendar setSelectionMode:KalSelectionModeRange];
        _calendar.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Today", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(showAndSelectToday)];
 //       _calendar.delegate = self;
//        _dataSource = [[EventKitDataSource alloc] init];
        _calendar.dataSource = _dataSource;
    }
}

#pragma mark UITableViewDelegate protocol conformance

//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    // Display a details screen for the selected event/row.
//    EKEventViewController *vc = [[EKEventViewController alloc] init];
//    vc.event = [dataSource eventAtIndexPath:indexPath];
//    vc.allowsEditing = NO;
//    [navController pushViewController:vc animated:YES];
//}

#pragma mark -

@end
