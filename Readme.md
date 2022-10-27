
# KSYLive_iOS_Vietnamese

Flow sử dụng cơ bản:


    - Tạo object KSYGPUStreamerKit
    - Đăng ký các notification cần thiết để nhận thông tin từ SDK trả về khi cần
    - Configure thông số về video được thu từ camera cho preview, stream push, ví dụ như độ phân giải, frame rate,..
    - Bắt đầu thu video và hiện preview (sử dụng preview view)
    - Configure thông số về stream push, như bitrate, codec,..
    - Bắt đầu/ kết thúc stream
    - Kết thúc preview


Sử dụng các tính năng của SDK qua object KSYGPUStreamerKit
```swift
let streamerKit = KSYGPUStreamerKit(defaultCfg: ())
// configure streamerKit for video/audio

// configure stream push

streamerKit.startPreview(self.previewView)
streamerKit.streamerBase.startStream(URL(string: "rtmp://192.168.76.161/live/hello"))
streamerKit.streamerBase.stopStream()
streamerKit.stopPreview()
```
## Video
### Configure video
Có thể chọn camera trước hoặc sau, độ phân giải của preview host nhìn thấy, độ phân giải của stream được push lên, framerate , orientation của stream và setup callback để nhận buffer  (CMSampleBuffer), mirror video thu từ camera cho stream và preview
```swift
streamerKit.cameraPosition = .front
//streamerKit.switchCamera() để chuyển camera
streamerKit.capPreset = AVCaptureSession.Preset.hd1280x720.rawValue as NSString
streamerKit.previewDimension = CGSize(width: 720, height: 1280)
streamerKit.streamDimension = CGSize(width: 720, height: 1280)
streamerKit.videoFPS = 24
streamerKit.videoOrientation = UIInterfaceOrientation.portrait
streamerKit.previewMirrored = true // mirror ảnh preview
streamerKit.streamerMirrored = true // mirror ảnh stream
```
*Note:  
Trước khi chạy preview cần set previewDimension trước.
Cần đảm bảo  previewDimension và streamDimension có cùng aspect ratio (video trên stream sẽ biến dạng).
Recommendation: capPreset == previewDimension ≥ streamDimension

* Thêm ảnh watermark cho nội dung stream:
```swift
streamerKit.logoPic = KSYGPUPicture(image: UIImage(named: "logo"))
streamerKit.logoAlpha = 0.5
streamerKit.logoRect = CGRect(x: 0.05, y: 0.05, width: width, height: height)
```
*Note:
Toạ độ x,y của logoRect có giá trị từ 0 đến 1, là offset top-left trong preview

* Thêm text watermark cho nội dung stream với property textLabel là một UILabel
```swift
streamerKit.textLabel.text = "Text watermark"
//streamerKit.updateTextLabel() dể update nội dung text
```
### Notifications
Notification về state của capture video với name: NSNotification.Name.KSYCaptureStateDidChange
```swift
NotificationCenter.default.addObserver(self, selector: #selector(onStreamStateChange(notification:)), name: NSNotification.Name.KSYCaptureStateDidChange, object: nil)

@objc func onCaptureStateChange(notification: Notification) {
    guard let streamerKit = streamerKit else { return }
    switch streamerKit.captureState {
    case .idle:
        print("idle")
    case .capturing:
        print("capturing")
    case .closingCapture:
        print("closingCapture")
    case .devAuthDenied:
        print("devAuthDenied")
    case .parameterError:
        print("parameterError")
    case .devBusy:
        print("devBusy")
    default:
        print("unknown")
    }
}
```
###  Video processing
1. Built-in Beauty Filter:
     Sử dụng filter qua hàm setupFilter của streamerkit, tương thích với filter của SDK GPUImage.
```swift
let filter = KSYBeautifyFaceFilter()
streamerKit.setupFilter(filter)
//streamerKit.setupFilter(nil) tắt filter
```
Hỗ trợ sẵn 6 loại filter beauty làm mịn, trắng, hồng da.
    
| Filter | name | whitening  <br>Effect | Microdermabrasion  <br>Effect | rosy  <br>Effect | Does it depend on  <br>KSYGPUResource.  <br>bundle |
| --- | --- | --- | --- | --- | --- |
| [KSYGPUBeautifyExtFilter](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYGPUBeautifyExtFilter.html) | skin rejuvenation | middle | middle | powerful | no  |
| [KSYGPUBEautifyFilter](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYGPUBeautifyFilter.html) | fair skin | powerful | middle | Low | no  |
| [KSYGPUDnoiseFilter](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYGPUDnoiseFilter.html) | nature | middle | Low | Low | no  |
| [KSYGPUBeautifyPlusFilter](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYGPUBeautifyPlusFilter.html) | Soft skin | middle | middle | middle | no  |
| [KSYBeautifyFaceFilter](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYBeautifyFaceFilter.html) | fair | middle | powerful | Low | Yes |
| [KSYBeautifyProFilter](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYBeautifyProFilter.html) | pink | middle | powerful | middle | Yes |
 
[-> More detail](https://github.com/ksvc/KSYLive_iOS/wiki/filter)

2. Video Mixer


 SDK cung cấp khả năng mix các layer, overlay các nội dung khác nhau ngoài video từ camera. Thông qua class KSYGPUPicMixer (là subclass của multi-input GPUImageFilter)
Các layer có index từ 0 -> n, với 0 là layer ở dưới dùng. Mỗi layer có thể chỉ định size , vị trí, opacity. Có thể swap cũng như đổi nội dung của layer ở runtime.

*Note: refresh rate của output cuối sẽ là refresh rate của masterLayer 

```swift
guard let streamerKit = streamerKit,
      let previewVMixer = streamerKit.vPreviewMixer,
      let camera = GPUImageVideoCamera(sessionPreset: AVCaptureSession.Preset.hd1280x720.rawValue, cameraPosition: .front),
      let picture = GPUImagePicture(image: UIImage(named: "somePic")),
      let movie = GPUImageMovie(url: URL(string: "videoURL")!)
else { return }

previewVMixer.masterLayer = 0 // camera layer là master layer
// connect layer vào video mixer
camera.addTarget(previewVMixer, atTextureLocation: 0)
picture.addTarget(previewVMixer, atTextureLocation: 1)
movie.addTarget(previewVMixer, atTextureLocation: 2)
// configure layer in mixer
previewVMixer.setPicRect(CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1), ofLayer: 1)
previewVMixer.setPicAlpha(0.5, ofLayer: 1)
// connect mixer to previewview
previewVMixer.addTarget(self.previewView)
```
### Video Buffer Data
Có thể get ra video buffer data ở 2 giai đoạn:
* Khi vừa thu được từ camera:
```swift
streamerKit.videoProcessingCallback = { sampleBuffer in
    // sampleBuffer
}
```
* Sau khi qua xử lý hình ảnh:

```swift
streamerKit.gpuToStr.videoProcessingCallback =  { pixelBuffer, timeInfo in
    // pixelBuffer, timeInfo
}
```

## Audio
### Configure Audio
 Khi stream, có thể sử dụng AVAudioPlayer để phát nhạc (SDK sẽ set category của audio session thành playAndRecord sau khi start preview)
#### Audio Output
 Default nhạc sẽ phát qua tai nghe. Để phát nhạc qua loa có thể setup 1 trong 2 cách:
 ```swift
var opts = audioSession.categoryOptions
do {
    try audioSession.setCategory(audioSession.category, options: [opts, .defaultToSpeaker])
} catch {}
```
Hoặc
```swift
audioSession.bDefaultToSpeaker = true
```
#### Interrupt other Audio
Có thể tắt nhạc nền của app khác khi bắt đầu phát
```swift
audioSession.bInterruptOtherAudio = true
```
####   Bluetooth Headset device
Cho phép dùng tai nghe bluetooth và sử dụng micro
```swift
audioSession.bAllowBluetooth = true
// một số hàm kiểm tra bluetooth/ headset 
AVAudioSession.isBluetoothInputAvaible()
AVAudioSession.switchBluetoothInput(true)
AVAudioSession.isHeadsetInputAvaible()
AVAudioSession.isHeadsetPluggedIn()
```
### Audio Processing

Có 2 module chính trong audio unit của SDK:
* [KSYAUAudioCapture](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYAUAudioCapture.html) thu và xử lý audio từ microphone.
* [KSYBGMPlayer](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYBgmPlayer.html)  trình phát nhạc chạy nền dựa trên AudioQueue.

Có thể nhận callback buffer raw từ micro 
```swift
let aCapDev = streamerKit.aCapDev
aCapDev.audioProcessingCallback = { sample in
    // sample
}
```
#### Mic Volume
```swift
aCapDev.micVolume = 0.5 // từ 0 -> 1.0
```
#### Reverberation
 Có thể tuỳ chỉnh độ vang của mic.
```swift
aCapDev.reverbType = 1
reverbType＝ 0;// OFF
reverbType ＝1;// Phòng thu
reverbType ＝2;// Buổi hoà nhạc
reverbType ＝3;// Karaoke
reverbType ＝4;// Sân khấu nhỏ
```
####  Voice changer
Hiệu ứng giọng nói:
```swift
aCapDev.effectType = .ROBOT
// effect list
.ROBOT
.FEMALE
.MALE
.HEROIC
.NONE
.COUSTOM
```
Với custom option thì có thể set reverb, pitchShift và delay parameter theo nhu cầu:

* Revert:
```swift
aCapDev.setReverbParamID(0, withInValue: 8)

 - 0 kReverb2Param_DryWetMix
 - 1 kReverb2Param_Gain
 - 2 kReverb2Param_MinDelayTime
 - 3 kReverb2Param_MaxDelayTime
 - 4 kReverb2Param_DecayTimeAt0Hz
 - 5 kReverb2Param_DecayTimeAtNyquist
 - 6 kReverb2Param_RandomizeReflections
```
* PitchShift:
```swift
aCapDev.setPitchParamID(0, withInValue: 2)

 - 0 kNewTimePitchParam_Rate
 - 1 kNewTimePitchParam_Pitch
 - 4 kNewTimePitchParam_Overlap
 - 6 kNewTimePitchParam_EnablePeakLocking
```
* Delay:
```swift
aCapDev.setDelayParamID(1, withInValue: 4)

 - 0 kDelayParam_WetDryMix
 - 1 kDelayParam_DelayTime
 - 2 kDelayParam_Feedback
 - 3 kDelayParam_LopassCutoff
```
#### Phát lại Mic
```swift
aCapDev.bPlayCapturedAudio = true
```
#### Noise reduction
```swift
aCapDev.noiseSuppressionLevel = .MEDIUM

// noise reduction levels
.OFF
.LOW
.MEDIUM
.HIGH
.VERYHIGH
```
#### Audio Mixer
Mix âm thanh từ nhiều nguồn, trước khi push stream thông qua KSYAudioMixer:


Có thể enable các nguồn audio:
```swift
streamerKit.aMixer.setTrack(streamerKit.pipTrack, enable: true)
// với default micTrack và bgmTrack được enable

// các track support:
streamerKit.pipTrack
streamerKit.bgmTrack
streamerKit.micTrack
```
#### Stereo 
 SDK hỗ trợ tối đa 2 channel audio:
```swift
audioMixer.bStereo = true
```
*Note:
* Khi push audio mono, không khuyến nghị sử dụng KSYAudioCodec\_AAC\_HE_V2
* Không sử dụng KSYAudioCodec\_AT\_AAC  khi push audio bitrate thấy
### Play background music

 SDK hỗ trợ 2 player để phát nhạc background:
 * [KSYBgmPlayer](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYBgmPlayer.html)
* [KSYMoviePlayerController](http://ksvc.github.io/KSYLive_iOS/doc/html/Classes/KSYMoviePlayerController.html)


KSYBgmPlayer chỉ phát nhạc local, cho phéo nâng giảm tone nhạc. KSYMoviePlayerController cho phép stream nhạc từ internet, không có khả năng nâng hạ tone.
```swift
let player = streamerKit.bgmPlayer
```
#### Background music player configure 
Một số tuỳ chỉnh trên KSYBgmPlayer
```swift
player.startPlayBgm("musicPath", isLoop: true)
player.pauseBgm()
player.resumeBgm()
player.stopPlayBgm()
let currentProcess = player.bgmProcess // từ 0 đến 1
player.bgmVolume = 0.5 // từ 0 đến 1
playerr.bgmPitch = 10 // bgmPitch từ -24 -> 24, default là 0.01
player.playRate = 1 // playrate từ 0.5 -> 2, default là 1.0
```
####  Background music status monitoring
Có thể monitor audio state với notification name: NSNotification.Name.KSYAudioStateDidChange
```swift
@objc func audioDidChange(notification: Notification) {
    guard let kit = streamerKit else { return }
    let stateName = kit.bgmPlayer.getBgmStateName(kit.bgmPlayer.bgmPlayerState)
    switch stateName {
    case "KSYBgmPlayerStatePlaying":
        audioStateLabel.text = "Audio: Playing"
    case "KSYBgmPlayerStatePaused":
        audioStateLabel.text = "Audio: Paused"
    case "KSYBgmPlayerStateStopped":
        audioStateLabel.text = "Audio: Stopped"
    default:
        break
    }
}
```
###  Audio Buffer Data
Có thể get ra buffer audio data trong 2 giai đoạn:
* Khi vừa được thu từ device:
```swift
streamerKit.audioProcessingCallback = { sampleBuffer in
    // sampleBuffer
}
```
* Sau khi được xử lý âm:

```swift
streamerKit.aMixer.audioProcessingCallback = { sampleBuffer in
    // sampleBuffer
}
```
## Push Stream
Sử dụng thuộc tính streamerBase của streamerkit để configure và điều khiển push stream
```swift
let streamerBase = streamerKit.streamerBase
```
### Configure
####  Video/Audio Push
Có thể bật tắt cho phép push video/audio:
```swift 
streamerBase.bWithAudio = true
streamerBase.bWithVideo = true
```
#### Encoding 
SDK cho phép lựa chọn codec cho audio và video
```swift
streamerBase.audioCodec = .AAC
streamerBase.videoCodec = .X264
```
Support Video Codecs:
| Encoder configuration | Encoder name | Remark |
| --- | --- | --- |
| KSYVideoCodec_X264 | h264 software encoder | The CPU usage is higher, but the device compatibility is strong, and the video quality is higher |
| KSYVideoCodec_VT264 | iOS VT264 hardware encoder | CPU usage is lower, some devices do not support |
| KSYVideoCodec_AUTO | Automatically selected by the SDK | Prefer VT264, when not available, automatically switch to software encoder |
| KSYVideoCodec_QY265 | h265 software encoder | The CPU usage is higher, but the device compatibility is strong, and the video quality is higher |

Support Audio Codecs:
| Encoder configuration | Encoder name | Remark |
| --- | --- | --- |
| KSYAudioCodec\_AAC\_HE_V2 | AAC HE V2 Audio Software Encoder | The CPU usage is higher, but the device compatibility is strong and the sound quality is higher (can only accept stereo input data)) |
| KSYAudioCodec\_AAC\_HE | FDK AAC Audio Software Encoder | The CPU usage is higher, but the device compatibility is strong and the sound quality is higher |
| KSYAudioCodec_AAC | FDK AAC Audio Software Encoder | The CPU usage is lower, but the device compatibility is strong, and the sound quality is generally high |
| KSYAudioCodec\_AT\_AAC | iOS comes with audiotoolbox audio encoder | **The CPU usage is lower, and the audio bit rate is set to 64kbps and above, otherwise there will be squeaks** |

###  Bitrate / Framerate
Tuỳ chỉnh bitrate cho video, audio.


Tự động thay đổi bitrate và frameRate dựa trên điều kiện đường truyền mạng với điều chỉnh mode bandwidth estimate
```swift
streamerBase.audiokBPS = 128 // audio bitrate kbps

// video bitrate with bandwidth estimate mode
streamerBase.bwEstimateMode = .estMode_Default
// bitrate range
streamerBase.videoMaxBitrate = 2000
streamerBase.videoMinBitrate = 400
streamerBase.videoInitBitrate = 800
//framerate range
streamerBase.videoFPS = 24
streamerBase.videoMinFPS = 15
streamerBase.videoMaxFPS = 30

// estimate mode list
.estMode_Default // Default
.estMode_Disable // tắt chế độ dynamic bitrate framerate theo bandwidth
.estMode_Negtive // ưu tiên push lưu loát, chất lượng giảm mạnh khi cần
```
###  LiveScene / Coding Performance
Để tối ưu hiệu năng livestream, trước khi stream có thể configure các profile stream 
```swift
// liveScene chỉ support KSYVideoCodec_X264 
streamerBase.liveScene = .showself 
// available liveScene
.game // cho livestream game 
.showself // cho livestream quay host
.default

// recScene chỉ support KSYVideoCodec_X264 
streamerBase.recScene = .constantQuality
// available recScene 
.constantBitRate
.constantQuality

streamerBase.videoEncodePerf = .per_Balance
// availabel videoEncodePerf
.per_Balance // cân bằng
.per_LowPower // giảm cpu tiêu thụ, giảm chất lượng push video
.per_HighPerformance // tăng cpu tiêu thụ, tăng chất lượng push video
```
[-> More Detail](https://github.com/ksvc/KSYLive_iOS/wiki/liveScene)
### Notifications
Notification về state của livestream với notification name: NSNotification.Name.KSYStreamStateDidChange
```swift

@objc func onStreamStateChange(notification: Notification) {
    switch streamerKit?.streamerBase.streamState {
    case .idle:
        streamStateLabel.text = "Idle"
    case .connecting:
        streamStateLabel.text = "Connecting"
    case .connected:
        streamStateLabel.text = "Connected"
    case .disconnecting:
        streamStateLabel.text = "Disconnecting"
    case .error:
        guard let errorCode = streamerKit?.streamerBase.streamErrorCode,
        let errorName = streamerKit?.streamerBase.getKSYStreamErrorCodeName(errorCode) else { return }
        streamStateLabel.text = "Error: \(errorName)"
    default:
        break
    }
}
```
Notifcation giám sát điều kiện mạng với notifcation name: NSNotification.Name.KSYNetStateEvent
```swift
@objc func onNetStateEvent(notification: Notification) {
        guard let streamerKit = streamerKit else { return }
        switch streamerKit.streamerBase.netStateCode {
        case .NONE:
            print("NONE")
        case .SEND_PACKET_SLOW:
            print("SEND_PACKET_SLOW")
        case .EST_BW_RAISE:
            print("EST_BW_RAISE")
        case .EST_BW_DROP:
            print("EST_BW_DROP")
        case .VIDEO_FPS_RAISE:
            print("VIDEO_FPS_RAISE")
        case .VIDEO_FPS_DROP:
            print("VIDEO_FPS_DROP")
        case .KSYAUTHFAILED:
            print("KSYAUTHFAILED")
        case .IN_AUDIO_DISCONTINUOUS:
            print("IN_AUDIO_DISCONTINUOUS")
        case .UNREACHABLE:
            print("UNREACHABLE")
        case .REACHABLE:
            print("REACHABLE")
        default:
            print("default")
        }
    }
```
### Record while streaming
Record khi đang livestream
```swift 
// start record 
streamerBase.startBypassRecord(saveURL)
// stop record
streamerBase.stopBypassRecord()

// check duration record của file đang lưu
let duration: Double = streamerBase.bypassRecordDuration
```
Callback lắng nghe state record:
```swift
streamerBase.bypassRecordStateChange = { state in
    switch state {
    case .idle:
        print("idle")
    case .recording:
        print("recording")
    case .stopped:
        print("stopped")
        self.saveToAlbul(url: saveURL)
    case .error:
        print("error")
    default:
        print("default")
    }
}
```
### Push stream khi app ở background
Cho phép push stream khi app không còn trên foreground (về home hoặc chuyển app foreground)


Chỉ cần mở Capability: Background Modes trong xcode ( check vào Audio, AirPlay, and Picture in Picture)


Có thể dừng hay tiếp tục thu video/audio background khi cần:
```swift
streamerKit.aCapDev.start()
streamerKit.aCapDev.stop()
streamerKit.vCapDev.startCameraCapture()
streamerKit.vCapDev.stopCameraCapture()
```

###  Manual Video/Audio capture

Có thể tự capture video/ audio và xử lý nó thay vì dùng module capture và process có sẵn của SDK hỗ trợ, sau đó sử dụng streamerBase để push stream lên server.


Sau khi tự thu video/audio buffer (AVFoundation), có thể push stream bằng các phương thức có sẵn của StreamerBase:
```swift
// video
streamerBase.processVideoSampleBuffer(sampleBuffer) { isCompelete in

}
// hoặc
streamerBase.processVideoPixelBuffer(pixelBuffer, timeInfo: timeInfo) { isCompelete in

}

// audio
streamerBase.processAudioSampleBuffer(sampleBuffer)
```
### Video / Audio Stream toggle
 Có thể bật tắt video/audio stream:
```swift
streamerKit.streamerBase.bWithAudio = true
streamerKit.streamerBase.bWithVideo = false
```
## Camera Control
 SDK có sẵn hàm hỗ trợ đổi camera position (front back), bật tắt flash.
 ```swift
if streamerKit.switchCamera() {
    print("successfully switch camera")
}

if streamerKit.isTorchSupported() {
    streamerKit.toggleTorch()
}
```
 Có thể refer đến AVCaptureDevice để configure điều khiển camera: White Balance, focal length, focus.  
 ```swift
let cameraDevice = streamerKit.getCurrentCameraDevices()

// exposure
streamerKit.exposure(at: CGPoint(x: 0.5, y: 0.5)) // toạ độ 0-1
// focal length
streamerKit.pinchZoomFactor = 2.0

// white balance mode
if cameraDevice.isWhiteBalanceModeSupported(.autoWhiteBalance) {
    cameraDevice.whiteBalanceMode = .autoWhiteBalance
}
```
## Misc
### Built-in screenshot
SDK hỗ trợ sẵn việc capture screenshot của stream với 3 cách nhận ảnh:
#### Save to File
```swift
streamerKit.streamerBase.takePhoto(withQuality: 0.8, fileName: "screenshot.jpg")
```
#### UIImage from 
```swift
streamerKit.streamerBase.getSnapshotWithCompletion { image in
// image 
}
```
### Picture-in-picture
Có thể lồng nội dung ảnh hay video vào bên trong nội dung video từ camera
Sừ dụng KSYGPUPipStreamerKit, là một subclass của KSYGPUStreamerKit
```swift
let pipStreamerKit = KSYGPUPipStreamerKit(defaultCfg: ())!
pipStreamerKit.startPip(withPlayerUrl: videoURL, bgPic: picURL)
pipStreamerKit.stopPip()
```
Thuộc tính player của pipStreamerKit là [KSYMoviePlayerController](https://github.com/ksvc/KSYLive_iOS/blob/master/prebuilt/include/KSYPlayer/KSYMoviePlayerController.h), có thể điều khiển playback của video pip.
### Background Image Stream
Có thể livestream với video được thay bằng ảnh tĩnh. 
```swift
let bgpStreamerKit = KSYGPUBgmStreamerKit(defaultCfg: ())!
bgpStreamerKit.bgPic = KSYGPUPicture(image: UIImage(named: "pic"))

```

