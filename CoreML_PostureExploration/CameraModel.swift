//
//  CameraModel.swift
//  udemy_hotdogApp
//
//  Created by Christopher Guirguis on 1/29/21.
//

import Foundation
import SwiftUI
import AVFoundation
import os.signpost
import CoreML
import Vision
import CoreVideo

struct ClassifiedImage {
    var picData:Data? = nil
    var primary_classifierIdentifier:String? = nil
}

class JointModel: ObservableObject {
    @Published var points:[PredictedPoint?] = []
    @Published var 👨‍🔧 = Measure()
    @Published var isInferencing = false
    
    @Published var request: VNCoreMLRequest?
    @Published var visionModel: VNCoreMLModel?
    @Published var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    
    @Published var mvfilters: [MovingAverageFilter] = []
    
    // Inference Result Data
    @Published var tableData: [PredictedPoint?] = []
    
    
    
    // MARK: - Performance Measurement Property
    
    
    var refreshLog = OSLog(subsystem: "com.tucan9389.PoseEstimation-CoreML", category: "InferenceOperations")
}

extension JointModel: CameraModelDelegate {
    func videoCapture(_ capture: CameraModel, didCaptureVideoFrame pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
                if !isInferencing {
                    DispatchQueue.main.async {
                        self.isInferencing = true
                    }
                    // start of measure
                    self.👨‍🔧.🎬👏()
        //
        // predict!
        print("beginning prediction with vision")
        self.predictUsingVision(pixelBuffer: pixelBuffer)
                }
    }
    
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = self.request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        if #available(iOS 12.0, *) {
            //            os_signpost(.begin, log: refreshLog, name: "PoseEstimation")
        }
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if #available(iOS 12.0, *) {
            //            os_signpost(.event, log: refreshLog, name: "PoseEstimation")
        }
        self.👨‍🔧.🏷(with: "endInference")
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
           let heatmaps = observations.first?.featureValue.multiArrayValue {
            
            /* =================================================================== */
            /* ========================= post-processing ========================= */
            
            /* ------------------ convert heatmap to point array ----------------- */
            var predictedPoints = self.postProcessor.convertToPredictedPoints(from: heatmaps)
            
            /* --------------------- moving average filter ----------------------- */
            if predictedPoints.count != mvfilters.count {
                self.mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
            }
            for (predictedPoint, filter) in zip(predictedPoints, self.mvfilters) {
                filter.add(element: predictedPoint)
            }
            predictedPoints = mvfilters.map { $0.averagedValue() }
            /* =================================================================== */
            
            /* =================================================================== */
            /* ======================= display the results ======================= */
            DispatchQueue.main.sync {
                // draw line
                for point in predictedPoints{
                    if let point = point{
                        if let i = self.points.toUnwrapped().firstIndex(where: {$0.getName(selfArray: self.points) == point.getName(selfArray: predictedPoints)}){
                            print("updating point")
                            self.points[i]?.maxConfidence = point.maxConfidence
                            self.points[i]?.maxPoint = point.maxPoint
                        } else {
                            self.points.append(point)
                            print("adding point")
                        }
                        
                    }
                }
//                self.points = predictedPoints
                
                // show key points description
                self.showKeypointsDescription(with: predictedPoints)
                
                // end of measure
                self.👨‍🔧.🎬🤚()
                self.isInferencing = false
                
                if #available(iOS 12.0, *) {
                    //                    os_signpost(.end, log: refreshLog, name: "PoseEstimation")
                }
            }
            /* =================================================================== */
        } else {
            // end of measure
            self.👨‍🔧.🎬🤚()
            self.isInferencing = false
            
            if #available(iOS 12.0, *) {
                //                os_signpost(.end, log: refreshLog, name: "PoseEstimation")
            }
        }
    }
    
    func showKeypointsDescription(with n_kpoints: [PredictedPoint?]) {
        self.tableData = n_kpoints
        //        self.labelsTableView.reloadData()
    }
}

public protocol CameraModelDelegate: class {
    func videoCapture(_ capture: CameraModel, didCaptureVideoFrame: CVPixelBuffer, timestamp: CMTime)
}

public class CameraModel:NSObject, ObservableObject {
    //********
    //********
    //********
    //********
    //********
    //********
    
    public var fps = 30
    
    @Published var session = AVCaptureSession()
    @Published var alert = false
    
    public weak var delegate: CameraModelDelegate?
    
    @Published var output = AVCaptureVideoDataOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    private let sessionQueue = DispatchQueue(label: "session queue")
    var lastTimestamp = CMTime()
    
    @Published var isSaved = false
    @Published var classifiedImage:ClassifiedImage = ClassifiedImage()// = Data(count: 8)
    
    
    
    
    func Check(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
            case .authorized:
                self.setup(){outcome in
                    print(outcome)
                }
                return
                
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video){status in
                    if status {
                        self.setup(){outcome in
                            print(outcome)
                        }
                    }
                }
            case .denied:
                self.alert.toggle()
            default:
                return
        }
    }
    
    func setup(completion: @escaping(Bool)-> ()){
        
        DispatchQueue.main.async{
            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720
                
                let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                
                if let device = device {
                    let input = try AVCaptureDeviceInput(device: device)
                    
                    if self.session.canAddInput(input){
                        self.session.addInput(input)
                    }
                }
                
                let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = .portrait
                self.preview = previewLayer
                
                let settings: [String : Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
                ]
                
                self.output.videoSettings = settings
                self.output.alwaysDiscardsLateVideoFrames = true
                self.output.setSampleBufferDelegate(self, queue: self.sessionQueue)
                
                if self.session.canAddOutput(self.output){
                    self.session.addOutput(self.output)
                }
                
                self.output.connection(with: AVMediaType.video)?.videoOrientation = .portrait
                
                self.session.commitConfiguration()
                let success = true
                completion(success)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        
    }
    
    public func start() {
        DispatchQueue.main.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    public func stop() {
        DispatchQueue.main.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Because lowering the capture device's FPS looks ugly in the preview,
        // we capture at full speed but only call the delegate at its desired
        // framerate.
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("dropped frame")
    }
}




struct CameraPreview:UIViewRepresentable {
    @ObservedObject var camera:CameraModel
    @ObservedObject var jmod:JointModel
    @State var layerAdded = false
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView(frame: UIScreen.main.bounds)
//        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
//        camera.preview.frame = view.frame
//        camera.preview.videoGravity = .resizeAspectFill
        camera.start()
        if camera.preview != nil {
            print("adding sublayer via make")
            camera.preview.frame = view.frame
            camera.preview.videoGravity = .resizeAspectFill
            camera.delegate = jmod
        view.layer.addSublayer(camera.preview)
        }
        
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if camera.preview != nil && !layerAdded{
            
            DispatchQueue.main.async{
                self.layerAdded = true
            }
            print("adding sublayer via update")
            camera.preview.frame = uiView.frame
            camera.preview.videoGravity = .resizeAspectFill
            camera.delegate = jmod
            uiView.layer.addSublayer(camera.preview)
             
        }
    }
}


