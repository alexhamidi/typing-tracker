const { GlobalKeyboardListener } = require('node-global-key-listener');
const fs = require('fs');
const { Blob } = require('buffer');
const { exec } = require('child_process');
const robot = require('robotjs');
const keyboardListener = new GlobalKeyboardListener();

console.log('Keystroke listener started. Press any key...');
console.log('Press Ctrl+C to exit\n');

const get_name = (finger) => {
  const data = {
    "lp": "Left Pinky",
    "lr": "Left Ring",
    "lm": "Left Middle",
    "li": "Left Index",
    "lt": "Left Thumb",
    "rp": "Right Pinky",
    "rr": "Right Ring",
    "rm": "Right Middle",
    "ri": "Right Index",
    "rt": "Right Thumb",
  }
  return data[finger];
}
// Listen for all keyboard events
keyboardListener.addListener(async (e, down) => {
  // Only process key down events (down is an object with state)
  if (!down[e.name])return;

  const optimal_mapping = {
    "LEFT CTRL": "lp",
    "LEFT SHIFT": "lp",
    "LEFT META": "lt",
    "BACKTICK": "lp",
    "1": "lr",
    "Q": "lp",
    "A": "lp",
    "Z": "lp",
    "LEFT ALT": "lt",
    "FN": "lp",
    "W": "lr",
    "S": "lr",
    "X": "lr",

    "E": "lm",
    "D": "lm",
    "C": "li",
    "3": "li",
    "4": "li",
    "R": "li",
    "F": "li",
    "V": "li",
    "5": "li",
    "T": "li",
    "G": "li",
    "B": "li",

    "SPACE": "lt",

    "6": "ri",
    "7": "ri",
    "Y": "ri",
    "H": "ri",
    "N": "ri",
    "U": "rm",
    "J": "ri",
    "M": "ri",

    "8": "rm",
    "I": "rm",
    "K": "rm",
    "COMMA": "rm",

    "9": "rr",
    "O": "rr",
    "L": "rr",
    "DOT": "rr",

    "0": "rp",
    "MINUS": "rp",
    "EQUALS": "rp",
    "BACKSPACE": "rp",
    "BACKSLASH": "rp",
    "SQUARE BRACKET OPEN": "rp",
    "SQUARE BRACKET CLOSE": "rp",
    "P": "rr",
    "SEMICOLON": "rp",
    "QUOTE": "rp",
    "RETURN": "rp",
    "FORWARD SLASH": "rp",
    "RIGHT SHIFT": "rp",
    "RIGHT ALT": "rp",
    "RIGHT META": "rp",
    "DOWN ARROW": "rp",
    "LEFT ARROW": "rp",
    "UP ARROW": "rp",
}


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

  // Check if finger matches optimal mapping
  const optimal = optimal_mapping[e.name];
  const detected = data.closest_finger;

  if (optimal && detected) {
    // Special case: space bar accepts either thumb
    if (e.name === "SPACE" && (detected === "lt" || detected === "rt")) {
      console.log(`✓ ${e.name}: Correct finger (${get_name(detected)})`);
    } else if (optimal === detected) {
      console.log(`✓ ${e.name}: Correct finger (${get_name(detected)})`);
    } else {
      console.log(`\n⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️`);
      console.log(`\n⚠️  WARNING: WRONG FINGER DETECTED! ⚠️`);
      console.log(`\n⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️`);
      console.log(`   YOU USED YOUR  ${get_name(detected)} to click the ${e.name} key, use your ${get_name(optimal)} instead`);

      // Send backspace to undo the wrong keystroke immediately
      robot.keyTap('backspace');

      // Play error sound (macOS system beep)
      exec('afplay /System/Library/Sounds/Basso.aiff');
    }
  } else if (!detected) {
    console.log(`⚠️  ${e.name}: No finger detected`);
  } else {
    console.log(`${e.name}: ${detected} (no optimal mapping)`);
  }

});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nStopping keystroke listener...');
  keyboardListener.kill();
  process.exit(0);
});
