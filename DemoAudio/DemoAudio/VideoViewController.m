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
        _streamInfo.url = @"rtmp://send3.douyu.com/live/5194892rsbWB5qU2?wsSecret=1118fe50ed8655f0a1f109f79447cb70&wsTime=5d6e2760&wsSeek=off&wm=0&tw=0&roirecognition=0";
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
    if (!self.canRecord) {
        return;
    }
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.videoCodeManager encodeVideoData:pixelBuffer timeStamp:CACurrentMediaTime()*1000];
    return;
    
    
    
    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    if (!ciimage) {
        return;
    }
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CGFloat widthScale = width/720.0;
    CGFloat heightScale = height/1280.0;
    CGFloat realWidthScale = 1;
    CGFloat realHeightScale = 1;
    
    if (widthScale > 1 || heightScale > 1) {
        if (widthScale < heightScale) {
            realHeightScale = 1280.0/height;
            CGFloat nowWidth = width * 1280 / height;
            height = 1280;
            realWidthScale = nowWidth/width;
            width = nowWidth;
        } else {
            realWidthScale = 720.0/width;
            CGFloat nowHeight = 720 * height / width;
            width = 720;
            realHeightScale = nowHeight/height;
            height = nowHeight;
        }
    }
   
    CIContext *_ciContext = [CIContext contextWithOptions:nil];
    {
        CIImage *newImage = [ciimage imageByApplyingTransform:CGAffineTransformMakeScale(realWidthScale, realHeightScale)];
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRef newPixcelBuffer = nil;
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &newPixcelBuffer);
        if (newPixcelBuffer && newImage) {
            UIImage *sourceImage = [UIImage imageWithCIImage:newImage];
            UIFont *font = [UIFont fontWithName:@"Helvetica" size:20];
            CGSize size = CGSizeMake(50, 100);
            NSDictionary *attributes = @{NSFontAttributeName: font,
                                         NSForegroundColorAttributeName: [UIColor redColor]};
            UIGraphicsBeginImageContextWithOptions(size, NO, 0);
            [sourceImage drawInRect:CGRectMake(0, 0, sourceImage.size.width, sourceImage.size.height)];
//            [@"minzheminzheminzheminzheminzheminzheminzheminzheminzheminzheminzheminzhe" drawAtPoint:CGPointMake(size.width/2, size.height/2) withAttributes:attributes];
            [@"minzheminzheminzheminzheminzheminzheminzheminzheminzheminzheminzheminzhe" drawInRect:CGRectMake(0, 0, 500, 30) withAttributes:attributes];
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSLog(@"1---------  %@", [NSValue valueWithCGSize:size]);
            
            CIImage *filteredImage = [[CIImage alloc] initWithCGImage:image.CGImage];
            [_ciContext render:filteredImage toCVPixelBuffer:newPixcelBuffer bounds:[filteredImage extent] colorSpace:CGColorSpaceCreateDeviceRGB()];
            //                [_ciContext render:newImage toCVPixelBuffer:newPixcelBuffer];
            
            
            NSLog(@"2---------  %@", [NSValue valueWithCGSize:size]);
            
            [self.videoCodeManager encodeVideoData:newPixcelBuffer timeStamp:CACurrentMediaTime()*1000];
            NSLog(@"3---------  %@", [NSValue valueWithCGSize:size]);
            
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(newPixcelBuffer);
    }
    
    
    
}

#pragma mark -- AudioManagerDelegate

- (void)audioOutputData:(void* __nullable)mData mDataByteSize:(UInt32)mDataByteSize {
    if (self.canRecord) {
        [self.audioCodeManager encodeAudioWithSourceBuffer:mData sourceBufferSize:mDataByteSize];
    }
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
