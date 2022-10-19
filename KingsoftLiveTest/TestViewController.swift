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

class TestViewController: UIViewController, GPUImageVideoCameraDelegate {
    
    
    @IBOutlet weak var previewView: GPUImageView!
    
    private var session: AVCaptureSession!
    private var output: AVCaptureVideoDataOutput!
    private var device: AVCaptureDevice!
    
    var streamKit = KSYGPUStreamerKit(defaultCfg: ())!
    
    private var openCV: OpenCVWrapper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("version \( OpenCVWrapper.openCVVersionString())")
        openCV = OpenCVWrapper()
        openCV.configure()
        openCV.cameraSize = CGSize(width: 720, height: 1280)
        streamKit.streamerBase.videoCodec = .X264;
        streamKit.videoOrientation = .portrait
        
        streamKit.capturePixelFormat = kCVPixelFormatType_32BGRA
        streamKit.gpuOutputPixelFormat = kCVPixelFormatType_32BGRA
        
        streamKit.startPreview(previewView)
        
        
        streamKit.videoProcessingCallback = { sampleBuffer in
            guard let sampleBuffer = sampleBuffer else { return }
            let faces = self.openCV.grepFaces(for: sampleBuffer)
            // su dung faces data len sticker filter
        }
        streamKit.streamerBase.streamStateChange = { state in
            print(state.rawValue)
        }
        
        //
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        //            self.streamKit.streamerBase.startStream(URL(string: "rtmp://192.168.1.5/live/hello"))
        //        }
        setupSticker()
    }
    
    private func setupSticker() {
        let stickerPath = Bundle.main.resourcePath?.appending("/stickers/100009")
        
        guard let stickerPath = stickerPath,
              let data = NSData(contentsOfFile: stickerPath.appending("/config.json")),
              let dictionary = try? JSONSerialization.jsonObject(with: data as Data) as? [AnyHashable: Any] else { return }

        openCV.stickerConfig = dictionary
        
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
