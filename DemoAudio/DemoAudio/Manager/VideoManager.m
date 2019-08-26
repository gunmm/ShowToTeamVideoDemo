//
//  VideoManager.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "VideoManager.h"

@interface VideoManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *captureAudioOutput;

@property (nonatomic, strong) UIView *bgView;

@end

@implementation VideoManager

- (instancetype)initWithBgView:(UIView *)bgView {
    if (self = [super init]) {
        self.bgView = bgView;
        [self configManager];
    }
    return self;
}

- (void)configManager {
    
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
    
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = nil;
    AVCaptureDeviceDiscoverySession *deviceDiscoverySession =  [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    devices = deviceDiscoverySession.devices;
    if (devices.count > 0) {
        inputCamera = [devices lastObject];
    }
    
    AVCaptureDeviceInput *captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    [self.captureSession addInput:captureDeviceInput];
    
    
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoDataOutput = videoDataOutput;
    [self.captureSession addOutput:videoDataOutput];
    videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
                                                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    AVCaptureConnection *connection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    dispatch_queue_t videoQueue = dispatch_queue_create("videoQueue", NULL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoQueue];
    
    // 视频
    AVCaptureVideoPreviewLayer *mPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [mPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspect]; //设置预览时的视频缩放方式
    [mPreviewLayer setFrame:self.bgView.bounds];
    [self.bgView.layer addSublayer:mPreviewLayer];
    
//    // 获取麦克风设备
//    AVCaptureDevice *audioDevice = nil;
//    devices = nil;
//    deviceDiscoverySession =  [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
//    devices = deviceDiscoverySession.devices;
//    if (devices.count > 0) {
//        audioDevice = [devices lastObject];
//    }
//    
//    
//    // 把设备设置到输入设备，并添加到会话
//    AVCaptureDeviceInput *captureAudioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
//    [self.captureSession addInput:captureAudioDeviceInput];
//    
//    // 设置输出设备的参数，并把输出设备添加到会话
//    AVCaptureAudioDataOutput *captureAudioOutput = [[AVCaptureAudioDataOutput alloc] init];
//    [self.captureSession addOutput:captureAudioOutput];
//    dispatch_queue_t audiooQueue = dispatch_queue_create("audiooQueue", NULL);
//    [captureAudioOutput setSampleBufferDelegate:self queue:audiooQueue];
}

- (void)startSession {
    [self.captureSession startRunning];
}


#pragma mark ---AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output == self.videoDataOutput) {
        if ([self.delegate respondsToSelector:@selector(didOutputSampleBuffer:)]) {
            [self.delegate didOutputSampleBuffer:sampleBuffer];
        }
    } else {
        NSLog(@"-----  2 ******");
    }
    
}

@end
