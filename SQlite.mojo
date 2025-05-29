import sqlite3
import face_recognition
import numpy as np
from datetime import datetime

class FaceDatabase:
    def __init__(self, db_path='face_recognition.db'):
        self.conn = sqlite3.connect(db_path)
        self._create_tables()
        
    def _create_tables(self):
        cursor = self.conn.cursor()
        # 用户表 admin index
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        ''')
        
        # 人脸特征表 human face feature index
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS face_encodings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            encoding BLOB NOT NULL,
            image_id TEXT,  # 对应MongoDB中的图像ID
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
        ''')
        
        # 访问日志表 access janourlist index
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS access_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            access_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            result TEXT CHECK(result IN ('success', 'fail')),
            confidence REAL,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
        ''')
        self.conn.commit()
    
    def add_user(self, name, image_path):
        """添加新用户并提取人脸特征"""

        image = face_recognition.load_image_file(image_path)
        face_encodings = face_recognition.face_encodings(image)
        
        if not face_encodings:
            return False
        
        cursor = self.conn.cursor()
        
        # 添加用户 Add Administrator
        cursor.execute('INSERT INTO users (name) VALUES (?)', (name,))
        user_id = cursor.lastrowid
        
        # 存储人脸特征 Storage Human Feature
        for encoding in face_encodings:
            # 将numpy数组转换为二进制格式存储
            encoding_bytes = encoding.tobytes()
            cursor.execute('''
                INSERT INTO face_encodings (user_id, encoding) 
                VALUES (?, ?)
            ''', (user_id, encoding_bytes))
        
        self.conn.commit()
        return user_id
    
    def recognize_face(self, image_path):
        """识别人脸并返回匹配结果"""
        # 加载待识别图像 loading avatar 
        unknown_image = face_recognition.load_image_file(image_path)
        unknown_encoding = face_recognition.face_encodings(unknown_image)
        
        if not unknown_encoding:
            return None
        
        unknown_encoding = unknown_encoding[0]
        
        # 从数据库获取所有人脸特征 fetch all human feature from database
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT users.id, users.name, face_encodings.encoding 
            FROM face_encodings
            JOIN users ON users.id = face_encodings.user_id
        ''')
        
        matches = []
        for row in cursor.fetchall():
            user_id, name, encoding_bytes = row
            # 将二进制数据转换回numpy数组 translate Binary Data into numpy arraylist
            known_encoding = np.frombuffer(encoding_bytes, dtype=np.float64)
            
            # 比较人脸特征 compare huamn face feature
            result = face_recognition.compare_faces([known_encoding], unknown_encoding)
            if result[0]:
                distance = face_recognition.face_distance([known_encoding], unknown_encoding)[0]
                matches.append((user_id, name, distance))
        
        # 按距离排序（距离越小越相似）
        matches.sort(key=lambda x: x[2])
        
        # 记录访问日志 record visit journal
        if matches:
            best_match = matches[0]
            cursor.execute('''
                INSERT INTO access_logs (user_id, result, confidence) 
                VALUES (?, ?, ?)
            ''', (best_match[0], 'success', 1 - best_match[2]))
        else:
            cursor.execute('INSERT INTO access_logs (result) VALUES (?)', ('fail',))
        
        self.conn.commit()
        return matches[0] if matches else None
    
    def close(self):
        self.conn.close()

# 使用示例 usage example
if __name__ == "__main__":
    db = FaceDatabase()
    
    # 注册新用户 register new user
    user_id = db.add_user("张三", "zhangsan.jpg")
    print(f"注册用户ID: {user_id}")
    
    # 识别人脸 congnize human face
    match = db.recognize_face("test.jpg")
    if match:
        user_id, name, distance = match
        print(f"识别成功: {name} (相似度: {1 - distance:.2%})")
    else:
        print("未识别到匹配人脸")
    
    db.close()