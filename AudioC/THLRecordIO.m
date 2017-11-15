//
//  PlayerIO.m
//  AudioC
//
//  Created by 陶海龙 on 16/7/28.
//  Copyright © 2016年 lizi. All rights reserved.
//

#import "THLRecordIO.h"
#import <AVFoundation/AVFoundation.h>
static void TAudioFileStreamPropertyListener(void* inClientData,
                                              AudioFileStreamID inAudioFileStream,
                                              AudioFileStreamPropertyID inPropertyID,
                                              UInt32* ioFlags);


static void TAudioFileStreamPacketsCallback(void* inClientData,
                                             UInt32 inNumberBytes,
                                             UInt32 inNumberPackets,
                                             const void* inInputData,
                                             AudioStreamPacketDescription *inPacketDescriptions);




static OSStatus TPlayerConverterFiller(AudioConverterRef inAudioConverter,
                                        UInt32* ioNumberDataPackets,
                                        AudioBufferList* ioData,
                                        AudioStreamPacketDescription** outDataPacketDescription,
                                        void* inUserData);


static OSStatus TPlayerAURenderCallback(void *userData,
                                         AudioUnitRenderActionFlags *ioActionFlags,
                                         const AudioTimeStamp *inTimeStamp,
                                         UInt32 inBusNumber,
                                         UInt32 inNumberFrames,
                                         AudioBufferList *ioData);



static AudioStreamBasicDescription TSignedIntLinearPCMStreamDescription();
static const OSStatus KKAudioConverterCallbackErr_NoData = 'kknd';

@interface THLRecordIO()
{

    __weak id<THLRecordProtocol>_delegate;
    AudioComponentInstance audioUnit;
    
    short* musicBuffer;
    
    AudioFileStreamID audioFileStreamID;
    AudioStreamBasicDescription streamDescription;
    AudioConverterRef converter;
    AudioBufferList *renderBufferList;
    UInt32 renderBufferSize;
    NSMutableArray *packets;
    size_t readHead;
    
    NSData* _mp3Data;
    NSInteger _startOff;
    
    
    BOOL musicEnd;
    float _musicVolume;
    float _micVolume;
}



@end



@implementation THLRecordIO

AudioStreamBasicDescription TSignedIntLinearPCMStreamDescription()
{
    AudioStreamBasicDescription destFormat;
    bzero(&destFormat, sizeof(AudioStreamBasicDescription));
    destFormat.mSampleRate = 44100.0;
    destFormat.mFormatID = kAudioFormatLinearPCM;
    destFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    destFormat.mFramesPerPacket = 1;
    destFormat.mBytesPerPacket = 4;
    destFormat.mBytesPerFrame = 4;
    destFormat.mChannelsPerFrame = 2;
    destFormat.mBitsPerChannel = 16;
    destFormat.mReserved = 0;
    return destFormat;
}

- (void)dealloc
{
    AudioFileStreamClose(audioFileStreamID);
    AudioConverterDispose(converter);
    AudioOutputUnitStop(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(renderBufferList != nil)
    {
        free(renderBufferList->mBuffers[0].mData);
        free(renderBufferList);
        renderBufferList = NULL;
    }
    
    if(musicBuffer != NULL)
    {
        free(musicBuffer);
    }
}


-(void)setupIORemote
{

    AudioComponentDescription outputUnitDescription;
    bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
    
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    
    
    AudioComponent outputComponent = AudioComponentFindNext(NULL, &outputUnitDescription);
    OSStatus status = AudioComponentInstanceNew(outputComponent, &audioUnit);
    NSAssert(noErr==status, @"Must be no error");

}


-(void)buildPlayerUnit
{
    
    if (packets != nil)
    {
        return;
    }
     packets = [[NSMutableArray alloc] init];
    
//    set IO input format
    
    AudioStreamBasicDescription audioFormat = TSignedIntLinearPCMStreamDescription();
    
    AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
    
    
//    set render callBack
    
    
    AURenderCallbackStruct callBackStruct;
    
    callBackStruct.inputProcRefCon = (__bridge void*)self;
    callBackStruct.inputProc = TPlayerAURenderCallback;
    
    OSStatus status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callBackStruct, sizeof(callBackStruct));
     NSAssert(noErr == status, @"Must be no error.");
    
    
  
    
//  built buffer list
    UInt32 bufferSize = 4096 * 4;
    renderBufferSize = bufferSize;
    
    renderBufferList = (AudioBufferList*)calloc(1, sizeof(UInt32)+ sizeof(AudioBuffer));
    
    renderBufferList->mNumberBuffers = 1;
    renderBufferList->mBuffers[0].mNumberChannels = 2;
    renderBufferList->mBuffers[0].mDataByteSize = bufferSize;
    renderBufferList->mBuffers[0].mData = calloc(1, bufferSize);
    
    musicBuffer = malloc(sizeof(short)*2048);
    
}

-(void)builtRecordUnit
{
     AudioStreamBasicDescription audioFormat = TSignedIntLinearPCMStreamDescription();
    //    set IO output format
    UInt32 flagOne = 1;
    
    AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void*)self;
    cb.inputProc = TPlayerAURenderCallback;
    AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(audioFormat));
    AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));

}






-(id)initWithDelegate:(id<THLRecordProtocol>)delegate
{
    self = [super init];
    
    if (self)
    {
        _micVolume = 1.0;
        _musicVolume = 1.0;
        _delegate = delegate;
        musicEnd = true;
         AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
        //[session setMode:AVAudioSessionModeVideoChat error:nil];
        [session setActive:YES error:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
       
        [self setupIORemote];
        [self builtRecordUnit];
        [self play];
    }
    
    
    return self;
}


#pragma mark-  Player


-(void)startPlayerMusic:(NSString*)path
{
    if (musicEnd == false)
    {
        [self musicEnd];
    }
    musicEnd = false;
    
    [self buildPlayerUnit];
    AudioFileStreamOpen((__bridge void* )self, TAudioFileStreamPropertyListener , TAudioFileStreamPacketsCallback, kAudioFileMP3Type, &audioFileStreamID);
    
    [self builtMp3Stream:path];
    [self readBuffer:4094*50];

}



-(void)musicEnd
{
    _startOff = 0;
    musicEnd = true;
    [packets removeAllObjects];
    AudioFileStreamClose(audioFileStreamID);
}



- (double)packetsPerSecond
{
    if (streamDescription.mFramesPerPacket) {
        return streamDescription.mSampleRate / streamDescription.mFramesPerPacket;
    }
    return 44100.0/1152.0;
}



// sets the overall mixer output volume
- (void)setMusicVolume:(float)value
{
    _musicVolume = value;
}


-(void)setMicVolume:(float)value
{
    _micVolume = value;
}




- (void)play
{
    OSStatus status = AudioOutputUnitStart(audioUnit);
    NSAssert(noErr == status, @"AudioOutputUnitStart, error: %ld", (signed long)status);
}


- (void)pause
{
    OSStatus status = AudioOutputUnitStop(audioUnit);
    NSAssert(noErr == status, @"AudioOutputUnitStop, error: %ld", (signed long)status);
}


-(void)stopPlayer
{
//    OSStatus status = AudioOutputUnitStop(<#AudioUnit  _Nonnull ci#>)
//    NSAssert(noErr == status, @"AudioOutputUnitStop, error: %ld", (signed long)status);
}



- (void)_createAudioQueueWithAudioStreamDescription:(AudioStreamBasicDescription *)audioStreamBasicDescription
{
    memcpy(&streamDescription, audioStreamBasicDescription, sizeof(AudioStreamBasicDescription));
    AudioStreamBasicDescription destFormat = TSignedIntLinearPCMStreamDescription();
   OSStatus status = AudioConverterNew(&streamDescription, &destFormat, &converter);
    
//    UInt32 value = 0;
//    UInt32 size = sizeof(value);
//    AudioConverterGetProperty(converter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &value);
//    NSLog(@"value %d",value);
}



- (void)_storePacketsWithNumberOfBytes:(UInt32)inNumberBytes
                       numberOfPackets:(UInt32)inNumberPackets
                             inputData:(const void *)inInputData
                    packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
    for (int i = 0; i < inNumberPackets; ++i) {
        
        SInt64 packetStart = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize = inPacketDescriptions[i].mDataByteSize;
        assert(packetSize > 0);
        NSData *packet = [NSData dataWithBytes:inInputData + packetStart length:packetSize];
        [packets addObject:packet];
    }
    
    
    if([packets count] > (int)([self packetsPerSecond] * 3))
    {
       [self play];
    }
//    else
//    {
//        [self readBuffer:4096*50];
//    }
    //  第五步，因為 parse 出來的 packets 夠多，緩衝內容夠大，因此開始
    //  播放
    
//    if (readHead == 0 && [packets count] > (int)([self packetsPerSecond] * 3)) {
////        if (playerStatus.stopped) {
//            [self play];
////        }
//    }
}

- (OSStatus)callbackWithNumberOfFrames:(UInt32)inNumberOfFrames
                                ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber
{
    @synchronized(self) {
    
        if (musicEnd == false) {
            
            @autoreleasepool {
                
                UInt32 packetSize = inNumberOfFrames;
//                UInt32 packetSize = 512;
                // 第七步： Remote IO node 的 render callback 中，呼叫 converter 將 packet 轉成 LPCM
                NSLog(@"number frame %d",inNumberOfFrames);
                OSStatus status =
                AudioConverterFillComplexBuffer(converter,
                                                TPlayerConverterFiller,
                                                (__bridge void *)(self),
                                                &packetSize, renderBufferList, NULL);
//                NSLog(@"after number frame %d",packetSize);
                if (noErr != status && KKAudioConverterCallbackErr_NoData != status) {
                    [self pause];
                    return -1;
                }
                else if (!packetSize) {
                    inIoData->mNumberBuffers = 0;
                }
                else {
                    // 在這邊改變 renderBufferList->mBuffers[0].mData
                    // 可以產生各種效果
                    inIoData->mNumberBuffers = 1;
                    inIoData->mBuffers[0].mNumberChannels = 2;
                    inIoData->mBuffers[0].mDataByteSize = renderBufferList->mBuffers[0].mDataByteSize;
                    inIoData->mBuffers[0].mData = renderBufferList->mBuffers[0].mData;
                    NSLog(@"renderBufferList %s",renderBufferList->mBuffers[0].mData);
                    
                    memcpy(musicBuffer, renderBufferList->mBuffers[0].mData, renderBufferList->mBuffers[0].mDataByteSize);
                    
                    renderBufferList->mBuffers[0].mDataByteSize = renderBufferSize;
                }
            }
        }
        else {
            inIoData->mNumberBuffers = 0;
            return -1;
        }
    }
    
    return noErr;
}


- (OSStatus)_fillConverterBufferWithBufferlist:(AudioBufferList *)ioData
                             packetDescription:(AudioStreamPacketDescription** )outDataPacketDescription
{
    static AudioStreamPacketDescription aspdesc;
    
//    if (readHead >= [packets count]) {
//        return KKAudioConverterCallbackErr_NoData;
//    }
    
   
    ioData->mNumberBuffers = 1;
//    NSData *packet = packets[readHead];
     NSData *packet = packets[0];
    void const *data = [packet bytes];
    UInt32 length = (UInt32)[packet length];
    ioData->mBuffers[0].mData = (void *)data;
    ioData->mBuffers[0].mDataByteSize = length;
    
    *outDataPacketDescription = &aspdesc;
    aspdesc.mDataByteSize = length;
    aspdesc.mStartOffset = 0;
    aspdesc.mVariableFramesInPacket = 1;
    
    [packets removeObject:packet];
    

    if([packets count] < (int)([self packetsPerSecond] * 3))
    {
        //        [self play];
        [self readBuffer:4096*50];
    }

    
//    readHead++;
    return 0;
}


-(OSStatus)renderRecordData:(AudioUnitRenderActionFlags *)ioActionFlags numberFrame:(UInt32)numberFrame time:(AudioTimeStamp *)timeStamp bus:(UInt32)busNumber
{

    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = 2;
    
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    
    OSStatus status = AudioUnitRender(audioUnit,
                                      ioActionFlags,
                                      timeStamp,
                                      busNumber,
                                      numberFrame,
                                      &buffers);

    if(musicEnd == false)
    {
        [self mixPCMDataBuffer:buffers.mBuffers[0].mData lenth:numberFrame*2];
    }
    
    if(_delegate != nil)
    {
        [_delegate renderDataCallBack:&buffers numberFrame:numberFrame];
    }
    
//    NSLog(@"output buffer %d ",numberFrame);
    
    return status;
}


-(void)mixPCMDataBuffer:(short*)audio lenth:(UInt32)size
{
    
//    @synchronized (self) {
    
        short* music = musicBuffer;
        for (int i = 0; i < size ; i++) {
            
            short recordData = (short)audio[i];
            short musicData = music[i];
            int value = recordData*_micVolume + musicData*_musicVolume;
            
            value = value > 65534 ? 65534:value ;
            value = value < -65536 ? -65536:value;
            
            audio[i] = (short)(value/2);
        }
//    }
}



void TAudioFileStreamPropertyListener(void * inClientData,
                                       AudioFileStreamID inAudioFileStream,
                                       AudioFileStreamPropertyID inPropertyID,
                                       UInt32 * ioFlags)
{
    THLRecordIO *self = (__bridge THLRecordIO *)inClientData;
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 dataSize  = 0;
        OSStatus status = 0;
        AudioStreamBasicDescription audioStreamDescription;
        Boolean writable = false;
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream,
                                                kAudioFileStreamProperty_DataFormat, &dataSize, &writable);
        status = AudioFileStreamGetProperty(inAudioFileStream,
                                            kAudioFileStreamProperty_DataFormat, &dataSize, &audioStreamDescription);
        
//        NSLog(@"mSampleRate: %f", audioStreamDescription.mSampleRate);
//        NSLog(@"mFormatID: %u", audioStreamDescription.mFormatID);
//        NSLog(@"mFormatFlags: %u", audioStreamDescription.mFormatFlags);
//        NSLog(@"mBytesPerPacket: %u", audioStreamDescription.mBytesPerPacket);
//        NSLog(@"mFramesPerPacket: %u", audioStreamDescription.mFramesPerPacket);
//        NSLog(@"mBytesPerFrame: %u", audioStreamDescription.mBytesPerFrame);
//        NSLog(@"mChannelsPerFrame: %u", audioStreamDescription.mChannelsPerFrame);
//        NSLog(@"mBitsPerChannel: %u", audioStreamDescription.mBitsPerChannel);
//        NSLog(@"mReserved: %u", audioStreamDescription.mReserved);
        
        // 第三步： Audio Parser 成功 parse 出 audio 檔案格式，我們根據
        // 檔案格式資訊，建立 converter
        
        [self _createAudioQueueWithAudioStreamDescription:&audioStreamDescription];
    }
}

void TAudioFileStreamPacketsCallback(void* inClientData,
                                      UInt32 inNumberBytes,
                                      UInt32 inNumberPackets,
                                      const void* inInputData,
                                      AudioStreamPacketDescription* inPacketDescriptions)
{
    // 第四步： Audio Parser 成功 parse 出 packets，我們將這些資料儲存
    // 起來
    
    THLRecordIO *self = (__bridge THLRecordIO *)inClientData;
    [self _storePacketsWithNumberOfBytes:inNumberBytes
                         numberOfPackets:inNumberPackets
                               inputData:inInputData
                      packetDescriptions:inPacketDescriptions];
}

OSStatus TPlayerAURenderCallback(void *userData,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData)
{
    THLRecordIO *self = (__bridge THLRecordIO *)userData;
    
    if (inBusNumber == 1)
    {
        [self renderRecordData:ioActionFlags numberFrame:inNumberFrames time:inTimeStamp bus:inBusNumber];

        return 0;
    }
    
    // 第六步： Remote IO node 的 render callback
    
    OSStatus status = [self callbackWithNumberOfFrames:inNumberFrames
                                                ioData:ioData busNumber:inBusNumber];
    if (status != noErr) {
        ioData->mNumberBuffers = 0;
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
    }
    return status;
}

OSStatus TPlayerConverterFiller (AudioConverterRef inAudioConverter,
                                  UInt32* ioNumberDataPackets,
                                  AudioBufferList* ioData,
                                  AudioStreamPacketDescription** outDataPacketDescription,
                                  void* inUserData)
{
    // 第八步： AudioConverterFillComplexBuffer 的 callback
    THLRecordIO *self = (__bridge THLRecordIO *)inUserData;
    NSLog(@"convert packet %d",*ioNumberDataPackets);
    *ioNumberDataPackets = 0;
    OSStatus result = [self _fillConverterBufferWithBufferlist:ioData
                                             packetDescription:outDataPacketDescription];
    if (result == noErr) {
        *ioNumberDataPackets = 1;
    }
    return result;
}





#pragma mark -
#pragma mark NSURLConnectionDelegate


-(void)builtMp3Stream:(NSString*)path{

    NSURL* url = [NSURL URLWithString:path];
    if (url == nil)
    {
        return;
    }
    NSError* err = nil;
    _mp3Data = [[NSData alloc]initWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&err];
}

-(void)readBuffer:(NSInteger)size
{
    if (_startOff+1 == [_mp3Data length])
    {
        [self musicEnd];
        return;
    }
    
//    NSLog(@"size %d  startOff %d data length %d ",size,_startOff,[_mp3Data length]);
    if (_startOff + size > [_mp3Data length] - 1)
    {
        size = [_mp3Data length] - 1 - _startOff;
    }
    
    
    NSData* subData = [_mp3Data subdataWithRange:NSMakeRange(_startOff, size)];
    
    _startOff += size;
   AudioFileStreamParseBytes(audioFileStreamID, (UInt32)[subData length], [subData bytes], 0);
}


#pragma mark-----NoticCenter

- (void) handleInterruption:(NSNotification*)notification
{
    NSDictionary* userInfo = notification.userInfo;
    
    if([userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan) {
        [self pause];
    } else {
        [self play];
    }
}



@end
