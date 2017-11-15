//
//  ETAudioFile.h
//  AudioC
//
//  Created by hailong9 on 2017/11/13.
//  Copyright © 2017年 lizi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@interface ETAudioFile : NSObject
{
    ExtAudioFileRef _audioFile;
    AudioBufferList* _outBuffer;
    UInt64 _numFrames ;
    UInt32 _frameOffset;
}
- (instancetype)initWithFilePath:(NSString*)path withStreamDescription:(AudioStreamBasicDescription*)des;
- (AudioBufferList*)readAudioData:(UInt32)frameNu;
- (void)closeFile;
@end
