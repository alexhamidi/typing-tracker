# Typing Tracker

Real-time typing correction using computer vision to detect which finger presses each key.

## Prerequisites

- macOS
- iOS device with camera
- Python 3.11+ with `uv`
- Node.js 18+
- Xcode & CocoaPods

Both devices must be on the same network.

## Setup

### 1. Mobile App

```bash
cd mobile
pod install
open mobile.xcworkspace
```

Build and run in Xcode (⌘R). Position phone **above keyboard** looking down.

### 2. Inference Model

```bash
cd inference_model
uv sync
uv run python main.py
```

### 3. Calibration

```bash
cd desktop
npm install
```

1. Update your iPhone IP in `index.js` line 113
2. Set `calibrating = true` in `index.js`
3. Run `npm run dev`
4. Hold left index finger over each key and press it
5. Set `calibrating = false` in `index.js`

### 4. Running

Start all three components:

```bash
# Terminal 1 - Inference model
cd inference_model
uv run python main.py

# Terminal 2 - Desktop listener
cd desktop
npm run dev

# Mobile - Launch app on iPhone, position above keyboard
```

Start typing! The system will alert you when you use the wrong finger.
