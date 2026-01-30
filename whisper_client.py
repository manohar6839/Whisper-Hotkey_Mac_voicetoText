#!/usr/bin/env python3
"""
Whisper Client - Fast dictation by connecting to whisper_server.py
Falls back to direct mode if server not running
"""

import os
import sys
import socket
import json

SOCKET_PATH = '/tmp/whisper_server.sock'

def send_command(command):
    """Send command to server and get response"""
    try:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.settimeout(60)  # 60 second timeout for long recordings
        client.connect(SOCKET_PATH)
        client.sendall(command.encode('utf-8'))
        
        # Receive response
        response = b''
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            response += chunk
        
        client.close()
        return json.loads(response.decode('utf-8'))
    
    except FileNotFoundError:
        return None  # Server not running
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    # Try server first (fast path)
    result = send_command("DICTATE")
    
    if result is None:
        # Server not running - fall back to direct mode
        print("⚠️ Server not running, using direct mode (slower)", file=sys.stderr)
        print("💡 Tip: Run 'whisper_server.py' for faster dictation", file=sys.stderr)
        
        # Import and run directly (slower but works)
        from whisper_dictate import WhisperDictation
        
        model_size = sys.argv[1] if len(sys.argv) > 1 else "base"
        language = sys.argv[2] if len(sys.argv) > 2 else "en"
        
        dictation = WhisperDictation(model_size=model_size, language=language)
        result = dictation.dictate()
    
    # Output JSON for Hammerspoon
    print("\n__JSON_OUTPUT__")
    print(json.dumps(result, ensure_ascii=False))
    
    sys.exit(0 if result.get("success") else 1)

if __name__ == "__main__":
    main()
