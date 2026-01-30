#!/usr/bin/env python3
"""
Whisper Dictation Script for Hammerspoon
"""

import os
import sys

# Set ffmpeg path for Whisper (before importing whisper)
os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")

import whisper
import pyaudio
import wave
import tempfile
import json
import numpy as np
from datetime import datetime
import fcntl

class WhisperDictation:
    def __init__(self, model_size="base", language="en"):
        self.model_size = model_size
        self.language = language
        self.lock_file = "/tmp/whisper_dictation.lock"
        
        if not self.acquire_lock():
            print("ERROR: Already recording", file=sys.stderr)
            sys.exit(1)
        
        print(f"Loading Whisper '{model_size}' model...", file=sys.stderr)
        self.model = whisper.load_model(model_size)
        print(f"Model loaded!", file=sys.stderr)
        
        self.CHUNK = 1024
        self.FORMAT = pyaudio.paInt16
        self.CHANNELS = 1
        self.RATE = 16000
    
    def acquire_lock(self):
        try:
            self.lock_fd = open(self.lock_file, 'w')
            fcntl.flock(self.lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.lock_fd.write(str(os.getpid()))
            self.lock_fd.flush()
            return True
        except (IOError, OSError):
            return False
    
    def release_lock(self):
        try:
            if hasattr(self, 'lock_fd'):
                fcntl.flock(self.lock_fd, fcntl.LOCK_UN)
                self.lock_fd.close()
            if os.path.exists(self.lock_file):
                os.remove(self.lock_file)
        except:
            pass
    
    def __del__(self):
        self.release_lock()
    
    def record_with_silence_detection(
        self, 
        max_duration=30,
        silence_threshold=300,
        silence_duration=2.0,
        min_duration=1.0
    ):
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
            print(f"Error accessing microphone: {e}", file=sys.stderr)
            p.terminate()
            return None
        
        print("🎤 Recording...", file=sys.stderr)
        
        frames = []
        silent_chunks = 0
        silence_chunks_needed = int(self.RATE / self.CHUNK * silence_duration)
        min_chunks = int(self.RATE / self.CHUNK * min_duration)
        total_chunks = 0
        
        try:
            for i in range(0, int(self.RATE / self.CHUNK * max_duration)):
                data = stream.read(self.CHUNK, exception_on_overflow=False)
                frames.append(data)
                total_chunks += 1
                
                audio_data = np.frombuffer(data, dtype=np.int16)
                volume = np.abs(audio_data).mean()
                
                if volume < silence_threshold:
                    silent_chunks += 1
                    if total_chunks > min_chunks and silent_chunks >= silence_chunks_needed:
                        print("\n🔇 Silence detected", file=sys.stderr)
                        break
                else:
                    silent_chunks = 0
                    if i % 5 == 0:
                        print(".", end="", flush=True, file=sys.stderr)
        
        except KeyboardInterrupt:
            print("\n⚠️ Cancelled", file=sys.stderr)
        
        finally:
            stream.stop_stream()
            stream.close()
            p.terminate()
        
        print("\n✅ Recording complete", file=sys.stderr)
        
        temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        wf = wave.open(temp_file.name, 'wb')
        wf.setnchannels(self.CHANNELS)
        wf.setsampwidth(p.get_sample_size(self.FORMAT))
        wf.setframerate(self.RATE)
        wf.writeframes(b''.join(frames))
        wf.close()
        
        return temp_file.name
    
    def has_audio_content(self, audio_file, threshold=0.01):
        try:
            wf = wave.open(audio_file, 'rb')
            frames = wf.readframes(wf.getnframes())
            wf.close()
            
            audio_data = np.frombuffer(frames, dtype=np.int16)
            max_volume = np.abs(audio_data).max() / 32768.0
            
            return max_volume > threshold
        except Exception as e:
            print(f"Error checking audio: {e}", file=sys.stderr)
            return True
    
    def transcribe(self, audio_file):
        print("🤖 Transcribing...", file=sys.stderr)
        
        try:
            result = self.model.transcribe(
                audio_file,
                language=self.language,
                fp16=False,
                verbose=False
            )
            
            text = result["text"].strip()
            print(f"✅ Transcribed: {text}", file=sys.stderr)
            
            return text
            
        except Exception as e:
            print(f"Error during transcription: {e}", file=sys.stderr)
            return ""
    
    def dictate(self):
        try:
            start_time = datetime.now()
            
            audio_file = self.record_with_silence_detection()
            
            if not audio_file:
                return {
                    "success": False,
                    "error": "Failed to record audio",
                    "text": ""
                }
            
            if not self.has_audio_content(audio_file):
                print("⚠️ No speech detected", file=sys.stderr)
                os.remove(audio_file)
                return {
                    "success": False,
                    "error": "No speech detected",
                    "text": ""
                }
            
            text = self.transcribe(audio_file)
            
            os.remove(audio_file)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            
            if text:
                return {
                    "success": True,
                    "text": text,
                    "duration": elapsed
                }
            else:
                return {
                    "success": False,
                    "error": "No text transcribed",
                    "text": ""
                }
        
        finally:
            self.release_lock()

def main():
    model_size = sys.argv[1] if len(sys.argv) > 1 else "base"
    language = sys.argv[2] if len(sys.argv) > 2 else "en"
    if language == "auto":
        language = None
    
    try:
        dictation = WhisperDictation(model_size=model_size, language=language)
        result = dictation.dictate()
        
        print("\n__JSON_OUTPUT__")
        print(json.dumps(result, ensure_ascii=False))
        
        sys.exit(0 if result["success"] else 1)
        
    except KeyboardInterrupt:
        print("\n❌ Cancelled", file=sys.stderr)
        result = {"success": False, "error": "Cancelled", "text": ""}
        print("\n__JSON_OUTPUT__")
        print(json.dumps(result))
        sys.exit(1)
        
    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        result = {"success": False, "error": str(e), "text": ""}
        print("\n__JSON_OUTPUT__")
        print(json.dumps(result))
        sys.exit(1)

if __name__ == "__main__":
    main()
