//
//  ViewController.m
//  AudioC
//
//  Created by 陶海龙 on 16/7/28.
//  Copyright © 2016年 lizi. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioMix.h"
#import "TAudioFile.h"
#import "ETAudioFile.h"

const Float64 kGraphSampleRate = 44100.0;
typedef struct {
    AudioStreamBasicDescription asbd;
    Float32 *data;
    UInt32 numFrames;
    UInt32 sampleNum;
} SoundBuffer, *SoundBufferPtr;
#define MAXBUFS  2
@interface ViewController ()
{
    TAudioFile* _file;
    ETAudioFile* _efile;
    AUGraph audioGraph;
    AudioUnit mixerUnit;
    AudioUnit  outputUnit;
    ExtAudioFileRef xafref ;

}
@end

@implementation ViewController
OSStatus MyRenderCallback(void *userData,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData)
{
//    SoundBufferPtr sndbuf = (SoundBufferPtr)userData;
//    UInt32 bufSamples = sndbuf[inBusNumber].numFrames;
//
//    Float32 *in = sndbuf[inBusNumber].data;
//    Float32 *outA = (Float32 *)ioData->mBuffers[0].mData;
//    Float32 *outB = (Float32 *)ioData->mBuffers[1].mData;
//    UInt32 sample = sndbuf[inBusNumber].sampleNum;
//
//    ioData->mBuffers[0].mNumberChannels = 2;
//
//    if (YES) {
//        AudioStreamBasicDescription streamDes = sndbuf->asbd;
//        ioData->mBuffers[0].mDataByteSize = inNumberFrames*streamDes.mBytesPerFrame;
//        ioData->mBuffers[0].mData = (in+sample);
//        sample = sample + inNumberFrames;
//    }else{
//        for (UInt32 i = 0; i<inNumberFrames;  i++) {
//            if (inBusNumber == 1) {
//                outA[i] = in[sample++];
//                outB[i] = 0;
//            }else{
//                outB[i] = in[sample++];
//                outA[i] = 0;
//            }
//            if (sample > bufSamples) {
//                // start over from the beginning of the data, our audio simply loops
//                printf("looping data for bus %d after %ld source frames rendered\n", (unsigned int)inBusNumber, (long)sample-1);
//                sample = 0;
//            }
//        }
//        sndbuf[inBusNumber].sampleNum = sample;
//    }
//     return noErr;
    
    ViewController *self = (__bridge ViewController *)userData;
    AudioBufferList* data = [self readBuffer:inNumberFrames];

    if (data == NULL) {
        ioData->mNumberBuffers = 0;
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
        return  -1;
    }else{
        ioData->mNumberBuffers = 1;
        ioData->mBuffers[0].mNumberChannels = data->mBuffers[0].mNumberChannels;
        ioData->mBuffers[0].mDataByteSize = data->mBuffers[0].mDataByteSize;
        ioData->mBuffers[0].mData = data->mBuffers[0].mData;
        return noErr;
    }
  
}


- (void)viewDidLoad {
    
    [super viewDidLoad];
    
//    NSURL* url = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"mo.mp3"];
    NSString *sourceA = [[NSBundle mainBundle] pathForResource:@"fukua" ofType:@"mp3"];
    
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                                                      sampleRate:44100.0
                                                                                                        channels:1
                                                                                                    interleaved:YES];
////    TSignedIntLinearPCMStreamDescription();
    AudioStreamBasicDescription*  fileDes = clientFormat.streamDescription;
//
    _efile = [[ETAudioFile alloc]initWithFilePath:sourceA withStreamDescription:fileDes];
////    _file = [[TAudioFile alloc]initForReading:sourceA withConvert:&d];
////    [_file readAudioPacket:14368458];
//
    
    AVAudioFormat *graphFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                   sampleRate:44100.0
                                                                     channels:2
                                                                  interleaved:NO];
    
    [self creatAudioGraph:graphFormat.streamDescription];
}


- (void)creatAudioGraph:(const AudioStreamBasicDescription*)des{

   const AudioStreamBasicDescription* audioFormat= des;
    NewAUGraph(&audioGraph);
    
    AudioComponentDescription mixerUnitDescription;
    mixerUnitDescription.componentType= kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags = 0;
    mixerUnitDescription.componentFlagsMask = 0;
    AUNode mixerNode;
    AUGraphAddNode(audioGraph, &mixerUnitDescription, &mixerNode);
    
    
    AudioComponentDescription outputUnitDescription;
    bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    AUNode outputNode;
    AUGraphAddNode(audioGraph, &outputUnitDescription, &outputNode);
    
    OSStatus status = AUGraphConnectNodeInput(audioGraph, mixerNode, 0, outputNode, 0);
    
    status = AUGraphOpen(audioGraph);
    if (status) { printf("AUGraphOpen result %ld %08lX %4.4s\n", (long)status, (long)status, (char*)&status); return; }
    
    
   status = AUGraphNodeInfo(audioGraph, outputNode, &outputUnitDescription, &outputUnit);
    status = AUGraphNodeInfo(audioGraph, mixerNode, &mixerUnitDescription, &mixerUnit);
    
    
    
    
    UInt32 numbuses = 1;
    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    
    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, audioFormat, sizeof(AudioStreamBasicDescription));
//    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, audioFormat, sizeof(AudioStreamBasicDescription));
    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, audioFormat, sizeof(AudioStreamBasicDescription));
    
    
//    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,&maxFPS, sizeof(maxFPS));
    NSAssert(noErr == status, @"We need to set input format of the mixer effect node. %d", (int)status);
    
    
    


  status =   AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, audioFormat, sizeof(AudioStreamBasicDescription));
    //    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(audioFormat));
    // set outputUnit format
//  status =   AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, audioFormat, sizeof(AudioStreamBasicDescription));
    //   AudioUnitSetProperty(playerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioFormat, sizeof(audioFormat));
    
    
    for (int i = 0; i<numbuses; i++) {
        AURenderCallbackStruct callBackStruct;
        callBackStruct.inputProcRefCon = (__bridge void*)self;
        callBackStruct.inputProc = &MyRenderCallback;
        status = AUGraphSetNodeInputCallback(audioGraph, mixerNode, i, &callBackStruct);
    }
  
    NSAssert(noErr == status, @"Must be no error.");
    status = AUGraphInitialize(audioGraph);
    NSAssert(noErr == status, @"AUGraphInitialize error.");
    CAShow(audioGraph);
    OSStatus result = AUGraphStart(audioGraph);
    if (result) { printf("AUGraphStart result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
}


- (AudioBufferList*)readBuffer:(UInt32)inNumberFrames{
    
    if (_efile) {
        return [_efile readAudioData:inNumberFrames];
    }
    
    return  [_file readAudioFrame:inNumberFrames];
}


- (IBAction)changeVolum:(id)sender {
     _player = [[THLRecordIO alloc]initWithDelegate:nil];
    NSURL* url = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"mo.mp3"];
    [_player startPlayerMusic:url.absoluteString];
}


- (void)stopAudio{
     ExtAudioFileDispose(xafref);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
