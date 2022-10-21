//
//  LiveRecorder.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 21/10/2022.
//

import Foundation
import GPUImage

protocol LiveRecorderDelegate: AnyObject {
    func recordCompeleted()
    func recordFailWithError(_ error: Error)
}

class LiveRecorder: NSObject {
    
    weak var delegate: LiveRecorderDelegate?
    
    var recordFileURL: URL?
    private var movieWriter: GPUImageMovieWriter?
    
    var size = CGSize(width: 720, height: 1280)
    
    private weak var videoInput: GPUImageOutput?
    
    func startRecord(gpuImageOutput: GPUImageOutput) {
        videoInput = gpuImageOutput
        guard let recordFileURL = recordFileURL else {
            return
        }

        movieWriter = GPUImageMovieWriter(movieURL: recordFileURL, size: size)
        movieWriter?.shouldPassthroughAudio = true
        movieWriter?.delegate = self
        gpuImageOutput.audioEncodingTarget = movieWriter
        
        gpuImageOutput.addTarget(movieWriter)
        movieWriter?.startRecording()
    }
    
    func finishRecord() {
        videoInput?.removeTarget(movieWriter)
        movieWriter?.finishRecording {
                print("Finish record")
        }
    }
}
extension LiveRecorder: GPUImageMovieWriterDelegate {
    func movieRecordingCompleted() {
        print("Compelete record")
        delegate?.recordCompeleted()
    }
    
    func movieRecordingFailedWithError(_ error: Error!) {
        print("Record fail with description: \(error.localizedDescription)")
        delegate?.recordFailWithError(error)
    }
}
