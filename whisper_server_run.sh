#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Add Homebrew paths (for ffmpeg on Apple Silicon and Intel Macs)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$SCRIPT_DIR/venv/bin/activate"
python3 "$SCRIPT_DIR/whisper_server.py" "$@"
