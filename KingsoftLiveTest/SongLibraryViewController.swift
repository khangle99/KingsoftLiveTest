//
//  SongLibraryViewController.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 12/10/2022.
//

import UIKit
import libksygpulive

protocol SongLibraryViewControllerDelegate: AnyObject {
    func didSelectSong(urlString: String)
}

class SongLibraryViewController: UIViewController {
    
    weak var delegate: SongLibraryViewControllerDelegate?
    weak var streamKit: KSYGPUStreamerKit?
    var isRunning = false

    @IBOutlet weak var hieuthu2SongView: UIStackView!
    @IBOutlet weak var monoSongView: UIStackView!
    @IBOutlet weak var songtungSongView: UIStackView!
    
    @IBOutlet weak var playPaustBtn: UIButton!
    
    @IBOutlet weak var volumeSlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        addTapGesture(view: monoSongView, selector: #selector(songTap))
        addTapGesture(view: songtungSongView, selector: #selector(songTap))
        addTapGesture(view: hieuthu2SongView, selector: #selector(songTap))
    }
    
    func addTapGesture(view: UIView, selector: Selector) {
        let tap = UITapGestureRecognizer(target: self, action: selector)
        view.addGestureRecognizer(tap)
    }
    // MARK: - Library Songs
    @objc func songTap(_ tap: UITapGestureRecognizer) {
        
        // update state
        hieuthu2SongView.subviews.forEach { view in
            view.tintColor = .white
        }
        
        songtungSongView.subviews.forEach { view in
            view.tintColor = .white
        }
        
        monoSongView.subviews.forEach { view in
            view.tintColor = .white
        }
        
        var songName = ""
        switch tap.view?.tag {
        case 1:
            songName = "mono"
            monoSongView.subviews.forEach { view in
                view.tintColor = .orange
            }
        case 2:
            songName = "sontung"
            songtungSongView.subviews.forEach { view in
                view.tintColor = .orange
            }
        case 3:
            songName = "hieuthu2"
            hieuthu2SongView.subviews.forEach { view in
                view.tintColor = .orange
            }
        default:
            return
        }
        guard let songPath = Bundle.main.path(forResource: "beat", ofType: "m4a") else { return }
        self.delegate?.didSelectSong(urlString: songPath)
        
        isRunning = true
        playPaustBtn.setTitle("Pause", for: .normal)
        
        guard let streamKit = streamKit else {
            return
        }

        streamKit.aMixer.setMixVolume(0.5, of: streamKit.bgmTrack)
        streamKit.bgmPlayer.bgmVolume = 0.5
    }
    
    @IBAction func volumeChange(_ sender: UISlider) {
        streamKit?.bgmPlayer.bgmVolume = Double(sender.value)
    }
    
    @IBAction func pushVolumeChange(_ sender: UISlider) {
        guard let streamKit = streamKit else {
            return
        }
        streamKit.aMixer.setMixVolume(sender.value, of: streamKit.bgmTrack)
    }
    

    
    
    @IBAction func playPauseTap(_ sender: Any) {
        guard let kit = streamKit else { return }
        if isRunning {
            isRunning = false
            playPaustBtn.setTitle("Play", for: .normal)
            kit.bgmPlayer.pauseBgm()
        } else {
            isRunning = true
            playPaustBtn.setTitle("Pause", for: .normal)
            kit.bgmPlayer.resumeBgm()
        }
    }
}


extension UILabel {
    open override var tintColor: UIColor! {
        didSet {
            textColor = tintColor
        }
    }
}
