//
//  VectorUtilities.swift
//  Augra
//
//  Created by Ted Goddard on 2016-09-08.
//

import Foundation
import SceneKit

func sum(_ vectorLeft: SCNVector3, _ vectorRight: SCNVector3) -> SCNVector3 {
    return SCNVector3FromGLKVector3(GLKVector3Add(SCNVector3ToGLKVector3(vectorLeft), SCNVector3ToGLKVector3(vectorRight)))
}

func distance(_ vectorLeft: SCNVector3, _ vectorRight: SCNVector3) -> Float {
    return GLKVector3Distance(SCNVector3ToGLKVector3(vectorLeft), SCNVector3ToGLKVector3(vectorRight))
}

func multiply(_ matrixLeft: SCNMatrix4, _ vectorRight: SCNVector3) -> SCNVector3 {
    return SCNVector3FromGLKVector3(GLKMatrix4MultiplyVector3(SCNMatrix4ToGLKMatrix4(matrixLeft), SCNVector3ToGLKVector3(vectorRight)))
}

func scale(_ vectorLeft: SCNVector3, _ factor: Float) -> SCNVector3 {
    return SCNVector3(x: vectorLeft.x * factor, y: vectorLeft.y * factor, z: vectorLeft.z * factor)
}

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}

extension CGSize {
    func scaled(to size: CGSize) -> CGSize {
        return CGSize(
            width: self.width * size.width,
            height: self.height * size.height
        )
    }
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

