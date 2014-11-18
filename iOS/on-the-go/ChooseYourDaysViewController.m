//
//  ChooseYourDaysViewController.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/14/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "ChooseYourDaysViewController.h"
#import "Kal.h"
#import "ImagePickerViewController.h"

@interface ChooseYourDaysViewController () <UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *calendarPlaceholderView;
@property (weak, nonatomic) IBOutlet UIView *imagePickerPlaceholderView;
@property (assign, nonatomic) UIView *selectedPlaceholder;
@end

@implementation ChooseYourDaysViewController {
    __weak KalViewController *_calendar;
    __weak KalViewController *_imagePicker;
    
    id _dataSource;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectedPlaceholder = self.imagePickerPlaceholderView;
    
    // Do any additional setup after loading the view.
}

-(void)setSelectedPlaceholder:(UIView *)selectedPlaceholder {
    if (_selectedPlaceholder == selectedPlaceholder)
        return;
    
    _selectedPlaceholder = selectedPlaceholder;
    [self.calendarPlaceholderView setHidden:_selectedPlaceholder!=self.calendarPlaceholderView];
    [self.imagePickerPlaceholderView setHidden:_selectedPlaceholder!=self.imagePickerPlaceholderView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cameraRowAction:(id)sender {
    [self setSelectedPlaceholder:self.imagePickerPlaceholderView];
    
}

- (IBAction)calendarAction:(id)sender {
    [self setSelectedPlaceholder:self.calendarPlaceholderView];
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
    else if([segue.destinationViewController isKindOfClass:[ImagePickerViewController class]]) {
        _imagePicker = segue.destinationViewController;
    }
}

-(void)showAndSelectToday {
    [_calendar showAndSelectDate:[NSDate new]];
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
