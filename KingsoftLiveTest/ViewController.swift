//
//  ViewController.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 11/10/2022.
//

import UIKit
import libksygpulive
import Photos

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: GPUImageView!
    private var cameraSize = CGSize(width: 720, height: 1280)
    let streamerKit = KSYGPUStreamerKit(defaultCfg: ())
    
    @IBOutlet weak var rectImageView: UIImageView!
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var audioStateLabel: UILabel!
    
    @IBOutlet weak var streamStateLabel: UILabel!
    @IBOutlet weak var startLiveBtn: UIButton!
    
    private var cameraPosition: AVCaptureDevice.Position = .front
    @IBOutlet weak var focusView: UIImageView!
    
    @IBOutlet weak var songLibaryButton: UIButton!
    @IBOutlet weak var songLibraryView: UIView!
    private var openCV: OpenCVWrapper!
    
    private var videoCamera: VideoCamera!
    private var isShowSongLibrary = false {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.songLibraryView.alpha = self.isShowSongLibrary ? 1 : 0
            }
        }
    }
    
    // filter
    @IBOutlet weak var filterView: UIView!
    
    @IBOutlet weak var filterViewBottom: NSLayoutConstraint!
    
    private var filterManager = FilterManager.shared
    
    private var isShowBeautyConfigure: Bool = false {
        didSet {
            if isShowBeautyConfigure {
                self.filterViewBottom.constant = 0
            } else {
                self.filterViewBottom.constant = -(filterView.frame.height + view.safeAreaInsets.bottom)
            }
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        }
    }
    // recorder
    private var liveRecorder = LiveRecorder()
    
    func getDimension(_ sz: CGSize, byOrientation ori: UIInterfaceOrientation) -> CGSize {
        var outSz = sz
        if ori == .portraitUpsideDown || ori == .portrait {
            outSz.height = max(sz.width, sz.height);
            outSz.width  = min(sz.width, sz.height);
        }
        else  {
            outSz.height = min(sz.width, sz.height);
            outSz.width  = max(sz.width, sz.height);
        }
        return outSz;
    }
    
    func calcCropRect(_ camSz: CGSize, to outSz: CGSize) -> CGRect {
        let x = (camSz.width  - outSz.width )/2/camSz.width;
        let y = (camSz.height - outSz.height)/2/camSz.height;
        let wdt = outSz.width/camSz.width;
        let hgt = outSz.height/camSz.height;
        return CGRect(x: x, y: y, width: wdt, height: hgt)
    }
    
    func calcCropSize(_ inSz: CGSize, to targetSz: CGSize) -> CGSize {
        let preRatio = targetSz.width / targetSz.height;
        var cropSz = inSz; // set width
        cropSz.height = cropSz.width / preRatio;
        if (cropSz.height > inSz.height){
            cropSz.height = inSz.height; // set height
            cropSz.width  = cropSz.height * preRatio;
        }
        return cropSz;
    }
    
    func updatePreDimension() {
        guard let streamerKit = streamerKit else { return }
        streamerKit.previewDimension = getDimension(streamerKit.previewDimension, byOrientation: streamerKit.videoOrientation)
        var inSz = streamerKit.captureDimension()
        inSz = getDimension(inSz, byOrientation: .portrait)
        let cropSz = calcCropSize(inSz, to: streamerKit.previewDimension)
        guard let capToGPU = streamerKit.capToGpu else { return }
        capToGPU.cropRegion = calcCropRect(inSz, to: cropSz)
        capToGPU.outputRotation = kGPUImageNoRotation
        capToGPU.forceProcessing(at: streamerKit.previewDimension)
    }
    
    func updateStrDimension(orie: UIInterfaceOrientation) {
        guard let streamerKit = streamerKit,
              let gpuToStream = streamerKit.gpuToStr else { return }
        let dimension = streamerKit.streamDimension
        streamerKit.streamDimension = getDimension(dimension, byOrientation: orie)
        
        gpuToStream.bCustomOutputSize = true
        gpuToStream.outputSize = dimension
        let preSz = getDimension(streamerKit.previewDimension, byOrientation: orie)
        let cropSz = calcCropSize(preSz, to: dimension)
        gpuToStream.cropRegion = calcCropRect(preSz, to: cropSz)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        videoCamera = VideoCamera(sessionPreset: AVCaptureSession.Preset.hd1280x720.rawValue, cameraPosition: .front, useYuv: false)
        videoCamera.horizontallyMirrorFrontFacingCamera = true
        
        updatePreDimension()
        updateStrDimension(orie: .portrait)
        
        videoCamera.startCapture()
        videoCamera.frameRate = 24
        videoCamera.delegate = self
        
        songLibraryView.alpha = 0
        mixerViewHeight.constant = 0
        //isShowSongLibrary = false
        streamerKit?.streamerBase.videoCodec = .X264
        streamerKit?.streamerBase.audioCodec = .AAC
        streamerKit?.capturePixelFormat = kCVPixelFormatType_32BGRA
        streamerKit?.videoFPS = 24
        
        // configure performance
        streamerKit?.streamerBase.liveScene = .showself
        streamerKit?.streamerBase.recScene = .constantBitRate
        streamerKit?.streamerBase.videoEncodePerf = .per_Balance
        
        streamerKit?.setupFilter(filterManager.composedFilter())
        
        streamerKit?.streamerBase.bwEstimateMode = .estMode_Default
        streamerKit?.cameraPosition = cameraPosition
        streamerKit?.streamDimension = cameraSize
        
        observeBGM()
        handleRouteInterrupt()
        observeStreamState()
        
        focusView.frame.size = CGSize(width: 80, height: 80)
        
        // filter process
        filterManager.cameraSize = cameraSize
 
        previewView.fillMode = kGPUImageFillModeStretch
        streamerKit?.vPreviewMixer.addTarget(previewView)
        streamerKit?.aCapDev.start()
        
        
        // setup recorder
        liveRecorder.delegate = self
        liveRecorder.size = cameraSize
    }
    
    private func observeBGM() {
        NotificationCenter.default.addObserver(self, selector: #selector(audioDidChange(notification:)), name: NSNotification.Name.KSYAudioStateDidChange, object: nil)
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
    
    @objc func audioDidChange(notification: Notification) {
        guard let kit = streamerKit else { return }
        let stateName = kit.bgmPlayer.getBgmStateName(kit.bgmPlayer.bgmPlayerState)
        print("===name: \(stateName)")
        
        // KSYBgmPlayerStatePlaying / KSYBgmPlayerStatePaused / KSYBgmPlayerStateStopped
        
        switch stateName {
        case "KSYBgmPlayerStatePlaying":
            audioStateLabel.text = "Audio: Playing"
            songLibaryButton.rotate360Degrees()
        case "KSYBgmPlayerStatePaused":
            songLibaryButton.layer.removeAllAnimations()
            audioStateLabel.text = "Audio: Paused"
        case "KSYBgmPlayerStateStopped":
            audioStateLabel.text = "Audio: Stopped"
            songLibaryButton.layer.removeAllAnimations()
        default:
            break
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isShowBeautyConfigure = false
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        let orientation = UIApplication.shared.statusBarOrientation
        streamerKit?.videoOrientation = orientation
        let saveValue = isShowBeautyConfigure
       isShowBeautyConfigure = saveValue
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let kit = streamerKit else { return }
        if segue.identifier == "songlib" {
            guard let vc = segue.destination as? SongLibraryViewController else { return }
            vc.delegate = self
            vc.streamKit = kit
        }
        
        if segue.identifier == "mixer" {
            guard let vc = segue.destination as? MixerViewController else { return }
            vc.delegate = self
            vc.aMixer = kit.aMixer
            vc.aCapDev = kit.aCapDev
            vc.bgmPlayer = kit.bgmPlayer
        }
    }
    
    @IBAction func tapStartLive(_ sender: Any) {
        guard let kit = streamerKit else { return }
        if kit.streamerBase.isStreaming() {
            kit.streamerBase.stopStream()
            startLiveBtn.setTitle("Start Live", for: .normal)
            if PHPhotoLibrary.authorizationStatus() == .authorized {
                recordBtn.isHidden = true
            }
        } else {
            kit.streamerBase.startStream(URL(string: "rtmp://192.168.150.161/live/hello"))
            startLiveBtn.setTitle("Stop Live", for: .normal)
            recordBtn.isHidden = false
            
        }
    }
    
    private func observeStreamState() {
        NotificationCenter.default.addObserver(self, selector: #selector(onStreamStateChange(notification:)), name: NSNotification.Name.KSYStreamStateDidChange, object: nil)
    }
    
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
    
    @IBAction func outsideTap(_ sender: Any) {
        if isShowSongLibrary {
            isShowSongLibrary = false
        }
        
        if isShowMixer {
            isShowMixer = false
        }
        
        view.endEditing(true)
    }
    @IBAction func tapCameraPositionSwitch(_ sender: Any) {
        if cameraPosition == .front {
            cameraPosition = .back
        } else {
            cameraPosition = .front
        }
//        streamerKit?.cameraPosition = cameraPosition
//        streamerKit?.switchCamera()
        videoCamera.rotateCamera()
    }
    @IBAction func songLibraryTap(_ sender: Any) {
        isShowSongLibrary.toggle()
    }
    
    // MARK: - 3rd-party player
    private func allow3rdPartyPlayer() {
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func didBecomeActive() {
        streamerKit?.aCapDev.start()
        // run 3rd background music app
    }
    
    // MARK: - Background publish
    
    private func setupBackgroundStream() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func didEnterBackground() {
        streamerKit?.aCapDev.stop()
    }

    
    
    // MARK: - Mixer
    
    @IBOutlet weak var mixerViewHeight: NSLayoutConstraint!
    
    private var isShowMixer = false  {
        didSet {
            mixerViewHeight.constant = isShowMixer ? 400 : 0
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
                self.view.layoutIfNeeded()
            }
        }
    }
    @IBAction func mixerTap(_ sender: Any) {
        isShowMixer.toggle()
    }
    
    // MARK: - Filter
    @IBAction func beautyTap(_ sender: Any) {
        isShowBeautyConfigure.toggle()
    }
    
    @IBAction func grindSliderDidChange(_ sender: UISlider) {
        filterManager.grindRatio = CGFloat(sender.value)
    }
    
    @IBAction func whitenSliderDidChange(_ sender: UISlider) {
        filterManager.whitenRatio = CGFloat(sender.value)
    }
    @IBAction func beautySwitchDidChange(_ sender: UISwitch) {
        filterManager.isBeautyOn = sender.isOn
        streamerKit?.setupFilter(filterManager.composedFilter())
    }
    
    
    @IBAction func pigStickerDidChange(_ sender: UISwitch) {
        filterManager.isPigStickerOn = sender.isOn
        streamerKit?.setupFilter(filterManager.composedFilter())
    }
    
    // MARK: - Record while push
    
    private var isRecording = false {
        didSet {
            rectImageView.isHidden = !isRecording
            onRecordOptionChange(isRecording)
        }
    }
    
    @IBAction func recordTap(_ sender: Any) {
        isRecording.toggle()
    }
    
    private var recordFileURL: URL?
    private var pixelBufferInput: YUGPUImageCVPixelBufferInput!
    
    private func onRecordOptionChange(_ shouldRecord: Bool) {
        if shouldRecord {
            pixelBufferInput = YUGPUImageCVPixelBufferInput()
            let documentDirectoryUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            guard let fileURL = documentDirectoryUrl?.appendingPathComponent("hello.mp4") else { return }

            deleteFile(url: fileURL)
            recordFileURL = fileURL
            liveRecorder.recordFileURL = fileURL
            // adapt ksylive pixelBuffer
            streamerKit?.gpuToStr.videoProcessingCallback = { [weak self] buffer, time in
                self?.pixelBufferInput.processCVPixelBuffer(buffer, frameTime: time)
            }

            liveRecorder.startRecord(gpuImageOutput:pixelBufferInput)
        } else {
            liveRecorder.finishRecord()
        }
    }
    
    private func deleteFile(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch _ {
                
            }
        }
    }
    
    private func saveToAlbum(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { saved, error in
            if saved {
                DispatchQueue.main.sync {
                    let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                    let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alertController.addAction(defaultAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - CAMERA API (FOCUS, APERTURE)
    
    @IBAction func previewTouch(_ tapReg: UITapGestureRecognizer) {
        //guard let touch = touches.first,
        guard let kit = streamerKit else { return }
        let viewPoint = tapReg.location(in: tapReg.view)
        let point = convertToPointOfInterestFromViewCoordinates(viewCoordinates: viewPoint, in: tapReg.view!)
        kit.exposure(at: point)
        kit.focus(at: point)
        focusView.center = viewPoint
        focusView.transform = .init(scaleX: 1.5, y: 1.5)
        focusView.alpha = 1
        
        UIView.animate(withDuration: 1.0, animations: {
            self.focusView.transform = .identity
        }, completion: { _ in
            self.focusView.alpha = 0
        })
  
    }
    
    private func convertToPointOfInterestFromViewCoordinates(viewCoordinates: CGPoint, in view: UIView) -> CGPoint {
        var pointOfInterest = CGPoint.init(x: 0.5, y: 0.5)
        let frameSize = view.frame.size
        guard let kit = streamerKit else {
            return pointOfInterest
        }
        let apertureSize = kit.captureDimension()
        let point = viewCoordinates
        let apertureRatio = apertureSize.height / apertureSize.width
        let viewRatio = frameSize.width / frameSize.height
        var xc: CGFloat = 0.5
        var yc: CGFloat = 0.5
        
        if viewRatio > apertureRatio {
            let y2 = frameSize.height
            let x2 = frameSize.height * apertureRatio
            let x1 = frameSize.width
            let blackBar = (x1 - x2) / 2
            if point.x >= blackBar && point.x <= blackBar + x2 {
                
                xc = point.y / y2
                yc = CGFloat(1.0) - ((point.x - blackBar) / x2)
            }
        } else {
            let y2 = frameSize.width / apertureRatio
            let y1 = frameSize.height
            let x2 = frameSize.width
            let blackBar = (y1 - y2) / 2
            if point.y >= blackBar && point.y <= blackBar + y2 {
                xc = ((point.y - blackBar) / y2)
                yc = 1.0 - (point.x / x2)
            }
        }
        pointOfInterest = CGPoint.init(x: xc, y: yc)
        
        return pointOfInterest
    }
    
}

extension ViewController: SongLibraryViewControllerDelegate {
    func didSelectSong(urlString: String) {
        if let isRunning = streamerKit?.bgmPlayer.isRunning, isRunning == true {
            streamerKit?.bgmPlayer.stopPlayBgm({
                self.streamerKit?.bgmPlayer.startPlayBgm(urlString, isLoop: false)
            })
        } else {
            streamerKit?.bgmPlayer.startPlayBgm(urlString, isLoop: false)
        }
    }
}

extension ViewController: LiveRecorderDelegate {
    func recordCompeleted() {
        guard let url = recordFileURL else { return }
        self.saveToAlbum(url: url)
    }
    
    func recordFailWithError(_ error: Error) {
        
    }
}

extension ViewController: MixerViewControllerDelegate {
    
}

extension ViewController: GPUImageVideoCameraDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
        self.filterManager.configureFaceWidget(sampleBuffer: sampleBuffer)
        streamerKit?.capToGpu.processSampleBuffer(sampleBuffer)
    }
}
