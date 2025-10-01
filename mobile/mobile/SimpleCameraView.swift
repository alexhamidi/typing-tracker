//
//  SimpleCameraView.swift
//  mobile
//

import SwiftUI
import AVFoundation
import Swifter

struct SimpleCameraView: View {
    var body: some View {
        CameraPreview()
            .ignoresSafeArea()
    }
}

class CameraViewController: UIViewController {
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    let videoOutput = AVCaptureVideoDataOutput()
    let outputQueue = DispatchQueue(label: "videoQueue")

    static var latestFrame: Data?
    let server = HttpServer()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Start HTTP server
        server["/frame"] = { request in
            if let frameData = CameraViewController.latestFrame {
                return .ok(.data(frameData, contentType: "image/jpeg"))
            } else {
                return .notFound
            }
        }

        do {
            try server.start(8080)
            print("✓ HTTP server started on port 8080")
        } catch {
            print("ERROR: Failed to start server: \(error)")
        }

        captureSession.sessionPreset = .hd1280x720

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            return
        }

        captureSession.addInput(input)

        // Add video output to capture frames
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        let uiImage = UIImage(cgImage: cgImage)

        if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            CameraViewController.latestFrame = jpegData
        }
    }
}

struct CameraPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
}
