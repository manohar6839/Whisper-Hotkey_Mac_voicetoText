# 🎤 Whisper Mac Dictation

**System-wide voice dictation for macOS using OpenAI's Whisper - works everywhere, even in fullscreen apps!**

Press `⌘⇧V` anywhere → Speak → Text appears at cursor. That's it.

![Demo](docs/demo.gif)

## ✨ Features

- **Works Everywhere**: Any app, any text field, including fullscreen apps
- **Fully Offline**: No internet required, complete privacy
- **Auto Silence Detection**: Stops recording when you stop speaking
- **Visual Feedback**: Subtle overlay toast + menubar icon
- **Fast**: ~3-6 seconds for typical dictation (with `base` model)

## 🚀 Quick Install

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/whisper-mac-dictation.git
cd whisper-mac-dictation

# Run installer
chmod +x install.sh
./install.sh
```

## 📋 Manual Installation

### Prerequisites

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install python@3.11 ffmpeg portaudio
brew install --cask hammerspoon
```

### Setup Python Environment

```bash
# Create project directory
mkdir -p ~/MyProjects/whisper_hotkey
cd ~/MyProjects/whisper_hotkey

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install packages
pip install --upgrade pip
pip install openai-whisper pyaudio numpy
```

### Install Hammerspoon Config

```bash
# Copy the init.lua to Hammerspoon config
cp init.lua ~/.hammerspoon/init.lua

# Copy the Python script
cp whisper_dictate.py ~/MyProjects/whisper_hotkey/
```

### Grant Permissions

1. **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable Hammerspoon
2. **Microphone**: System Settings → Privacy & Security → Microphone → Enable Hammerspoon

### Reload Hammerspoon

Click Hammerspoon menu bar icon → Reload Config

## 🎯 Usage

| Action | Result |
|--------|--------|
| Press `⌘⇧V` | Start recording (green "🎤 Listening..." toast) |
| Speak naturally | Dots appear showing audio detected |
| Stop speaking (2s) | Auto-stops, transcribes |
| Text appears | Typed at cursor position |

### Menubar Icons

- 🎙️ Ready
- 🎤 Recording
- 🤖 Transcribing
- ❌ Error

## ⚙️ Configuration

Edit `~/.hammerspoon/init.lua`:

```lua
local config = {
    -- Model: 'tiny', 'base', 'small', 'medium', 'large'
    modelSize = "base",  -- Recommended for daily use
    
    -- Language: 'en', 'hi', 'es', etc. or 'auto'
    language = "en",
    
    -- Hotkey
    hotkey = {
        mods = {"cmd", "shift"},
        key = "V"
    },
    
    playSound = true,  -- Audio feedback
    debug = true       -- Console logging
}
```

### Model Comparison

| Model | Size | Speed | Accuracy | RAM |
|-------|------|-------|----------|-----|
| tiny | 39M | ~2s | Good | 1GB |
| base | 74M | ~4s | Better | 1GB |
| small | 244M | ~8s | Great | 2GB |
| medium | 769M | ~15s | Excellent | 5GB |
| large | 1550M | ~30s | Best | 10GB |

## 🔧 Troubleshooting

### Toast not showing in fullscreen?
The current implementation uses `hs.canvas` with overlay level - it should work in fullscreen. If not, check that Hammerspoon has Accessibility permissions.

### "Already recording" error?
```bash
# Clear the lock file
rm /tmp/whisper_dictation.lock
```

### No audio detected?
1. Check microphone permissions for Hammerspoon
2. Test microphone in System Settings → Sound → Input
3. Try increasing `silence_threshold` in `whisper_dictate.py`

### Slow transcription?
- Use `tiny` or `base` model for faster results
- Ensure you're not running on battery (throttles CPU)

### Check Hammerspoon Console
Click Hammerspoon icon → Console to see debug logs.

## 📁 Project Structure

```
whisper_hotkey/
├── README.md              # This file
├── LEARNINGS.md           # Development learnings & gotchas
├── init.lua               # Hammerspoon configuration
├── whisper_dictate.py     # Main dictation script
├── install.sh             # Automated installer
├── requirements.txt       # Python dependencies
└── docs/
    └── demo.gif           # Demo animation
```

## 🤝 Contributing

1. Fork the repo
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing`)
5. Open Pull Request

## 📄 License

MIT License - feel free to use, modify, and distribute.

## 🙏 Credits

- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition
- [Hammerspoon](https://www.hammerspoon.org/) - macOS automation
- Built with help from Claude (Anthropic)
