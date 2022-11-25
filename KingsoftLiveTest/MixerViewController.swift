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

    weak var liveManager: LiveStreamManager!
    
    
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
//        aCapDev?.pauseWithMuteData()
//        aCapDev?.resumeCapture()
        //TODO: FIX
    }
    
    
//    - 0 off
//     - 1 recording studio
//     - 2 ktv
//     - 3 small stages
//     - 4 concerts
    @IBAction func selectReverbScene(_ sender: UIButton) {
        guard let configuration = liveManager.audioConfiguration else { return }
        reverbStack.subviews.forEach { view in
            setSelectState(view: view, isSelected: false)
        }
        
        switch sender.tag {
        case 7:
            configuration.reverbrationLevel = 0
        case 8:
            configuration.reverbrationLevel = 1
        case 9:
            configuration.reverbrationLevel = 2
        case 10:
            configuration.reverbrationLevel = 3
        case 11:
            configuration.reverbrationLevel = 4
        default:
            return
        }
        setSelectState(view: sender, isSelected: true)
    }

    
    @IBAction func selectEffect(_ sender: UIButton) {
    }
    
    private func setSelectState(view: UIView, isSelected: Bool) {
        UIView.animate(withDuration: 0.15) {
            view.backgroundColor = isSelected ? .orange : .clear
            view.tintColor = isSelected ? .white : .orange
        }
    }
    
    
    @IBAction func selectNRLevel(sender: UIButton) {
        guard let configuration = liveManager.audioConfiguration else { return }
        noiseReductionStack.subviews.forEach { view in
            setSelectState(view: view, isSelected: false)
        }
        
        switch sender.titleLabel?.text {
        case "Off":
            configuration.noiseReductionLevel = -1
        case "Low":
            configuration.noiseReductionLevel = 0
        case "Medium":
            configuration.noiseReductionLevel = 1
        case "High":
            configuration.noiseReductionLevel = 2
        case "Very high":
            configuration.noiseReductionLevel = 3
        default:
            return
        }
        setSelectState(view: sender, isSelected: true)
    }
    
    @IBAction func pitchChange(_ sender: UISlider) {
        liveManager.backgroundMusicController?.musicPitch = Double(sender.value)
    }
    
    @IBAction func micSlider(_ sender: UISlider) {
        liveManager.audioConfiguration?.micVolume = Double(sender.value)
    }
    
    @IBAction func stereoTap(_ sender: Any) {
        guard let configuration = liveManager.audioConfiguration else { return }
        if configuration.isStereo {
            configuration.isStereo = true
            setSelectState(view: stereoBtn, isSelected: true)
        } else {
            configuration.isStereo = false
            setSelectState(view: stereoBtn, isSelected: false)
        }
    }
    
    @IBAction func earReturnTap(_ sender: Any) {
        guard let configuration = liveManager.audioConfiguration else { return }
        print("before \( configuration.isHeadphoneEarBack)")
       
        if configuration.isHeadphoneEarBack {
            configuration.isHeadphoneEarBack = false
            setSelectState(view: earReturnBtn, isSelected: true)
        } else {
            configuration.isHeadphoneEarBack = true
            setSelectState(view: earReturnBtn, isSelected: false)
        }
    }
}
