import cv2
import mediapipe as mp

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils

hands = mp_hands.Hands(static_image_mode=True, max_num_hands=2)

# Load your image
image = cv2.imread("/Users/alexh/typing-tracker/vit-test/h3.png")
rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# Process with MediaPipe
results = hands.process(rgb)

# Draw landmarks if found
if results.multi_hand_landmarks:
    for hand_landmarks in results.multi_hand_landmarks:
        mp_drawing.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

# Show output
cv2.imshow("Hand Tracking", image)
cv2.waitKey(0)
