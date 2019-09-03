//
//  VideoCodeManager.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "VideoCodeManager.h"
#import <VideoToolbox/VideoToolbox.h>

@interface VideoCodeManager ()
{
    VTCompressionSessionRef compressionSession;
    NSInteger frameCount;
    NSData *sps;
    NSData *pps;
    FILE *fp;
    BOOL enabledWriteVideoFile;
}

@end

@implementation VideoCodeManager

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"IOSCamDemo.h264"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}

#pragma mark - Callback
static void EncodeCallBack(void *VTref, void *VTFrameRef, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    
    //判断是不是关键帧
    if (!sampleBuffer) return;
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) return;
    
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)VTFrameRef) longLongValue];
    
    VideoCodeManager *videoCodeManager = (__bridge VideoCodeManager *)VTref;
    if (status != noErr) {
        return;
    }
    
    if (keyframe && !videoCodeManager->sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                videoCodeManager->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                videoCodeManager->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
                if (videoCodeManager->enabledWriteVideoFile) {
                    [videoCodeManager initForFilePath];
                    
                    NSMutableData *data = [[NSMutableData alloc] init];
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                    [data appendData:videoCodeManager->sps];
                    [data appendBytes:header length:4];
                    [data appendData:videoCodeManager->pps];
                    fwrite(data.bytes, 1, data.length, videoCodeManager->fp);
                }
                
            }
        }
    }
    
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            LFVideoFrame *videoFrame = [LFVideoFrame new];
            videoFrame.timestamp = timeStamp;
            videoFrame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            videoFrame.isKeyFrame = keyframe;
            videoFrame.sps = videoCodeManager->sps;
            videoFrame.pps = videoCodeManager->pps;

            if ([videoCodeManager.delegate respondsToSelector:@selector(receiveVideoEncoderData:)]) {
                [videoCodeManager.delegate receiveVideoEncoderData:videoFrame];
            }
            
            
            if (videoCodeManager->enabledWriteVideoFile) {
                NSMutableData *data = [[NSMutableData alloc] init];
                if (keyframe) {
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                } else {
                    uint8_t header[] = {0x00, 0x00, 0x01};
                    [data appendBytes:header length:3];
                }
                [data appendData:[[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength]];
                
                fwrite(data.bytes, 1, data.length, videoCodeManager->fp);
            }
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}


- (instancetype)init {
    if (self = [super init]) {
        enabledWriteVideoFile = YES;
        [self configManager];
    }
    return self;
}

- (void)configManager {
    if (compressionSession) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
    
    OSStatus status = VTCompressionSessionCreate(NULL, 720, 1280, kCMVideoCodecType_H264, NULL, NULL, NULL, EncodeCallBack, (__bridge void *)self, &compressionSession);
    if (status != noErr) {
        return;
    }
    
    //关键帧之间的最大间隔
//  kVTCompressionPropertyKey_MaxKeyFrameInterval: 关键帧之间的最大间隔，以帧的数量为单位。关键帧，也称为I帧，重置帧间依赖关系;解码关键帧足以准备解码器以正确解码随后的差异帧。允许视频编码器更频繁地生成关键帧，如果这将导致更有效的压缩。默认关键帧间隔为0，表示视频编码器应选择放置所有关键帧的位置。关键帧间隔为1表示每帧必须是关键帧，2表示至少每隔一帧必须是关键帧等此键可以与
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(30 * 2));
//  kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 从一个关键帧到下一个关键帧的最长持续时间（秒）。默认为零,没有限制。当帧速率可变时，此属性特别有用。此键可以与kVTCompressionPropertyKey\_MaxKeyFrameInterval一起设置，并且将强制执行这两个限制 - 每X帧或每Y秒需要一个关键帧，以先到者为准。
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(2));
//  kVTCompressionPropertyKey_ExpectedFrameRate: 期望帧率,帧率以每秒钟接收的视频帧数量来衡量.此属性无法控制帧率而仅仅作为编码器编码的指示.以便在编码前设置内部配置.实际取决于视频帧的duration并且可能是不同的.默认是0,表示未知.
//  每秒显示帧数
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(30));
    
//  kVTCompressionPropertyKey_AverageBitRate: 长期编码的平均码率.此属性不是一个绝对设置,实际产生的码率可能高于此值.默认为0,表示编码器应该自行决定编码数据的大小.注意,码率设置仅在为原始帧提供定时信息时有效，并且某些编解码器不支持限制到指定的码率。
//  视频码率就是数据传输时单位时间传送的数据位数
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(1200 * 1000));
//  kVTCompressionPropertyKey_DataRateLimits: 可以选择两个以下的硬性限制对于码率.每个硬限制由以字节为单位的数据大小和以秒为单位的持续时间来描述，并要求该持续时间（在解码时间内）的任何连续段的压缩数据的总大小不得超过数据大小。默认情况下，不设置数据速率限制。该属性是偶数个CFNumber的CFArray，在字节和秒之间交替。请注意，数据速率设置仅在为原始帧提供定时信息时有效，并且某些编解码器不支持限制指定的数据速率。
    NSArray *limit = @[@(1200 * 1000 * 1.5/8), @(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
//   kVTCompressionPropertyKey_RealTime: 是否实时执行压缩.false表示视频编码器可以比实时更慢地工作，以产生更好的结果.设置为true可以更加及时的编码.默认为NULL,表示未知.
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
//  kVTCompressionPropertyKey_ProfileLevel: 指定编码比特流的配置文件和级别。可用的配置文件和级别因格式和视频编码器而异。视频编码器应该在可用的地方使用标准密钥，而不是标准模式。
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
//  kVTCompressionPropertyKey_AllowFrameReordering: 如果编码器开启B帧,则时间会乱序,编码器必须重新排序.默认为True,将其设置为false以防止帧重新排序.注意: iOS中一般不用相机采集B帧.
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
//  kVTCompressionPropertyKey_H264EntropyMode: H.264压缩的熵编码模式。如果H.264编码器支持，则此属性控制编码器是使用基于上下文的自适应可变长度编码（CAVLC）还是基于上下文的自适应二进制算术编码（CABAC）。CABAC通常以更高的计算开销为代价提供更好的压缩。默认值是编码器特定的，可能会根据其他编码器设置而改变。使用此属性时应小心 - 更改可能会导致配置与请求的配置文件和级别不兼容。这种情况下的结果是未定义的，可能包括编码错误或不符合要求的输出流。
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);
    
}

//编码
- (void)encodeVideoData:(CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp {
//    CMTime可是專門用來表示影片時間用的類別,
//    他的用法為: CMTimeMake(time, timeScale)
//    time指的就是時間(不是秒),
//    而時間要換算成秒就要看第二個參數timeScale了.
//    timeScale指的是1秒需要由幾個frame構成(可以視為fps),
//    因此真正要表達的時間就會是 time / timeScale 才會是秒.
//    CMTimeMake(a,b)
//    a当前第几帧，b每秒钟多少帧
    
    frameCount++;
    CMTime presentationTimeStamp = CMTimeMake(frameCount, (int32_t)30);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)30);
    
    NSNumber *timeNumber = @(timeStamp);
//    @param presentationTimeStamp
//    此帧的显示时间戳，将附加到样本缓冲区。
//    传递给会话的每个演示文稿时间戳必须大于前一个。
//    @param时间
//    此帧的表示持续时间，将附加到样本缓冲区。
//    如果您没有持续时间信息，请传递kCMTimeInvalid。
//    @param frameProperties
//    包含键/值对，指定用于编码此帧的其他属性。
//    请注意，某些会话属性也可能在帧之间更改。
//    这些变化对随后编码的帧有影响。
//    @param sourceFrameRefcon
//    帧的参考值，将传递给输出回调函数。
//    @param infoFlagsOut
//    指向VTEncodeInfoFlags以接收有关编码操作的信息。
//    如果编码正在（或正在）运行，则可以设置kVTEncodeInfo_Asynchronous位
//    异步。
//    如果帧被丢弃（同步），则可以设置kVTEncodeInfo_FrameDropped位。
//    如果您不想接收此信息，请传递NULL。
    
    OSStatus status = VTCompressionSessionEncodeFrame(compressionSession, pixelBuffer, presentationTimeStamp, duration, nil, (__bridge_retained void *)timeNumber, &flags);
    if(status != noErr){
        [self configManager];
    }
}

@end
