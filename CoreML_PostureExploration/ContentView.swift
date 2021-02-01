//
//  ContentView.swift
//  CoreML_PostureExploration
//
//  Created by Christopher Guirguis on 2/1/21.
//

import SwiftUI
import CoreData
import CoreML
import Vision
import CoreMedia
import os.signpost
import AVFoundation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var camera = CameraModel()
    @StateObject var jointmodel = JointModel()
    
    typealias EstimationModel = model_cpm
    
    var body: some View {
        ZStack{
            
            CameraPreview(camera: camera, jmod: jointmodel)
                .opacity(0.5)
            DrawingJointSwiftUIView(jointMod: jointmodel)
            
        }.onAppear(){
            camera.Check()
            setUpModel()
        }
    }
    
    
}


extension ContentView {
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.jointmodel.visionModel = visionModel
            jointmodel.request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            jointmodel.request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if #available(iOS 12.0, *) {
            //            os_signpost(.event, log: refreshLog, name: "PoseEstimation")
        }
        self.jointmodel.👨‍🔧.🏷(with: "endInference")
        if let observations = self.jointmodel.request?.results as? [VNCoreMLFeatureValueObservation],
           let heatmaps = observations.first?.featureValue.multiArrayValue {
            
            /* =================================================================== */
            /* ========================= post-processing ========================= */
            
            /* ------------------ convert heatmap to point array ----------------- */
            var predictedPoints = jointmodel.postProcessor.convertToPredictedPoints(from: heatmaps)
            
            /* --------------------- moving average filter ----------------------- */
            if predictedPoints.count != jointmodel.mvfilters.count {
                DispatchQueue.main.async {
                    self.jointmodel.mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
                }
                
            }
            for (predictedPoint, filter) in zip(predictedPoints, jointmodel.mvfilters) {
                filter.add(element: predictedPoint)
            }
            predictedPoints = jointmodel.mvfilters.map { $0.averagedValue() }
            /* =================================================================== */
            
            /* =================================================================== */
            /* ======================= display the results ======================= */
            DispatchQueue.main.sync {
                // draw line
                for point in predictedPoints{
                    if let point = point{
                        if let i = self.jointmodel.points.toUnwrapped().firstIndex(where: {$0.getName(selfArray: self.jointmodel.points) == point.getName(selfArray: predictedPoints)}){
                            print("updating point")
                            self.jointmodel.points[i]?.maxConfidence = point.maxConfidence
                            self.jointmodel.points[i]?.maxPoint = point.maxPoint
                        } else {
                            self.jointmodel.points.append(point)
                            print("adding point")
                        }
                        
                    }
                }
                //                self.jointmodel.points = predictedPoints
                
                // show key points description
                self.showKeypointsDescription(with: predictedPoints)
                
                // end of measure
                self.jointmodel.👨‍🔧.🎬🤚()
                self.jointmodel.isInferencing = false
                
                if #available(iOS 12.0, *) {
                    //                    os_signpost(.end, log: refreshLog, name: "PoseEstimation")
                }
            }
            /* =================================================================== */
        } else {
            // end of measure
            self.jointmodel.👨‍🔧.🎬🤚()
            self.jointmodel.isInferencing = false
            
            if #available(iOS 12.0, *) {
                //                os_signpost(.end, log: refreshLog, name: "PoseEstimation")
            }
        }
    }
    
    func showKeypointsDescription(with n_kpoints: [PredictedPoint?]) {
        self.jointmodel.tableData = n_kpoints
    }
}

