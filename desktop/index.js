const { GlobalKeyboardListener } = require("node-global-key-listener");
const { exec } = require("child_process");
const robot = require("robotjs");

const keyboardListener = new GlobalKeyboardListener();
const calibrating = false;
let ignoreNextBackspace = false;

console.log("Keystroke listener started. Press any key...");
console.log("Press Ctrl+C to exit\n");

const FINGER_NAMES = {
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
};

const getFingerName = (finger) => FINGER_NAMES[finger];
const OPTIMAL_MAPPING = {
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
  "2": "lr",
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
};

keyboardListener.addListener(async (e, down) => {
  if (!down[e.name]) return;

  if (e.name === "BACKSPACE" && ignoreNextBackspace) {
    ignoreNextBackspace = false;
    return;
  }

  const url = `http://localhost:8000/${calibrating ? "calibrate/" : "infer/"}${e.name}`;

  const res = await fetch("http://100.116.66.24:8080/frame");
  const arrayBuffer = await res.arrayBuffer();
  const blob = new Blob([Buffer.from(arrayBuffer)], { type: "image/jpeg" });
  const file = new File([blob], "frame.jpg", { type: "image/jpeg" });

  const formData = new FormData();
  formData.append("file", file);

  const response = await fetch(url, {
    method: "POST",
    body: formData,
  });

  const data = await response.json();
  const optimal = OPTIMAL_MAPPING[e.name];
  const detected = data.closest_finger;

  if (optimal && detected && !calibrating) {
    const isCorrect =
      (e.name === "SPACE" && (detected === "lt" || detected === "rt")) ||
      optimal === detected;

    if (isCorrect) {
      console.log(`✓ ${e.name}: Correct finger (${getFingerName(detected)})`);
    } else {
      console.log(
        `\n⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️`,
      );
      console.log(`\n⚠️  WARNING: WRONG FINGER DETECTED! ⚠️`);
      console.log(
        `\n⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️⛔️⚠️`,
      );
      console.log(
        `   YOU USED YOUR ${getFingerName(detected)} to click the ${e.name} key, use your ${getFingerName(optimal)} instead`,
      );

      ignoreNextBackspace = true;
      robot.keyTap("backspace");
      exec("afplay /System/Library/Sounds/Basso.aiff");
    }
  } else if (!detected && !calibrating) {
    console.log(`⚠️  ${e.name}: No finger detected`);
  } else {
    console.log(`${e.name}: ${detected} (no optimal mapping)`);
  }
});

// Handle graceful shutdown
process.on("SIGINT", () => {
  console.log("\nStopping keystroke listener...");
  keyboardListener.kill();
  process.exit(0);
});
