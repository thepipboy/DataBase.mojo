from pymongo import MongoClient
from gridfs import GridFS
from datetime import datetime
import json

class EnvironmentDatabase:
    def __init__(self, db_name='environment_db'):
        self.client = MongoClient('mongodb://localhost:27017/')
        self.db = self.client[db_name]
        self.fs = GridFS(self.db)  # For storing large files
    
    def store_environment_data(self, sensor_data, image_path=None, audio_path=None):
        """Store environmental detection data and associated multimedia"""
        doc = {
            'timestamp': datetime.now(),
            'sensor_data': sensor_data,
            'images': [],
            'audios': []
        }
        
        # Store image
        if image_path:
            with open(image_path, 'rb') as img_file:
                image_id = self.fs.put(img_file, filename=image_path)
                doc['images'].append(str(image_id))
        
        # Store audio
        if audio_path:
            with open(audio_path, 'rb') as audio_file:
                audio_id = self.fs.put(audio_file, filename=audio_path)
                doc['audios'].append(str(audio_id))
        
        # Insert document
        result = self.db.environment.insert_one(doc)
        return result.inserted_id
    
    def store_voice_interaction(self, text, audio_path, recognized=False):
        """Store voice interaction records"""
        doc = {
            'timestamp': datetime.now(),
            'text': text,
            'recognized': recognized,
            'audio_id': None
        }
        
        if audio_path:
            with open(audio_path, 'rb') as audio_file:
                audio_id = self.fs.put(audio_file, filename=audio_path)
                doc['audio_id'] = str(audio_id)
        
        result = self.db.voice_interactions.insert_one(doc)
        return result.inserted_id
    
    def get_environment_data(self, time_range=None, limit=10):
        """Query environmental data"""
        query = {}
        if time_range:
            query['timestamp'] = {'$gte': time_range[0], '$lte': time_range[1]}
        
        return list(self.db.environment.find(query).sort('timestamp', -1).limit(limit))
    
    def get_image(self, file_id):
        """Retrieve stored image"""
        return self.fs.get(file_id).read()
    
    def get_audio(self, file_id):
        """Retrieve stored audio"""
        return self.fs.get(file_id).read()
    
    def close(self):
        self.client.close()

# Usage example
if __name__ == "__main__":
    env_db = EnvironmentDatabase()
    
    # Simulate sensor data
    sensor_data = {
        'temperature': 25.4,
        'humidity': 45,
        'light_level': 780,
        'motion_detected': True
    }
    
    # Store environmental data and associated image
    env_id = env_db.store_environment_data(
        sensor_data, 
        image_path='environment.jpg'
    )
    print(f"Stored environment data ID: {env_id}")
    
    # Store voice interaction
    voice_id = env_db.store_voice_interaction(
        text="Please turn on the living room light", 
        audio_path='voice_command.wav',
        recognized=True
    )
    print(f"Stored voice interaction ID: {voice_id}")
    
    # Query recent environmental data
    recent_data = env_db.get_environment_data(limit=3)
    print("Recent environmental data:")
    for data in recent_data:
        print(f"- {data['timestamp']}: {data['sensor_data']}")
    
    env_db.close()