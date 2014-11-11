//
//  RootViewController.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/11/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "RootViewController.h"
#import "CordovaViewController.h"

@interface RootViewController ()

@end

@implementation RootViewController

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
    if ([segue.identifier isEqualToString:@"TopPicksSegue"]) {
        CordovaViewController *c = segue.destinationViewController;
//        [c setWwwFolderName:@"www/views"];
//        [c setStartPage:@"top-picks.html"];
        [c setWwwFolderName:@"www"];
        [c setStartPage:@"index.html"];
    }
}

@end
