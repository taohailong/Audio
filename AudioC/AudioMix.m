//
//  AudioMix.m
//  AudioC
//
//  Created by 陶海龙 on 16/8/2.
//  Copyright © 2016年 lizi. All rights reserved.
//

#import "AudioMix.h"

#import <AVFoundation/AVFoundation.h>
@interface AudioMix()

{
    AUGraph audioGraph;
    AudioUnit mixerUnit;
    AudioUnit outputUnit;
     AudioUnit playerUnit;
    
    
    
    AudioFileStreamID audioFileStreamID;
    AudioStreamBasicDescription streamDescription;
    AudioConverterRef converter;
    AudioBufferList *renderBufferList;
    UInt32 renderBufferSize;
    NSMutableArray *packets;
    size_t readHead;
    
    NSData* _mp3Data;
    NSInteger _startOff;

}
@end


@implementation AudioMix

static const OSStatus KKAudioConverterCallbackErr_NoData = 'kknd';




-(id)init{
    
    self = [super init];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
    //[session setMode:AVAudioSessionModeVideoChat error:nil];
    [session setActive:YES error:nil];

    UInt32 bufferSize = 4096 * 4;
    renderBufferSize = bufferSize;
    
    renderBufferList = (AudioBufferList*)calloc(1, sizeof(UInt32)+ sizeof(AudioBuffer));
    
    renderBufferList->mNumberBuffers = 1;
    renderBufferList->mBuffers[0].mNumberChannels = 2;
    renderBufferList->mBuffers[0].mDataByteSize = bufferSize;
    renderBufferList->mBuffers[0].mData = calloc(1, bufferSize);

    [self setupAudioGraph];
    [self audioNodes];
    
    
    packets = [[NSMutableArray alloc] init];
    
    AudioFileStreamOpen((__bridge void* )self, TAudioFileStreamPropertyListener , TAudioFileStreamPacketsCallback, kAudioFileMP3Type, &audioFileStreamID);
    [self builtMp3Stream];
    [self readBuffer:4094*50];

    return self;
}

-(void)setupAudioGraph
{
    NewAUGraph(&audioGraph);
    AUGraphOpen(audioGraph);
}

-(void)audioNodes
{

    AudioComponentDescription mixerUnitDescription;
    mixerUnitDescription.componentType= kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags = 0;
    mixerUnitDescription.componentFlagsMask = 0;
    AUNode mixerNode;
    AUGraphAddNode(audioGraph, &mixerUnitDescription, &mixerNode);

    
    
//    AudioComponentDescription inputUnitDescription;
//    inputUnitDescription.componentType = kAudioUnitType_Output;
//    inputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
//    inputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
//    inputUnitDescription.componentFlags = 0;
//    inputUnitDescription.componentFlagsMask = 0;
//    AUNode inputNode;
//    AUGraphAddNode(audioGraph, &inputUnitDescription, &inputNode);

    

    
    AudioComponentDescription outputUnitDescription;
    bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    AUNode outputNode;
    AUGraphAddNode(audioGraph, &outputUnitDescription, &outputNode);
    
    
    
    
    
    
    
    UInt32 numbuses = 2;
   OSStatus status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    
     status =  AUGraphConnectNodeInput(audioGraph, mixerNode, 0, outputNode, 0);
    NSAssert(noErr == status, @"AUGraphConnectNodeInput. %d", (int)status);
//    status =  AUGraphConnectNodeInput(audioGraph, outputNode, 1,mixerNode , 0);
//    NSAssert(noErr == status, @"AUGraphConnectNodeInput. %d", (int)status);
    
//    OSStatus status =  AUGraphConnectNodeInput(audioGraph, outputNode, 1, mixerNode, 1);
//    NSAssert(noErr == status, @"AUGraphConnectNodeInput. %d", (int)status);
//    status = AUGraphConnectNodeInput(audioGraph, inputNode, 0, mixerNode, 0);
//    NSAssert(noErr == status, @"AUGraphConnectNodeInput. %d", (int)status);
    
    
    
    
    
//    AUGraphNodeInfo(audioGraph, inputNode, &inputUnitDescription, &playerUnit);
    AUGraphNodeInfo(audioGraph, outputNode, &outputUnitDescription, &outputUnit);
    AUGraphNodeInfo(audioGraph, mixerNode, &mixerUnitDescription, &mixerUnit);
    
    
    
    
    // 設定 mixer node 的輸入輸出格式
    
    AudioStreamBasicDescription audioFormat = TSignedIntLinearPCMStreamDescription();
    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &audioFormat, sizeof(audioFormat));
    NSAssert(noErr == status, @"We need to set input format of the mixer node. %d", (int)status);
    
    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioFormat, sizeof(audioFormat));
    NSAssert(noErr == status, @"We need to set input format of the mixer effect node. %d", (int)status);
    
    
    

    
    
    
    
  
    
    
    

    // set inputUnit format
    UInt32 flagOne = 1;
    status = AudioUnitSetProperty(outputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    NSAssert(noErr == status, @"inputUnit Must be no error.");
    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &audioFormat, sizeof(audioFormat));
//    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(audioFormat));
    // set outputUnit format
    
    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioFormat, sizeof(audioFormat));
//   AudioUnitSetProperty(playerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioFormat, sizeof(audioFormat));
    

    
    
    //    set render callBack
    
    
    AURenderCallbackStruct callBackStruct;
    callBackStruct.inputProcRefCon = (__bridge void*)self;
    callBackStruct.inputProc = TPlayerAURenderCallback;
    
    //    status = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callBackStruct, sizeof(callBackStruct));
    status = AUGraphSetNodeInputCallback(audioGraph, mixerNode, 0, &callBackStruct);
    NSAssert(noErr == status, @"Must be no error.");

    
    
    
    
    
    AudioUnitAddRenderNotify(mixerUnit, mixerCallBack, (__bridge void*)self);
    
    
    status = AUGraphInitialize(audioGraph);
    NSAssert(noErr == status, @"AUGraphInitialize error.");
    CAShow(audioGraph);
    
}


-(void)builtMp3Stream{
    
    NSURL* url = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"mo.mp3"];
    
    NSError* err = nil;
    _mp3Data = [[NSData alloc]initWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&err];
}

-(void)readBuffer:(NSInteger)size
{
    if (_startOff+1 == [_mp3Data length])
    {
        [self pause];
        return;
    }
    
    NSLog(@"size %d  startOff %d data length %d ",size,_startOff,[_mp3Data length]);
    if (_startOff + size > [_mp3Data length] - 1)
    {
        size = [_mp3Data length] - 1 - _startOff;
    }
    
    
    NSData* subData = [_mp3Data subdataWithRange:NSMakeRange(_startOff, size)];
    
    _startOff += size;
    AudioFileStreamParseBytes(audioFileStreamID, (UInt32)[subData length], [subData bytes], 0);
}

- (double)packetsPerSecond
{
    if (streamDescription.mFramesPerPacket) {
        return streamDescription.mSampleRate / streamDescription.mFramesPerPacket;
    }
    return 44100.0/1152.0;
}


#pragma mark- playerController

- (void)play
{
    OSStatus status = AUGraphStart(audioGraph);
    NSAssert(noErr == status, @"AudioOutputUnitStart, error: %ld", (signed long)status);
}


- (void)pause
{
    OSStatus status = AUGraphStop(audioGraph);
    NSAssert(noErr == status, @"AudioOutputUnitStop, error: %ld", (signed long)status);
}



#pragma mark---------   dataParse



- (void)_createAudioQueueWithAudioStreamDescription:(AudioStreamBasicDescription *)audioStreamBasicDescription
{
    memcpy(&streamDescription, audioStreamBasicDescription, sizeof(AudioStreamBasicDescription));
    AudioStreamBasicDescription destFormat = TSignedIntLinearPCMStreamDescription();
    AudioConverterNew(&streamDescription, &destFormat, &converter);
    
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
}

- (OSStatus)callbackWithNumberOfFrames:(UInt32)inNumberOfFrames
                                ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber
{
    @synchronized(self) {
        
        if (readHead < [packets count]) {
            
            @autoreleasepool {
                
                UInt32 packetSize = inNumberOfFrames;
                // 第七步： Remote IO node 的 render callback 中，呼叫 converter 將 packet 轉成 LPCM
//                NSLog(@"number frame %d",inNumberOfFrames);
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









OSStatus TPlayerAURenderCallback(void *userData,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData)
{
    
    
    if (inBusNumber == 1)
    {
        //        NSLog(@"output buffer %d ",inNumberFrames);
        return 0;
    }
    
    // 第六步： Remote IO node 的 render callback
    AudioMix *self = (__bridge AudioMix *)userData;
    OSStatus status = [self callbackWithNumberOfFrames:inNumberFrames
                                                ioData:ioData busNumber:inBusNumber];
    if (status != noErr) {
        ioData->mNumberBuffers = 0;
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
    }
    return status;
}



static OSStatus mixerCallBack(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp * inTimeStamp, UInt32 inBusNumber,UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    
    NSLog(@"inBusNumber %d inNumberFrames %d ",inBusNumber,inNumberFrames);
//    if ((*ioActionFlags) & kAudioUnitRenderAction_PostRender)
//        return (ExtAudioFileWrite(extAudioFile, inNumberFrames, ioData));
    
    return noErr;
}





void TAudioFileStreamPropertyListener(void * inClientData,
                                      AudioFileStreamID inAudioFileStream,
                                      AudioFileStreamPropertyID inPropertyID,
                                      UInt32 * ioFlags)
{
    AudioMix *self = (__bridge AudioMix *)inClientData;
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 dataSize  = 0;
        OSStatus status = 0;
        AudioStreamBasicDescription audioStreamDescription;
        Boolean writable = false;
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream,
                                                kAudioFileStreamProperty_DataFormat, &dataSize, &writable);
        status = AudioFileStreamGetProperty(inAudioFileStream,
                                            kAudioFileStreamProperty_DataFormat, &dataSize, &audioStreamDescription);
        
        NSLog(@"mSampleRate: %f", audioStreamDescription.mSampleRate);
        NSLog(@"mFormatID: %u", audioStreamDescription.mFormatID);
        NSLog(@"mFormatFlags: %u", audioStreamDescription.mFormatFlags);
        NSLog(@"mBytesPerPacket: %u", audioStreamDescription.mBytesPerPacket);
        NSLog(@"mFramesPerPacket: %u", audioStreamDescription.mFramesPerPacket);
        NSLog(@"mBytesPerFrame: %u", audioStreamDescription.mBytesPerFrame);
        NSLog(@"mChannelsPerFrame: %u", audioStreamDescription.mChannelsPerFrame);
        NSLog(@"mBitsPerChannel: %u", audioStreamDescription.mBitsPerChannel);
        NSLog(@"mReserved: %u", audioStreamDescription.mReserved);
        
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
    
    AudioMix *self = (__bridge AudioMix *)inClientData;
    [self _storePacketsWithNumberOfBytes:inNumberBytes
                         numberOfPackets:inNumberPackets
                               inputData:inInputData
                      packetDescriptions:inPacketDescriptions];
}



OSStatus TPlayerConverterFiller (AudioConverterRef inAudioConverter,
                                 UInt32* ioNumberDataPackets,
                                 AudioBufferList* ioData,
                                 AudioStreamPacketDescription** outDataPacketDescription,
                                 void* inUserData)
{
    // 第八步： AudioConverterFillComplexBuffer 的 callback
    AudioMix *self = (__bridge AudioMix *)inUserData;
    //    NSLog(@"convert packet %d",*ioNumberDataPackets);
    *ioNumberDataPackets = 0;
    OSStatus result = [self _fillConverterBufferWithBufferlist:ioData
                                             packetDescription:outDataPacketDescription];
    if (result == noErr) {
        *ioNumberDataPackets = 1;
    }
    return result;
}






@end
