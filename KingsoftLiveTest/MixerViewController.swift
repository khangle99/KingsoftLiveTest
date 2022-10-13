//
//  MixerViewController.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 13/10/2022.
//

import UIKit
import libksygpulive

protocol MixerViewControllerDelegate: AnyObject {
    
}

class MixerViewController: UIViewController {

    weak var delegate: MixerViewControllerDelegate?
    weak var aMixer: KSYAudioMixer?
    weak var aCapDev: KSYAUAudioCapture?
    weak var bgmPlayer: KSYBgmPlayer?
    
    var isAudioCaptur = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        aCapDev?.audioProcessingCallback = { buffer in
            
        }
    }
    
    func startStopAudioCapture() {
        aCapDev?.pauseWithMuteData()
        aCapDev?.resumeCapture()
    }
    
    func selectReverbScene() {
        aCapDev?.reverbType = 0
    }
    
    func selectStereo() {
        aMixer?.bStereo = true
    }
    
    func setNoiseReductionLevel() {
        aCapDev?.noiseSuppressionLevel = .LOW
    }
    
    func setPitchLevel() {
        bgmPlayer?.bgmPitch = 0.01
    }
    
    func voiceChangingScene() {
        aCapDev?.effectType = .NONE
    }
    
    func setEarReturn(_ isOn: Bool) {
        aCapDev?.bPlayCapturedAudio = isOn
    }
    
    func setMicVolume(value: Float) {
        aCapDev?.micVolume = value
    }

}
