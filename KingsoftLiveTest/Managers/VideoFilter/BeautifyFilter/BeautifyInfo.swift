//
//  FaceShapeMeshInfo.swift
//  KingsoftLiveTest
//
//  Created by Khang L on 26/11/2022.
//

import Foundation

protocol SkinBeauty: AnyObject {
    var grindIntensity: Float { get set }
    var whitenIntensity: Float { get set }
    var ruddyIntensity: Float { get set }
}
protocol FaceShapeBeauty: AnyObject {
    var id: String { get }
    var intensity: Float { get set }
}

