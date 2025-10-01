//
//  WebRTCManager.swift
//  mobile
//
//  Created by alex h on 9/30/25.
//

import Foundation
import WebRTC

class WebRTCManager: NSObject {
    private var peerConnection: RTCPeerConnection?
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var videoTrack: RTCVideoTrack?
    private var videoSource: RTCVideoSource?
    private var dataChannel: RTCDataChannel?

    private let videoQueue = DispatchQueue(label: "com.mobile.webrtc.video")

    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    var onConnectionStateChange: ((RTCPeerConnectionState) -> Void)?

    override init() {
        super.init()
        setupPeerConnectionFactory()
    }

    private func setupPeerConnectionFactory() {
        RTCInitializeSSL()

        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()

        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
    }

    func createPeerConnection(iceServers: [String] = ["stun:stun.l.google.com:19302"]) throws {
        let config = RTCConfiguration()
        config.iceServers = iceServers.map { serverUrl in
            RTCIceServer(urlStrings: [serverUrl])
        }
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let pc = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        ) else {
            throw WebRTCError.peerConnectionCreationFailed
        }

        peerConnection = pc
        setupVideoTrack()
    }

    private func setupVideoTrack() {
        videoSource = peerConnectionFactory.videoSource()

        // Create video track
        videoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "video0")

        // Add track to peer connection
        guard let pc = peerConnection, let track = videoTrack else {
            return
        }

        pc.add(track, streamIds: ["stream0"])
    }

    func sendVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let videoSource = videoSource,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeStampNs = Int64(CMTimeGetSeconds(timeStamp) * 1_000_000_000)

        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let rtcVideoFrame = RTCVideoFrame(
            buffer: rtcPixelBuffer,
            rotation: RTCVideoRotation._0,
            timeStampNs: timeStampNs
        )

        videoSource.capturer(RTCVideoCapturer(), didCapture: rtcVideoFrame)
    }

    func createOffer(completion: @escaping (Result<RTCSessionDescription, Error>) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveVideo": "false",
                "OfferToReceiveAudio": "false"
            ],
            optionalConstraints: nil
        )

        peerConnection?.offer(for: constraints) { sdp, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let sdp = sdp else {
                completion(.failure(WebRTCError.offerCreationFailed))
                return
            }

            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(sdp))
                }
            }
        }
    }

    func setRemoteDescription(_ sdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        peerConnection?.setRemoteDescription(sdp, completionHandler: completion)
    }

    func addIceCandidate(_ candidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        peerConnection?.add(candidate, completionHandler: completion)
    }

    func close() {
        peerConnection?.close()
        peerConnection = nil
        videoTrack = nil
        videoSource = nil
    }

    deinit {
        RTCCleanupSSL()
    }

    enum WebRTCError: Error {
        case peerConnectionCreationFailed
        case offerCreationFailed
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Stream added")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("Stream removed")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE connection state changed: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        onIceCandidate?(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ICE candidates removed")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        print("Peer connection state changed: \(newState.rawValue)")
        onConnectionStateChange?(newState)
    }
}
