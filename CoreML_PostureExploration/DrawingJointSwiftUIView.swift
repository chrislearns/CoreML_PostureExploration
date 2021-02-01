//
//  DrawingJointSwiftUIView.swift
//  udemy_hotdogApp
//
//  Created by Christopher Guirguis on 2/1/21.
//

import SwiftUI

var UniversalSafeOffsets = UIApplication.shared.windows.first?.safeAreaInsets
 
struct DrawingJointSwiftUIView: View {
    
    let screenHeight = UIScreen.main.bounds.height - ((UniversalSafeOffsets?.top ?? 0) + (UniversalSafeOffsets?.bottom ?? 0))
    @ObservedObject var jointMod:JointModel
    var body: some View {
        ZStack{
//            Rectangle().foregroundColor(.green).opacity(0.2)
            VStack{
                Text("\(jointMod.points.toUnwrapped().count) points found")
                Spacer()
            }
//                List{
//                    ForEach(jointMod.points.toUnwrapped()){point in
//
//                        Text("\(point.maxPoint.debugDescription ?? "err")")
//                    }
//                }
//                .opacity(0.2)
            ForEach(jointMod.points.toUnwrapped()){point in
                Circle().frame(width: 20, height: 20)
                    .foregroundColor(.green)
                    .opacity(0.4)
                    .offset(x: -UIScreen.main.bounds.width/2, y: -screenHeight/2)
                    .offset(x: point.maxPoint.x * UIScreen.main.bounds.width,
                            y: point.maxPoint.y * screenHeight)
                    .animation(.linear(duration: 0.2))
            }
            
            ForEach(0..<PoseEstimationForMobileConstant.connectedPointIndexPairs.count){i in
                Group{
                    getPath(pair: PoseEstimationForMobileConstant.connectedPointIndexPairs[i], bodyPoints: jointMod.points)?
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        .opacity(0.4)
                        .animation(.linear(duration: 0.2))
                        
                }
            }
        }
    }
    
    func getPath(pair: (Int, Int), bodyPoints:[PredictedPoint?]) -> Line?{
        
        let pIndex1 = pair.0
        let pIndex2 = pair.1
        if bodyPoints.count > pIndex1 && bodyPoints.count > pIndex2{
        if let bp1 = bodyPoints[pIndex1], bp1.maxConfidence > DrawingJointUIView.threshold,
           let bp2 = bodyPoints[pIndex2], bp2.maxConfidence > DrawingJointUIView.threshold {
            let p1 = bp1.maxPoint
            let p2 = bp2.maxPoint
            let point1 = CGPoint(x: p1.x * UIScreen.main.bounds.width, y: p1.y*screenHeight)
            let point2 = CGPoint(x: p2.x * UIScreen.main.bounds.width, y: p2.y*screenHeight)
//            drawLine(ctx: ctx, from: point1, to: point2, color: color)
            return Line(start: point1, end: point2)
        } else {
            print("could not setup bps")
            return nil
        }
        } else {
            print("count was off")
            return nil
        }
        
        
    }
}

//struct DrawingJointSwiftUIView_Previews: PreviewProvider {
//    static var previews: some View {
//        DrawingJointSwiftUIView()
//    }
//}


struct Line: Shape {
    var start, end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
    }
}

extension Line {
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set { (start.animatableData, end.animatableData) = (newValue.first, newValue.second) }
    }
}
