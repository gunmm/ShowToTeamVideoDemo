//
//  VideoViewController.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "VideoViewController.h"
#import "VideoManager.h"
#import "VideoCodeManager.h"
#import "LFStreamRTMPSocket.h"

@interface VideoViewController () <VideoManagerDelegate, VideoCodeManagerDelegate, LFStreamSocketDelegate>

@property (nonatomic, strong) VideoManager *videoManager;
@property (nonatomic, strong) VideoCodeManager *videoCodeManager;

@property (nonatomic, strong) id<LFStreamSocket> socket;
@property (nonatomic, strong) LFLiveStreamInfo *streamInfo;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) uint64_t relativeTimestamps;

@property (nonatomic, assign) BOOL canRecord;

@end

@implementation VideoViewController

- (LFLiveStreamInfo *)streamInfo {
    if (!_streamInfo) {
        _streamInfo = [[LFLiveStreamInfo alloc] init];
        _streamInfo.url = @"rtmp://send3.douyu.com/live/5194892ra0rVKqis?wsSecret=f99dd51a41baff075d2af9a36f24f9de&wsTime=5d5bc21e&wsSeek=off&wm=0&tw=0&roirecognition=0";
    }
    
    return _streamInfo;
}

- (id<LFStreamSocket>)socket {
    if (!_socket) {
        _socket = [[LFStreamRTMPSocket alloc] initWithStream:self.streamInfo reconnectInterval:0 reconnectCount:0];
        [_socket setDelegate:self];
    }
    return _socket;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.videoManager = [[VideoManager alloc] initWithBgView:self.view];
    self.videoManager.delegate = self;
    
    self.videoCodeManager = [[VideoCodeManager alloc] init];
    self.videoCodeManager.delegate = self;
//    [self.socket start];
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
    [self.videoCodeManager encodeVideoData:pixelBuffer timeStamp:CACurrentMediaTime()*1000];
}

#pragma mark -- VideoCodeManagerDelegate

- (void)receiveVideoEncoderData:(LFFrame *)frame {
    if (self.canRecord) {
        if(self.relativeTimestamps == 0){
            self.relativeTimestamps = frame.timestamp;
        }
        frame.timestamp = [self uploadTimestamp:frame.timestamp];
        [self.socket sendFrame:frame];
    }
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status {
    NSLog(@"--------%lu", status);
    if (status == LFLiveStart) {
        self.canRecord = YES;
    } else {
        self.canRecord = NO;
    }
}

@end
