//
//  ViewController.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "ViewController.h"
#import "VideoViewController.h"
#import "AudioViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (IBAction)videoBtnAct:(id)sender {
    [self.navigationController pushViewController:[VideoViewController new] animated:YES];
}

- (IBAction)audioBtnAct:(id)sender {
    [self.navigationController pushViewController:[AudioViewController new] animated:YES];
}

@end
