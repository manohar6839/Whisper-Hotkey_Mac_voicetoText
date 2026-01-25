#!/usr/bin/env python3
"""
Whisper Voice Recorder for Hammerspoon Integration
===================================================
Records audio when triggered and transcribes it using Whisper.
Uses background server for instant transcription (model stays loaded).

Usage:
    python3 whisper_recorder.py start   # Start recording
    python3 whisper_recorder.py stop    # Stop recording and transcribe
    python3 whisper_recorder.py status  # Check if recording

Author: Created for Manohar's voice-to-text project
"""

import sys
import os
import signal
import json
import socket
import threading
import time
from pathlib import Path

# Try to import required libraries
try:
    import sounddevice as sd
    import soundfile as sf
    import numpy as np
except ImportError as e:
    print(f"ERROR: Missing dependency - {e}")
    print("Install with: pip3 install sounddevice soundfile numpy")
    sys.exit(1)


# ============================================================================
# CONFIGURATION
# ============================================================================

WHISPER_MODEL = "base"
SAMPLE_RATE = 16000
CHANNELS = 1

# Use a fixed location in user's home directory
TEMP_DIR = Path.home() / ".whisper_hotkey"
PID_FILE = TEMP_DIR / "recorder.pid"
AUDIO_FILE = TEMP_DIR / "recording.wav"
STATUS_FILE = TEMP_DIR / "status.json"
SOCKET_PATH = TEMP_DIR / "whisper.sock"

LANGUAGE = "en"  # English only - faster


# ============================================================================
# RECORDING CLASS
# ============================================================================

class AudioRecorder:
    def __init__(self):
        self.is_recording = False
        self.audio_data = []
        self.stream = None

    def audio_callback(self, indata, frames, time, status):
        if status:
            print(f"Audio warning: {status}", file=sys.stderr)
        if self.is_recording:
            self.audio_data.append(indata.copy())

    def start(self):
        self.is_recording = True
        self.audio_data = []
        self.stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            callback=self.audio_callback,
            dtype=np.float32
        )
        self.stream.start()

    def stop(self):
        self.is_recording = False
        if self.stream:
            self.stream.stop()
            self.stream.close()
            self.stream = None
        if self.audio_data:
            return np.concatenate(self.audio_data)
        return None

    def save(self, filepath):
        audio = self.stop()
        if audio is not None and len(audio) > 0:
            sf.write(filepath, audio, SAMPLE_RATE)
            return True
        return False


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def ensure_temp_dir():
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

def write_status(status: str, **kwargs):
    ensure_temp_dir()
    data = {"status": status, "timestamp": time.time(), **kwargs}
    STATUS_FILE.write_text(json.dumps(data))

def read_status():
    if STATUS_FILE.exists():
        try:
            return json.loads(STATUS_FILE.read_text())
        except:
            pass
    return {"status": "idle"}

def write_pid():
    ensure_temp_dir()
    PID_FILE.write_text(str(os.getpid()))

def read_pid():
    if PID_FILE.exists():
        try:
            return int(PID_FILE.read_text().strip())
        except:
            pass
    return None

def is_process_running(pid):
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False

def stop_recording_process():
    pid = read_pid()
    if pid and is_process_running(pid):
        try:
            os.kill(pid, signal.SIGTERM)
            return True
        except:
            pass
    return False


def is_server_running():
    """Check if the Whisper server is running."""
    if not SOCKET_PATH.exists():
        return False
    try:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(str(SOCKET_PATH))
        client.settimeout(5)
        client.sendall(json.dumps({"command": "ping"}).encode('utf-8'))
        response = client.recv(4096).decode('utf-8')
        client.close()
        return json.loads(response).get("status") == "ok"
    except:
        return False


def transcribe_via_server(audio_path: str) -> str:
    """Transcribe audio using the background server (fast!)."""
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(str(SOCKET_PATH))
    client.settimeout(60)

    request = {"command": "transcribe", "audio_path": audio_path}
    client.sendall(json.dumps(request).encode('utf-8'))

    response = client.recv(65536).decode('utf-8')
    client.close()

    result = json.loads(response)
    if result.get("status") == "ok":
        return result.get("text", "")
    else:
        raise Exception(result.get("message", "Unknown error"))


def transcribe_directly(audio_path: str) -> str:
    """Transcribe audio by loading model directly (slow, fallback)."""
    import whisper
    model = whisper.load_model(WHISPER_MODEL)
    result = model.transcribe(
        audio_path,
        language=LANGUAGE,
        fp16=False
    )
    return result["text"].strip()


def transcribe_audio(audio_path: str) -> str:
    """Transcribe audio - uses server if available, otherwise loads model."""
    write_status("transcribing")

    if is_server_running():
        # Fast path: use the background server
        return transcribe_via_server(audio_path)
    else:
        # Slow path: load model directly
        print("WARNING: Server not running, using slow transcription", file=sys.stderr)
        return transcribe_directly(audio_path)


# ============================================================================
# MAIN COMMANDS
# ============================================================================

def cmd_start():
    status = read_status()
    if status.get("status") == "recording":
        pid = read_pid()
        if is_process_running(pid):
            print("ERROR: Already recording")
            return 1

    ensure_temp_dir()

    recorder = AudioRecorder()
    should_stop = threading.Event()

    def handle_signal(signum, frame):
        should_stop.set()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    write_pid()
    write_status("recording")

    print("RECORDING_STARTED", flush=True)
    sys.stdout.flush()

    recorder.start()

    while not should_stop.is_set():
        time.sleep(0.1)

    if recorder.save(str(AUDIO_FILE)):
        try:
            text = transcribe_audio(str(AUDIO_FILE))
            write_status("idle")
            print(f"TRANSCRIPTION:{text}", flush=True)
            AUDIO_FILE.unlink(missing_ok=True)
            PID_FILE.unlink(missing_ok=True)
            return 0
        except Exception as e:
            print(f"ERROR: Transcription failed - {e}", file=sys.stderr)
            write_status("idle", error=str(e))
            return 1
    else:
        print("ERROR: No audio recorded")
        write_status("idle")
        return 1


def cmd_stop():
    if stop_recording_process():
        print("STOP_SIGNAL_SENT")
        return 0
    else:
        print("ERROR: No recording in progress")
        return 1


def cmd_status():
    status = read_status()
    pid = read_pid()
    if status.get("status") == "recording":
        if not is_process_running(pid):
            status["status"] = "idle"
            write_status("idle")

    # Add server status
    status["server_running"] = is_server_running()
    print(json.dumps(status))
    return 0


def cmd_toggle():
    status = read_status()
    pid = read_pid()
    if status.get("status") == "recording" and is_process_running(pid):
        return cmd_stop()
    else:
        return cmd_start()


def cmd_cleanup():
    """Force cleanup of all state files."""
    try:
        PID_FILE.unlink(missing_ok=True)
        AUDIO_FILE.unlink(missing_ok=True)
        write_status("idle")
        print("CLEANUP_DONE")
        return 0
    except Exception as e:
        print(f"ERROR: {e}")
        return 1


# ============================================================================
# MAIN
# ============================================================================

def print_usage():
    print("""
Whisper Voice Recorder
======================
Usage: python3 whisper_recorder.py <command>

Commands:
    start   - Start recording
    stop    - Stop recording and transcribe
    toggle  - Toggle recording on/off
    status  - Check current status
    cleanup - Force cleanup stale state

For faster transcription, start the background server:
    python3 whisper_server.py start
    """)


def main():
    if len(sys.argv) < 2:
        print_usage()
        return 1

    command = sys.argv[1].lower()

    global WHISPER_MODEL
    WHISPER_MODEL = os.environ.get("WHISPER_MODEL", WHISPER_MODEL)

    if command == "start":
        return cmd_start()
    elif command == "stop":
        return cmd_stop()
    elif command == "toggle":
        return cmd_toggle()
    elif command == "status":
        return cmd_status()
    elif command == "cleanup":
        return cmd_cleanup()
    elif command in ["help", "-h", "--help"]:
        print_usage()
        return 0
    else:
        print(f"ERROR: Unknown command '{command}'")
        print_usage()
        return 1


if __name__ == "__main__":
    sys.exit(main() or 0)
