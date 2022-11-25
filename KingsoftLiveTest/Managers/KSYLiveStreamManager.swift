//
//  KSYLiveStreamManager.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 24/11/2022.
//

import Foundation
import libksygpulive

class KSYLiveStreamManager: NSObject, LiveStreamManager {
    
    lazy var streamConfiguration: LiveStreamConfiguration? = {
        let configuration = KSYLiveStreamConfiguration(streamerKit: streamerKit)
        return configuration
    }()
    
    lazy var videoConfiguration: LiveVideoConfiguration? = {
        let configuration = KSYLiveVideoConfiguration(streamerKit: streamerKit)
        configuration.delegate = self
        return configuration
    }()
    
    lazy var audioConfiguration: LiveAudioConfiguration? = {
        let configuration = KSYLiveAudioConfiguration(streamerKit: streamerKit)
        return configuration
    }()
    
    lazy var backgroundMusicController: LiveBackgroundMusicController? = {
        let control = KSYLiveBackgroundMusicController(streamerKit: streamerKit)
        return control
    }()
    
    lazy var cameraController: LiveCameraController? = {
        let control = KSYLiveCameraController(streamerKit: streamerKit)
        return control
    }()

    var delegate: LiveStreamManagerDelegate?
    
    private let streamerKit = KSYGPUStreamerKit(defaultCfg: ())
    
    var audioSession: AVAudioSession?

    /// configure KSYLive streambase
    func prepareForLive() {
        guard let streamerKit = streamerKit else { return }

        streamerKit.streamerBase.bwEstimateMode = .estMode_Default

        // configure performance
        streamerKit.streamerBase.liveScene = .showself
        streamerKit.streamerBase.recScene = .constantBitRate
        streamerKit.streamerBase.videoEncodePerf = .per_Balance
        
        handleRouteInterrupt()
        observeBGM()
        observeStreamState()
    }
    
    func prepareForRecord() {
        streamerKit?.gpuToStr.videoProcessingCallback = { [weak self] pixBuff, time in
            guard let `self` = self,
            let buffer = pixBuff else {
                return
            }
            self.delegate?.gpuOutputPixelBuffer(buffer, with: time)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("deinit ksy livestream manager")
    }
    
    // MARK: Notification
    private func observeStreamState() {
        NotificationCenter.default.addObserver(self, selector: #selector(onStreamStateChange(notification:)), name: NSNotification.Name.KSYStreamStateDidChange, object: nil)
    }
    
    @objc func onStreamStateChange(notification: Notification) {
        switch streamerKit?.streamerBase.streamState {
        case .idle:
            delegate?.streamStateChange(.idle)
            
        case .connecting:
            delegate?.streamStateChange(.connecting)
        case .connected:
            delegate?.streamStateChange(.connected)
        case .disconnecting:
            delegate?.streamStateChange(.disconnecting)
        case .error:
            guard let errorCode = streamerKit?.streamerBase.streamErrorCode,
                  let errorName = streamerKit?.streamerBase.getKSYStreamErrorCodeName(errorCode) else { return }
            delegate?.streamStateChange(.error(errorName, errorCode.rawValue.description))
        default:
            break
        }
    }
    
    private func handleRouteInterrupt() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(handleInterruption),
                                       name: AVAudioSession.interruptionNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(handleRouteChange),
                                       name: AVAudioSession.routeChangeNotification,
                                       object: nil)
    }
    
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue),
              let kit = streamerKit else {
            return
        }
        switch reason {
        case .newDeviceAvailable:
            let session = AVAudioSession.sharedInstance()
            for output in session.currentRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                print("headphones connected")
                kit.aMixer.setTrack(kit.bgmTrack, enable: true)
                kit.aCapDev.bPlayCapturedAudio = true
                break
            }
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                    print("headphones disconnected")
                    kit.aMixer.setTrack(kit.bgmTrack, enable: false)
                    kit.aCapDev.bPlayCapturedAudio = false
                    break
                }
            }
        default: ()
        }
    }
    
    private func observeBGM() {
        NotificationCenter.default.addObserver(self, selector: #selector(audioDidChange(notification:)), name: NSNotification.Name.KSYAudioStateDidChange, object: nil)
    }
    
    @objc func audioDidChange(notification: Notification) {
        guard let kit = streamerKit else { return }
        let stateName = kit.bgmPlayer.getBgmStateName(kit.bgmPlayer.bgmPlayerState)
        print("===name: \(String(describing: stateName))")
        
        // KSYBgmPlayerStatePlaying / KSYBgmPlayerStatePaused / KSYBgmPlayerStateStopped
        
        switch stateName {
        case "KSYBgmPlayerStatePlaying":
            delegate?.backgroundMusicStateChange(.play)
        case "KSYBgmPlayerStatePaused":
            delegate?.backgroundMusicStateChange(.pause)
        case "KSYBgmPlayerStateStopped":
            delegate?.backgroundMusicStateChange(.stop)
        default:
            break
        }
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            print("Interruption began")
            // Interruption began, take appropriate actions
        }
        else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption Ended - playback should resume
                    print("Interruption Ended - playback should resume")
                    //play()
                } else {
                    // Interruption Ended - playback should NOT resume
                    print("Interruption Ended - playback should NOT resume")
                }
            }
        }
    }
    
}

extension KSYLiveStreamManager: KSYLiveVideoConfigurationDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
        
    }
    
    func gpuOutputPixelBuffer(_ pixelBuffer: CVPixelBuffer, with time: CMTime) {
        
    }
    
}

// MARK: -------------------------------------------- Configuration Submodule classes----------------------------------------------------
class KSYLiveVideoConfiguration: NSObject, LiveVideoConfiguration {
    
    var delegate: KSYLiveVideoConfigurationDelegate?
    
    private weak var streamerKit: KSYGPUStreamerKit?
    
    private lazy var videoCamera: VideoCamera = {
        let videoCamera = VideoCamera(sessionPreset: capturePreset.rawValue, cameraPosition: cameraPosition, useYuv: false)
        videoCamera.horizontallyMirrorFrontFacingCamera = isMirrorPreview
        return videoCamera
    }()
    
    private var previewView: GPUImageView = {
        let view = GPUImageView()
        view.fillMode = kGPUImageFillModePreserveAspectRatioAndFill
        return view
    }()
    
    init(streamerKit: KSYGPUStreamerKit?) {
        self.streamerKit = streamerKit
    }
    
    var cameraPosition: AVCaptureDevice.Position = .front {
        didSet {
            streamerKit?.cameraPosition = cameraPosition
        }
    }
    
    var isMirrorPreview: Bool = true {
        didSet {
            streamerKit?.previewMirrored = isMirrorPreview
        }
    }
    var isMirrorStream: Bool = true {
        didSet {
            streamerKit?.streamerMirrored = isMirrorPreview
        }
    }
    
    var orientation: UIInterfaceOrientation = .portrait {
        didSet {
            streamerKit?.videoOrientation = orientation
        }
    }
    var frameRate: Int = 24 {
        didSet {
            streamerKit?.videoFPS = Int32(frameRate)
        }
    }
    
    var capturePreset: AVCaptureSession.Preset = .hd1280x720 {
        didSet {
            streamerKit?.vCapDev.captureSessionPreset = capturePreset.rawValue
        }
    }
    
    var captureResolution: CGSize = CGSize(width: 1280, height: 720)
    
    var previewResolution: CGSize = CGSize(width: 1280, height: 720) {
        didSet {
            streamerKit?.previewDimension = previewResolution
        }
    }
    
    var streamResolution: CGSize = CGSize(width: 1280, height: 720) {
        didSet {
            streamerKit?.streamDimension = streamResolution
        }
    }
    
    func rotateCamera() {
        videoCamera.rotateCamera()
    }
    
    func setupPreviewView(_ container: UIView) {
        guard let streamerKit = streamerKit else { return }
        
        previewView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(previewView)
        container.sendSubviewToBack(previewView)
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: container.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            previewView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            previewView.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        ])
        
        // setup video pineline
        streamerKit.capturePixelFormat = kCVPixelFormatType_32BGRA
        videoCamera.delegate = self
        //streamerKit.vCapDev.captureSessionPreset = AVCaptureSession.Preset.hd1280x720.rawValue
        streamerKit.vPreviewMixer.addTarget(previewView)
        videoCamera.startCapture()
        streamerKit.aCapDev.start()
    }
}

extension KSYLiveVideoConfiguration: GPUImageVideoCameraDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
        delegate?.willOutputSampleBuffer(sampleBuffer)
        streamerKit?.capToGpu.processSampleBuffer(sampleBuffer)
    }
}

class KSYLiveAudioConfiguration: LiveAudioConfiguration {
    
    private weak var streamerKit: KSYGPUStreamerKit?
    
    init(streamerKit: KSYGPUStreamerKit?) {
        self.streamerKit = streamerKit
    }
    
    var micVolume: Double = 0.5 {
        didSet {
            streamerKit?.aCapDev.micVolume = Float32(micVolume)
        }
    }
    
    var isStereo: Bool = true {
        didSet {
            streamerKit?.bStereoAudioStream = isStereo
        }
    }
    
    var noiseReductionLevel: Int = 0 {
        didSet {
            streamerKit?.aCapDev.noiseSuppressionLevel = .init(rawValue: noiseReductionLevel) ?? .OFF
        }
    }
    
    var reverbrationLevel: Int = 0 {
        didSet {
            streamerKit?.aCapDev.reverbType = Int32(reverbrationLevel)
        }
    }
    
    var isHeadphoneEarBack: Bool = true {
        didSet {
            streamerKit?.aCapDev.bPlayCapturedAudio = isHeadphoneEarBack
        }
    }
    
    func startAudioCapture() {
        streamerKit?.aCapDev.start()
    }
    
    func stopAudioCapture() {
        streamerKit?.aCapDev.stop()
    }
}


class KSYLiveBackgroundMusicController: LiveBackgroundMusicController {
    
    private weak var streamerKit: KSYGPUStreamerKit?
    
    init(streamerKit: KSYGPUStreamerKit?) {
        self.streamerKit = streamerKit
    }
    
    
    func startBackgroundMusic(with url: URL) {
        streamerKit?.bgmPlayer.startPlayBgm(url.absoluteString, isLoop: false)
    }
    
    func pauseMusic() {
        streamerKit?.bgmPlayer.pauseBgm()
    }
    
    func resumeMusic() {
        streamerKit?.bgmPlayer.resumeBgm()
    }
    
    func stopMusic(_ completion: (() -> Void)? = nil) {
        streamerKit?.bgmPlayer.stopPlayBgm({
            completion?()
        })
    }
    
    var currentProgress: Double {
        get {
            guard let time =  streamerKit?.bgmPlayer.bgmProcess else { return 0 }
            return Double(time)
        }
        set {
            if let streamerKit = streamerKit {
                streamerKit.bgmPlayer.seek(toProgress: Float(newValue))
            }
        }
    }
    
    var musicVolume: Double = 0.5 {
        didSet {
            streamerKit?.bgmPlayer.bgmVolume = musicVolume
        }
    }
    
    var pushMusicVolume: Double = 0.5 {
        didSet {
            if let kit = streamerKit {
                kit.aMixer.setMixVolume(Float(pushMusicVolume), of: kit.bgmTrack)
            }
            
        }
    }
    
    var musicPitch: Double = 0.01 {
        didSet {
            streamerKit?.bgmPlayer.bgmPitch = musicPitch
        }
    }
    
    
    var musicPlayRate: Double = 1 {
        didSet {
            streamerKit?.bgmPlayer.playRate = musicPlayRate
        }
    }
    
    var isMusicOnSpeaker: Bool = true
    
    var isInterruptOtherAudio: Bool = true {
        didSet {
            // interrupt
        }
    }
    
    var isPlayingMusic: Bool {
        streamerKit?.bgmPlayer.isRunning ?? false
    }
    
    
}

class KSYLiveCameraController: LiveCameraController {
    
    private weak var streamerKit: KSYGPUStreamerKit?
    
    init(streamerKit: KSYGPUStreamerKit?) {
        self.streamerKit = streamerKit
    }
    
    func exposure(at point: CGPoint) {
        streamerKit?.exposure(at: point)
    }
    
    func focus(at point: CGPoint) {
        streamerKit?.focus(at: point)
    }
    
    var isTorchOn: Bool = false {
        didSet {
            // on off flash
        }
    }
    
}

class KSYLiveStreamConfiguration: LiveStreamConfiguration {
    
    private weak var streamerKit: KSYGPUStreamerKit?
    
    init(streamerKit: KSYGPUStreamerKit?) {
        self.streamerKit = streamerKit
    }
    
    var videoBitrate: Int = 3000 {
        didSet {
            streamerKit?.streamerBase.videoMaxBitrate = Int32(videoBitrate)
            streamerKit?.streamerBase.videoMinBitrate = Int32(videoBitrate)
        }
    }
    
    var audioBitrate: Int = 128 {
        didSet {
            streamerKit?.streamerBase.audiokBPS = Int32(audioBitrate)
        }
    }
    
    var isPublishAudio: Bool = true {
        didSet {
            streamerKit?.streamerBase.bWithAudio = isPublishAudio
        }
    }
    
    var isPublishVideo: Bool = true {
        didSet {
            streamerKit?.streamerBase.bWithVideo = isPublishVideo
        }
    }
    
    var videoCodec: VideoCodec = .h264soft {
        didSet {
            switch videoCodec {
            case .h264soft:
                streamerKit?.streamerBase.videoCodec = .X264
            case .h265soft:
                streamerKit?.streamerBase.videoCodec = .QY265
            case .vt264hard:
                streamerKit?.streamerBase.videoCodec = .VT264
            case .auto:
                streamerKit?.streamerBase.videoCodec = .AUTO
            }
            
        }
    }
    
    var audioCodec: AudioCodec = .aac {
        didSet {
            switch audioCodec {
            case .aac:
                streamerKit?.streamerBase.audioCodec = .AAC
            case .aac_he:
                streamerKit?.streamerBase.audioCodec = .AAC_HE
            case .aac_he2:
                streamerKit?.streamerBase.audioCodec = .AAC_HE_V2
            case .at_acc:
                streamerKit?.streamerBase.audioCodec = .AT_AAC
            }
        }
    }
    
    var publishFPS: Int = 24 {
        didSet {
            streamerKit?.streamerBase.videoFPS = Int32(publishFPS)
        }
    }
    
    var backgroundPicture: UIImage?
    
    var isPureAudioStream: Bool = false
    
    var isMuted: Bool = false
    
    var isStreaming: Bool {
        streamerKit?.streamerBase.isStreaming() ?? false
    }
    
    func startStream(with url: URL!) {
        streamerKit?.streamerBase.startStream(url)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func stopStream() {
        streamerKit?.streamerBase.stopStream()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
}
