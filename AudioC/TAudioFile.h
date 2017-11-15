//
//  AudioFile.h
//  AudioC
//
//  Created by hailong9 on 2017/11/7.
//  Copyright © 2017年 lizi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioMix.h"
#import <AudioToolbox/AudioFormat.h>
typedef struct PacketBuffer{
    void* data;
    UInt32 size;
    UInt32 offset;
    UInt32 packetNu;
} PacketBuffer;


@interface TAudioFile : NSObject
{
   AudioFileID _audioFileID;
    AudioStreamBasicDescription _streamDescription;
    AudioBufferList* _outBuffer;
    AudioConverterRef _converter;
    PacketBuffer* _packetBuffet;
}
- (instancetype)initForReading:(NSString*)url withConvert:(AudioStreamBasicDescription*)des;
- (AudioBufferList*)readAudioFrame:(unsigned int)frameNu;
- (void)closeFile;
@end
