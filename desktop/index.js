const { GlobalKeyboardListener } = require('node-global-key-listener');
const fs = require('fs');
const { Blob } = require('buffer');
const { RTCPeerConnection, RTCSessionDescription, RTCVideoSink } = require('@roamhq/wrtc');
const { createCanvas } = require('canvas');

const keyboardListener = new GlobalKeyboardListener();

// Global buffer to store the latest frame
let latestFrame = null;

// WebRTC connection setup
const pc = new RTCPeerConnection({
  iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
});

// Handle incoming video track
pc.ontrack = (event) => {
  console.log('Received video track from phone');
  const track = event.track;

  if (track.kind === 'video') {
    const sink = new RTCVideoSink(track);

    sink.onframe = ({ frame }) => {
      // Extract frame data
      const { width, height, data } = frame;

      // Create canvas
      const canvas = createCanvas(width, height);
      const ctx = canvas.getContext('2d');

      // Convert I420 to RGBA
      const rgbaData = i420ToRgba(data, width, height);

      // Create ImageData and put on canvas
      const imageData = ctx.createImageData(width, height);
      imageData.data.set(rgbaData);
      ctx.putImageData(imageData, 0, 0);

      // Store as JPEG buffer (overwrite previous frame)
      latestFrame = canvas.toBuffer('image/jpeg');
    };
  }
};

// I420 (YUV) to RGBA conversion
function i420ToRgba(i420Data, width, height) {
  const rgbaSize = width * height * 4;
  const rgba = new Uint8ClampedArray(rgbaSize);

  const ySize = width * height;
  const uvSize = ySize / 4;

  const yPlane = i420Data.slice(0, ySize);
  const uPlane = i420Data.slice(ySize, ySize + uvSize);
  const vPlane = i420Data.slice(ySize + uvSize, ySize + 2 * uvSize);

  for (let row = 0; row < height; row++) {
    for (let col = 0; col < width; col++) {
      const yIndex = row * width + col;
      const uvIndex = Math.floor(row / 2) * Math.floor(width / 2) + Math.floor(col / 2);

      const y = yPlane[yIndex];
      const u = uPlane[uvIndex];
      const v = vPlane[uvIndex];

      // YUV to RGB conversion
      const r = y + 1.402 * (v - 128);
      const g = y - 0.344136 * (u - 128) - 0.714136 * (v - 128);
      const b = y + 1.772 * (u - 128);

      const rgbaIndex = yIndex * 4;
      rgba[rgbaIndex] = Math.max(0, Math.min(255, r));
      rgba[rgbaIndex + 1] = Math.max(0, Math.min(255, g));
      rgba[rgbaIndex + 2] = Math.max(0, Math.min(255, b));
      rgba[rgbaIndex + 3] = 255; // Alpha
    }
  }

  return rgba;
}

// ICE candidates will be handled per WebSocket connection

// WebSocket signaling server
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
  console.log('Phone connected to signaling server');

  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);

      switch (data.type) {
        case 'offer':
          console.log('Received offer from phone');
          const offer = new RTCSessionDescription({ type: 'offer', sdp: data.sdp });
          await pc.setRemoteDescription(offer);
          const answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          ws.send(JSON.stringify({ type: 'answer', sdp: answer.sdp }));
          break;

        case 'candidate':
          if (data.candidate) {
            const candidate = new RTCIceCandidate({
              candidate: data.candidate.candidate,
              sdpMLineIndex: data.candidate.sdpMLineIndex,
              sdpMid: data.candidate.sdpMid
            });
            await pc.addIceCandidate(candidate);
          }
          break;
      }
    } catch (error) {
      console.error('Error handling signaling message:', error);
    }
  });

  // Send ICE candidates to phone
  pc.onicecandidate = (event) => {
    if (event.candidate && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'candidate',
        candidate: {
          candidate: event.candidate.candidate,
          sdpMLineIndex: event.candidate.sdpMLineIndex,
          sdpMid: event.candidate.sdpMid
        }
      }));
    }
  };

  ws.on('close', () => {
    console.log('Phone disconnected from signaling server');
  });
});

console.log('WebSocket signaling server running on port 8080');

console.log('Keystroke listener started. Press any key...');
console.log('Press Ctrl+C to exit\n');

// Listen for all keyboard events
keyboardListener.addListener(async (e, down) => {
  console.log('Key event:', {
    name: e.name,
    state: down ? 'DOWN' : 'UP',
    rawKey: e.rawKey
  });

  // Skip if no frame available yet
  if (!latestFrame) {
    console.log('No frame available yet, skipping inference');
    return;
  }

  const url = "http://localhost:8000/infer/" + e.name

  const blob = new Blob([latestFrame], { type: 'image/jpeg' });
  const file = new File([blob], 'frame.jpg', { type: 'image/jpeg' });

  const formData = new FormData();
  formData.append("file", file);

  const response = await fetch(url, {
    method: "POST",
    body: formData
  })

  const data = await response.json()
  console.log(data)

});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nStopping keystroke listener...');
  keyboardListener.kill();
  process.exit(0);
});
