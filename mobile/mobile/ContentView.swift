//
//  ContentView.swift
//  mobile
//
//  Created by alex h on 9/30/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var desktopUrl = "ws://localhost:8080"

    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(previewLayer: viewModel.previewLayer)
                .edgesIgnoringSafeArea(.all)

            // Controls overlay
            VStack {
                Spacer()

                VStack(spacing: 20) {
                    // Status
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        Text(viewModel.connectionState)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                    }

                    // Desktop URL input
                    if !viewModel.isStreaming {
                        TextField("Desktop URL", text: $desktopUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 40)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    // Start/Stop button
                    Button(action: {
                        Task {
                            if viewModel.isStreaming {
                                viewModel.stopStreaming()
                            } else {
                                await viewModel.startStreaming(desktopUrl: desktopUrl)
                            }
                        }
                    }) {
                        Text(viewModel.isStreaming ? "Stop Streaming" : "Start Streaming")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(viewModel.isStreaming ? Color.red : Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .task {
            await viewModel.setupCamera()
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case "Connected":
            return .green
        case "Connecting":
            return .yellow
        case "Failed":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        if let previewLayer = previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

#Preview {
    ContentView()
}
