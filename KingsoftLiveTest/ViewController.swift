//
//  ViewController.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 11/10/2022.
//

import UIKit
import libksygpulive
import Photos
import ZLivestreamSDK

class ViewController: UIViewController {
    
    
    lazy private var liveStreamManager: LiveStreamManager = {
        let manager = KSYLiveStreamManager()
        manager.delegate = self
        return manager
    }()
    
    @IBOutlet weak var previewView: UIView!
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
    
    //private var videoCamera: VideoCamera!
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
    private var streamInfo: ZLSStreamInfo!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        liveStreamManager.videoConfiguration?.setupPreviewView(previewView)
        
        liveStreamManager.prepareForLive()
        
        songLibraryView.alpha = 0
        mixerViewHeight.constant = 0
        //isShowSongLibrary = false
        
        //streamerKit?.setupFilter(filterManager.composedFilter())
        liveStreamManager.videoConfiguration?.filterManager?.reset()
        
        focusView.frame.size = CGSize(width: 80, height: 80)
        
        // filter process
        //filterManager.cameraSize = cameraSize

        // setup recorder
        liveRecorder.delegate = self
        liveRecorder.size = cameraSize
        
        // init zls
        self.initSDK {[weak self] error in
            //guard let `self` = self else { return }
            if let error = error, error.code != ZLSErrorCode.SUCCESS.rawValue {
                print("Init SDK got error: \(error)")
                //self.showError(error)
                return
            }
            print("Init SDK success")
        }
        
        // demo sticker
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [ weak self ] in
            guard let `self` = self else { return }
            print("test filter")
            let stickerPath = Bundle.main.resourcePath?.appending("/stickers/simplebear") ?? ""
            self.liveStreamManager.videoConfiguration?.filterManager?.selectSticker(FilterInfo(path: stickerPath, isFaceDetect: true))
        }
    }
    
    fileprivate func initSDK(completion: ((ZLSError?) -> ())?) {
        //self.showLoading()
        ZLSSDK.shared.initialize(authenKey: AppConfig.AuthenKey,
                                 appID: AppConfig.AppID,
                                 appToken: AppConfig.AppToken,
                                 apiKey: AppConfig.ApiKey,
                                 secretKey: AppConfig.SecretKey) {[weak self] in
//            guard let `self` = self else { return }
//            self.hideLoading()
            completion?(nil)
        } onError: {[weak self] error in
//            guard let `self` = self else { return }
//            self.hideLoading()
            completion?(error)
        }
    }
    
    private func stopLivetream() {
        guard let streamID = streamInfo?.streamID else {
            print("streamInfo is nil")
            return
        }
        ZLSSDK.shared.endLivestream(streamID: streamID) { response in
            print("\(response)")
        } onError: {[weak self] error in
            print("error: \(error)")
//            DispatchQueue.main.async { [weak self] in
//                guard let `self` = self else {
//                    return
//                }
//                self.showError(error)
//            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isShowBeautyConfigure = false
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        let orientation = UIApplication.shared.statusBarOrientation
        liveStreamManager.videoConfiguration?.orientation = orientation
        let saveValue = isShowBeautyConfigure
       isShowBeautyConfigure = saveValue
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "songlib" {
            guard let vc = segue.destination as? SongLibraryViewController else { return }
            vc.delegate = self
            vc.liveStreamManager = liveStreamManager
        }
        
        if segue.identifier == "mixer" {
            guard let vc = segue.destination as? MixerViewController else { return }
            vc.delegate = self
            vc.liveManager = liveStreamManager
        }
    }
    
    @IBAction func tapStartLive(_ sender: Any) {
        guard let streamConfiguration = liveStreamManager.streamConfiguration else { return }
        if streamConfiguration.isStreaming {
            streamConfiguration.stopStream()
            stopLivetream()
            startLiveBtn.setTitle("Start Live", for: .normal)
            if PHPhotoLibrary.authorizationStatus() == .authorized {
                recordBtn.isHidden = true
            }
        } else {
            // zls call
            ZLSSDK.shared.createLivestream { [weak self] streamInfo in
                guard let `self` = self else { return }
                self.streamInfo = streamInfo
                print("\(streamInfo)")
                //UIPasteboard.general.string = streamInfo.downstreamUrls?[1].url
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    //self.streamInfo = streamInfo
                    let urlString = "\(streamInfo.upstreamURL!)/\(streamInfo.streamKey!)"
                    streamConfiguration.startStream(with: URL(string: urlString))
                    self.startLiveBtn.setTitle("Stop Live", for: .normal)
                    self.recordBtn.isHidden = false
                }
            } onError: {[weak self] error in
                guard let `self` = self else { return }
                print("\(error)")
//                self.showError(error)
            }
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
        liveStreamManager.videoConfiguration?.rotateCamera()
    }
    @IBAction func songLibraryTap(_ sender: Any) {
        isShowSongLibrary.toggle()
    }
    
    // MARK: - 3rd-party player
    private func allow3rdPartyPlayer() {
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func didBecomeActive() {
        liveStreamManager.audioConfiguration?.startAudioCapture()
        // run 3rd background music app
    }
    
    // MARK: - Background publish
    
    private func setupBackgroundStream() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func didEnterBackground() {
        liveStreamManager.audioConfiguration?.stopAudioCapture()
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
        //filterManager.grindRatio = CGFloat(sender.value)
    }
    
    @IBAction func whitenSliderDidChange(_ sender: UISlider) {
        //filterManager.whitenRatio = CGFloat(sender.value)
    }
    @IBAction func beautySwitchDidChange(_ sender: UISwitch) {
        //filterManager.isBeautyOn = sender.isOn
        //streamerKit?.setupFilter(filterManager.composedFilter())
        fatalError("not handle")
    }
    
    @IBAction func pigStickerDidChange(_ sender: UISwitch) {
        //filterManager.isPigStickerOn = sender.isOn
        //streamerKit?.setupFilter(filterManager.composedFilter())
        fatalError("not handle")
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
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - CAMERA API (FOCUS, APERTURE)
    
    @IBAction func previewTouch(_ tapReg: UITapGestureRecognizer) {
        //guard let touch = touches.first,
        let viewPoint = tapReg.location(in: tapReg.view)
        let point = convertToPointOfInterestFromViewCoordinates(viewCoordinates: viewPoint, in: tapReg.view!)
        liveStreamManager.cameraController?.focus(at: point)
        liveStreamManager.cameraController?.exposure(at: point)
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
        guard let videoConfiguration = liveStreamManager.videoConfiguration else  { return pointOfInterest }
        
        let apertureSize = videoConfiguration.captureResolution
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
        guard let controller = liveStreamManager.backgroundMusicController else { return }
        if controller.isPlayingMusic {
            controller.stopMusic {
                controller.startBackgroundMusic(with: URL(string: urlString)!)
            }
        } else {
            controller.startBackgroundMusic(with: URL(string: urlString)!)
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

//extension ViewController: GPUImageVideoCameraDelegate {
//    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
//        self.filterManager.configureFaceWidget(sampleBuffer: sampleBuffer)
//        streamerKit?.capToGpu.processSampleBuffer(sampleBuffer)
//    }
//}

extension ViewController: LiveStreamManagerDelegate {
    
    func captureStateChange(_ captureState: CaptureState) {
        
    }
    
    func backgroundMusicStateChange(_ musicState: MusicState) {
        switch musicState {
        case .play:
            audioStateLabel.text = "Audio: Playing"
            songLibaryButton.rotate360Degrees()
        case .pause:
            songLibaryButton.layer.removeAllAnimations()
            audioStateLabel.text = "Audio: Paused"
        case .stop:
            audioStateLabel.text = "Audio: Stopped"
            songLibaryButton.layer.removeAllAnimations()
        }
    }
    
    func streamStateChange(_ streamState: StreamState) {
        switch streamState {
        case .idle:
            streamStateLabel.text = "Idle"
        case .connecting:
            streamStateLabel.text = "Connecting"
        case .connected:
            streamStateLabel.text = "Connected"
        case .disconnecting:
            streamStateLabel.text = "Disconnecting"
        case .error(let name, let code):
            streamStateLabel.text = "Error name: \(name), code: \(code)"
        }
    }
    
    
}
