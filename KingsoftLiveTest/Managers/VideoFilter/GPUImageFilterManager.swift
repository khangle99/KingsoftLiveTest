//
//  StickerManager.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 21/10/2022.
//

import Foundation
import GPUImage
import libksygpulive

struct FilterInfo {
    let path: String // the path for resource compatible with adopted FilterManager
    let isFaceDetect: Bool
}

protocol LiveFilterManager: AnyObject {
    func selectSticker(_ info: FilterInfo)
    func reset()
}

/// This class wil compose filter group for ksy, and update its filter data after face detect process
class GPUImageFilterManager: LiveFilterManager {
    
    weak var streamerKit: KSYGPUStreamerKit?
    
    // face skin image filter
    private var skinImage: GPUImagePicture = GPUImagePicture(image: UIImage(named: "empty"))
    private var faceSkinImageFilter = GPUFaceImageSkinFilter()
    
    private var blendFilter =  GPUImageBlendFilter()
    
    // mesh
    private let meshFilter = GPUImageMeshFilter()
    
     init(streamerKit: KSYGPUStreamerKit?) {
         self.streamerKit = streamerKit
         let openCv = OpenCVWrapper()
         openCv.configure()
         openCv.cameraSize = cameraSize
         self.openCV = openCv
     }
    
    // public
    private var openCV: OpenCVWrapper!
    var cameraSize = CGSize(width: 720, height: 1280) {
        didSet {
            openCV.cameraSize = self.cameraSize
        }
    }
    
    private var currentFilterInfo: FilterInfo?
    
    // beautify filters
    var isBeautyOn = false // TODO: Support generic beautify filter protocol in next version
    
    //private var beautifyFilterList: [GPUBeautifyFilter] // TODO: Support generic beautify filter protocol in next version
    private var beautyFilter = KSYBeautifyFaceFilter()
    
    // face widget filters
    
    private var faceWidgetPictureList: [GPUImagePicture] = []
    private var faceWidgetPicture: GPUImagePicture?
    private var faceWidgetPicture1: GPUImagePicture?
    
    
    private var filterGroupList: [GPUImageOutput & GPUImageInput] = []
    private var filterIndicesDict: [String: Int] = [:] // for random access for marked filter by key (unique string)
    //private var faceWidgetFilterList: [GPUImageFaceWidgetComposeFilter] = [] // used for random access to inject image overlay
    
    private var faceWidgetFilter: GPUImageFaceWidgetComposeFilter?
    private var faceWidgetFilter1: GPUImageFaceWidgetComposeFilter?
    
    private let placeHolder =  GPUImagePicture(image: UIImage(named: "empty")!)

    private var stickerFrameIndex: Int = 0 // index for animated sticker
    
    private var stickerPath: String {
        currentFilterInfo?.path ?? ""
    }
    
    private var gpuImageCache: [String: GPUImagePicture] = [:]
    
    // MARK: Filter compose
    func selectSticker(_ info: FilterInfo) {
        currentFilterInfo = info
        needFaceDetect = info.isFaceDetect
        let filterGroup = composeFilterGroup()
        streamerKit?.setupFilter(filterGroup)
    }
    
    /// Compose filter render pineline (compose all sticker/ beautify filters) to a single filter group for ksy
    /// recall whenever single filter chain remove or add
    func composeFilterGroup() -> GPUImageFilterGroup? {
        
        // Step 0: clear all filter in group list
        filterGroupList.forEach { filter in
            filter.removeAllTargets()
        }
        filterGroupList.removeAll()
                
        // beautify filter
        let filterGroup = GPUImageFilterGroup()
        
        let firstFilter = GPUImageFilter() // placeholder first filter
        var lastFilter: GPUImageFilter = firstFilter
        filterGroupList.append(firstFilter)
        filterGroup.addFilter(firstFilter)
       
//        if isBeautyOn {
//            beautyFilter?.removeAllTargets()
//            beautyFilter = KSYBeautifyFaceFilter()
//            lastFilter.addTarget(beautyFilter)
//            filterGroup.addFilter(beautyFilter)
//            lastFilter = beautyFilter
//            filterGroupList.append(beautyFilter!)
//        }
        
        // STEP 1: clear old widget sticker
        
        faceWidgetPictureList.forEach { picture in
            picture.removeAllTargets()
        }
        faceWidgetPictureList.removeAll()
        
        guard let data = NSData(contentsOfFile: stickerPath.appending("/config.json")),
              let dictionary = try? JSONSerialization.jsonObject(with: data as Data) as? [AnyHashable: Any] else { return nil }
        
        openCV.stickerConfig = dictionary // opencv need json to configure widget param
        
        // STEP 2: create list of widget filter base on selected widget sticker

        if let items = dictionary["items"] as? [[String:Any]] {
            
            let placeholderPicture = GPUImagePicture(image: UIImage(named: "empty"))
            gpuImageCache["empty"] = placeholderPicture
            
            let widgetParams: [String: Any] = ["count": "0"] // reset param
            for (idx, item) in items.enumerated() {
                // init widget filter at location 0
                let filter = GPUImageFaceWidgetComposeFilter()
                filter.imgSize = self.cameraSize
                filter.setStickerParams(widgetParams)
                filterGroup.addFilter(filter)
                filterGroupList.append(filter)
                placeholderPicture?.addTarget(filter, atTextureLocation: 1)
                lastFilter.addTarget(filter)
                lastFilter = filter
                //store index of filter by key logic:
                filterIndicesDict["item:\(item["folderName"]).\(idx)"] = filterGroupList.count - 1
            }
            
            placeholderPicture?.processImage()
        }
        
        // STEP 3: configure face skin filter
        if let skins = self.openCV.stickerConfig["skins"] as? [[String:Any]] {
            let skin = skins[0]
            let folderName = skin["folderName"] as! String
            let idxFile = String(format: "%@/%@/%@.idx", stickerPath, folderName, folderName)
            let crdFile = String(format: "%@/%@/%@.crd", stickerPath, folderName, folderName)
            let pngFile = String(format: "%@/%@/%@_000.png", stickerPath, folderName, folderName)
            skinImage.removeAllTargets()
            if FileManager.default.fileExists(atPath: pngFile) {
                skinImage = GPUImagePicture(image: UIImage(contentsOfFile: pngFile)!) // force cast

                /* compose Face Image Skin Filter
                 camera(lastFilter) -> faceSkinFilter (bottom layer: index 0)
                 faceSkinImage      -> faceSkinFilter (top layer: index 1)
                */
                faceSkinImageFilter.update(with: crdFile, idxFile)
                lastFilter.addTarget(faceSkinImageFilter, atTextureLocation: 0)
                skinImage.addTarget(faceSkinImageFilter, atTextureLocation: 1)
                filterGroup.addFilter(faceSkinImageFilter)

                /* compose Blend Filter
                 camera(lastFilter)  -> blendfilter (bottom layer: index 0)
                 faceImageSkinFilter -> blendfilter (top layer: index 1)
                */
                lastFilter.addTarget(blendFilter, atTextureLocation: 0)
                faceSkinImageFilter.addTarget(blendFilter, atTextureLocation: 1)
                filterGroup.addFilter(blendFilter)
                lastFilter = blendFilter
                skinImage.processImage()
            }
        }
        
        // STEP 4: configure mesh filter
        
        if let meshs = self.openCV.stickerConfig["meshs"] as? [[String:Any]] {
            lastFilter.addTarget(meshFilter)
            filterGroup.addFilter(meshFilter)
            lastFilter = meshFilter
        }
        
        filterGroup.initialFilters = [firstFilter]
        filterGroup.terminalFilter = lastFilter
        
        return filterGroup
    }
    
    /// base on selected list of beautify filter
    func appendBeautyfiFilter() { // TODO: Support generic beautify filter protocol in next version
        
    }
    
    private var previousFaceCount: Int = 0
    
    private var needFaceDetect = false
    
    /// face detect for AR Filter
    func configureFilters(with sampleBuffer: CMSampleBuffer?) {
        
        guard needFaceDetect else { return }
        
        // data for 3 kind of face filters
        var meshItems: NSMutableArray?
        var skinItems: NSMutableArray?
        var faceParams: NSMutableArray?
        guard let sampleBuffer = sampleBuffer else { return }
        
        let faceCount = openCV.grepFaces(for: sampleBuffer, widgetParams: &faceParams, skinItems: &skinItems, meshItems: &meshItems)
        if faceCount != previousFaceCount {
            print("faceCount: \(faceCount)")
            previousFaceCount = Int(faceCount)
        }
        
        // reset widget filter data
        if faceCount < 1 {
            let parames = ["count" : "0"]
            if let items = self.openCV.stickerConfig["items"] as? [[String:Any]] {
                for (idx, item) in items.enumerated() {
                    if let filterIndex = filterIndicesDict["item:\(item["folderName"]).\(idx)"],
                       let widgetFilter = filterGroupList[filterIndex] as? GPUImageFaceWidgetComposeFilter {
                        widgetFilter.setStickerParams(parames)
                    }
                }
            }
            
            meshFilter.items = nil
            //self.detectoredFace = NO;
            faceSkinImageFilter.items = nil
//            self.mouthOpening = NO;
//            self.mouthStickerFrameIndex = 0;
            return
        }
        
        //update mesh data if need
        if let mesh = self.openCV.stickerConfig["meshs"] as? [[String:Any]] {
            meshFilter.items = meshItems
        }
        // update skins data if need
        if let skins = self.openCV.stickerConfig["skins"] as? [[String:Any]] {
            faceSkinImageFilter.items = skinItems
        }
//        print("debug face params")
//        print(faceParams)
        // update item filter if need
        if let items = self.openCV.stickerConfig["items"] as? [[String:Any]],
           let params = faceParams as? [[AnyHashable: Any]] {

            for (idx, item) in items.enumerated() {
                if let filterIndex = filterIndicesDict["item:\(item["folderName"]).\(idx)"],
                   let widgetFilter = filterGroupList[filterIndex] as? GPUImageFaceWidgetComposeFilter {
                    
                    widgetFilter.setStickerParams(params[idx])
                }

            }
        }
        
        // update frame picture for animated sticker
        updateWidgetPictureFrame()
        
    }
    
    private func updateWidgetPictureFrame() {
        guard let items = self.openCV.stickerConfig["items"] as? [[String:Any]] else { return }
        
        for (idx, item) in items.enumerated() {
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
            
            // access to filter
            let range = 0...filterGroupList.count
            if let filterIndex = filterIndicesDict["item:\(item["folderName"]).\(idx)"], range.contains(filterIndex) {
                itemPic?.addTarget(filterGroupList[filterIndex])
            }
            itemPic?.processImage()
//            switch idx {
//            case 0:
//                self.faceWidgetPicture?.removeAllTargets()
//                self.faceWidgetPicture = itemPic
//                self.faceWidgetPicture?.addTarget(filter, atTextureLocation: 1)
//                self.faceWidgetPicture?.processImage()
//                break
//            case 1:
//                self.faceWidgetPicture1?.removeAllTargets()
//                self.faceWidgetPicture1 = itemPic
//                self.faceWidgetPicture1?.addTarget(filter1, atTextureLocation: 1)
//                self.faceWidgetPicture1?.processImage()
//                break
//            default:
//                break
//            }
            
        }
        
        self.stickerFrameIndex += 1
    }
    
    /*
    /// call to update frame ( face param/ change sticker frames) for filter
    func configureFaceWidget(sampleBuffer: CMSampleBuffer?) {
        
        if faceWidgetFilterList.isEmpty {
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
     */
    
    func reset() {
        //TODO: Reset filter
    }
    
    // MARK: -  BEAUTIFY FILTER
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