//
//  ViewController.swift
//  swift_ehancements_test
//
//  Created by ios_k on 6/24/24.
//

import UIKit
import AVFoundation
import Vision
import ImageIO

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let imagePicker = UIImagePickerController()
    var capturedImage: UIImage? {
        didSet {
            self.imageView.image = self.capturedImage
        }
    }
    var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let selectPhotoButton = UIButton(type: .system)
        let captureButton = UIButton(type: .system)
        view.addSubview(captureButton)
        view.addSubview(selectPhotoButton)
        
        selectPhotoButton.setTitle("选择照片", for: .normal)
        selectPhotoButton.addTarget(self, action: #selector(selectPhotoButtonTapped), for: .touchUpInside)
        
        selectPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            selectPhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectPhotoButton.centerYAnchor.constraint(equalTo: captureButton.bottomAnchor, constant: 20)
        ])
        
        captureButton.setTitle("拍照", for: .normal)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 100)
        ])
        
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: selectPhotoButton.bottomAnchor, constant: 20),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        imagePicker.delegate = self
    }
    
    @objc func selectPhotoButtonTapped() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @objc func capturePhoto() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
            present(imagePicker, animated: true, completion: nil)
        } else {
            // 处理相机不可用的情况
            print("相机不可用")
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            capturedImage = image.fixOrientation()
            recognizeImage(image: image)
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func recognizeImage(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("无法获取CGImage")
            return
        }
        capturedImage = image.fixOrientation()
        let barcodesRequest = DetectBarcodesRequest()
        
        var textRequest = RecognizeTextRequest()
        textRequest.automaticallyDetectsLanguage = true
        textRequest.usesLanguageCorrection = true
        textRequest.recognitionLevel = .accurate
        
        let handler = ImageRequestHandler(image.pngData()!, orientation: CGImagePropertyOrientation(image.imageOrientation))
        
        let requests: [any VisionRequest] = [barcodesRequest, textRequest]
//        let requests: [any VisionRequest] = [textRequest]
        let stream = handler.performAll(requests)
        
        Task {
            for try await result in stream {
                switch result {
                case .detectBarcodes(_, let barcodes):
                    // [BarcodeObservation]
                    if let productIdentifier = barcodes.first?.payloadString, let normalizedBoundingBox = barcodes.first?.boundingBox {
                        if let capturedImage = self.capturedImage {
                            self.capturedImage = self.drawObservations(normalizedBoundingBox: normalizedBoundingBox, content: productIdentifier, on: capturedImage)
                        }
                    } else {
                        print("未检测到条码")
                    }
                case .recognizeText(_, let text):
                    // [RecognizedTextObservation]
//                    print("text: \(text)")
                    if let capturedImage = self.capturedImage {
                        self.capturedImage = self.drawObservations(observation: text, on: capturedImage)
                    }
//                    for textObservation in text {
//                        let recognizedTextList = textObservation.topCandidates(1)
//                        print("recognizedTextList: \(recognizedTextList)")
//                        if let recognizedText = recognizedTextList.first {
//                            let string = recognizedText.string
//                            if let start = string.startIndex.samePosition(in: string.utf16),
//                               let end = string.index(start, offsetBy: string.utf16.count, limitedBy: string.endIndex),
//                               let rectangleObservation = recognizedText.boundingBox(for: start..<end) {
//                                let boundingBox = rectangleObservation.boundingBox
//                                capturedImage = self.drawObservations(normalizedBoundingBox: boundingBox, content: "\(string) -- confidence: \(recognizedText.confidence)", on: capturedImage!)
//                            }
//                            print("string: \(string) -- confidence: \(recognizedText.confidence)")
//                        }
//                    }
//                    if let textString = text.first?.topCandidates(1).first?.string,
//                       let start = textString.startIndex.samePosition(in: textString.utf16),
//                       let end = textString.index(start, offsetBy: textString.utf16.count, limitedBy: textString.endIndex),
//                       let rectangleObservation = text.first?.topCandidates(1).first?.boundingBox(for: start..<end) {
//                        let boundingBox = rectangleObservation.boundingBox
//                        capturedImage = self.drawObservations(normalizedBoundingBox: boundingBox, content: textString, on: capturedImage!)
//                    }
                    if text.count == 0 {
                        print("未检测到文本 number:\(text.count))")
                    }
                default:
                    print("无法识别: \(result)")
                }
            }
        }
    }
    
    func drawObservations(normalizedBoundingBox: NormalizedRect, content: String, on image: UIImage) -> UIImage? {
        let imageSize = image.size
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(20.0)
        
        let boundingBoxNew = normalizedBoundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
//        let boundingBox = CGRect(x: normalizedBoundingBox.cgRect.origin.x*imageSize.width, y: normalizedBoundingBox.cgRect.origin.y*imageSize.height, width: normalizedBoundingBox.cgRect.width*imageSize.width, height: normalizedBoundingBox.cgRect.height*imageSize.height)
        context.addRect(boundingBoxNew)
        context.strokePath()
        
        let textFontAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 58, weight: .heavy),
            .foregroundColor: UIColor.blue
        ]
        
        let contentRect = CGRect(x: boundingBoxNew.origin.x, y: boundingBoxNew.origin.y - 60, width: boundingBoxNew.width < 200 ? 200 : boundingBoxNew.width , height: 60)
        content.draw(in: contentRect, withAttributes: textFontAttributes)
        
        print("imageSize: \(imageSize), boundingBoxNew: \(boundingBoxNew), contentRect: \(contentRect), content: \(content)")
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
//    VisionObservation
    func drawObservations(observation: [any VisionObservation], on image: UIImage) -> UIImage? {
        let imageSize = image.size
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        
        if let text = observation as? [RecognizedTextObservation] {
            for (index, textObservation) in text.enumerated() {
//                if index > 1 { break }
                print("index: \(index)")
                let recognizedTextList = textObservation.topCandidates(1)
                if let recognizedText = recognizedTextList.first {
                    let string = recognizedText.string
                    if let start = string.startIndex.samePosition(in: string.utf16),
                       let end = string.index(start, offsetBy: string.utf16.count, limitedBy: string.endIndex),
                       let rectangleObservation = recognizedText.boundingBox(for: start..<end) {
                        
                        context.setStrokeColor(UIColor.red.cgColor)
                        context.setLineWidth(5.0)
                        
                        let boundingBox = rectangleObservation.boundingBox
                        let boundingBoxNew = boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
                        context.addRect(boundingBoxNew)
                        context.strokePath()
                        
                        let textFontAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 38, weight: .heavy),
                            .foregroundColor: UIColor.blue
                        ]
                        
                        let contentRect = CGRect(x: boundingBoxNew.origin.x, y: boundingBoxNew.origin.y - 40, width: boundingBoxNew.width < 200 ? 200 : boundingBoxNew.width , height: 60)
                        string.draw(in: contentRect, withAttributes: textFontAttributes)
                    }
                    
                    print("string: \(string) -- confidence: \(recognizedText.confidence)")
                }
            }
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

extension CGRect {
    func toImageCoordinates(_ imageSize: CGSize, origin: CGPoint) -> CGRect {
        return CGRect(
            x: origin.x + self.origin.x * imageSize.width,
            y: origin.y + (1 - self.origin.y - self.size.height) * imageSize.height,
            width: self.size.width * imageSize.width,
            height: self.size.height * imageSize.height
        )
    }
}

// 修正图片方向的扩展
extension UIImage {
    func fixOrientation() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        if imageOrientation == .up {
            return self
        }
        
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else { return nil }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        guard let newCgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCgImage)
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            fatalError()
        }
    }
}
extension UIImage.Orientation {
    init(_ cgOrientation: UIImage.Orientation) {
        switch cgOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            fatalError()
        }
    }
}
