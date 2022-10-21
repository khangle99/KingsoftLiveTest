//
//  StickerManager.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 21/10/2022.
//

import Foundation
import GPUImage
import libksygpulive

class FilterManager {
    private init() {}
    
    static var shared: FilterManager = {
        let manager = FilterManager()
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
    
    // face widget filters
    private var faceWidgetPicture: GPUImagePicture?
    private var faceWidgetPicture1: GPUImagePicture?
    
    private let placeHolder =  GPUImagePicture(image: UIImage(named: "bizi_000")!)
    
    private var faceWidgetFilter: GPUImageFaceWidgetComposeFilter?
    private var faceWidgetFilter1: GPUImageFaceWidgetComposeFilter?
    
    // skin filters
    private var beautyFilter = KSYBeautifyFaceFilter()
    
    private var stickerFrameIndex: Int = 0
    private var stickerPath: String = ""
    
    private var gpuImageCache: [String: GPUImagePicture] = [:]
    
    var isBeautyOn = false
    var isPigStickerOn = false
    
    // MARK: Filter compose
    
    func composedFilter() -> GPUImageFilterGroup? {
        // init filter
        if !isBeautyOn && !isPigStickerOn {
            return nil
        }
        
        var filterList: [GPUImageOutput] = []
        let filterGroup = GPUImageFilterGroup()
     
        if isBeautyOn {
            beautyFilter?.removeAllTargets()
            beautyFilter = KSYBeautifyFaceFilter()
            filterGroup.addFilter(beautyFilter)
            filterList.append(beautyFilter!)
        }
        
        if isPigStickerOn {
            faceWidgetFilter?.removeAllTargets()
            faceWidgetFilter1?.removeAllTargets()
            faceWidgetFilter = GPUImageFaceWidgetComposeFilter()
            faceWidgetFilter1 = GPUImageFaceWidgetComposeFilter()
            faceWidgetFilter!.imgSize = self.cameraSize
           
            faceWidgetFilter1!.imgSize = self.cameraSize
            
            faceWidgetFilter!.addTarget(faceWidgetFilter1)
            
            placeHolder?.addTarget(faceWidgetFilter, atTextureLocation: 1)
            placeHolder?.addTarget(faceWidgetFilter1, atTextureLocation: 1)
            placeHolder?.processImage()
            
            filterGroup.addFilter(faceWidgetFilter)
            filterGroup.addFilter(faceWidgetFilter1)
            filterList.append(faceWidgetFilter!)
            filterList.append(faceWidgetFilter1!)
            
            stickerPath = Bundle.main.resourcePath?.appending("/stickers/100009") ?? ""
            
            guard let data = NSData(contentsOfFile: stickerPath.appending("/config.json")),
                  let dictionary = try? JSONSerialization.jsonObject(with: data as Data) as? [AnyHashable: Any] else { return nil }
            
            openCV.stickerConfig = dictionary
        }
        
        // su dung array de get ra init terminal filter, wire filter
        
        for idx in 0..<filterList.count - 1 {
            let filter = filterList[idx]
            filter.addTarget((filterList[idx + 1] as! GPUImageInput))
        }
        
        filterGroup.initialFilters = [filterList.first!]
        filterGroup.terminalFilter = filterList.last as! GPUImageOutput & GPUImageInput

        return filterGroup
    }
    
    
    func configureFaceWidget(sampleBuffer: CMSampleBuffer?) {
        if !isPigStickerOn {
            return
        }
        guard let sampleBuffer = sampleBuffer,
              let filter = self.faceWidgetFilter,
              let filter1 = self.faceWidgetFilter1,
              let faces = self.openCV.grepFaces(for: sampleBuffer) as? [[AnyHashable: Any]] else { return }
        if faces.count == 0 { // reset filter
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
    
    // MARK: beauty filter configure
    var grindRatio: CGFloat  = 0.87 {
        didSet {
            beautyFilter?.grindRatio = grindRatio
        }
    }
    
    var whitenRatio: CGFloat = 0.6 {
        didSet {
            beautyFilter?.whitenRatio = whitenRatio
        }
    }
}
