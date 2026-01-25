--[[
Hammerspoon Configuration for Whisper Voice-to-Text
====================================================
Press Ctrl+Shift+Space to start/stop voice recording.
Transcribed text is automatically typed at your cursor.

Installation: Run install.sh which will copy this to ~/.hammerspoon/
]]--

-- IMPORTANT: This path will be replaced by install.sh
-- If installing manually, change this to your whisper_run.sh location
local recorderScript = "$SCRIPT_DIR/whisper_run.sh"

-- Hotkey configuration (change these to customize)
local hotkeyModifiers = {"ctrl", "shift"}
local hotkeyKey = "space"

-- Whisper model (tiny, base, small, medium, large)
local whisperModel = "base"

-- Notification settings
local showAlerts = true
local alertDuration = 1.5

-- State variables (don't modify)
local isRecording = false
local recordingTask = nil
local statusMenuBar = nil

-- Helper function: Show notification
local function showNotification(title, message, duration)
    if showAlerts then
        hs.alert.closeAll()
        hs.alert.show(title .. "\n" .. (message or ""), duration or alertDuration)
    end
end

-- Helper function: Update menu bar icon
local function updateMenuBar(status)
    if statusMenuBar == nil then
        statusMenuBar = hs.menubar.new()
    end
    if status == "recording" then
        statusMenuBar:setTitle("🔴")
        statusMenuBar:setTooltip("Whisper: Recording...")
    elseif status == "transcribing" then
        statusMenuBar:setTitle("🟡")
        statusMenuBar:setTooltip("Whisper: Transcribing...")
    else
        statusMenuBar:setTitle("🟢")
        statusMenuBar:setTooltip("Whisper: Ready (Ctrl+Shift+Space)")
    end
end

-- Helper function: Type text at cursor
local function typeText(text)
    if text and text ~= "" then
        hs.eventtap.keyStrokes(text)
    end
end

-- Helper function: Copy to clipboard
local function copyToClipboard(text)
    if text and text ~= "" then
        hs.pasteboard.setContents(text)
    end
end

-- Start recording
local function startRecording()
    if isRecording then return end

    print("Starting recording...")
    isRecording = true
    updateMenuBar("recording")
    showNotification("🎤 Recording", "Speak now...")

    local env = { WHISPER_MODEL = whisperModel }

    recordingTask = hs.task.new(
        "/bin/bash",
        function(exitCode, stdOut, stdErr)
            print("Recording finished, exit: " .. tostring(exitCode))
            print("stdout: " .. (stdOut or ""))

            isRecording = false
            updateMenuBar("idle")

            if stdOut then
                local transcription = stdOut:match("TRANSCRIPTION:(.+)")
                if transcription then
                    transcription = transcription:gsub("^%s+", ""):gsub("%s+$", "")
                    if transcription ~= "" then
                        showNotification("✅ Done", transcription:sub(1, 50) .. "...")
                        copyToClipboard(transcription)
                        hs.timer.doAfter(0.2, function()
                            typeText(transcription)
                        end)
                    else
                        showNotification("⚠️ Empty", "No speech detected")
                    end
                else
                    local errorMsg = stdOut:match("ERROR:(.+)") or stdErr or "Unknown error"
                    showNotification("❌ Error", errorMsg)
                end
            end
        end,
        {recorderScript, "start"}
    ):setEnvironment(env):start()

    if not recordingTask then
        isRecording = false
        updateMenuBar("idle")
        showNotification("❌ Error", "Failed to start recording")
    end
end

-- Stop recording and transcribe
local function stopRecording()
    if not isRecording then return end

    print("Stopping recording...")
    updateMenuBar("transcribing")
    showNotification("⏳ Transcribing", "Please wait...")

    hs.task.new(
        "/bin/bash",
        function(exitCode, stdOut, stdErr)
            print("Stop signal sent")
        end,
        {recorderScript, "stop"}
    ):start()
end

-- Toggle recording on/off
local function toggleRecording()
    if isRecording then
        stopRecording()
    else
        startRecording()
    end
end

-- Bind the hotkey
hs.hotkey.bind(hotkeyModifiers, hotkeyKey, function()
    toggleRecording()
end)

-- Initialize
updateMenuBar("idle")
showNotification("🎙️ Whisper Ready", "Ctrl+Shift+Space to record", 3)
print("Whisper voice-to-text loaded!")
print("Script: " .. recorderScript)
