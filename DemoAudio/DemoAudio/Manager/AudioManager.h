//
//  AudioManager.h
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AudioManagerDelegate <NSObject>

- (void)audioOutputData:(void* __nullable)mData mDataByteSize:(UInt32)mDataByteSize;

@end

@interface AudioManager : NSObject

@property (nonatomic, assign) id<AudioManagerDelegate> delegate;

- (AudioStreamBasicDescription)getAudioDataFormat;

- (void)startCapture;

@end

NS_ASSUME_NONNULL_END
