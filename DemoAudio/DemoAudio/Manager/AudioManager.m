//
//  AudioManager.m
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "AudioManager.h"

@interface AudioManager ()

@property (nonatomic, assign) AudioUnit audioUnit;
@property (nonatomic, assign) AudioStreamBasicDescription audioDataFormat;

@end

@implementation AudioManager

#pragma mark -- CallBack
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    @autoreleasepool {
        AudioManager *source = (__bridge AudioManager *)inRefCon;
        if (!source) return -1;
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;
//        启动音频单元的渲染周期。
//        ioData
//        输入时，音频单元要渲染的音频缓冲列表。输出时，音频单元呈现的音频数据。
        OSStatus status = AudioUnitRender(source.audioUnit,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
    
        if (!status) {
            if (source.delegate && [source.delegate respondsToSelector:@selector(audioOutputData:mDataByteSize:)]) {
                [source.delegate audioOutputData:buffers.mBuffers[0].mData mDataByteSize:buffers.mBuffers[0].mDataByteSize];
            }
        }
        return status;
    }
}

- (instancetype)init {
    if (self = [super init]) {
        [self configManager];
    }
    return self;
}

- (void)configManager {
    
    //创建AudioUnit
    AudioUnit audioUnit;
    AudioComponentDescription audioDesc;
    audioDesc.componentType         = kAudioUnitType_Output;
    audioDesc.componentSubType      = kAudioUnitSubType_RemoteIO;
//    audioDesc.componentType      = kAudioUnitType_Mixer;
//    audioDesc.componentSubType   = kAudioUnitSubType_MultiChannelMixer;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags        = 0;
    audioDesc.componentFlagsMask    = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    OSStatus status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    if (status != noErr)  {
        NSLog(@"%d - create audio unit failed, status  \n", (int)status);
        return;
    }
    self.audioUnit = audioUnit;
    
    //打开输入
    UInt32 flagOne = 1;
    AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    
    //初始化音频流数据格式 ASBD
    AudioStreamBasicDescription desc = {0};
    desc.mSampleRate = 44100;    //采样率
    desc.mFormatID = kAudioFormatLinearPCM;     
    desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;  //设置采样值的flag mFormatID下的格式
    desc.mChannelsPerFrame = 1;   //s声道
    desc.mFramesPerPacket = 1;   //每个包中有多少帧
    desc.mBitsPerChannel = 16;   //每个声道有多少位
    desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;  //每一帧中有多少字节
    desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;     //每个音频包中有多少字节数
    
    //用来往出传
    memcpy(&_audioDataFormat, &desc, sizeof(desc));

    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void *)(self);
    cb.inputProc = handleInputBuffer;
    AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
    AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
    
    AudioUnitConnection conn;
    conn.destInputNumber = 0;
    conn.sourceAudioUnit = audioUnit;
    conn.sourceOutputNumber = 1;
    OSStatus statu = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &conn, sizeof(conn));
    if (noErr != statu) {
        //        [self showStatus:err];
        NSLog(@"音频链接错误");
    }
    
    status = AudioUnitInitialize(self.audioUnit);
    
    if (noErr != status) {
        return;
    }
}

- (void)startCapture {
    OSStatus status;

    status = AudioOutputUnitStart(self.audioUnit);
    if (status == noErr) {
        NSLog(@"s音频采集启动s成功");

    }else {
        NSLog(@"s音频采集启动错误-----%d", (int)status);
    }
}

- (AudioStreamBasicDescription)getAudioDataFormat {
    return _audioDataFormat;
}

@end
