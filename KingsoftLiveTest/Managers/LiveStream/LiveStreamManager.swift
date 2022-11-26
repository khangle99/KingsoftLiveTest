//
//  LiveStreamManager.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 24/11/2022.
//

import Foundation
import AVFoundation
import UIKit

protocol LiveStreamManagerDelegate: AnyObject {
    func captureStateChange(_ captureState: CaptureState)
    func backgroundMusicStateChange(_ musicState: MusicState)
    func streamStateChange(_ streamState: StreamState)
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!)
    func gpuOutputPixelBuffer(_ pixelBuffer: CVPixelBuffer, with time: CMTime)
}

extension LiveStreamManagerDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {}
    func gpuOutputPixelBuffer(_ pixelBuffer: CVPixelBuffer, with time: CMTime) {}
}

protocol LiveStreamManager: AnyObject {
    var delegate: LiveStreamManagerDelegate? { get set }
    
    // video
    var videoConfiguration: LiveVideoConfiguration? { get set }
    
    func prepareForLive()
    
    // audio
    var audioSession: AVAudioSession? { get set }
    var audioConfiguration: LiveAudioConfiguration? { get set }
    
    // background music
    var backgroundMusicController: LiveBackgroundMusicController? { get set }
    
    // publish stream
    var streamConfiguration: LiveStreamConfiguration? { get set }
    
    // camera control
    var cameraController: LiveCameraController? { get set }
}

// MARK: CAMERA
protocol LiveCameraController: AnyObject {
    func exposure(at point: CGPoint)
    func focus(at point: CGPoint)
    var isTorchOn: Bool { get set }
}

extension LiveCameraController {
    func exposure(at point: CGPoint) {}
    func focus(at point: CGPoint) {}
}

// MARK: BACKGROUND MUSIC
protocol LiveBackgroundMusicController: AnyObject {
    func startBackgroundMusic(with url: URL)
    func pauseMusic()
    func resumeMusic()
    func stopMusic(_ completion: (() -> Void)?)
    var currentProgress: Double { get set } // set for seek
    var musicVolume: Double { get set } // 0 -> 1
    var pushMusicVolume: Double { get set }
    var musicPitch: Double { get set } // -24 -> 24
    var musicPlayRate: Double { get set } // 0.5 -> 2
    var isMusicOnSpeaker: Bool { get set }
    var isInterruptOtherAudio: Bool { get set }
    var isPlayingMusic: Bool { get }
    // TODO: mixer
}

// MARK: VIDEO
protocol KSYLiveVideoConfigurationDelegate: AnyObject {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!)
    func gpuOutputPixelBuffer(_ pixelBuffer: CVPixelBuffer, with time: CMTime)
}

protocol LiveVideoConfiguration: AnyObject {
    var delegate: KSYLiveVideoConfigurationDelegate? { get set }
    var capturePreset: AVCaptureSession.Preset { get set }
    var streamResolution: CGSize { get set }
    var previewResolution: CGSize { get set }
    var captureResolution: CGSize { get set }
    var frameRate: Int { get set }
    var orientation: UIInterfaceOrientation { get set }
    var isMirrorPreview: Bool { get set }
    var isMirrorStream: Bool { get set }
    var cameraPosition: AVCaptureDevice.Position { get set }
    func rotateCamera()
    func setupPreviewView(_ container: UIView)
    
    // filter module
    var filterManager: LiveFilterManager? { get set }
}

// MARK: AUDIO
protocol LiveAudioConfiguration: AnyObject {
    var micVolume: Double { get set } // 0 -> 1
    var reverbrationLevel: Int { get set } // 0 -> 4
    var isHeadphoneEarBack: Bool { get set }
    var noiseReductionLevel: Int { get set } // 0 -> 4
    var isStereo: Bool { get set }
    func startAudioCapture()
    func stopAudioCapture()
}

// MARK: PUBLISH STREAM
protocol LiveStreamConfiguration {
    var videoBitrate: Int { get set }
    var audioBitrate: Int { get set }
    var isPublishAudio: Bool { get set }
    var isPublishVideo: Bool { get set }
    
    // encoding
    var videoCodec: VideoCodec { get set }
    var audioCodec: AudioCodec { get set }
    var publishFPS: Int { get set }
    
    // picture video push
    var backgroundPicture: UIImage? { get set }
    var isPureAudioStream: Bool { get set } // khong the tat khi dang stream, su dung backgroundPicture thay the
    var isMuted: Bool { get set }
    var isStreaming: Bool { get }
    
    func startStream(with url: URL!)
    func stopStream()
}

// MARK: ENUMS
enum VideoCodec {
    case h264soft
    case h265soft
    case vt264hard
    case auto
}

enum AudioCodec {
    case aac
    case aac_he
    case aac_he2
    case at_acc
}

enum CaptureState {
    case idle
    case capturing
    case authDenied
    case error
}

enum MusicState {
    case play
    case pause
    case stop
}

enum StreamState {
    case idle
    case connecting
    case connected
    case disconnecting
    case error(String, String)
}
