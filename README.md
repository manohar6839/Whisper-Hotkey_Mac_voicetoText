# 🎙️ Whisper Hotkey - Voice-to-Text for macOS

**Press a global hotkey anywhere on your Mac to transcribe your voice instantly!**

A seamless voice-to-text solution using OpenAI's Whisper and Hammerspoon. Speak naturally, and your words appear wherever your cursor is - in any app.

![Demo](https://img.shields.io/badge/Platform-macOS-blue) ![License](https://img.shields.io/badge/License-MIT-green) ![Whisper](https://img.shields.io/badge/AI-OpenAI%20Whisper-orange)

## ✨ Features

- **Global Hotkey** - Press `Ctrl+Shift+Space` anywhere to start/stop recording
- **Fast Transcription** - Background server keeps model loaded for instant results
- **High Accuracy** - Uses Whisper's `base` model (upgradeable to `small`/`medium`)
- **Works Everywhere** - Text appears at your cursor in any app
- **Menu Bar Indicator** - See recording status at a glance (🟢 Ready, 🔴 Recording, 🟡 Transcribing)

## 🚀 Quick Start

### Prerequisites

- macOS (Apple Silicon or Intel)
- Python 3.9+
- Homebrew (will be installed if missing)

### Installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/whisper-hotkey.git
   cd whisper-hotkey
   ```

2. **Run the installer:**
   ```bash
   bash install.sh
   ```

3. **Start the background server** (for fast transcription):
   ```bash
   ./whisper_server_run.sh start
   ```

4. **Open Hammerspoon** and grant permissions when prompted:
   - Accessibility (System Preferences → Privacy → Accessibility)
   - Microphone (will prompt on first recording)

5. **Reload Hammerspoon config:**
   - Click the 🔨 menu bar icon → Reload Config

### Usage

| Action | What Happens |
|--------|--------------|
| Press `Ctrl+Shift+Space` | 🔴 Start recording |
| Speak your text | Audio is captured |
| Press `Ctrl+Shift+Space` again | 🟡 Transcribing... |
| Wait 1-2 seconds | ✅ Text appears at cursor! |

## 📁 Project Structure

```
whisper-hotkey/
├── README.md                 # This file
├── install.sh               # One-click installer
├── whisper_recorder.py      # Main recording script
├── whisper_server.py        # Background server (keeps model loaded)
├── whisper_run.sh           # Wrapper script for recorder
├── whisper_server_run.sh    # Wrapper script for server
├── init.lua                 # Hammerspoon configuration
└── requirements.txt         # Python dependencies
```

## ⚙️ Configuration

### Change the Hotkey

Edit `~/.hammerspoon/init.lua`:

```lua
-- Default: Ctrl+Shift+Space
local hotkeyModifiers = {"ctrl", "shift"}
local hotkeyKey = "space"

-- Example: Use Cmd+Shift+R instead
local hotkeyModifiers = {"cmd", "shift"}
local hotkeyKey = "r"
```

### Change the Whisper Model

Edit `whisper_server.py` and `whisper_recorder.py`:

```python
WHISPER_MODEL = "base"  # Options: tiny, base, small, medium, large
```

| Model | Speed | Accuracy | RAM |
|-------|-------|----------|-----|
| tiny | ⚡⚡⚡⚡ | Basic | ~1GB |
| base | ⚡⚡⚡ | Good | ~1GB |
| small | ⚡⚡ | Better | ~2GB |
| medium | ⚡ | High | ~5GB |
| large | 🐢 | Best | ~10GB |

### Change the Language

Edit the `LANGUAGE` variable in both `whisper_server.py` and `whisper_recorder.py`:

```python
LANGUAGE = "en"      # English only (fastest)
LANGUAGE = None      # Auto-detect (slower but multilingual)
LANGUAGE = "hi"      # Hindi
LANGUAGE = "es"      # Spanish
```

## 🔧 Manual Installation

If the installer doesn't work, follow these steps:

### 1. Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Hammerspoon
```bash
brew install --cask hammerspoon
```

### 3. Install system dependencies
```bash
brew install portaudio ffmpeg
```

### 4. Create Python virtual environment
```bash
cd whisper-hotkey
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install openai-whisper sounddevice soundfile numpy
deactivate
```

### 5. Copy Hammerspoon config
```bash
mkdir -p ~/.hammerspoon
cp init.lua ~/.hammerspoon/
```

### 6. Make scripts executable
```bash
chmod +x whisper_run.sh whisper_server_run.sh whisper_recorder.py whisper_server.py
```

## 📋 Commands Reference

### Recorder Commands
```bash
./whisper_run.sh start    # Start recording
./whisper_run.sh stop     # Stop and transcribe
./whisper_run.sh status   # Check status
./whisper_run.sh cleanup  # Reset if stuck
```

### Server Commands
```bash
./whisper_server_run.sh start   # Start background server
./whisper_server_run.sh stop    # Stop server
./whisper_server_run.sh status  # Check if running
```

## 🔍 Troubleshooting

### "Server not running" warning
Start the background server:
```bash
./whisper_server_run.sh start
```

### Recording stuck / not responding
```bash
pkill -9 -f whisper
rm -rf ~/.whisper_hotkey
./whisper_run.sh cleanup
```

### Hammerspoon not responding to hotkey
1. Check Hammerspoon has Accessibility permission
2. Click 🔨 → Reload Config
3. Check Console for errors (🔨 → Console)

### "ffmpeg not found" error
```bash
brew install ffmpeg
```

### Transcription is slow
1. Make sure the server is running: `./whisper_server_run.sh status`
2. If not, start it: `./whisper_server_run.sh start`
3. Consider using the `tiny` model for faster (but less accurate) results

### Text not appearing in apps
1. Verify Hammerspoon has Accessibility permission
2. Text is also copied to clipboard - try `Cmd+V` to paste

## 🚀 Performance Tips

1. **Always run the background server** - Transcription is 5-10x faster
2. **Use English-only mode** - Set `LANGUAGE = "en"` to skip language detection
3. **Speak clearly** - Whisper works best with clear speech at normal pace
4. **Keep recordings short** - 5-30 seconds is ideal
5. **Quiet environment** - Less background noise = better accuracy

## 🛠️ How It Works

1. **Hammerspoon** listens for the global hotkey (`Ctrl+Shift+Space`)
2. When pressed, it starts the **recorder script** which captures microphone audio
3. When pressed again, audio is saved and sent to the **Whisper server**
4. The server (with model pre-loaded) transcribes instantly
5. Transcribed text is typed at your cursor position

```
┌─────────────┐    hotkey    ┌──────────────┐    audio    ┌─────────────┐
│ Hammerspoon │ ──────────▶  │   Recorder   │ ─────────▶  │   Server    │
│  (Hotkey)   │              │  (Capture)   │             │  (Whisper)  │
└─────────────┘              └──────────────┘             └─────────────┘
       │                                                         │
       │                      transcribed text                   │
       ◀─────────────────────────────────────────────────────────┘
       │
       ▼
  Types text at cursor
```

## 📄 License

MIT License - Feel free to use and modify!

## 🙏 Credits

- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition model
- [Hammerspoon](https://www.hammerspoon.org/) - macOS automation tool
- Built with ❤️ for the voice-to-text community

## 🤝 Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

---

**Enjoy hands-free typing! 🎤✨**
