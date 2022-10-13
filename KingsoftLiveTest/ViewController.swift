//
//  ViewController.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 11/10/2022.
//

import UIKit
import GPUImage
import libksygpulive

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    let streamerKit = KSYGPUStreamerKit(defaultCfg: ())
    
    @IBOutlet weak var audioStateLabel: UILabel!
    @IBOutlet weak var startLiveBtn: UIButton!
    
    @IBOutlet weak var songLibaryButton: UIButton!
    private var cameraPosition: AVCaptureDevice.Position = .front
    
    @IBOutlet weak var songLibraryView: UIView!
    private var isShowSongLibrary = false {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.songLibraryView.alpha = self.isShowSongLibrary ? 1 : 0
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        songLibraryView.alpha = 0
        mixerViewHeight.constant = 0
        //isShowSongLibrary = false
        streamerKit?.streamerBase.videoCodec = .X264
        streamerKit?.streamerBase.audioCodec = .AAC
        
        
        streamerKit?.streamerBase.bwEstimateMode = .estMode_Default
        streamerKit?.cameraPosition = cameraPosition
        streamerKit?.streamDimension = CGSize(width: 1280, height: 720)
        streamerKit?.startPreview(previewView)
        observeBGM()
        handleRouteInterrupt()
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
                DispatchQueue.main.sync {
                    //self.play()
                    kit.aMixer.setTrack(kit.bgmTrack, enable: true)
                    kit.aCapDev.bPlayCapturedAudio = true
                }
                break
            }
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                    print("headphones disconnected")
                    DispatchQueue.main.sync {
                        kit.aMixer.setTrack(kit.bgmTrack, enable: false)
                        kit.aCapDev.bPlayCapturedAudio = false
                        //self.pause()
                    }
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
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        let orientation = UIApplication.shared.statusBarOrientation
        streamerKit?.videoOrientation = orientation
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
        } else {
            kit.streamerBase.startStream(URL(string: "rtmp://192.168.1.8/live/hello"))
            startLiveBtn.setTitle("Stop Live", for: .normal)
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
        streamerKit?.cameraPosition = cameraPosition
        streamerKit?.switchCamera()
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

extension ViewController: MixerViewControllerDelegate {
    
}


extension UIView {
    func rotate360Degrees(duration: CFTimeInterval = 3) {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(Double.pi * 2)
        rotateAnimation.isRemovedOnCompletion = false
        rotateAnimation.duration = duration
        rotateAnimation.repeatCount=Float.infinity
        self.layer.add(rotateAnimation, forKey: nil)
    }
}
