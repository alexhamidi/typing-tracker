# Mobile Video Streaming App

This iOS app continuously streams video frames to a desktop application for low-latency typing tracking.

## Architecture

The app implements the design from `plan.md`:

- **CameraManager**: Handles AVCaptureSession setup and captures video frames at 30fps
- **WebRTCManager**: Manages WebRTC peer connection and streams video
- **SignalingClient**: WebSocket-based signaling for WebRTC handshake
- **ContentViewModel**: Coordinates all components and manages app state
- **ContentView**: UI with camera preview and streaming controls

## Setup

### 1. Install CocoaPods Dependencies

```bash
cd mobile
pod install
```

### 2. Open Workspace

```bash
open mobile.xcworkspace
```

**Important**: Always use `mobile.xcworkspace`, not `mobile.xcodeproj` after installing pods.

### 3. Add Files to Xcode

If the new Swift files aren't visible in Xcode:
1. Right-click the `mobile` group in Project Navigator
2. Select "Add Files to mobile..."
3. Add:
   - `CameraManager.swift`
   - `VideoEncoder.swift`
   - `WebRTCManager.swift`
   - `ContentViewModel.swift`

### 4. Configure Signing

1. Select the project in Project Navigator
2. Select the `mobile` target
3. Go to "Signing & Capabilities"
4. Select your development team

### 5. Run on Device

WebRTC streaming requires a physical iOS device (simulator won't work for camera access).

## Usage

1. Make sure your desktop signaling server is running (default: `ws://localhost:8080`)
2. Update the desktop URL in the app if different
3. Tap "Start Streaming" to begin
4. The app will continuously stream video frames at ~30fps
5. Desktop receives frames in real-time with <20ms latency

## How It Works

1. **Continuous Streaming**: Camera captures frames at 30fps using `AVCaptureVideoDataOutput`
2. **Hardware Encoding**: Frames are encoded with H.264 using VideoToolbox
3. **WebRTC Transport**: Encoded frames sent via WebRTC data channel
4. **Desktop Buffering**: Desktop maintains latest frame in memory
5. **On Trigger**: Desktop reads from buffer (no network wait)

## Permissions

The app requires:
- **Camera**: To capture video frames
- **Local Network**: To connect to desktop via WebSocket/WebRTC

These are configured in `Info.plist`.

## Next Steps

- Implement the desktop Node.js receiver (see `plan.md`)
- Add signaling server
- Test end-to-end latency
- Optimize frame rate/quality for your use case
