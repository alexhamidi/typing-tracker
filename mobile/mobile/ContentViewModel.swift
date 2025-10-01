//
//  ContentViewModel.swift
//  mobile
//
//  Created by alex h on 9/30/25.
//

import Foundation
import SwiftUI
import AVFoundation
import WebRTC

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isStreaming = false
    @Published var connectionState: String = "Disconnected"
    @Published var errorMessage: String?

    private let cameraManager = CameraManager()
    private let webRTCManager = WebRTCManager()
    private let signalingClient = SignalingClient()

    var previewLayer: AVCaptureVideoPreviewLayer? {
        cameraManager.previewLayer
    }

    init() {
        setupManagers()
    }

    private func setupManagers() {
        cameraManager.delegate = self

        webRTCManager.onConnectionStateChange = { [weak self] state in
            Task { @MainActor in
                self?.updateConnectionState(state)
            }
        }

        webRTCManager.onIceCandidate = { [weak self] candidate in
            Task {
                await self?.signalingClient.sendIceCandidate(candidate)
            }
        }

        signalingClient.onRemoteDescription = { [weak self] sdp in
            self?.webRTCManager.setRemoteDescription(sdp) { error in
                if let error = error {
                    print("Error setting remote description: \(error)")
                }
            }
        }

        signalingClient.onIceCandidate = { [weak self] candidate in
            self?.webRTCManager.addIceCandidate(candidate) { error in
                if let error = error {
                    print("Error adding ICE candidate: \(error)")
                }
            }
        }
    }

    func setupCamera() async {
        do {
            try await cameraManager.setupCamera()
        } catch {
            errorMessage = "Camera setup failed: \(error.localizedDescription)"
        }
    }

    func startStreaming(desktopUrl: String) async {
        do {
            // Connect to signaling server
            try await signalingClient.connect(to: desktopUrl)

            // Create peer connection
            try webRTCManager.createPeerConnection()

            // Start camera
            cameraManager.startCapture()

            // Create and send offer
            let result = await withCheckedContinuation { continuation in
                webRTCManager.createOffer { result in
                    continuation.resume(returning: result)
                }
            }

            switch result {
            case .success(let offer):
                await signalingClient.sendOffer(offer)
                isStreaming = true
            case .failure(let error):
                errorMessage = "Failed to create offer: \(error.localizedDescription)"
            }

        } catch {
            errorMessage = "Streaming failed: \(error.localizedDescription)"
        }
    }

    func stopStreaming() {
        cameraManager.stopCapture()
        webRTCManager.close()
        signalingClient.disconnect()
        isStreaming = false
        connectionState = "Disconnected"
    }

    private func updateConnectionState(_ state: RTCPeerConnectionState) {
        switch state {
        case .new:
            connectionState = "New"
        case .connecting:
            connectionState = "Connecting"
        case .connected:
            connectionState = "Connected"
        case .disconnected:
            connectionState = "Disconnected"
        case .failed:
            connectionState = "Failed"
            errorMessage = "Connection failed"
        case .closed:
            connectionState = "Closed"
        @unknown default:
            connectionState = "Unknown"
        }
    }
}

// MARK: - CameraManagerDelegate
extension ContentViewModel: CameraManagerDelegate {
    nonisolated func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        // Send frame directly to WebRTC (hardware encoding happens in WebRTC)
        webRTCManager.sendVideoFrame(sampleBuffer)
    }
}

// MARK: - SignalingClient
class SignalingClient {
    var onRemoteDescription: ((RTCSessionDescription) -> Void)?
    var onIceCandidate: ((RTCIceCandidate) -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?

    func connect(to urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw SignalingError.invalidURL
        }

        session = URLSession(configuration: .default)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        startListening()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    func sendOffer(_ offer: RTCSessionDescription) async {
        let message = SignalingMessage(type: "offer", sdp: offer.sdp)
        await send(message)
    }

    func sendAnswer(_ answer: RTCSessionDescription) async {
        let message = SignalingMessage(type: "answer", sdp: answer.sdp)
        await send(message)
    }

    func sendIceCandidate(_ candidate: RTCIceCandidate) async {
        let candidateDict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? ""
        ]
        let message = SignalingMessage(type: "candidate", candidate: candidateDict)
        await send(message)
    }

    private func send(_ message: SignalingMessage) async {
        guard let webSocket = webSocket else { return }

        do {
            let data = try JSONEncoder().encode(message)
            let string = String(data: data, encoding: .utf8) ?? ""
            try await webSocket.send(.string(string))
        } catch {
            print("Failed to send message: \(error)")
        }
    }

    private func startListening() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.startListening() // Continue listening
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }

        do {
            let data = text.data(using: .utf8) ?? Data()
            let signalingMessage = try JSONDecoder().decode(SignalingMessage.self, from: data)

            switch signalingMessage.type {
            case "answer":
                if let sdp = signalingMessage.sdp {
                    let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
                    onRemoteDescription?(sessionDescription)
                }
            case "candidate":
                if let candidateDict = signalingMessage.candidate,
                   let candidateString = candidateDict["candidate"] as? String,
                   let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int32,
                   let sdpMid = candidateDict["sdpMid"] as? String {
                    let candidate = RTCIceCandidate(
                        sdp: candidateString,
                        sdpMLineIndex: sdpMLineIndex,
                        sdpMid: sdpMid
                    )
                    onIceCandidate?(candidate)
                }
            default:
                break
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }

    enum SignalingError: Error {
        case invalidURL
    }
}

struct SignalingMessage: Codable {
    let type: String
    let sdp: String?
    let candidate: [String: Any]?

    init(type: String, sdp: String? = nil, candidate: [String: Any]? = nil) {
        self.type = type
        self.sdp = sdp
        self.candidate = candidate
    }

    enum CodingKeys: String, CodingKey {
        case type, sdp, candidate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        sdp = try container.decodeIfPresent(String.self, forKey: .sdp)
        if let candidateData = try? container.decodeIfPresent(Data.self, forKey: .candidate) {
            candidate = try? JSONSerialization.jsonObject(with: candidateData) as? [String: Any]
        } else {
            candidate = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(sdp, forKey: .sdp)
        if let candidate = candidate {
            let data = try JSONSerialization.data(withJSONObject: candidate)
            try container.encode(data, forKey: .candidate)
        }
    }
}
