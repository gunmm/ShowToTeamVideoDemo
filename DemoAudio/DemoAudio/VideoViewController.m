//
//  VideoViewController.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "VideoViewController.h"
#import "VideoManager.h"

@interface VideoViewController () <VideoManagerDelegate>

@property (nonatomic, strong) VideoManager *videoManager;

@end

@implementation VideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.videoManager = [[VideoManager alloc] initWithBgView:self.view];
    self.videoManager.delegate = self;
    
}

- (IBAction)beginBtnAct:(id)sender {
    
    [self.videoManager startSession];
}

#pragma mark -- VideoManagerDelegate

- (void)didOutputSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    NSLog(@"====== width:%zu height:%zu", width, height);
}


@end
