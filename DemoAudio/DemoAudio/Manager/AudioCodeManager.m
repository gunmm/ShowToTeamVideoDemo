//
//  AudioCodeManager.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "AudioCodeManager.h"

struct ConverterInfo {
    UInt32   sourceChannelsPerFrame;
    UInt32   sourceDataSize;
    void     *sourceBuffer;
};

typedef struct ConverterInfo ConverterInfoType;


@interface AudioCodeManager (){
    AudioConverterRef m_converter;
}

@property (nonatomic, assign) AudioStreamBasicDescription inputFormat;
@property (nonatomic, assign) AudioStreamBasicDescription outputFormat;


@end

@implementation AudioCodeManager

#pragma mark - Encode Callback
OSStatus EncodeConverterComplexInputDataProc(AudioConverterRef              inAudioConverter,
                                             UInt32                         *ioNumberDataPackets,
                                             AudioBufferList                *ioData,
                                             AudioStreamPacketDescription   **outDataPacketDescription,
                                             void                           *inUserData) {
    ConverterInfoType *info = (ConverterInfoType *)inUserData;
    ioData->mNumberBuffers              = 1;
    ioData->mBuffers[0].mData           = info->sourceBuffer;
    ioData->mBuffers[0].mNumberChannels = info->sourceChannelsPerFrame;
    ioData->mBuffers[0].mDataByteSize   = info->sourceDataSize;
    
    return noErr;
}

- (instancetype)initWithInputFormat:(AudioStreamBasicDescription)inputFormat {
    if (self = [super init]) {
        _inputFormat = inputFormat;
        [self configManager];
    }
    return self;
}

- (void)configManager {
    
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = _inputFormat.mSampleRate;       // 采样率保持一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;            // AAC编码 kAudioFormatMPEG4AAC kAudioFormatMPEG4AAC_HE_V2
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mFramesPerPacket = 1024;                     // AAC一帧是1024个字节
    self.outputFormat = outputFormat;
    
    const OSType subtype = kAudioFormatMPEG4AAC;
//    AudioClassDescription结构体描述了系统使用音频编码器信息,其中最重要的就是指定使用硬编或软编。然后编码器的数量，即数组的个数，由当前的声道数决定。
    AudioClassDescription requestedCodecs[1] = {
//        {
//            kAudioEncoderComponentType,
//            subtype,
//            kAppleSoftwareAudioCodecManufacturer
//        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    OSStatus result = AudioConverterNewSpecific(&_inputFormat, &outputFormat, 2, requestedCodecs, &m_converter);
    
    //    我们可以手动设置需要的码率,如果没有特殊要求一般可以根据采样率使用建议值,如下.
    UInt32 outputBitRate = 64000;
    UInt32 propSize = sizeof(outputBitRate);
    if (outputFormat.mSampleRate >= 44100) {
        outputBitRate = 192000;
    } else if (outputFormat.mSampleRate < 22000) {
        outputBitRate = 32000;
    }
    outputBitRate *= outputFormat.mChannelsPerFrame;
    
    if(result == noErr) {
        result = AudioConverterSetProperty(m_converter, kAudioConverterEncodeBitRate, propSize, &outputBitRate);
    }
  
}

- (void)encodeAudioWithSourceBuffer:(void *)sourceBuffer sourceBufferSize:(UInt32)sourceBufferSize {
    UInt32 outputSizePerPacket = _outputFormat.mBytesPerPacket; //每个音频包中有多少字节数
    if (outputSizePerPacket == 0) {
        // if the destination format is VBR, we need to get max size per packet from the converter
        UInt32 size = sizeof(outputSizePerPacket);
        OSStatus result = AudioConverterGetProperty(m_converter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &outputSizePerPacket);
        if(result != noErr) {
            NSLog(@"noErr---AudioConverterGetProperty");
            return;
        }
    }
    
    UInt32 numberOutputPackets = 1;
    UInt32 theOutputBufferSize = sourceBufferSize;
    AudioStreamPacketDescription outputPacketDescriptions;
    
    // Set up output buffer list.
    AudioBufferList fillBufferList = {};
    fillBufferList.mNumberBuffers = 1;
    fillBufferList.mBuffers[0].mNumberChannels  = _outputFormat.mChannelsPerFrame;
    fillBufferList.mBuffers[0].mDataByteSize    = theOutputBufferSize;
    fillBufferList.mBuffers[0].mData            = malloc(theOutputBufferSize * sizeof(char));
    
    ConverterInfoType userInfo = {0};
    userInfo.sourceBuffer           = sourceBuffer;
    userInfo.sourceDataSize         = sourceBufferSize;
    userInfo.sourceChannelsPerFrame = _inputFormat.mChannelsPerFrame;
    
    // Convert data
    UInt32 ioOutputDataPackets = numberOutputPackets;
    OSStatus status = AudioConverterFillComplexBuffer(m_converter,
                                                      EncodeConverterComplexInputDataProc,
                                                      &userInfo,
                                                      &ioOutputDataPackets,
                                                      &fillBufferList,
                                                      &outputPacketDescriptions);
    
    
    
    // if interrupted in the process of the conversion call, we must handle the error appropriately
    if (status != noErr) {
        if (status == kAudioConverterErr_HardwareInUse) {
            printf("Audio Converter returned kAudioConverterErr_HardwareInUse!\n");
        } else {
            NSLog(@"---- %d", (int)status);
            return;
        }
    } else {
        if (ioOutputDataPackets == 0) {
            // This is the EOF condition.
            status = noErr;
        }
        
        
        LFAudioFrame *audioFrame = [LFAudioFrame new];
        audioFrame.timestamp = (CACurrentMediaTime()*1000);
        audioFrame.data = [NSData dataWithBytes:fillBufferList.mBuffers->mData length:fillBufferList.mBuffers->mDataByteSize];
        
        if ([self.delegate respondsToSelector:@selector(audioOutputData:)]) {
            [self.delegate audioOutputData:audioFrame];
        }
    }
}

@end
