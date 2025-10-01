
on keypress, we tell the phone to take a picture 

mobile side - take photo and send to desktop on demand (quickly)

or just stream recording



If you want to stream video in real time (e.g., like FaceTime, Zoom, or Twitch), you’ll need to use AVCaptureSession with AVCaptureVideoDataOutput.

That lets you grab video frames (CMSampleBuffer) as they’re captured.

You can then encode them (H.264, HEVC, or WebRTC) and push them over a socket, RTMP, WebRTC, or a custom API endpoint.

This requires more work: you handle compression, networking, and possibly packetization.

Many apps that do real-time streaming (like broadcasting apps) use WebRTC or RTMP libraries on iOS for this.

]
# hardest problem:

finger = f(key, image)

use a vit?_


assume we have a black box endpoint 

# details
The Simple Design

Phone (Swift app)

Continuously streams video frames to the desktop.

Use WebRTC or a lightweight socket stream (e.g., RTP over UDP).

Phone never waits for a request — it just keeps sending.

Desktop (Node.js)

Always receives frames from the phone and decodes them into memory.

Keeps only the most recent frame in a buffer (overwrite the old one every time).

On trigger, it just grabs the frame that’s already in memory — no network hop, no wait.

Trigger Event

The trigger code reads the latest frame pointer from memory (instant).

At that point, you have an image ready to use.

Why This Works for <20 ms

The stream is always “hot” — phone is sending, desktop is decoding.

Trigger doesn’t cause any network round trip.

“Trigger → image ready” is just a memory read, which is basically free (<1 ms).

What to Build (Step by Step)

Phone side (Swift)

Capture frames (AVCaptureVideoDataOutput).

Encode them with hardware H.264.

Send over WebRTC (easiest) or a raw UDP stream.

Desktop side (Node.js)

Use wrtc (WebRTC library) to receive the video track.

Continuously decode frames.

Store the latest one in a global variable like latestFrame.

On trigger: use(latestFrame).