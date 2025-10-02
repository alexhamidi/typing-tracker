# Typing Tracker

A real-time typing posture correction system that uses computer vision to detect which finger you're using to press each key and provides instant feedback when you use the wrong finger.

## Overview

The system consists of three components:
1. **Mobile App (iOS)** - Streams video of your hands via camera
2. **Inference Model (Python/FastAPI)** - Detects finger positions using MediaPipe
3. **Desktop App (Node.js)** - Listens to keystrokes and validates finger usage

## How It Works

1. The mobile app continuously streams video frames from your phone's camera
2. When you press a key, the desktop app captures the current frame from the mobile stream
3. The frame is sent to the inference model which detects hand landmarks and identifies which finger is closest to the key
4. If the wrong finger is detected, the system provides audio feedback and automatically deletes the mistyped character

## Prerequisites

- **macOS** (for desktop app - uses macOS-specific features)
- **iOS device** (iPhone/iPad with camera)
- **Python 3.11+** (for inference model)
- **Node.js 18+** (for desktop app)
- **Xcode** (for building the iOS app)
- **CocoaPods** (for iOS dependencies)

Both devices must be on the same local network.

## Setup Instructions

### 1. Mobile App Setup

The mobile app streams video frames from your iPhone's camera over HTTP.

#### Installation

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```

2. Install CocoaPods dependencies:
   ```bash
   pod install
   ```

3. Open the Xcode workspace:
   ```bash
   open mobile.xcworkspace
   ```

4. In Xcode:
   - Select your iPhone as the target device
   - Update the bundle identifier if needed
   - Build and run the app (⌘R)

5. Allow camera permissions when prompted

6. Find your iPhone's IP address:
   - Go to Settings → Wi-Fi → tap the (i) icon next to your network
   - Note the IP address (e.g., `192.168.1.100`)

The app will now stream video frames on `http://<iPhone-IP>:8080/frame`

### 2. Inference Model Setup

The inference model uses MediaPipe to detect hand landmarks and determine which finger is being used.

#### Installation

1. Navigate to the inference model directory:
   ```bash
   cd inference_model
   ```

2. Install dependencies using uv:
   ```bash
   uv sync
   ```

#### Running the Server

Start the FastAPI server:
```bash
uv run python main.py
```

The server will be available at `http://localhost:8000`

### 3. Desktop Calibration

Before you can use the typing tracker, you need to calibrate each key by recording where it appears in the camera frame.

#### Installation

1. Navigate to the desktop directory:
   ```bash
   cd desktop
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Update the mobile IP address in `index.js`:
   - Open `desktop/index.js`
   - Find line 113: `const res = await fetch("http://100.116.66.24:8080/frame");`
   - Replace `100.116.66.24` with your iPhone's IP address

#### Calibration Process

1. Set calibration mode to `true` in `desktop/index.js`:
   ```javascript
   const calibrating = true;
   ```

2. Position your phone's camera so it has a clear view of your keyboard and hands

3. Run the calibration script:
   ```bash
   npm run dev
   ```

4. For each key you want to track:
   - Hold your **left index finger** over the key
   - Press the key
   - The system will record the finger position for that key
   - A calibration image will be saved showing the detected finger position

5. Repeat for all keys you want to track (recommended: calibrate all letter keys, numbers, and common symbols)

6. The calibration data is saved in `inference_model/keyboard_calibration.txt`

7. Once complete, set calibration mode back to `false`:
   ```javascript
   const calibrating = false;
   ```

**Calibration Tips:**
- Ensure consistent lighting
- Keep your camera position fixed after calibration
- Calibrate in your natural typing position
- The calibration file stores key positions as: `KEY_NAME,x,y`

## Getting Started

Once calibration is complete, you can start using the typing tracker:

1. **Start the inference model** (in `inference_model/`):
   ```bash
   uv run python main.py
   ```

2. **Start the mobile app**:
   - Launch the app on your iPhone
   - Position it **above your keyboard** looking down to view your keyboard and hands
   - Ensure it shows the camera preview

3. **Start the desktop listener** (in `desktop/`):
   ```bash
   npm run dev
   ```

4. **Start typing!**
   - When you press a key, the system will:
     - ✓ Display a checkmark if you used the correct finger
     - ⚠️ Show a warning and play a sound if you used the wrong finger
     - Automatically delete the mistyped character (backspace)

## Configuration

### Finger Mapping

The optimal finger mapping is defined in `desktop/index.js` (lines 41-108). The system uses this mapping to determine the correct finger for each key:

- **Left Pinky (lp)**: Q, A, Z, 1, Left Shift, Left Ctrl, etc.
- **Left Ring (lr)**: W, S, X, 2
- **Left Middle (lm)**: E, D
- **Left Index (li)**: R, F, V, T, G, B, 3, 4, 5
- **Left/Right Thumb (lt/rt)**: Space bar
- **Right Index (ri)**: Y, H, N, 6, 7
- **Right Middle (rm)**: U, J, M, K, 8
- **Right Ring (rr)**: I, O, L, 9
- **Right Pinky (rp)**: P, ;, ', /, 0, -, =, [, ], \, Backspace, Enter, Right Shift

### Network Configuration

Update IP addresses in:
- `desktop/index.js` line 113: Mobile app IP
- `inference_model/main.py`: Server will bind to `0.0.0.0:8000`

### Audio Feedback

Wrong finger detection plays a system sound (macOS):
```javascript
exec('afplay /System/Library/Sounds/Basso.aiff');
```

You can change this to any macOS system sound in `/System/Library/Sounds/`

## API Endpoints

### Inference Model

- `POST /record/{key_code}` - Record calibration data for a key
  - Accepts: `multipart/form-data` with image file
  - Returns: Key position and calibration status

- `POST /infer/{key_code}` - Detect which finger is pressing a key
  - Accepts: `multipart/form-data` with image file
  - Returns: Closest finger, distance, and annotated image

### Mobile App

- `GET /frame` - Get the latest camera frame
  - Returns: JPEG image data

## Troubleshooting

### Mobile app not streaming
- Ensure the app has camera permissions
- Check that the phone and computer are on the same network
- Verify the HTTP server started (check Xcode console for "✓ HTTP server started on port 8080")

### No finger detected
- Improve lighting conditions
- Ensure hands are clearly visible in the camera frame
- Re-run calibration if camera position has changed

### Wrong finger detected consistently
- Re-calibrate the problematic keys
- Ensure consistent hand positioning during typing
- Check that the camera view hasn't shifted since calibration

### Desktop app can't connect
- Verify the mobile app IP address in `desktop/index.js`
- Ensure the inference model server is running on port 8000
- Check firewall settings aren't blocking connections

## Project Structure

```
typing-tracker/
├── desktop/              # Node.js keystroke listener
│   ├── index.js         # Main application
│   └── package.json     # Dependencies
│
├── inference_model/     # Python FastAPI server
│   ├── main.py         # Hand detection & inference
│   ├── pyproject.toml  # Dependencies
│   └── keyboard_calibration.txt  # Calibration data
│
└── mobile/             # iOS camera streaming app
    ├── mobile/
    │   ├── ContentView.swift
    │   └── SimpleCameraView.swift
    └── Podfile         # iOS dependencies
```

## Technical Details

- **Hand Detection**: MediaPipe Hands library detects 21 3D hand landmarks
- **Finger Identification**: System tracks 5 fingertips (thumb, index, middle, ring, pinky) for each hand
- **Matching Algorithm**: Euclidean distance between detected fingertip and calibrated key position
- **Video Streaming**: Phone continuously captures and serves frames over HTTP
- **Latency**: Typically <20ms from keystroke to finger detection

## License

MIT

## Contributing

Contributions welcome! Please open an issue or submit a pull request.
