#!/usr/bin/env python3
"""
Whisper Dictation Server - Keeps model loaded for instant transcription
Run once: python3 whisper_server.py
Then use whisper_client.py for fast dictation
"""

import os
import sys
import socket
import json
import threading
import signal

os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")

import whisper
import pyaudio
import wave
import tempfile
import numpy as np
from datetime import datetime

# Server configuration
HOST = '127.0.0.1'
PORT = 52525
SOCKET_PATH = '/tmp/whisper_server.sock'

class WhisperServer:
    def __init__(self, model_size="base", language="en"):
        self.model_size = model_size
        self.language = language
        self.running = False
        self.recording = False
        
        # Audio settings
        self.CHUNK = 1024
        self.FORMAT = pyaudio.paInt16
        self.CHANNELS = 1
        self.RATE = 16000
        
        print(f"🚀 Loading Whisper '{model_size}' model...")
        self.model = whisper.load_model(model_size)
        print(f"✅ Model loaded and ready!")
    
    def record_audio(self, max_duration=30, silence_threshold=300, 
                     silence_duration=1.5, min_duration=0.5):
        """Record audio with silence detection"""
        p = pyaudio.PyAudio()
        
        try:
            stream = p.open(
                format=self.FORMAT,
                channels=self.CHANNELS,
                rate=self.RATE,
                input=True,
                frames_per_buffer=self.CHUNK
            )
        except Exception as e:
            print(f"❌ Microphone error: {e}")
            p.terminate()
            return None
        
        print("🎤 Recording...")
        
        frames = []
        silent_chunks = 0
        silence_chunks_needed = int(self.RATE / self.CHUNK * silence_duration)
        min_chunks = int(self.RATE / self.CHUNK * min_duration)
        total_chunks = 0
        
        try:
            for i in range(int(self.RATE / self.CHUNK * max_duration)):
                data = stream.read(self.CHUNK, exception_on_overflow=False)
                frames.append(data)
                total_chunks += 1
                
                audio_data = np.frombuffer(data, dtype=np.int16)
                volume = np.abs(audio_data).mean()
                
                if volume < silence_threshold:
                    silent_chunks += 1
                    if total_chunks > min_chunks and silent_chunks >= silence_chunks_needed:
                        print("🔇 Silence detected")
                        break
                else:
                    silent_chunks = 0
        
        except KeyboardInterrupt:
            print("⚠️ Recording cancelled")
        
        finally:
            stream.stop_stream()
            stream.close()
            p.terminate()
        
        # Save to temp file
        temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        wf = wave.open(temp_file.name, 'wb')
        wf.setnchannels(self.CHANNELS)
        wf.setsampwidth(pyaudio.get_sample_size(self.FORMAT))
        wf.setframerate(self.RATE)
        wf.writeframes(b''.join(frames))
        wf.close()
        
        return temp_file.name
    
    def transcribe(self, audio_file):
        """Transcribe audio file"""
        print("🤖 Transcribing...")
        
        try:
            result = self.model.transcribe(
                audio_file,
                language=self.language,
                fp16=False,
                verbose=False
            )
            text = result["text"].strip()
            print(f"✅ Result: {text}")
            return text
        except Exception as e:
            print(f"❌ Transcription error: {e}")
            return ""
    
    def handle_dictation(self):
        """Full dictation pipeline"""
        if self.recording:
            return {"success": False, "error": "Already recording", "text": ""}
        
        self.recording = True
        start_time = datetime.now()
        
        try:
            audio_file = self.record_audio()
            
            if not audio_file:
                return {"success": False, "error": "Recording failed", "text": ""}
            
            text = self.transcribe(audio_file)
            os.remove(audio_file)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            
            if text:
                return {"success": True, "text": text, "duration": elapsed}
            else:
                return {"success": False, "error": "No speech detected", "text": ""}
        
        finally:
            self.recording = False
    
    def handle_client(self, conn):
        """Handle incoming client connection"""
        try:
            data = conn.recv(1024).decode('utf-8').strip()
            
            if data == "DICTATE":
                result = self.handle_dictation()
            elif data == "PING":
                result = {"success": True, "status": "ready"}
            elif data == "QUIT":
                self.running = False
                result = {"success": True, "status": "shutting down"}
            else:
                result = {"success": False, "error": f"Unknown command: {data}"}
            
            conn.sendall(json.dumps(result).encode('utf-8'))
        
        except Exception as e:
            print(f"❌ Client error: {e}")
            try:
                conn.sendall(json.dumps({"success": False, "error": str(e)}).encode('utf-8'))
            except:
                pass
        
        finally:
            conn.close()
    
    def start(self):
        """Start the server"""
        # Remove existing socket file
        if os.path.exists(SOCKET_PATH):
            os.remove(SOCKET_PATH)
        
        # Create Unix socket (faster than TCP)
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(SOCKET_PATH)
        server.listen(1)
        server.settimeout(1.0)
        
        self.running = True
        
        print(f"")
        print(f"═══════════════════════════════════════")
        print(f"🎙️  Whisper Server Running")
        print(f"═══════════════════════════════════════")
        print(f"   Model: {self.model_size}")
        print(f"   Socket: {SOCKET_PATH}")
        print(f"   Press Ctrl+C to stop")
        print(f"═══════════════════════════════════════")
        print(f"")
        
        def signal_handler(sig, frame):
            print("\n👋 Shutting down...")
            self.running = False
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        while self.running:
            try:
                conn, addr = server.accept()
                # Handle in thread for responsiveness
                thread = threading.Thread(target=self.handle_client, args=(conn,))
                thread.start()
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"❌ Server error: {e}")
        
        server.close()
        if os.path.exists(SOCKET_PATH):
            os.remove(SOCKET_PATH)
        
        print("✅ Server stopped")

def main():
    model_size = sys.argv[1] if len(sys.argv) > 1 else "base"
    language = sys.argv[2] if len(sys.argv) > 2 else "en"
    
    server = WhisperServer(model_size=model_size, language=language)
    server.start()

if __name__ == "__main__":
    main()
