-- Whisper Dictation for Hammerspoon

local config = {
    pythonPath = os.getenv("HOME") .. "/MyProjects/whisper_hotkey/venv/bin/python3",
    scriptPath = os.getenv("HOME") .. "/MyProjects/whisper_hotkey/whisper_dictate.py",
    modelSize = "base",
    language = "en",
    
    hotkey = {
        mods = {"cmd", "shift"},
        key = "V"
    },
    
    showNotifications = true,
    playSound = true,
    debug = true
}

local state = {
    isRecording = false,
    currentTask = nil,
    menubar = nil,
    canvas = nil
}

function log(message)
    print("[Whisper] " .. message)
end

-- Create a canvas-based overlay that works in fullscreen
function createOverlay(message, duration, color)
    duration = duration or 2
    color = color or {red = 0.2, green = 0.2, blue = 0.2, alpha = 0.85}
    
    -- Remove existing overlay
    if state.canvas then
        state.canvas:delete()
        state.canvas = nil
    end
    
    local screen = hs.screen.mainScreen()
    local frame = screen:fullFrame()
    
    -- Small, subtle size
    local width = 180
    local height = 36
    local x = frame.x + (frame.w - width) / 2
    local y = frame.y + 60  -- Near top but not at very edge
    
    state.canvas = hs.canvas.new({x = x, y = y, w = width, h = height})
    
    state.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    state.canvas:level(hs.canvas.windowLevels.overlay)
    
    -- Background rounded rectangle
    state.canvas:appendElements({
        type = "rectangle",
        action = "fill",
        roundedRectRadii = {xRadius = 8, yRadius = 8},
        fillColor = color
    })
    
    -- Text
    state.canvas:appendElements({
        type = "text",
        text = message,
        textAlignment = "center",
        textColor = {white = 1, alpha = 1},
        textSize = 14,
        textFont = ".AppleSystemUIFont",
        frame = {x = 0, y = 8, w = width, h = height - 8}
    })
    
    state.canvas:show()
    
    -- Auto-hide after duration
    hs.timer.doAfter(duration, function()
        if state.canvas then
            state.canvas:delete()
            state.canvas = nil
        end
    end)
    
    log("Overlay: " .. message)
end

-- Update menubar icon
function updateMenubar(status)
    if not state.menubar then
        state.menubar = hs.menubar.new()
    end
    
    if status == "recording" then
        state.menubar:setTitle("🎤")
    elseif status == "transcribing" then
        state.menubar:setTitle("🤖")
    elseif status == "ready" then
        state.menubar:setTitle("🎙️")
    elseif status == "error" then
        state.menubar:setTitle("❌")
    end
end

function playSound(soundName)
    if config.playSound and soundName then
        local sound = hs.sound.getByName(soundName)
        if sound then sound:play() end
    end
end

function startDictation()
    if state.isRecording then
        log("Already recording")
        createOverlay("⚠️ Already recording", 2, {red = 0.6, green = 0.3, blue = 0, alpha = 0.9})
        playSound("Basso")
        return
    end
    
    if state.currentTask and state.currentTask:isRunning() then
        log("Terminating previous task")
        state.currentTask:terminate()
        state.currentTask = nil
        hs.timer.doAfter(0.5, startDictation)
        return
    end
    
    log("Starting dictation")
    state.isRecording = true
    
    updateMenubar("recording")
    createOverlay("🎤 Listening...", 30, {red = 0.1, green = 0.4, blue = 0.1, alpha = 0.9})
    playSound("Ping")
    
    local args = {config.scriptPath, config.modelSize, config.language}
    
    state.currentTask = hs.task.new(
        config.pythonPath,
        function(exitCode, stdOut, stdErr)
            log("Task completed: " .. exitCode)
            state.isRecording = false
            state.currentTask = nil
            handleResult(exitCode, stdOut, stdErr)
        end,
        args
    )
    
    if state.currentTask then
        local success = state.currentTask:start()
        if not success then
            log("ERROR: Failed to start")
            state.isRecording = false
            state.currentTask = nil
            updateMenubar("error")
            createOverlay("❌ Failed to start", 3, {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.9})
            playSound("Basso")
            hs.timer.doAfter(3, function() updateMenubar("ready") end)
        end
    end
end

function handleResult(exitCode, stdOut, stdErr)
    if config.debug then
        log("STDOUT: " .. stdOut)
        log("STDERR: " .. stdErr)
    end
    
    updateMenubar("transcribing")
    
    if stdErr:find("Already recording") then
        createOverlay("⚠️ Wait...", 2, {red = 0.6, green = 0.3, blue = 0, alpha = 0.9})
        playSound("Basso")
        updateMenubar("ready")
        return
    end
    
    local jsonStart = stdOut:find("__JSON_OUTPUT__")
    if not jsonStart then
        log("ERROR: No JSON output")
        createOverlay("❌ No output", 3, {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.9})
        playSound("Basso")
        updateMenubar("error")
        hs.timer.doAfter(3, function() updateMenubar("ready") end)
        return
    end
    
    local jsonStr = stdOut:sub(jsonStart + 16):match("^%s*(.-)%s*$")
    
    local success, result = pcall(function()
        return hs.json.decode(jsonStr)
    end)
    
    if not success then
        log("ERROR: JSON parse failed")
        createOverlay("❌ Parse error", 3, {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.9})
        playSound("Basso")
        updateMenubar("error")
        hs.timer.doAfter(3, function() updateMenubar("ready") end)
        return
    end
    
    if result.success and result.text and result.text ~= "" then
        log("Success: " .. result.text)
        
        createOverlay("✅ Done!", 1.5, {red = 0.1, green = 0.5, blue = 0.1, alpha = 0.9})
        playSound("Glass")
        updateMenubar("ready")
        
        hs.timer.doAfter(0.15, function()
            hs.eventtap.keyStrokes(result.text)
        end)
    else
        local err = result.error or "Unknown error"
        createOverlay("❌ " .. err, 3, {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.9})
        playSound("Basso")
        updateMenubar("error")
        hs.timer.doAfter(3, function() updateMenubar("ready") end)
    end
end

function cleanup()
    local lockFile = "/tmp/whisper_dictation.lock"
    if hs.fs.attributes(lockFile) then
        os.remove(lockFile)
    end
    if state.currentTask and state.currentTask:isRunning() then
        state.currentTask:terminate()
    end
    if state.canvas then
        state.canvas:delete()
        state.canvas = nil
    end
    state.isRecording = false
    state.currentTask = nil
end

log("Initializing...")
cleanup()

local pythonExists = hs.fs.attributes(config.pythonPath) ~= nil
local scriptExists = hs.fs.attributes(config.scriptPath) ~= nil

if not pythonExists then
    hs.alert.show("❌ Python not found", 5)
    log("ERROR: Python missing")
end

if not scriptExists then
    hs.alert.show("❌ Script not found", 5)
    log("ERROR: Script missing")
end

if pythonExists and scriptExists then
    hs.hotkey.bind(config.hotkey.mods, config.hotkey.key, startDictation)
    updateMenubar("ready")
    createOverlay("✅ Whisper ready", 2)
    playSound("Blow")
    log("Ready!")
else
    log("ERROR: Init failed")
    updateMenubar("error")
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            hs.reload()
            return
        end
    end
end):start()
