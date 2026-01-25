#!/usr/bin/env python3
"""
Whisper Background Server
=========================
Keeps the Whisper model loaded in memory for instant transcription.

This server:
1. Loads the model once at startup
2. Listens for transcription requests via a socket
3. Returns transcriptions instantly (no model loading delay)

Usage:
    python3 whisper_server.py start    # Start the server (background)
    python3 whisper_server.py stop     # Stop the server
    python3 whisper_server.py status   # Check if server is running
    python3 whisper_server.py transcribe <audio_file>  # Transcribe a file

Author: Created for Manohar's voice-to-text project
"""

import sys
import os
import json
import signal
import socket
import threading
import time
from pathlib import Path

# Server configuration
SERVER_DIR = Path.home() / ".whisper_hotkey"
SOCKET_PATH = SERVER_DIR / "whisper.sock"
PID_FILE = SERVER_DIR / "server.pid"
LOG_FILE = SERVER_DIR / "server.log"

WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "base")
LANGUAGE = "en"  # English only - faster (skips language detection)

# Global model reference
model = None


def log(message):
    """Write to log file."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_line = f"[{timestamp}] {message}\n"
    print(log_line, end='', flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(log_line)
    except:
        pass


def load_model():
    """Load the Whisper model into memory."""
    global model
    import whisper
    log(f"Loading Whisper '{WHISPER_MODEL}' model...")
    model = whisper.load_model(WHISPER_MODEL)
    log("Model loaded and ready!")
    return model


def transcribe_audio(audio_path):
    """Transcribe audio using the pre-loaded model."""
    global model
    if model is None:
        load_model()

    result = model.transcribe(
        audio_path,
        language=LANGUAGE,
        fp16=False
    )
    return result["text"].strip()


def handle_client(conn):
    """Handle a client connection."""
    try:
        data = conn.recv(4096).decode('utf-8')
        request = json.loads(data)

        command = request.get("command")

        if command == "transcribe":
            audio_path = request.get("audio_path")
            if audio_path and os.path.exists(audio_path):
                log(f"Transcribing: {audio_path}")
                start_time = time.time()
                text = transcribe_audio(audio_path)
                elapsed = time.time() - start_time
                log(f"Transcription completed in {elapsed:.2f}s")
                response = {"status": "ok", "text": text, "time": elapsed}
            else:
                response = {"status": "error", "message": "Audio file not found"}

        elif command == "ping":
            response = {"status": "ok", "message": "pong", "model": WHISPER_MODEL}

        elif command == "shutdown":
            response = {"status": "ok", "message": "shutting down"}
            conn.sendall(json.dumps(response).encode('utf-8'))
            conn.close()
            os._exit(0)

        else:
            response = {"status": "error", "message": f"Unknown command: {command}"}

        conn.sendall(json.dumps(response).encode('utf-8'))

    except Exception as e:
        log(f"Error handling client: {e}")
        try:
            response = {"status": "error", "message": str(e)}
            conn.sendall(json.dumps(response).encode('utf-8'))
        except:
            pass
    finally:
        conn.close()


def run_server():
    """Run the server."""
    SERVER_DIR.mkdir(parents=True, exist_ok=True)

    # Remove old socket if exists
    if SOCKET_PATH.exists():
        SOCKET_PATH.unlink()

    # Load model before accepting connections
    load_model()

    # Create Unix socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(SOCKET_PATH))
    server.listen(5)

    # Save PID
    PID_FILE.write_text(str(os.getpid()))

    log(f"Server listening on {SOCKET_PATH}")

    # Handle shutdown signals
    def shutdown(signum, frame):
        log("Received shutdown signal")
        server.close()
        SOCKET_PATH.unlink(missing_ok=True)
        PID_FILE.unlink(missing_ok=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    while True:
        try:
            conn, _ = server.accept()
            # Handle each client in a thread
            thread = threading.Thread(target=handle_client, args=(conn,))
            thread.daemon = True
            thread.start()
        except Exception as e:
            log(f"Server error: {e}")
            break


def send_command(command, **kwargs):
    """Send a command to the server."""
    if not SOCKET_PATH.exists():
        return {"status": "error", "message": "Server not running"}

    try:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(str(SOCKET_PATH))
        client.settimeout(60)  # 60 second timeout for transcription

        request = {"command": command, **kwargs}
        client.sendall(json.dumps(request).encode('utf-8'))

        response = client.recv(65536).decode('utf-8')
        client.close()

        return json.loads(response)

    except socket.timeout:
        return {"status": "error", "message": "Timeout waiting for response"}
    except ConnectionRefusedError:
        return {"status": "error", "message": "Server not running"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def is_server_running():
    """Check if the server is running."""
    if not PID_FILE.exists():
        return False

    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)

        # Also verify socket responds
        result = send_command("ping")
        return result.get("status") == "ok"
    except:
        return False


def cmd_start():
    """Start the server."""
    if is_server_running():
        print("Server is already running")
        return 0

    # Fork to background
    pid = os.fork()
    if pid > 0:
        # Parent process
        print(f"Starting Whisper server (PID: {pid})...")
        time.sleep(3)  # Give it time to load model

        if is_server_running():
            print("Server started successfully!")
            return 0
        else:
            print("Server failed to start. Check ~/.whisper_hotkey/server.log")
            return 1
    else:
        # Child process - become the server
        os.setsid()

        # Redirect stdout/stderr to log file
        SERVER_DIR.mkdir(parents=True, exist_ok=True)
        log_fd = open(LOG_FILE, "a")
        os.dup2(log_fd.fileno(), sys.stdout.fileno())
        os.dup2(log_fd.fileno(), sys.stderr.fileno())

        run_server()


def cmd_stop():
    """Stop the server."""
    if not is_server_running():
        print("Server is not running")
        return 0

    result = send_command("shutdown")
    if result.get("status") == "ok":
        print("Server stopped")
        # Clean up files
        time.sleep(0.5)
        SOCKET_PATH.unlink(missing_ok=True)
        PID_FILE.unlink(missing_ok=True)
        return 0
    else:
        # Force kill
        try:
            pid = int(PID_FILE.read_text().strip())
            os.kill(pid, signal.SIGKILL)
            print("Server force stopped")
        except:
            pass
        SOCKET_PATH.unlink(missing_ok=True)
        PID_FILE.unlink(missing_ok=True)
        return 0


def cmd_status():
    """Check server status."""
    if is_server_running():
        result = send_command("ping")
        print(f"Server is running (model: {result.get('model', 'unknown')})")
        return 0
    else:
        print("Server is not running")
        return 1


def cmd_transcribe(audio_path):
    """Transcribe an audio file using the server."""
    if not is_server_running():
        print("ERROR: Server not running. Start it with: whisper_server.py start")
        return 1

    result = send_command("transcribe", audio_path=audio_path)

    if result.get("status") == "ok":
        print(result.get("text", ""))
        return 0
    else:
        print(f"ERROR: {result.get('message', 'Unknown error')}")
        return 1


def main():
    if len(sys.argv) < 2:
        print("""
Whisper Background Server
=========================
Usage: python3 whisper_server.py <command>

Commands:
    start      - Start the background server
    stop       - Stop the server
    status     - Check if server is running
    transcribe <file>  - Transcribe an audio file
        """)
        return 1

    command = sys.argv[1].lower()

    global WHISPER_MODEL
    WHISPER_MODEL = os.environ.get("WHISPER_MODEL", WHISPER_MODEL)

    if command == "start":
        return cmd_start()
    elif command == "stop":
        return cmd_stop()
    elif command == "status":
        return cmd_status()
    elif command == "transcribe":
        if len(sys.argv) < 3:
            print("ERROR: Missing audio file path")
            return 1
        return cmd_transcribe(sys.argv[2])
    else:
        print(f"Unknown command: {command}")
        return 1


if __name__ == "__main__":
    sys.exit(main() or 0)
