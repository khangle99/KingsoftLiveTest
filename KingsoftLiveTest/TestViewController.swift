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

class TestViewController: UIViewController {
    
    private var faceWidgetPicture: GPUImagePicture?
    private var faceWidgetPicture1: GPUImagePicture?
    
    private var faceWidgetFilter: GPUImageFaceWidgetComposeFilter!
    private var faceWidgetFilter1: GPUImageFaceWidgetComposeFilter!
    private var cameraSize = CGSize(width: 720, height: 1280)
    private var stickerFrameIndex: Int = 0
    private var stickerPath: String = ""
    
    private var gpuImageCache: [String: GPUImagePicture] = [:]
   
    @IBOutlet weak var previewView: UIView!
    
    var streamKit = KSYGPUStreamerKit(defaultCfg: ())!
    
    private var openCV: OpenCVWrapper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("version \( OpenCVWrapper.openCVVersionString())")
        openCV = OpenCVWrapper()
        openCV.configure()
        openCV.cameraSize = self.cameraSize
        streamKit.streamerBase.videoCodec = .X264;
        streamKit.videoOrientation = .portrait
        
        streamKit.capturePixelFormat = kCVPixelFormatType_32BGRA
        streamKit.gpuOutputPixelFormat = kCVPixelFormatType_32BGRA
        
        streamKit.startPreview(previewView)
        
        streamKit.videoProcessingCallback = { sampleBuffer in
            guard let sampleBuffer = sampleBuffer,
            let filter = self.faceWidgetFilter,
            let filter1 = self.faceWidgetFilter1,
            let faces = self.openCV.grepFaces(for: sampleBuffer) as? [[AnyHashable: Any]] else { return }
            if faces.count == 0 {
                let empty = ["count": 0]
                filter.setStickerParams(empty)
                filter1.setStickerParams(empty)
                return
            }

            // get image frame from file and wire filter
            guard let configs = self.openCV.stickerConfig["items"] as? [[String:Any]] else { return }

            for (idx, item) in configs.enumerated() {
                let frames = item["frames"] as! Int
                let frameIndex = self.stickerFrameIndex % frames
                let folderName = item["folderName"] as! String
                let folderPath = "\(self.stickerPath)/\(folderName)"
                let fileName = "\(folderName)_\(String(format: "%03d", frameIndex)).png"
                let filePath = "\(folderPath)/\(fileName)"

                var itemPic: GPUImagePicture?
                if self.gpuImageCache[filePath] == nil {
                    if FileManager.default.fileExists(atPath: filePath) {
                        let image =  UIImage(contentsOfFile: filePath)
                        itemPic = GPUImagePicture(image: image)
                    }
                    if itemPic == nil {
                        continue // next item
                    }
                    self.gpuImageCache[filePath] = itemPic
                }
                itemPic = self.gpuImageCache[filePath]

                switch idx {
                case 0:
                    self.faceWidgetPicture?.removeAllTargets()
                    self.faceWidgetPicture = itemPic
                    self.faceWidgetPicture?.addTarget(filter, atTextureLocation: 1)
                    self.faceWidgetPicture?.processImage()
                    break
                case 1:
                    self.faceWidgetPicture1?.removeAllTargets()
                    self.faceWidgetPicture1 = itemPic
                    self.faceWidgetPicture1?.addTarget(filter1, atTextureLocation: 1)
                    self.faceWidgetPicture1?.processImage()
                    break
                default:
                    break
                }

            }

            self.stickerFrameIndex += 1

            // su dung faces data len sticker filter

            filter.setStickerParams(faces[0])
            filter1.setStickerParams(faces[1])
        }
        streamKit.streamerBase.streamStateChange = { state in
            print(state.rawValue)
        }
        
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        //            self.streamKit.streamerBase.startStream(URL(string: "rtmp://192.168.1.5/live/hello"))
        //        }
        setupSticker()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    private let testPicture =  GPUImagePicture(image: UIImage(named: "bizi_000")!)
    
    private func setupSticker() {
        // init filter
       let filterGroup = GPUImageFilterGroup()
       
        faceWidgetFilter = GPUImageFaceWidgetComposeFilter()
        faceWidgetFilter.imgSize = self.cameraSize
        
        faceWidgetFilter1 = GPUImageFaceWidgetComposeFilter()
        faceWidgetFilter1.imgSize = self.cameraSize
        
        faceWidgetFilter.addTarget(faceWidgetFilter1)
        
        testPicture?.addTarget(faceWidgetFilter, atTextureLocation: 1)
        testPicture?.addTarget(faceWidgetFilter1, atTextureLocation: 1)
        testPicture?.processImage()
        
        filterGroup.addFilter(faceWidgetFilter)
        filterGroup.addFilter(faceWidgetFilter1)
        
        filterGroup.initialFilters = [faceWidgetFilter]
        filterGroup.terminalFilter = faceWidgetFilter1

        streamKit.setupFilter(filterGroup)
       
//        testPicture?.addTarget(faceWidgetFilter, atTextureLocation: 1)
//        faceWidgetFilter.useNextFrameForImageCapture()
//        testPicture?.processImage()
//        faceWidgetFilter.setStickerParams(test)
        
        stickerPath = Bundle.main.resourcePath?.appending("/stickers/100009") ?? ""
        
        guard let data = NSData(contentsOfFile: stickerPath.appending("/config.json")),
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
