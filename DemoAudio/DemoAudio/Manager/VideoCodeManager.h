//
//  VideoCodeManager.h
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import "LFStreamRTMPSocket.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VideoCodeManagerDelegate <NSObject>

@optional

- (void)receiveVideoEncoderData:(LFFrame *)frame;

@end

@interface VideoCodeManager : NSObject

@property (nonatomic, weak) id<VideoCodeManagerDelegate> delegate;

- (void)encodeVideoData:(CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;

@end

NS_ASSUME_NONNULL_END
