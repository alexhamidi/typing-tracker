const { GlobalKeyboardListener } = require('node-global-key-listener');

const keyboardListener = new GlobalKeyboardListener();

console.log('Keystroke listener started. Press any key...');
console.log('Press Ctrl+C to exit\n');

// Listen for all keyboard events
keyboardListener.addListener((e, down) => {
  console.log('Key event:', {
    name: e.name,
    state: down ? 'DOWN' : 'UP',
    rawKey: e.rawKey
  });
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nStopping keystroke listener...');
  keyboardListener.kill();
  process.exit(0);
});
