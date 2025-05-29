import sqlite3
from pymongo import MongoClient
import face_recognition
import numpy as np
from datetime import datetime
import whisper  # Speech recognition
import pyttsx3  # Text-to-speech
import cv2  # Environmental detection
import time

class SmartSystem:
    def __init__(self):
        # Initialize databases
        self.face_db = FaceDatabase()
        self.env_db = EnvironmentDatabase()
        
        # Initialize voice model
        self.voice_model = whisper.load_model("base")
        self.tts_engine = pyttsx3.init()
        
        # Initialize environment detection
        self.cap = cv2.VideoCapture(0)  # Camera
    
    def process_voice_command(self, audio_path):
        """Process voice commands"""
        # Speech recognition
        result = self.voice_model.transcribe(audio_path)
        text = result["text"]
        
        # Store voice interaction
        self.env_db.store_voice_interaction(text, audio_path, recognized=True)
        
        # Simple command processing
        if "turn on the light" in text.lower() or "turn on light" in text.lower():
            return "Okay, turning on the light."
        elif "turn off the light" in text.lower() or "turn off light" in text.lower():
            return "Okay, turning off the light."
        elif "temperature" in text.lower():
            # Get latest environment data
            data = self.env_db.get_environment_data(limit=1)
            if data:
                temp = data[0]['sensor_data']['temperature']
                return f"The current temperature is {temp}°C"
            else:
                return "Unable to retrieve temperature data"
        else:
            return f"Command received: {text}"
    
    def capture_and_analyze_environment(self):
        """Capture and analyze environment"""
        ret, frame = self.cap.read()
        if not ret:
            return None
        
        # Save current frame
        image_path = f"env_{int(time.time())}.jpg"
        cv2.imwrite(image_path, frame)
        
        # Simple environment analysis (use YOLO etc. in real applications)
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        light_level = cv2.mean(gray)[0]
        motion_detected = False  # Motion detection logic needed
        
        # Create sensor data
        sensor_data = {
            'temperature': 25.0,  # Get from sensor in real application
            'humidity': 45.0,
            'light_level': light_level,
            'motion_detected': motion_detected
        }
        
        # Store environment data
        env_id = self.env_db.store_environment_data(sensor_data, image_path)
        return env_id
    
    def face_recognition_pipeline(self, image_path):
        """Face recognition pipeline"""
        # Recognize face
        result = self.face_db.recognize_face(image_path)
        
        if result:
            user_id, name, distance = result
            confidence = 1 - distance
            
            # Voice feedback
            response = f"Welcome back, {name}!"
            self.tts_engine.say(response)
            self.tts_engine.runAndWait()
            
            # Adjust environment based on user preferences (example)
            self.adjust_environment_for_user(user_id)
            
            return name, confidence
        else:
            response = "Unauthorized user detected"
            self.tts_engine.say(response)
            self.tts_engine.runAndWait()
            return None
    
    def adjust_environment_for_user(self, user_id):
        """Adjust environment based on user preferences (example)"""
        # In a real application, this would query user preferences and control smart devices
        print(f"Adjusting environment settings for user {user_id}...")
    
    def run(self):
        """Main loop"""
        try:
            while True:
                # 1. Environment detection
                self.capture_and_analyze_environment()
                
                # 2. Face recognition (every 5 seconds)
                if int(time.time()) % 5 == 0:
                    # Capture current frame for face recognition
                    ret, frame = self.cap.read()
                    if ret:
                        face_image = f"face_{int(time.time())}.jpg"
                        cv2.imwrite(face_image, frame)
                        self.face_recognition_pipeline(face_image)
                
                # 3. Voice interaction processing (need to implement recording)
                # In a real application, this would listen for voice input
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            print("System shutting down")
            self.cap.release()
            self.face_db.close()
            self.env_db.close()

if __name__ == "__main__":
    system = SmartSystem()
    system.run()