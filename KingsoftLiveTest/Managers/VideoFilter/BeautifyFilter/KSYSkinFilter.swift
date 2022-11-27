//
//  KSYBeautifyFaceFilter+BeautyInfo.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 27/11/2022.
//

import Foundation
import libksygpulive


class KSYSkinFilter: SkinBeauty {
    
    private let ksyBeauty: KSYBeautifyFaceFilter
    
    init(ksyBeauty: KSYBeautifyFaceFilter) {
        self.ksyBeauty = ksyBeauty
    }
    
    var grindIntensity: Float {
        get {
            Float(ksyBeauty.grindRatio)
        }
        set {
            ksyBeauty.grindRatio = CGFloat(newValue)
        }
    }
    
    var whitenIntensity: Float {
        get {
            Float(ksyBeauty.whitenRatio)
        }
        set {
            ksyBeauty.whitenRatio = CGFloat(newValue)
        }
    }
    
    var ruddyIntensity: Float {
        get {
            Float(ksyBeauty.ruddyRatio)
        }
        set {
            ksyBeauty.ruddyRatio = CGFloat(newValue)
        }
    }
}


