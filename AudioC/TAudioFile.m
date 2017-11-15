//
//  TAudioFile.m
//  AudioC
//
//  Created by hailong9 on 2017/11/7.
//  Copyright © 2017年 lizi. All rights reserved.
//

#import "TAudioFile.h"
//static  int  convertNu = 0;
//static BOOL isRead = NO;
@implementation TAudioFile
OSStatus ConverterFiller (AudioConverterRef inAudioConverter,
                          UInt32* ioNumberDataPackets,
                          AudioBufferList* ioData,
                          AudioStreamPacketDescription** outDataPacketDescription,
                          void* inUserData)
{
    TAudioFile* self = (__bridge TAudioFile *)(inUserData);
    PacketBuffer* buffet = [self readPacketData];
    
    if ( buffet->size == 0) {
        * ioNumberDataPackets = 0;
        return 0;
    }
    
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mData = buffet->data;
    ioData->mBuffers[0].mDataByteSize = buffet->size;
    
    static AudioStreamPacketDescription aspdesc;
    *outDataPacketDescription = &aspdesc;
    aspdesc.mDataByteSize = ioData->mBuffers[0].mDataByteSize;
    aspdesc.mStartOffset = 0;
    aspdesc.mVariableFramesInPacket = 0;
    *ioNumberDataPackets = 1;
    return 0;
}


- (instancetype)initForReading:(NSString*)url withConvert:(AudioStreamBasicDescription*)des{
    self = [super init];
    
    CFURLRef cfurl =   CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)url , kCFURLPOSIXPathStyle, false);
   OSStatus status = AudioFileOpenURL(cfurl , kAudioFileReadPermission, kAudioFileMP3Type, &_audioFileID);

    //获取格式信息
    UInt32 formatListSize = 0;
     status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status == noErr){
        AudioFormatListItem *formatList = (AudioFormatListItem *)malloc(formatListSize);
        status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, formatList);
        if (status == noErr){
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem)){
                memcpy(&_streamDescription, &formatList[i].mASBD, sizeof(AudioStreamBasicDescription));
                //选择需要的格式。。
            }
        }
        free(formatList);
    }
  
  /*
//   读取一个packet 中有多少个frame
    AudioFramePacketTranslation* packetTranslation = malloc(sizeof(AudioFramePacketTranslation));
    packetTranslation->mPacket = 1;
    UInt32 Translationtsize = sizeof(AudioFramePacketTranslation);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyPacketToFrame, &Translationtsize, packetTranslation);
    printf("%d %d",packetTranslation->mFrame,packetTranslation->mPacket);
   
   //获取码率
   //    UInt32 bitRateSize = sizeof(bitRate);
   ////    UInt32 bitRateSize = 8;
   //    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyBitRate, &bitRateSize, &bitRate);
   //    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyAudioDataByteCount, &bitRateSize, &bitRate);//5213622
   
   convert 可以转换packet的最大数量
   UInt32 convertInputSize = 0;
   UInt32 convertSize = sizeof(convertInputSize);
   status = AudioConverterGetProperty(_converter, kAudioConverterPropertyMaximumInputPacketSize, &convertSize, &convertInputSize);
   
    */
    
    AudioStreamBasicDescription destFormat = *des;
   status =  AudioConverterNew(&_streamDescription, &destFormat , &_converter);
    
    UInt32 packet = 0;
    UInt32 packetsize = sizeof(packet);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMaximumPacketSize, &packetsize, &packet);
    
    
    UInt64 packetcount = 0;
    UInt32 packetcountsize = sizeof(packetcount);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyAudioDataPacketCount, &packetcountsize, &packetcount);//12474
    

    _packetBuffet =  malloc(sizeof(PacketBuffer));
    _packetBuffet->size = packet;
    _packetBuffet->data = malloc(_packetBuffet->size);
    _packetBuffet->packetNu = (UInt32)packetcount;
    

    UInt32 ioNumBytes =  4008 * sizeof(UInt32); //预留足够大
    _outBuffer = (AudioBufferList*)calloc(1, sizeof(UInt32)+ sizeof(AudioBufferList));
    _outBuffer->mNumberBuffers = 1;
    _outBuffer->mBuffers[0].mDataByteSize = ioNumBytes;
    _outBuffer->mBuffers[0].mData = (void *)malloc(ioNumBytes);
    
    
    if (status != noErr){
        //错误处理
    }
    return self;
}


- (AudioBufferList*)readAudioFrame:(unsigned int)frameNu{
  
    UInt32 size = frameNu;
    OSStatus status = AudioConverterFillComplexBuffer(_converter,
                                    ConverterFiller,
                                   (__bridge void * _Nullable)(self),
                                    &size,_outBuffer ,NULL);
//    在转换的data 大于需要的数量时，多余的部分会暂存在convert 下次转换时再用。
    
     NSAssert(status == noErr, @"AudioConverterFillComplexBuffer error");
     _outBuffer->mBuffers[0].mNumberChannels = 1;
     return _outBuffer;
}

- (PacketBuffer*)readPacketData{

    _packetBuffet->size = 418;
    UInt32 ioNumPackets = 1;
    UInt32 descSize = sizeof(AudioStreamPacketDescription) * ioNumPackets;
    AudioStreamPacketDescription * outPacketDescriptions = (AudioStreamPacketDescription *)malloc(descSize);
    OSStatus status =  AudioFileReadPacketData(_audioFileID, NO, &_packetBuffet->size, outPacketDescriptions,_packetBuffet->offset, &ioNumPackets, _packetBuffet->data);
    free(outPacketDescriptions);
    
    if (_packetBuffet->offset >= _packetBuffet->packetNu) {
        _packetBuffet->offset = 0;
    }else{
         _packetBuffet->offset += 1;
    }
    return _packetBuffet;
}

- (void)closeFile{
  
    if (_packetBuffet != NULL) {
        free(_packetBuffet->data);
        free(_packetBuffet);
        _packetBuffet = NULL;
    }
    if (_outBuffer != NULL) {
        free(_outBuffer->mBuffers[0].mData);
        free(_outBuffer);
        _outBuffer = NULL;
    }
    if (&_streamDescription != NULL) {
        free(&_streamDescription);
    }
    
    AudioConverterDispose(_converter);
    AudioFileClose(_audioFileID);
}


@end
