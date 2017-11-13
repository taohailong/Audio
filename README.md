# Audio
  在ios开发上Audio Unit 使用率是很低的，造成的结果就是对于这方面的资料少之又少。在研究了一段时间的音频单元后把自己的一些成果跟大家分享，希望ios开发者
在这方面能少走弯路。
   
   对于音频的开发首先要懂得一些声音的基本知识，声音是靠振幅的大小决定是大声还是小声，靠震动的频率决定是高音还是低音。而数字音频是把大自然的声波用数字模拟
出来。以时间轴为X轴，振幅为Y轴将声音记录下来。每一个时间单位内纪录的数据样本叫做sample 或者叫一个frame。一秒钟有多少个sample 叫做 采样比 sample rate
通常用到的采样率是44100Hz 也就是一秒钟有44100个frame。

   原始的数字采样叫做PCM格式，也就是ios系统内扬声器要播放的格式，我们日常中常用到的音频大多是MP3 AAC等。都是对PCM的封装和压缩得来的。以mp3为例，它的
格式是把pcm封装在一个个的packet中， MP3编码方式常用的有两种固定码率(Constant bitrate，CBR)和可变码率(Variable bitrate，VBR)对CBR的MP3数据来说
每个帧中包含的PCM数据帧是固定的，每一个packet中的frame 一般是1152个，而VBR是可变的。 当然其他的格式中如AAC也是不固定的。   
   
   还有一个比较重要的参数BitRate 表示每秒的比特数注意大小是bit。一般码率越高质量越高。也可以用 bitrate来计算音频时间长度。
   
   那我们手机播放mp3的过程：
   
   1 读取mp3 帧分离得到 packet数据。
   2 对packet进行转化得到pcm。
   3 pcm 可以做混音等操作。
   4 把pcm交给硬件播放。
   
   流程看起来很简单，但是操作过程却是很复杂。ios 音频播放的高级类别有AVAudioPlayer/AVPlayer／ 使用很简单，不能对pcm做定制。AVAudioEngine
是介于中间的一个高级封装。但是有些效果还是没有达到，比如卡拉OK伴唱。
   
   我们可以用到的有
   1 Audio File  读写音频数据 可以是网络的也可以是本地的（解析为packet）。
   2 Audio File Stream 可以对音频二进制流解析为packet。
   3 Audio Converter 对packet转化为pcm。
   4 Audio Unit 可以直接播放pcm 数据，还能进行麦克风录音数据采集。
   5 Audio Processing Graph 是对 Audio Unit的进一步集成，可以加入各种混音效果。
   6 Audio Queue 属于一种半自动的播放，不需要pcm，有packet就能播放。
   7 Extended Audio File 包含了Audio File和Audio Converter真的是好用。
   
   接下来主要讲解以Audio Processing Graph 为播放器，分别用Audio File 和 Extended Audio File对mp3进行解析。为什么用Audio Processing Graph
   ？为后面卡拉OK伴唱打基础。
   
