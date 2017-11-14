# Audio
 在ios开发上Audio Unit 使用率是很低的，造成的结果就是对于这方面的资料少之又少。在研究了一段时间的音频单元后把自己的一些成果跟大家分享，希望ios开发者 在这方面能少走弯路。

对于音频的开发首先要懂得一些声音的基本知识，声音是靠振幅的大小决定是大声还是小声，靠震动的频率决定是高音还是低音。而数字音频是把大自然的声波用数字模拟 出来。以时间轴为X轴，振幅为Y轴将声音记录下来。每一个时间单位内纪录的数据样本叫做sample 或者叫一个frame。一秒钟有多少个sample 叫做 采样比 sample rate 通常用到的采样率是44100Hz 也就是一秒钟有44100个frame。

原始的数字采样叫做PCM格式，也就是ios系统内扬声器要播放的格式，我们日常中常用到的音频大多是MP3 AAC等。都是对PCM的封装和压缩得来的。以mp3为例，它的 格式是把pcm封装在一个个的packet中， MP3编码方式常用的有两种固定码率(Constant bitrate，CBR)和可变码率(Variable bitrate，VBR)对CBR的MP3数据来说 每个帧中包含的PCM数据帧是固定的，每一个packet中的frame 一般是1152个，而VBR是可变的。 当然其他的格式中如AAC也是不固定的。

还有一个比较重要的参数BitRate 表示每秒的比特数注意大小是bit。一般码率越高质量越高。也可以用 bitrate来计算音频时间长度。

那我们手机播放mp3的过程：

1 读取mp3 帧分离得到 packet数据。
2 对packet进行转化得到pcm。
3 pcm 可以做混音等操作。 
4 把pcm交给硬件播放。

流程看起来很简单，但是操作过程却是很复杂。ios 音频播放的高级类别有AVAudioPlayer/AVPlayer／ 使用很简单，不能对pcm做定制。AVAudioEngine 是介于中间的一个高级封装。但是有些效果还是没有达到，比如卡拉OK伴唱。

我们可以用到的有 1 Audio File 读写音频数据 可以是网络的也可以是本地的（解析为packet）。 2 Audio File Stream 可以对音频二进制流解析为packet。 3 Audio Converter 对packet转化为pcm。 4 Audio Unit 可以直接播放pcm 数据，还能进行麦克风录音数据采集。 5 Audio Processing Graph 是对 Audio Unit的进一步集成，可以加入各种混音效果。 6 Audio Queue 属于一种半自动的播放，不需要pcm，有packet就能播放。 7 Extended Audio File 包含了Audio File和Audio Converter真的是好用。

接下来主要讲解以Audio Processing Graph 为播放器，分别用Audio File 和 Extended Audio File对mp3进行解析。为什么用Audio Processing Graph ？为后面卡拉OK伴唱打基础。


Audio Processing Graph在iOS系统中算得上是底层的api了，掌握了它可以实现你想要的各种效果。Audio Processing Graph 好比是一个平台，它可以提供一个环境让音效的控制和播放都融合在里面。

![ Enter your image description here: ](/Users/hailong9/Desktop/2062231-4908ba2a1f8a106c.png)

首先生成  NewAUGraph(&audioGraph); 这就产生舞台了，然后创建一个个node 相当于是喇叭，架子鼓等，node 一般都是有input 和 output 两个通道的。node 通过 input output 串联起来最后有一个输出的node就播放出来了。
   
首先创建一个mixernode 它可以有多个input 通道，可以把多个通道输入的音频混合起来播放。
  AudioComponentDescription mixerUnitDescription;
    mixerUnitDescription.componentType= kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags = 0;
    mixerUnitDescription.componentFlagsMask = 0;
    AUNode mixerNode;
    AUGraphAddNode(audioGraph, &mixerUnitDescription, &mixerNode);


输出的node
AudioComponentDescription outputUnitDescription;
    bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    AUNode outputNode;
    AUGraphAddNode(audioGraph, &outputUnitDescription, &outputNode);

把它们都串联起来，mixerNode 的output 0 连接到 outputNode input 0
 OSStatus status = AUGraphConnectNodeInput(audioGraph, mixerNode, 0, outputNode, 0);


  status = AUGraphOpen(audioGraph);

要设置node 的一些属性时还要使用AudioUnit ，下面分别生成 mixerUnit， outputUnit
status = AUGraphNodeInfo(audioGraph, outputNode, &outputUnitDescription, &outputUnit);
status = AUGraphNodeInfo(audioGraph, mixerNode, &mixerUnitDescription, &mixerUnit);

下面就要给 mixerUnit  outputUnit 的进口和出口的数据设置格式了，这里进出口的数据都是pcm，pcm 也是分为好多种格式的，mSampleRate 采样率，mBytesPerPacket 每个packet的大小，mFramesPerPacket，每个packet中有多少个frame，mBytesPerFrame ，每个frame 的大小，还有frame 是16 位还是32位。mFormatID 是什么类型的（pcm 、AAC等）

   我们设置mixer 输出的数据格式 要跟 outputUnit 输入的格式一致才能播放。

设置outputUnit的输入格式，它的输出就直接到了扬声器，可以不用设置了。
 status =   AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, audioFormat, sizeof(AudioStreamBasicDescription));


设置 mixerUnit 有几个input 入口。
UInt32 numbuses = 1;
  status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    
  mixerUnit 有几个input  output 口格式设置。

   status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, audioFormat, sizeof(AudioStreamBasicDescription));

//    status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, audioFormat, sizeof(AudioStreamBasicDescription));

  status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, audioFormat, sizeof(AudioStreamBasicDescription));

   status 在这里是状态标示，如果为noerror 说明执行的没有问题。坑就在这里好多api执行出问题后根本不知道错在哪里，api 的解释好多都不到位，只能摸索着试。

这里剩下一个重要的输入源了，一般我们的输入源是mp3等音频文件，经转换得到pcm后怎样交给mixerUnit呢？

为什么是一个for循环？ 如果有多个输入源时可是使用，这就是卡拉OK伴唱的原理，背景音乐作为一个输入源，通过麦克分采集到主播的声音作为一个输入源。通过mix混合后输出 给output就能听到了。如果把他打包通过网络传输给粉丝，这就是直播过程中声音的处理过程。

for (int i = 0; i<numbuses; i++) {
        AURenderCallbackStruct callBackStruct;
        callBackStruct.inputProcRefCon = (__bridge void*)self;
        callBackStruct.inputProc = &MyRenderCallback;
        status = AUGraphSetNodeInputCallback(audioGraph, mixerNode, i, &callBackStruct);
    }

首先是 mixerNode 的input 入口提供数据 是一个callback   通过AUGraphSetNodeInputCallback 传入一个结构体AURenderCallbackStruct 来设置。  AURenderCallbackStruct中有 inputProc 这是callback方法的传入地址，是一个C的静态方法。 inputProcRefCon  传入的是一个指针可以在callBack的C 方法中使用。


这就是它的callback
OSStatus MyRenderCallback(void *userData,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData)
{    
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

关键的参数  AudioBufferList *ioData 它是传递数据的载体，inNumberFrames 需要多少个frame。inBusNumber标示这是哪个input 接口的回调。
结束时不要忘记 audioGraph 进行释放 ExtAudioFileDispose(xafref);

到此处播放设置的部分已经完成。

接下来以mp3为例说说从音频文件到pcm 的转化。

首先我们使用的是 AudioFile 这个类可以支持音频文件的读取和写入。这里只介绍读取本地文件的使用。
 CFURLRef cfurl =   CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)url , kCFURLPOSIXPathStyle, false);
   OSStatus status = AudioFileOpenURL(cfurl , kAudioFileReadPermission, kAudioFileMP3Type, &_audioFileID);

   cfurl 是音频文件的路径 AudioFileOpenURL 传入的 kAudioFileReadPermission kAudioFileMP3Type 一个是声明是MP3格式，一个是要有读的权限。  打开成功后_audioFileID是这个文件的标示，后面需要使用。
 

ioNumBytes 是传入的buffer 的size， inStartingPacket packet 的index，要ioNumPackets 读取的packet 数量，outBuffer packet 的存放地方。

AudioFileReadPacketData (	AudioFileID  					inAudioFile, 
                       		Boolean							inUseCache,
                       		UInt32 *						ioNumBytes,
                       		AudioStreamPacketDescription * __nullable outPacketDescriptions,
                       		SInt64							inStartingPacket, 
                       		UInt32 * 						ioNumPackets,
                       		void * __nullable				outBuffer)
	
这是读取音频文件中的数据转化为packet数据，我们知道播放使用的是pcm ，所以还要有一个packet 的解析过程。咱们使用的是AudioConverter ，这个类中有三个关于pcm的方法 AudioConverterFillComplexBuffer 这个方法是万能的，其他两个有各种限制，比如只能是pcm不同格式间的转化，mSampleRate必须一致。
 
 AudioConverterFillComplexBuffer 可以任意转换，packet 转化 pcm    pcm转AAC， 不同格式的pcm转化。

  AudioStreamBasicDescription destFormat = *des;
   status =  AudioConverterNew(&_streamDescription, &destFormat , &_converter);

这是它的初始化，第一个是它的要转换的音频文件格式， destFormat要转换的格式。如果 _streamDescription和destFormat设置不正确，后面的就无法转换了，要注意。

 OSStatus status = AudioConverterFillComplexBuffer(_converter,
                                    ConverterFiller,
                                   (__bridge void * _Nullable)(self),
                                    &size,_outBuffer ,NULL);
   这是转换的方法，第一个是_converter 不介绍，ConverterFiller是一个函数指针，接着是一个函数传入的标签，size 是传入的是要转换出来frame 的数量，如果packet的数量不足或者其他原因，size返回的是实际转换的数量。_outBuffer AudioBufferList是转换后数据的载体。最后一个参数是outPacketDescription 可以忽略。




     这是Converter的callBack
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
inUserData 不介绍，ioData是传入的data 的载体，* ioNumberDataPackets  是本次转换少的的数量。outDataPacketDescription一般不常使用。还要注意的是，一次性不要转换太多的packet 它是有限制的。
超过了限制就会报错（血的教训啊）。
这里可以查看和设置 Converter的属性。
 convert 可以转换packet的最大数量
   UInt32 convertInputSize = 0;
   UInt32 convertSize = sizeof(convertInputSize);
   status = AudioConverterGetProperty(_converter, kAudioConverterPropertyMaximumInputPacketSize, &convertSize, &convertInputSize);


   这个转换方法很容易报错，status 的查询也肯坑。[ 点这里 ](https://www.osstatus.com/search/results?platform=all&framework=all&search=560100710)  这是我找到一个查询错误码的网址。

回到咱们的流程中 AudioFileOpenURL以后用_audioFileID 可以读取到音频文件的格式
//获取格式信息
   
      AudioFormatListItem *formatList = (AudioFormatListItem *)malloc(formatListSize);
      status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, formatList);

有了这个就能生成 _converter。

读取 一个packet 的最大字节
 UInt32 packet = 0;
    UInt32 packetsize = sizeof(packet);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMaximumPacketSize, &packetsize, &packet);
    
    
读取 文件中packet 的数量
    UInt64 packetcount = 0;
    UInt32 packetcountsize = sizeof(packetcount);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyAudioDataPacketCount, &packetcountsize, &packetcount);//12474
    

这两个有什么用呢， 第一本的的mp3文件不能一次性全部转换成pcm这样内存消耗太大，音频的播放转换过程又是不太消耗cup的，所以以时间换空间，系统需要多少frame 我就读取packet 转换多少个。




这是我的 [ github ](https://github.com/taohailong/Audio)    https://github.com/taohailong/Audio     上面有音频开发的Demo

