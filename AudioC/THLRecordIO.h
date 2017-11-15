//
//  PlayerIO.h
//  AudioC
//
//  Created by 陶海龙 on 16/7/28.
//  Copyright © 2016年 lizi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol THLRecordProtocol <NSObject>

-(void)renderDataCallBack:(AudioBufferList*)buffer numberFrame:(UInt32)frames;

@end


@interface THLRecordIO : NSObject

-(id)initWithDelegate:(id<THLRecordProtocol>)delegate;
- (void)setMusicVolume:(float)value;
-(void)setMicVolume:(float)value;
- (void)play;
- (void)pause;
-(void)startPlayerMusic:(NSString*)path;
@end
