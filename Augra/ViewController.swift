//
//  ViewController.swift
//  Augra
//
//  Created by Goddards on 2017-06-05.
//  Copyright © 2017 Electrovore. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

let HALF_SIZE = CGSize(width: 0.5, height: 0.5)

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var cursor: SCNNode?
    var handleTL: SCNNode?
    var handleTR: SCNNode?
    var handleBL: SCNNode?
    var handleBR: SCNNode?

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        sceneView.scene = scene

        addModels()
        addLights()

        addHandle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
//        let configuration = ARSessionConfiguration()
        
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
        sceneView.session.delegate = self
        let baseAnchor = matrix_float4x4(columns: 
            (vector_float4(1, 0, 0, 0),
             vector_float4(0, 1, 0, 0),
             vector_float4(0, 0, 1, 0),
             vector_float4(0, 0, 0, 0)))
        let anchorPlane = ARAnchor(transform: baseAnchor)
        sceneView.session.add(anchor: anchorPlane)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }


    var currentImageSize: CGSize?

    lazy var rectanglesRequest: VNDetectRectanglesRequest = {
        let detectionRequest = VNDetectRectanglesRequest(completionHandler: self.handleRectangles)
//        detectionRequest.maximumObservations = 4
        detectionRequest.maximumObservations = 1
        return detectionRequest
    }()


    func findRectangles(frame: ARFrame?) {
        guard let imageBuffer = frame?.capturedImage else {
            print("ARFrame missing capturedImage")
            return
        }
        currentImageSize = CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))

        let imageHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .up)

        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try imageHandler.perform([self.rectanglesRequest])
            } catch {
                print(error)
            }
        }
    }

    func handleRectangles(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation] else {
            print("unexpected result type from VNDetectRectanglesRequest")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.overlayShape(rectangles: observations)
        }
    }

    func overlayShape(rectangles: [VNRectangleObservation]) {
        view.layer.sublayers = nil
        for rectangle in rectangles {
            overlayShape(rectangle: rectangle)
        }
        if let rectangle = rectangles.first {
            overlayHandle(rectangle: rectangle)
        }
    }

    func overlayHandle(rectangle: VNRectangleObservation) {
        guard let imageSize = currentImageSize?.scaled(to: HALF_SIZE) else {
            print("No current image size.")
            return
        }

        //TODO: determine actual values from screen and camera
        let viewSize = CGSize(width: 1.0/400.0, height: 1.0/400.0)

        let topLeft = rectangle.topLeft.scaled(to: imageSize).scaled(to: viewSize)
        let topRight = rectangle.topRight.scaled(to: imageSize).scaled(to: viewSize)
        let bottomLeft = rectangle.bottomLeft.scaled(to: imageSize).scaled(to: viewSize)
        let bottomRight = rectangle.bottomRight.scaled(to: imageSize).scaled(to: viewSize)

        if let cameraTransform = sceneView.session.currentFrame?.camera.transform {
            func cameraPoint(point: CGPoint) -> SCNMatrix4 {
                return SCNMatrix4Mult(SCNMatrix4MakeTranslation(Float(point.x) * 1.0, Float(point.y) * 1.0, -1.4), SCNMatrix4Mult(SCNMatrix4MakeTranslation(-0.8, -0.5, 0), SCNMatrix4(cameraTransform)))
            }

            handleTL?.transform = cameraPoint(point: topLeft)
            handleTR?.transform = cameraPoint(point: topRight)
            handleBL?.transform = cameraPoint(point: bottomLeft)
            handleBR?.transform = cameraPoint(point: bottomRight)
        }
    }

    func overlayShape(rectangle: VNRectangleObservation) {
        guard let imageSize = currentImageSize?.scaled(to: HALF_SIZE) else {
            print("No current image size.")
            return
        }

        let topLeft = rectangle.topLeft.scaled(to: imageSize)
        let topRight = rectangle.topRight.scaled(to: imageSize)
        let bottomLeft = rectangle.bottomLeft.scaled(to: imageSize)
        let bottomRight = rectangle.bottomRight.scaled(to: imageSize)

        let shape = CAShapeLayer()
        var transform = CATransform3DMakeRotation(3 * .pi / 2, 0.0, 0.0, 1.0)
        transform = CATransform3DScale(transform, -1, 1, 1)
        transform = CATransform3DTranslate(transform, 5, 5, 0)
        shape.transform = transform
        shape.opacity = 0.5
        shape.lineWidth = 2
        shape.lineJoin = kCALineJoinMiter
        shape.strokeColor = UIColor.blue.cgColor
        shape.fillColor = UIColor.green.cgColor

        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.addLine(to: topLeft)
        path.close()
        shape.path = path.cgPath

        view.layer.addSublayer(shape)
    }

    private func addHandle() {
        handleTL = addColoredBoxCursor(color: .red)
        handleTR = addColoredBoxCursor(color: .orange)
        handleBL = addColoredBoxCursor(color: .yellow)
        handleBR = addColoredBoxCursor(color: .green)
    }

    private func addColoredCursor(color: UIColor) -> SCNNode {
        let newCursor = SCNNode()
        newCursor.geometry = SCNSphere(radius: 0.05)
        newCursor.geometry?.firstMaterial?.diffuse.contents = color
        sceneView.scene.rootNode.addChildNode(newCursor)
        return newCursor
    }

    private func addColoredBoxCursor(color: UIColor) -> SCNNode {
        let newCursor = SCNNode()
        newCursor.geometry = SCNBox(width:  0.05, height:  0.05, length:  0.05, chamferRadius:  0.0)
        newCursor.geometry?.firstMaterial?.diffuse.contents = color
        sceneView.scene.rootNode.addChildNode(newCursor)
        return newCursor
    }

    private func addModels() {
        let modelLoader = ModelLoader(environmentScene: sceneView.scene)
        modelLoader.addAssortedMesh()
    }
    
    private func addLights() {
        addPointLight()
        addAmbientLight()
    }
    
    private func addPointLight() {
        let light = SCNLight()
        light.intensity = 1000
        light.type = .omni
        light.color = UIColor.white
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0.0, 0.0, 0.0)
        sceneView.scene.rootNode.addChildNode(lightNode)
    }
    
    private func addAmbientLight() {
        let light = SCNLight()
        light.intensity = 200
        light.type = .ambient
        light.color = UIColor.white
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0.0, 0.0, 0.0)
        sceneView.scene.rootNode.addChildNode(lightNode)
    }
    
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let pos = SCNVector3.positionFromTransform(anchor.transform)
//        textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
        
        let plane = Plane(anchor, false)
        
        planes[anchor] = plane
        node.addChildNode(plane)
        print("added plane \(pos.friendlyString())")
        sceneView.scene.rootNode.addChildNode(plane)
        
//        textManager.cancelScheduledMessage(forType: .planeEstimation)
//        textManager.showMessage("SURFACE DETECTED")
//        if virtualObject == nil {
//            textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
//        }
    }

    func addBox(node: SCNNode, anchor: ARPlaneAnchor) {
        let boxNode = SCNNode()
        
        let boundingBox = SCNBox()
        boundingBox.width = 0.5
        boundingBox.height = 0.1
        boundingBox.length = 0.5
        boxNode.geometry = boundingBox
        
//        boxNode.position = SCNVector3(anchor.center)
        boxNode.position = SCNVector3(0, 0, 0)
        boxNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
        node.addChildNode(boxNode)
    }

    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    func removePlane(anchor: ARPlaneAnchor) {
        if let plane = planes.removeValue(forKey: anchor) {
            plane.removeFromParentNode()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.addPlane(node: node, anchor: planeAnchor)
                self.addBox(node: node, anchor: planeAnchor)
//                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.updatePlane(anchor: planeAnchor)
//                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.removePlane(anchor: planeAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        findRectangles(frame: frame)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
