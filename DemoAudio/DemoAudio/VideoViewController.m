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

#import "AudioManager.h"
#import "AudioCodeManager.h"

@interface VideoViewController () <VideoManagerDelegate, VideoCodeManagerDelegate, LFStreamSocketDelegate, AudioManagerDelegate, AudioCodeManagerDelegate>

@property (nonatomic, strong) VideoManager *videoManager;
@property (nonatomic, strong) VideoCodeManager *videoCodeManager;

@property (nonatomic, strong) AudioManager *audioManager;
@property (nonatomic, strong) AudioCodeManager *audioCodeManager;

@property (nonatomic, strong) id<LFStreamSocket> socket;
@property (nonatomic, strong) LFLiveStreamInfo *streamInfo;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) uint64_t relativeTimestamps;

@property (nonatomic, assign) BOOL canRecord;

@property (nonatomic, strong) LFLiveAudioConfiguration *audioConfiguration;

@end

@implementation VideoViewController

- (LFLiveStreamInfo *)streamInfo {
    if (!_streamInfo) {
        _streamInfo = [[LFLiveStreamInfo alloc] init];
        _streamInfo.url = @"rtmp://send3.douyu.com/live/5194892rT0rZyuOR?wsSecret=0422abb54322396fbaf55a7f6c9a45d1&wsTime=5d6501f4&wsSeek=off&wm=0&tw=0&roirecognition=0";
    }
    
    return _streamInfo;
}

- (LFLiveAudioConfiguration *)audioConfiguration {
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfiguration];
    }
    return _audioConfiguration;
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
    
    self.audioManager = [[AudioManager alloc] init];
    self.audioManager.delegate = self;
    AudioStreamBasicDescription audioDataFormat = [self.audioManager getAudioDataFormat];

    self.audioCodeManager = [[AudioCodeManager alloc] initWithInputFormat:audioDataFormat];
    self.audioCodeManager.delegate = self;
    
    NSLog(@"");
    [self.socket start];
}

- (IBAction)beginBtnAct:(id)sender {
    [self.videoManager startSession];
    [self.audioManager startCapture];
}

#pragma mark -- VideoManagerDelegate

- (void)didOutputSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    NSLog(@"====== width:%zu height:%zu", width, height);
    [self.videoCodeManager encodeVideoData:pixelBuffer timeStamp:CACurrentMediaTime()*1000];
}

#pragma mark -- AudioManagerDelegate

- (void)audioOutputData:(void* __nullable)mData mDataByteSize:(UInt32)mDataByteSize {
    [self.audioCodeManager encodeAudioWithSourceBuffer:mData sourceBufferSize:mDataByteSize];
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

#pragma mark -- audioCodeManagerDelegate
- (void)audioOutputData:(LFAudioFrame *)frame {
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    char exeData[2];
    exeData[0] = self.audioConfiguration.asc[0];
    exeData[1] = self.audioConfiguration.asc[1];
    frame.audioInfo = [NSData dataWithBytes:exeData length:2];
    [self.socket sendFrame:frame];
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

/** callback buffer current status (回调当前缓冲区情况，可实现相关切换帧率 码率等策略)*/
- (void)socketBufferStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveBuffferState)status {
    
}

/** callback socket errorcode */
- (void)socketDidError:(nullable id <LFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode {
    
}

@end
