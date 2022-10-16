//
//  TestViewController.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 15/10/2022.
//

import UIKit
import GPUImage
import libksygpulive
import VideoToolbox
import Vision
class TestViewController: UIViewController {

 
    @IBOutlet weak var previewView: GPUImageView!
    private var videoCamera: GPUImageVideoCamera!
    var isStreaming = false
    var streamKit = KSYGPUStreamerKit(defaultCfg: ())!
    var detector: CIDetector!
    

    let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
        if let results = request.results as? [VNFaceObservation], results.count > 0 {

            print("nose: \(results.first?.landmarks?.nose?.normalizedPoints)")
            
        } else {
            print("did not detect any face")
        }
//        DispatchQueue.init(label: "dd").async {
//
//        }
    })
    let faceDetectionHandler = VNSequenceRequestHandler()
    
    //var streamerBase: KSYStreamerBase!
    
    var camera: GPUImageVideoCamera!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
       // KSYStreamerBase* _streamer = [[KSYStreamerBase alloc] initWithDefaultCfg];
        streamKit.streamerBase.videoCodec = .X264;//视频编码方式
        streamKit.previewDimension = CGSize(width: 640, height: 360)
        streamKit.streamDimension = CGSize(width: 640, height: 360)
//        streamKit.streamerBase.videoFPS   = 15;//视频帧率
//        streamKit.streamerBase.audiokBPS  = 48;   // 音频码率
//        streamKit.streamerBase.videoInitBitrate  = 600; // k bit ps//初始码率
//        streamKit.streamerBase.videoMaxBitrate   = 1000; // k bit ps//最大码率
//        streamKit.streamerBase.videoMinBitrate   = 0;  // k bit ps//最小码率

        detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])

        streamKit.startPreview(previewView)
//        streamKit.streamerBase.bWithAudio = false

        streamKit.streamerBase.streamStateChange = { state in
            print(state.rawValue)
        }
//        streamKit.setupFilter(GPUImageSepiaFilter())
        
        streamKit.gpuToStr.videoProcessingCallback = { pixelBuffer, time in
            guard let buffer = pixelBuffer else { return }
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            let ciimage = CIImage(cvPixelBuffer: buffer)
            var uiimage = UIImage(ciImage: ciimage)
//            DispatchQueue.init(label: "sample").async {
//                try? self.faceDetectionHandler.perform([self.faceDetectionRequest], on: buffer)
//            }
            try? self.faceDetectionHandler.perform([self.faceDetectionRequest], on: buffer)

                

            
            // CIImage
//            let firstFace = self.detector.features(in: ciimage).first
//            if let firstFace = firstFace {
//                 uiimage = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
//                    uiimage.draw(at: .zero)
//                    // Get the Graphics Context
//                    let context = context.cgContext
//
//                    // Set the rectangle outerline-width
//                    context.setLineWidth( 5.0)
//
//                    // Set the rectangle outerline-colour
//                    UIColor.red.set()
//
//                    // Create Rectangle
//                     context.addRect(firstFace.bounds)
//
//                     // Draw
//                     context.strokePath()
//                }
//            }
            
            let processBuffer = self.convertBuffer(from: uiimage)
            self.streamKit.streamerBase.processVideoPixelBuffer(processBuffer, timeInfo: time) { isCompleted in
                if !isCompleted {
                    print("not complete")
                }
            }
            
        }

        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isStreaming = true
            self.streamKit.streamerBase.startStream(URL(string: "rtmp://192.168.1.5/live/hello"))
        }
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation], results.count > 0 {
                    print("did detect \(results.count) face(s)")
                    
                    
                } else {
                    print("did not detect any face")
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    func convertBuffer(from image: UIImage) -> CVPixelBuffer? {
      let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
      var pixelBuffer : CVPixelBuffer?
      let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
      guard (status == kCVReturnSuccess) else {
        return nil
      }

      CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

      context?.translateBy(x: 0, y: image.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)

      UIGraphicsPushContext(context!)
      image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

      return pixelBuffer
    }
    
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }

 
}
