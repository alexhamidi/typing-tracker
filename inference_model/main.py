import math
import cv2
import mediapipe as mp
import numpy as np
from fastapi import FastAPI, UploadFile, File
import uvicorn

app = FastAPI()

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(static_image_mode=True, max_num_hands=2)

CALIBRATION_FILE = 'keyboard_calibration.txt'
TIP_MAP = {
    4: 't',   # thumb
    8: 'i',   # index
    12: 'm',  # middle
    16: 'r',  # ring
    20: 'p'   # pinky
}

@app.post('/record/{key_code}')
async def record(key_code: str, file: UploadFile = File(...)):
    """Record left index finger position for a given key"""
    contents = await file.read()
    np_arr = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(rgb)

    if results.multi_hand_landmarks and results.multi_handedness:
        h, w, _ = image.shape

        for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
            label = handedness.classification[0].label

            if label == 'Left':
                index_tip = hand_landmarks.landmark[8]
                x, y = int(index_tip.x * w), int(index_tip.y * h)

                cv2.circle(image, (x, y), 10, (0, 255, 0), -1)
                mp_drawing.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

                image_path = 'calibration.jpg'
                cv2.imwrite(image_path, image)

                calibration_data = {}
                try:
                    with open(CALIBRATION_FILE, 'r') as f:
                        for line in f:
                            parts = line.strip().split(',')
                            if len(parts) == 3:
                                key, cx, cy = parts
                                calibration_data[key] = (cx, cy)
                except FileNotFoundError:
                    pass

                calibration_data[key_code] = (str(x), str(y))

                with open(CALIBRATION_FILE, 'w') as f:
                    for key, (cx, cy) in calibration_data.items():
                        f.write(f'{key},{cx},{cy}\n')

                return {'key': key_code, 'position': [x, y], 'image': image_path, 'status': 'recorded'}

    return {'error': 'Left hand index finger not detected'}

@app.post('/infer/{key_code}')
async def infer(key_code: str, file: UploadFile = File(...)):
    """Infer which finger was used to press a key"""
    calibration = {}
    try:
        with open(CALIBRATION_FILE, 'r') as f:
            for line in f:
                parts = line.strip().split(',')
                if len(parts) == 3:
                    key, x, y = parts
                    calibration[key] = (int(x), int(y))
    except FileNotFoundError:
        return {'error': 'Calibration file not found'}

    if key_code not in calibration:
        return {'error': f'Key {key_code} not calibrated'}

    key_x, key_y = calibration[key_code]

    contents = await file.read()
    np_arr = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(rgb)

    fingertip_list = []
    if results.multi_hand_landmarks and results.multi_handedness:
        h, w, _ = image.shape

        for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
            label = handedness.classification[0].label
            prefix = 'r' if label == 'Left' else 'l'

            for idx, code in TIP_MAP.items():
                pt = hand_landmarks.landmark[idx]
                x, y = int(pt.x * w), int(pt.y * h)
                fingertip_list.append(((x, y), prefix + code))

            mp_drawing.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

    closest_finger = None
    min_distance = None

    for (fx, fy), finger_code in fingertip_list:
        distance = math.sqrt((fx - key_x)**2 + (fy - key_y)**2)
        if min_distance is None or distance < min_distance:
            min_distance = distance
            closest_finger = finger_code

    cv2.circle(image, (key_x, key_y), 15, (0, 0, 255), 3)
    cv2.putText(image, key_code, (key_x - 10, key_y - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

    output_path = f'annotated_{file.filename}'
    cv2.imwrite(output_path, image)

    if closest_finger:
        print(f'Key: {key_code}, Closest finger: {closest_finger}, Distance: {min_distance:.1f}px')
    else:
        print(f'Key: {key_code}, No fingers detected')

    return {
        'key': key_code,
        'closest_finger': closest_finger,
        'distance': round(min_distance, 1) if min_distance else None,
        'key_position': [key_x, key_y],
        'fingertips': fingertip_list,
        'output_file': output_path
    }

if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8000)
