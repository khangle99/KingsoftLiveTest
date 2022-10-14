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
    weak var aMixer: KSYAudioMixer!
    weak var aCapDev: KSYAUAudioCapture!
    weak var bgmPlayer: KSYBgmPlayer!
    
    
    @IBOutlet weak var noiseReductionStack: UIStackView!
    @IBOutlet weak var reverbStack: UIStackView!
    @IBOutlet weak var audioEffectStack: UIStackView!
    @IBOutlet weak var earReturnBtn: UIButton!
    @IBOutlet weak var stereoBtn: UIButton!
    var isAudioCaptur = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setSelectState(view: earReturnBtn, isSelected: true)
        setSelectState(view: stereoBtn, isSelected: true)
        noiseReductionStack.subviews.forEach { view in
            view.layer.cornerRadius = 6
        }
        
        reverbStack.subviews.forEach { view in
            view.layer.cornerRadius = 6
        }
        
        audioEffectStack.subviews.forEach { view in
            view.layer.cornerRadius = 6
        }
        
//        aCapDev?.audioProcessingCallback = { buffer in
//            
//        }
    }
    
    func startStopAudioCapture() {
        aCapDev?.pauseWithMuteData()
        aCapDev?.resumeCapture()
    }
    
    func selectReverbScene() {
        aCapDev?.reverbType = 0
    }
    
    
//    - 0 off
//     - 1 recording studio
//     - 2 ktv
//     - 3 small stages
//     - 4 concerts
    @IBAction func selectReverbScene(_ sender: UIButton) {
        reverbStack.subviews.forEach { view in
            setSelectState(view: view, isSelected: false)
        }
        
        switch sender.tag {
        case 7:
            aCapDev.reverbType = 0
        case 8:
            aCapDev.reverbType = 1
        case 9:
            aCapDev.reverbType = 2
        case 10:
            aCapDev.reverbType = 3
        case 11:
            aCapDev.reverbType = 4
        default:
            return
        }
        setSelectState(view: sender, isSelected: true)
    }

    
    @IBAction func selectEffect(_ sender: UIButton) {
        audioEffectStack.subviews.forEach { view in
            setSelectState(view: view, isSelected: false)
        }
        
        switch sender.tag {
        case 1:
            aCapDev.effectType = .NONE
        case 2:
            aCapDev.effectType = .MALE
        case 3:
            aCapDev.effectType = .FEMALE
        case 4:
            aCapDev.effectType = .HEROIC
        case 5:
            aCapDev.effectType = .ROBOT
        case 6:
            aCapDev.effectType = .COUSTOM
        default:
            return
        }
        setSelectState(view: sender, isSelected: true)
    }
    
    private func setSelectState(view: UIView, isSelected: Bool) {
        UIView.animate(withDuration: 0.15) {
            view.backgroundColor = isSelected ? .orange : .clear
            view.tintColor = isSelected ? .white : .orange
        }
    }
    
    
    @IBAction func selectNRLevel(sender: UIButton) {
        noiseReductionStack.subviews.forEach { view in
            setSelectState(view: view, isSelected: false)
        }
        
        switch sender.titleLabel?.text {
        case "Off":
            aCapDev.noiseSuppressionLevel = .OFF
        case "Low":
            aCapDev.noiseSuppressionLevel = .LOW
        case "Medium":
            aCapDev.noiseSuppressionLevel = .MEDIUM
        case "High":
            aCapDev.noiseSuppressionLevel = .HIGH
        case "Very high":
            aCapDev.noiseSuppressionLevel = .VERYHIGH
        default:
            return
        }
        setSelectState(view: sender, isSelected: true)
    }
    
    @IBAction func pitchChange(_ sender: UISlider) {
        bgmPlayer.bgmPitch = Double(sender.value)
    }
    
    @IBAction func micSlider(_ sender: UISlider) {
        aCapDev.micVolume = sender.value
    }
    
    @IBAction func stereoTap(_ sender: Any) {
        aMixer.bStereo.toggle()
        if aMixer.bStereo {
            setSelectState(view: stereoBtn, isSelected: true)
        } else {
            setSelectState(view: stereoBtn, isSelected: false)
        }
    }
    
    @IBAction func earReturnTap(_ sender: Any) {
        print("before \(aCapDev.bPlayCapturedAudio)")
       
        print(aCapDev.bPlayCapturedAudio)
        if aCapDev.bPlayCapturedAudio {
            aCapDev.bPlayCapturedAudio = false
            setSelectState(view: earReturnBtn, isSelected: true)
        } else {
            aCapDev.bPlayCapturedAudio = true
            setSelectState(view: earReturnBtn, isSelected: false)
        }
    }
}
