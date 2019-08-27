//
//  AudioCodeManager.h
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "LFStreamRTMPSocket.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AudioCodeManagerDelegate <NSObject>

- (void)audioOutputData:(LFAudioFrame *)audioFrame;

@end

@interface AudioCodeManager : NSObject

@property (nonatomic, assign) id<AudioCodeManagerDelegate> delegate;


- (instancetype)initWithInputFormat:(AudioStreamBasicDescription)inputFormat;

- (void)encodeAudioWithSourceBuffer:(void *)sourceBuffer sourceBufferSize:(UInt32)sourceBufferSize;


@end

NS_ASSUME_NONNULL_END
