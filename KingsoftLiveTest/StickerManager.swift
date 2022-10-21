//
//  StickerManager.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 21/10/2022.
//

import Foundation
import GPUImage

class StickerManager {
    private init() {}
    
    static var shared: StickerManager = {
        let manager = StickerManager()
        manager.openCV = OpenCVWrapper()
        manager.openCV.configure()
        manager.openCV.cameraSize = manager.cameraSize
        
        return manager
    }()
    // public
    private var openCV: OpenCVWrapper!
    var cameraSize = CGSize(width: 720, height: 1280) {
        didSet {
            openCV.cameraSize = self.cameraSize
        }
    }
    
    // filters
    private var faceWidgetPicture: GPUImagePicture?
    private var faceWidgetPicture1: GPUImagePicture?
    
    private var faceWidgetFilter: GPUImageFaceWidgetComposeFilter!
    private var faceWidgetFilter1: GPUImageFaceWidgetComposeFilter!
    
   
    private let placeHolder =  GPUImagePicture(image: UIImage(named: "bizi_000")!)
    
    private var stickerFrameIndex: Int = 0
    private var stickerPath: String = ""
    
    private var gpuImageCache: [String: GPUImagePicture] = [:]
    
     func setupPigSticker() -> GPUImageFilterGroup? {
        // init filter
       let filterGroup = GPUImageFilterGroup()
       
        faceWidgetFilter = GPUImageFaceWidgetComposeFilter()
        faceWidgetFilter.imgSize = self.cameraSize
        
        faceWidgetFilter1 = GPUImageFaceWidgetComposeFilter()
        faceWidgetFilter1.imgSize = self.cameraSize
        
        faceWidgetFilter.addTarget(faceWidgetFilter1)
        
         placeHolder?.addTarget(faceWidgetFilter, atTextureLocation: 1)
         placeHolder?.addTarget(faceWidgetFilter1, atTextureLocation: 1)
         placeHolder?.processImage()
        
        filterGroup.addFilter(faceWidgetFilter)
        filterGroup.addFilter(faceWidgetFilter1)
        
        filterGroup.initialFilters = [faceWidgetFilter]
        filterGroup.terminalFilter = faceWidgetFilter1

        //streamKit.setupFilter(filterGroup)
        
        stickerPath = Bundle.main.resourcePath?.appending("/stickers/100009") ?? ""
        
        guard let data = NSData(contentsOfFile: stickerPath.appending("/config.json")),
              let dictionary = try? JSONSerialization.jsonObject(with: data as Data) as? [AnyHashable: Any] else { return nil }

        openCV.stickerConfig = dictionary
         return filterGroup
    }
    
    
    func configureFaceWidget(sampleBuffer: CMSampleBuffer?) {
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
}
