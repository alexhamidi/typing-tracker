const { GlobalKeyboardListener } = require('node-global-key-listener');
const fs = require('fs');
const { Blob } = require('buffer');
const keyboardListener = new GlobalKeyboardListener();

console.log('Keystroke listener started. Press any key...');
console.log('Press Ctrl+C to exit\n');

// Listen for all keyboard events
keyboardListener.addListener(async (e, down) => {
  console.log('Key event:', {
    name: e.name,
    state: down ? 'DOWN' : 'UP',
    rawKey: e.rawKey
  });

  const url = "http://localhost:8000/infer/" + e.name;

  const res = await fetch("http://100.116.66.24:8080/frame");
  const arrayBuffer = await res.arrayBuffer();
  const blob = new Blob([Buffer.from(arrayBuffer)], { type: 'image/jpeg' });
  const file = new File([blob], 'test.jpg', { type: 'image/jpeg' });

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
