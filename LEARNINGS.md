# 📚 Development Learnings & Gotchas

This document captures all the issues encountered and solutions discovered while building this voice dictation system. **Future developers/AI agents: read this first!**

---

## 🎯 Project Overview

**Goal**: System-wide voice dictation on macOS using Whisper + Hammerspoon
**Stack**: Python (Whisper, PyAudio) + Lua (Hammerspoon) + macOS APIs

---

## 🐛 Issues Encountered & Solutions

### Issue #1: macOS Notifications Not Appearing

**Problem**: `hs.notify` notifications weren't showing up.

**Root Cause**: macOS notification permissions weren't granted to Hammerspoon.

**Failed Approach**: Using `hs.notify.new()` requires:
- Notification permissions in System Settings
- User may have notifications disabled
- Notifications can be in "Do Not Disturb" mode

**Solution**: Use `hs.alert.show()` instead - it's an on-screen toast that doesn't require notification permissions.

```lua
-- ❌ Requires permissions
hs.notify.new({title = "Test", informativeText = "Message"}):send()

-- ✅ Works immediately
hs.alert.show("Message", 2)
```

---

### Issue #2: Toast Not Visible in Fullscreen Apps

**Problem**: `hs.alert.show()` toasts don't appear when apps are in fullscreen mode (like Claude Desktop).

**Root Cause**: `hs.alert` uses standard window levels that are below fullscreen app windows.

**Failed Approach**: Tried various `hs.alert.defaultStyle` settings - none worked for fullscreen.

**Solution**: Use `hs.canvas` with special window behaviors:

```lua
local canvas = hs.canvas.new({x = x, y = y, w = width, h = height})

-- These two lines are CRITICAL for fullscreen support:
canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + 
                hs.canvas.windowBehaviors.stationary)
canvas:level(hs.canvas.windowLevels.overlay)

canvas:show()
```

**Key Settings**:
- `canJoinAllSpaces`: Appears on all desktops/spaces
- `stationary`: Doesn't move with space switches
- `windowLevels.overlay`: Renders above fullscreen apps

---

### Issue #3: Toast Size Too Large/Intrusive

**Problem**: Default alert style was too big and distracting.

**Solution**: Create subtle, pill-shaped overlay:

```lua
local width = 180
local height = 36
local x = frame.x + (frame.w - width) / 2
local y = frame.y + 60  -- Near top, not at edge

-- Small, readable font
textSize = 14
textFont = ".AppleSystemUIFont"
```

**Design Principles**:
- Small enough to not distract
- Large enough to be noticeable
- Positioned at top-center (out of main work area)
- Color-coded for status (green=good, red=error, orange=warning)

---

### Issue #4: Multiple Recording Sessions Conflict

**Problem**: Pressing hotkey multiple times caused overlapping recordings.

**Solution**: Implement file-based locking in Python:

```python
import fcntl

def acquire_lock(self):
    try:
        self.lock_fd = open("/tmp/whisper_dictation.lock", 'w')
        fcntl.flock(self.lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except (IOError, OSError):
        return False
```

Also track state in Lua:
```lua
local state = {
    isRecording = false,
    currentTask = nil
}

-- Check before starting
if state.isRecording then
    showToast("⚠️ Already recording!")
    return
end
```

---

### Issue #5: Whisper Can't Find ffmpeg

**Problem**: Whisper failed with "ffmpeg not found" even though it was installed.

**Root Cause**: Homebrew installs to `/opt/homebrew/bin` on Apple Silicon, but Python subprocess doesn't inherit the full PATH.

**Solution**: Explicitly set PATH at the start of Python script:

```python
import os
os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")

# Now import whisper
import whisper
```

---

### Issue #6: PyAudio Installation Fails on macOS

**Problem**: `pip install pyaudio` fails with compilation errors.

**Solution**: Install portaudio first, then pyaudio:

```bash
brew install portaudio
pip install pyaudio
```

If still failing on Apple Silicon:
```bash
pip install --global-option='build_ext' \
            --global-option='-I/opt/homebrew/include' \
            --global-option='-L/opt/homebrew/lib' \
            pyaudio
```

---

### Issue #7: Recording Never Stops

**Problem**: Silence detection wasn't working properly.

**Root Cause**: Silence threshold too low for the environment.

**Solution**: Tune these parameters in `whisper_dictate.py`:

```python
def record_with_silence_detection(
    self, 
    max_duration=30,        # Max recording time
    silence_threshold=300,  # Adjust based on environment (higher = less sensitive)
    silence_duration=2.0,   # Seconds of silence to stop
    min_duration=1.0        # Minimum recording time
):
```

**Tuning Tips**:
- Quiet room: `silence_threshold=200-300`
- Noisy environment: `silence_threshold=500-800`
- Test with: `python3 -c "import pyaudio, numpy as np; ..."`

---

### Issue #8: Text Not Typing in Some Apps

**Problem**: `hs.eventtap.keyStrokes()` didn't work in some applications.

**Root Cause**: Some apps (especially Electron-based) handle keyboard input differently.

**Attempted Solutions**:
1. `hs.eventtap.keyStrokes(text)` - Works in most apps
2. Clipboard + paste approach (more reliable):

```lua
-- Alternative: Use clipboard
hs.pasteboard.setContents(result.text)
hs.eventtap.keyStroke({"cmd"}, "v")
```

**Current Solution**: Using `keyStrokes` with small delay:
```lua
hs.timer.doAfter(0.15, function()
    hs.eventtap.keyStrokes(result.text)
end)
```

---

### Issue #9: Hammerspoon Console Errors Hard to Debug

**Problem**: Errors in Lua code were hard to track down.

**Solution**: Implement comprehensive logging:

```lua
local config = {
    debug = true
}

function log(message)
    print("[Whisper] " .. message)
end

-- Use throughout
log("Starting dictation")
log("STDOUT: " .. stdOut)
log("ERROR: " .. errorMessage)
```

Access logs: Hammerspoon menu bar → Console

---

### Issue #10: JSON Parsing Between Python and Lua

**Problem**: Passing structured data from Python to Hammerspoon.

**Solution**: Use a marker-based JSON protocol:

**Python side**:
```python
print("\n__JSON_OUTPUT__")
print(json.dumps({"success": True, "text": "Hello", "duration": 3.5}))
```

**Lua side**:
```lua
local jsonStart = stdOut:find("__JSON_OUTPUT__")
if jsonStart then
    local jsonStr = stdOut:sub(jsonStart + 16):match("^%s*(.-)%s*$")
    local result = hs.json.decode(jsonStr)
end
```

---

## 🏗️ Architecture Decisions

### Why Hammerspoon + Python (not pure Python or pure Lua)?

| Approach | Pros | Cons |
|----------|------|------|
| Pure Python | Simple, one language | Hard to do global hotkeys, no good macOS integration |
| Pure Lua | Fast, native macOS | No good ML libraries for Whisper |
| **Hammerspoon + Python** | Best of both: native hotkeys + ML power | Two languages, IPC overhead |

### Why Canvas Instead of Alerts?

- Alerts: Simple but don't work in fullscreen
- Canvas: More code but works everywhere, fully customizable

### Why File Locking?

- Prevents multiple whisper processes from running simultaneously
- Survives Hammerspoon reloads
- Easy to manually clear if stuck (`rm /tmp/whisper_dictation.lock`)

---

## 📝 Code Patterns to Reuse

### Pattern: Overlay Toast for Any macOS App

```lua
function createOverlay(message, duration, color)
    local canvas = hs.canvas.new({x = x, y = y, w = width, h = height})
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + 
                    hs.canvas.windowBehaviors.stationary)
    canvas:level(hs.canvas.windowLevels.overlay)
    -- Add elements...
    canvas:show()
    hs.timer.doAfter(duration, function() canvas:delete() end)
end
```

### Pattern: Python Script with JSON Output

```python
# Always output JSON at the end with a marker
result = {"success": True, "data": "..."}
print("\n__JSON_OUTPUT__")
print(json.dumps(result, ensure_ascii=False))
sys.exit(0 if result["success"] else 1)
```

### Pattern: Hammerspoon Task with Callback

```lua
local task = hs.task.new(
    "/path/to/python",
    function(exitCode, stdOut, stdErr)
        -- Handle completion
    end,
    {"/path/to/script.py", "arg1", "arg2"}
)
task:start()
```

---

## 🔮 Future Improvements

1. **Streaming transcription**: Show partial results while speaking
2. **Custom vocabulary**: Add technical terms to improve accuracy
3. **Multiple hotkeys**: Different keys for different languages
4. **Voice commands**: "Delete that", "New paragraph", etc.
5. **iPhone companion**: Trigger from iPhone, transcribe on Mac

---

## 📚 Resources

- [Hammerspoon Docs](https://www.hammerspoon.org/docs/)
- [hs.canvas API](https://www.hammerspoon.org/docs/hs.canvas.html)
- [OpenAI Whisper](https://github.com/openai/whisper)
- [PyAudio Docs](https://people.csail.mit.edu/hubert/pyaudio/docs/)

---

*Last updated: January 2026*
*Maintained by: Manohar with Claude*
