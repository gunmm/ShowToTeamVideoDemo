//
//  VideoManager.h
//  DemoAudio
//
//  Created by minzhe on 2019/8/20.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol VideoManagerDelegate <NSObject>

- (void)didOutputSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer;

@end

NS_ASSUME_NONNULL_BEGIN

@interface VideoManager : NSObject

@property (nonatomic, assign) id<VideoManagerDelegate> delegate;

- (instancetype)initWithBgView:(UIView *)bgView;

- (void)startSession;
- (void)stopSession;

@end

NS_ASSUME_NONNULL_END
