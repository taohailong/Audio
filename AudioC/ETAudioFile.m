//
//  ETAudioFile.m
//  AudioC
//
//  Created by hailong9 on 2017/11/13.
//  Copyright © 2017年 lizi. All rights reserved.
//

#import "ETAudioFile.h"

@implementation ETAudioFile
- (instancetype)initWithFilePath:(NSString*)path withStreamDescription:(AudioStreamBasicDescription*)des{
    self = [super init];
    
    CFURLRef url= CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
    OSStatus result = ExtAudioFileOpenURL(url, &_audioFile);
    if (result || !_audioFile) { printf("ExtAudioFileOpenURL result error");}
    
    AudioStreamBasicDescription fileFormat;
    UInt32 propSize = sizeof(fileFormat);
    
    result = ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
    if (result) { printf("ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat result error"); }
    
    
    // used to account for any sample rate conversion
    double rateRatio = 44100.0 / fileFormat.mSampleRate;
    propSize = sizeof(AudioStreamBasicDescription);
    result = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, propSize, des);
    if (result) { printf("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat error"); }
    
    // 获取file  sample frames 数量
    propSize = sizeof(_numFrames);
    result = ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileLengthFrames, &propSize, &_numFrames);
    if (result) { printf("ExtAudioFileGetProperty kExtAudioFileProperty_FileLengthFrames result error");  }
    
    _numFrames = (_numFrames * rateRatio); // account for any sample rate conversion
    
    _outBuffer = malloc(sizeof(AudioBufferList)) ;
    _outBuffer->mNumberBuffers = 1;
    _outBuffer->mBuffers[0].mNumberChannels = 1;
     _outBuffer->mBuffers[0].mDataByteSize = 512 * des->mBytesPerFrame ;
    _outBuffer->mBuffers[0].mData = (Float32 *)malloc(_outBuffer->mBuffers[0].mDataByteSize);
    return self;
}

- (AudioBufferList*)readAudioData:(UInt32)frameNu{
    UInt32 numPackets = (UInt32)frameNu;
    OSStatus result = ExtAudioFileRead(_audioFile, &numPackets, _outBuffer);
    _frameOffset = _frameOffset + numPackets;
    if (_frameOffset > _numFrames) {
        _frameOffset = 0;
        ExtAudioFileSeek(_audioFile, _frameOffset);
    }
    return _outBuffer;
}

- (void)closeFile{
    if (_outBuffer != NULL) {
        free(_outBuffer->mBuffers[0].mData);
        free(_outBuffer);
        _outBuffer = NULL;
    }
     ExtAudioFileDispose(_audioFile);
}

@end
