
//
//  Source.swift
//  SingleRecognizer
//
//  Created by ingun on 29/07/2019.
//  Copyright © 2019 ingun37. All rights reserved.
//

import Foundation
import UIKit
import TensorFlowLite
import Promises

public func CGPath2SquareImage(path:CGPath, toSize:CGFloat)-> UIImage? {
    let bbox = path.boundingBoxOfPath
    let fitEdge = max(bbox.size.width, bbox.size.height)
    let pad = fitEdge * 0.15
    let edge = 2*pad + fitEdge
    let scale = toSize / edge
    
    let to = CGPoint(x: toSize/2, y: toSize/2)
    let from = CGPoint(x: bbox.midX * scale, y: bbox.midY * scale)
    let vecX = to.x - from.x
    let vecY = to.y - from.y
    
    UIGraphicsBeginImageContext(CGSize(width: toSize, height: toSize))
    guard let context = UIGraphicsGetCurrentContext() else {return nil}
    
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: toSize, height: toSize))
    let t = CGAffineTransform(translationX: vecX, y: vecY).scaledBy(x: scale, y: scale)
    context.concatenate(t)
    
    context.addPath(path)
    context.setLineCap(.round)
    context.setBlendMode(.normal)
    context.setLineWidth(2)
    context.setStrokeColor(UIColor.white.cgColor)
    context.strokePath()
    
    let img = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return img
}
enum Err:Error {
    case e(String)
}
class Static {
    private static var _model:ModelDataHandler? = nil
    static func model()-> ModelDataHandler {
        if let m = _model {
            return m
        } else {
            print("initializing a Model")
            _model = ModelDataHandler()
            return _model!
        }
    }
}
/// A result from invoking the `Interpreter`.
public struct Result {
    public let inferenceTime: Double
    public let inferences: [Inference]
}

/// An inference from invoking the `Interpreter`.
public struct Inference: Comparable {
    public static func < (lhs: Inference, rhs: Inference) -> Bool {
        return lhs.confidence < rhs.confidence
    }
    
    public let confidence: Float
    public let label: String
}

/// Information about a model file or labels file.
typealias FileInfo = (name: String, extension: String)

/// Information about the MobileNet model.
enum ByClass {
    static let modelInfo: FileInfo = (name: "converted_model", extension: "tflite")
    static let labelsInfo: FileInfo = (name: "labels", extension: "txt")
}

public func recognize(img28x28:UIImage)->Result? {
    return Static.model().runModel(onFrame: img28x28)
}
/// This class handles all data preprocessing and makes calls to run inference on a given frame
/// by invoking the `Interpreter`. It then formats the inferences obtained and returns the top N
/// results for a successful inference.
public class ModelDataHandler {
    
    // MARK: - Internal Properties
    
    /// The current thread count used by the TensorFlow Lite Interpreter.
    let threadCount: Int
    
    let resultCount = 3
    let threadCountLimit = 10
    
    // MARK: - Model Parameters
    
    let batchSize = 1
    let inputChannels = 1
    let inputWidth = 28
    let inputHeight = 28
    
    // MARK: - Private Properties
    
    /// List of labels from the given labels file.
    private var labels: [String] = []
    
    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    private var interpreter: Interpreter
    
    // MARK: - Initialization
    
    /// A failable initializer for `ModelDataHandler`. A new instance is created if the model and
    /// labels files are successfully loaded from the app's main bundle. Default `threadCount` is 1.
    private var bundle:Bundle {
        return Bundle(url: Bundle.main.bundleURL.appendingPathComponent("SignedNumberRecognizer.bundle"))!
    }
    public init?() {
        let modelFileInfo = ByClass.modelInfo
        let labelsFileInfo = ByClass.labelsInfo
        let threadCount = 1
        let modelFilename = modelFileInfo.name
        
        let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("SignedNumberRecognizer.bundle"))!
        guard let modelPath = bundle.path(
            forResource: modelFilename,
            ofType: modelFileInfo.extension
            ) else {
                print("Failed to load the model file with name: \(modelFilename).")
                return nil
        }
        
        // Specify the options for the `Interpreter`.
        self.threadCount = threadCount
        var options = InterpreterOptions()
        options.threadCount = threadCount
        do {
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter.allocateTensors()
        } catch let error {
            print("Failed to create the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        // Load the classes listed in the labels file.
        loadLabels(fileInfo: labelsFileInfo)
    }
    private func loadLabels(fileInfo: FileInfo) {
        let filename = fileInfo.name
        let fileExtension = fileInfo.extension
        guard let fileURL = bundle.url(forResource: filename, withExtension: fileExtension) else {
            fatalError("Labels file not found in bundle. Please add a labels file with name " +
                "\(filename).\(fileExtension) and try again.")
        }
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            labels = contents.components(separatedBy: .newlines)
        } catch {
            fatalError("Labels file named \(filename).\(fileExtension) cannot be read. Please add a " +
                "valid labels file and try again.")
        }
    }
    // MARK: - Internal Methods
    
    /// Performs image preprocessing, invokes the `Interpreter`, and processes the inference results.
    public func runModel(onFrame img28x28: UIImage) -> Result? {
        
        guard let pixelBuffer = img28x28.toCVPixelBuffer() else { return nil }
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_16Gray else { return nil }
        
        let thumbnailPixelBuffer = pixelBuffer
        
        let interval: TimeInterval
        let outputTensor: Tensor
        do {
            let inputTensor = try interpreter.input(at: 0)
            guard inputTensor.dataType == .float32 else {
                return nil
            }
            // Remove the alpha component from the image buffer to get the RGB data.
            guard let rgbData = rgbDataFromBuffer(
                thumbnailPixelBuffer,
                byteCount: batchSize * inputWidth * inputHeight * inputChannels
                ) else {
                    print("Failed to convert the image buffer to RGB data.")
                    return nil
            }
            
            // Copy the RGB data to the input `Tensor`.
            try interpreter.copy(rgbData, toInputAt: 0)
            
            // Run inference by invoking the `Interpreter`.
            let startDate = Date()
            try interpreter.invoke()
            interval = Date().timeIntervalSince(startDate) * 1000
            
            // Get the output `Tensor` to process the inference results.
            outputTensor = try interpreter.output(at: 0)
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        
        let results = [Float32](unsafeData: outputTensor.data) ?? []
        
        // Process the results.
        let topNInferences = getTopN(results: results)
        
        // Return the inference time and inference results.
        return Result(inferenceTime: interval, inferences: topNInferences)
    }
    
    // MARK: - Private Methods
    
    /// Returns the top N inference results sorted in descending order.
    private func getTopN(results: [Float]) -> [Inference] {
        // Create a zipped array of tuples [(labelIndex: Int, confidence: Float)].
        let zippedResults = zip(labels.indices, results)
        
        // Sort the zipped results by confidence value in descending order.
        let sortedResults = zippedResults.sorted { $0.1 > $1.1 }.prefix(resultCount)
        
        // Return the `Inference` results.
        return sortedResults.map { result in Inference(confidence: result.1, label: labels[result.0]) }
    }
    
    private func rgbDataFromBuffer(
        _ buffer: CVPixelBuffer,
        byteCount: Int
        ) -> Data? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let mutableRawPointer = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_16Gray else {
            return nil
        }
        var rgbBytes = [UInt16](repeating: 0, count: byteCount)
        var index = 0
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        //        let grayArray = mutableRawPointer.assumingMemoryBound(to: UInt16.self)
        for ri in (0..<height).reversed() {
            let row = mutableRawPointer.advanced(by: ri * bytesPerRow).assumingMemoryBound(to: UInt16.self)
            for ci in 0..<width {
                rgbBytes[index] = row[ci]
                index += 1
            }
        }
        
        return Data(copyingBufferOf: rgbBytes.map { Float($0) / Float(UINT16_MAX) })
    }
}

extension Data {
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
}

extension Array {
    /// Creates a new array from the bytes of the given unsafe data.
    ///
    /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
    ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
    ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
    /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
    ///     `MemoryLayout<Element>.stride`.
    /// - Parameter unsafeData: The data containing the bytes to turn into an array.
    init?(unsafeData: Data) {
        guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
        #if swift(>=5.0)
        self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
        #else
        self = unsafeData.withUnsafeBytes {
            .init(UnsafeBufferPointer<Element>(
                start: $0,
                count: unsafeData.count / MemoryLayout<Element>.stride
            ))
        }
        #endif  // swift(>=5.0)
    }
}

extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_16Gray, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }
        
        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
            
            let space = CGColorSpaceCreateDeviceGray()
            let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 16, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue)
            
            //            context?.translateBy(x: 0, y: self.size.height)
            //            context?.scaleBy(x: 1.0, y: -1.0)
            
            UIGraphicsPushContext(context!)
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            UIGraphicsPopContext()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            return pixelBuffer
        }
        
        return nil
    }
}

public func seperate(path:CGPath)-> [CGPath] {
    var draws:[CGMutablePath] = []
    path.applyWithBlock { (element) in
        let e = element.pointee
        let p = e.points.pointee
        switch e.type {
        case .moveToPoint:
            draws.append(CGMutablePath())
            draws.last?.move(to: p)
        case .addLineToPoint:
            draws.last?.addLine(to: p)
        default:
            print("-- unknown: \(e.type.rawValue)")
        }
    }
    
    let newPaths = draws.reduce([]) { (paths:[CGPath], path) -> [CGPath] in
        if let last = paths.last {
            let lastbox = last.boundingBoxOfPath
            let bbox = path.boundingBoxOfPath
            let sec = lastbox.intersection(bbox)
            guard let mu = last.mutableCopy() else {
                return paths + [path]
            }
            if sec.isNull {
                if bbox.maxY < lastbox.minY {
                    mu.addPath(path)
                    return paths.dropLast() + [mu]
                } else {
                    return paths + [path]
                }
            } else {
                if sec.width < lastbox.width/3 && sec.width < bbox.width/3 {
                    return paths + [path]
                } else {
                    mu.addPath(path)
                    return paths.dropLast() + [mu]
                }
            }
        } else {
            return [path]
        }
    }
    return newPaths
}

public func recognizeSingle(path:CGPath)->Result? {
    if let img = CGPath2SquareImage(path: path, toSize: 28) {
        return Static.model().runModel(onFrame: img)
    }
    return nil
}
public enum Sign:String {
    case N = "-"
    case P = ""
}
public func recognize(paths:[CGPath])->(Sign, [Result]) {
    let paths = paths.sorted { (a, b) -> Bool in
        return a.boundingBoxOfPath.midX < b.boundingBoxOfPath.midX
    }
    guard let first = paths.first else {
        return (.P, [])
    }
    let bbox = first.boundingBoxOfPath
    if 3 < bbox.width / bbox.height {
        return (.N, paths.dropFirst().compactMap({ recognizeSingle(path: $0) }))
    } else {
        return (.P, paths.compactMap({ recognizeSingle(path: $0) }))
    }
}
public func mostLikely(sign:Sign, results:[Result])-> String {
    return sign.rawValue + results.compactMap({
        $0.inferences.max()?.label
    }).joined()
}

public func recognize(path:CGPath)->String {
    let r = recognize(paths: seperate(path: path))
    return mostLikely(sign: r.0, results: r.1)
}

public func recognizeAsync(path:CGPath)-> Promise<String> {
    let pend = Promise<String>.pending()
    DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
        let r = recognize(paths: seperate(path: path))
        DispatchQueue.main.async {
            pend.fulfill(mostLikely(sign: r.0, results: r.1))
        }
    }
    return pend
}
