# 🎤 Whisper Mac Dictation

**System-wide voice dictation for macOS using OpenAI's Whisper - works everywhere, even in fullscreen apps!**

Press `⌘⇧V` anywhere → Speak → Text appears at cursor. That's it.

---

## ⚡ Speed Comparison

| Mode | First Use | Subsequent |
|------|-----------|------------|
| **With Server (recommended)** | ~3s | **~1-2s** |
| Without Server | ~5-7s | ~5-7s |

The server keeps the Whisper model loaded in memory, eliminating the 3-4 second model loading time on each use.

---

## 📋 Prerequisites Checklist

Before using, make sure:

| Requirement | How to Check | How to Fix |
|-------------|--------------|------------|
| **Hammerspoon running** | Look for 🎙️ in menu bar | Open Hammerspoon.app |
| **Accessibility permission** | Try the hotkey | System Settings → Privacy → Accessibility → Enable Hammerspoon |
| **Microphone permission** | Try recording | System Settings → Privacy → Microphone → Enable Hammerspoon |
| **Server running (for speed)** | 🎙️ = fast, ⚪ = slow | Click 🎙️ menu → Start Server |

### First Time Setup Permissions

1. **System Settings → Privacy & Security → Accessibility**
   - Find **Hammerspoon** → Toggle ON ✓

2. **System Settings → Privacy & Security → Microphone**  
   - Find **Hammerspoon** → Toggle ON ✓

---

## 🚀 Quick Install

```bash
# Clone the repo
git clone https://github.com/manohar6839/Whisper-Hotkey_Mac_voicetoText.git
cd Whisper-Hotkey_Mac_voicetoText

# Run installer
chmod +x install.sh
./install.sh
```

---

## 🎯 Daily Usage

### You Don't Need to Do Anything!

Once installed:
1. **Turn on Mac** → Hammerspoon auto-starts
2. **Open any app** → Press `⌘⇧V` → Speak → Done!

### Menu Bar Icon Guide

| Icon | Meaning |
|------|---------|
| 🎙️ | Ready (server running, fastest) |
| ⚪ | Ready (server off, slower) |
| 🎤 | Recording your voice |
| 🤖 | Transcribing |
| ❌ | Error occurred |

### Menu Bar Options (Click the icon)

- **Start Dictation** - Same as `⌘⇧V`
- **Start Server** - Enable fast mode
- **Stop Server** - Free up RAM (~500MB)
- **Server Status** - Check if server is running

---

## ⚡ Speed Optimization

### Option 1: Manual Server Start (Recommended for testing)

Click menu bar icon → **Start Server**

Or run in Terminal:
```bash
cd ~/MyProjects/whisper_hotkey
source venv/bin/activate
python3 whisper_server.py
```

### Option 2: Auto-Start Server at Login

```bash
# Install the LaunchAgent
cp com.whisper.dictation.server.plist ~/Library/LaunchAgents/

# Edit to use your username
sed -i '' "s|USER_HOME|$USER|g" ~/Library/LaunchAgents/com.whisper.dictation.server.plist

# Load it
launchctl load ~/Library/LaunchAgents/com.whisper.dictation.server.plist
```

Now the server starts automatically when you log in!

### Option 3: Use Faster Model

Edit `~/.hammerspoon/init.lua`:
```lua
modelSize = "tiny",  -- Fastest: ~1-2s total
-- modelSize = "base",  -- Balanced: ~2-3s total
-- modelSize = "small",  -- Accurate: ~4-5s total
```

### Speed Tips

1. **Keep server running** - Saves 3-4 seconds per dictation
2. **Use `tiny` model** - Good enough for English dictation
3. **Reduce silence duration** - Edit `whisper_server.py`: `silence_duration=1.0`
4. **Keep Mac plugged in** - Battery mode throttles CPU

---

## ⚙️ Configuration

Edit `~/.hammerspoon/init.lua`:

```lua
local config = {
    -- Model: 'tiny' (fast), 'base' (balanced), 'small' (accurate)
    modelSize = "base",
    
    -- Language: 'en', 'hi', 'es', 'auto' (auto-detect)
    language = "en",
    
    -- Hotkey (default: Cmd+Shift+V)
    hotkey = { mods = {"cmd", "shift"}, key = "V" },
    
    -- Sound feedback
    playSound = true,
    
    -- Debug logging (see Hammerspoon Console)
    debug = true
}
```

### Model Comparison

| Model | Download | RAM | Speed | Accuracy |
|-------|----------|-----|-------|----------|
| tiny | 39 MB | ~1 GB | ⚡⚡⚡ | Good |
| base | 74 MB | ~1 GB | ⚡⚡ | Better |
| small | 244 MB | ~2 GB | ⚡ | Great |
| medium | 769 MB | ~5 GB | 🐌 | Excellent |

---

## 🔧 Troubleshooting

### "Server not running" / Slow dictation
```bash
# Start the server manually
cd ~/MyProjects/whisper_hotkey
source venv/bin/activate
python3 whisper_server.py
```

### Toast not appearing in fullscreen?
Should work! If not, check Accessibility permissions for Hammerspoon.

### "Already recording" error
```bash
rm /tmp/whisper_dictation.lock
rm /tmp/whisper_server.sock
```

### Check server logs
```bash
cat /tmp/whisper_server.log
```

### Check Hammerspoon logs
Click Hammerspoon menu bar icon → **Open Console**

---

## 📁 Project Structure

```
whisper_hotkey/
├── README.md                              # This file
├── LEARNINGS.md                           # All gotchas & solutions
├── init.lua                               # Hammerspoon config
├── whisper_server.py                      # Background server (fast)
├── whisper_client.py                      # Client for server
├── whisper_dictate.py                     # Standalone script (fallback)
├── install.sh                             # Installer
├── requirements.txt                       # Python deps
└── com.whisper.dictation.server.plist    # LaunchAgent for auto-start
```

---

## 🆚 Comparison with Other Solutions

| Feature | This Project | macOS Dictation | Wispr Flow |
|---------|--------------|-----------------|------------|
| Offline | ✅ Yes | ❌ No | ❌ No |
| Privacy | ✅ 100% local | ❌ Apple servers | ❌ Cloud |
| Speed | ⚡ 1-3s | ⚡ 1-2s | ⚡ 1-2s |
| Accuracy | 🟢 Good | 🟢 Good | 🟢 Good |
| Free | ✅ Yes | ✅ Yes | ❌ $10/mo |
| Custom model | ✅ Yes | ❌ No | ❌ No |
| Works in fullscreen | ✅ Yes | ✅ Yes | ✅ Yes |

---

## 📚 Learn More

- **[LEARNINGS.md](LEARNINGS.md)** - All issues we solved and why
- [OpenAI Whisper](https://github.com/openai/whisper) - The ML model
- [Hammerspoon Docs](https://www.hammerspoon.org/docs/) - macOS automation

---

## 🤝 Contributing

1. Fork the repo
2. Create feature branch
3. Commit changes  
4. Push and open PR

---

## 📄 License

MIT License - use freely!

---

*Built with 🎤 by Manohar with Claude*
