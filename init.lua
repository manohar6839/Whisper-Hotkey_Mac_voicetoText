-- Whisper Dictation for Hammerspoon
-- Fast mode: Uses background server (if running)
-- Fallback: Direct mode (slower, but always works)

local config = {
    -- Python paths
    pythonPath = os.getenv("HOME") .. "/MyProjects/whisper_hotkey/venv/bin/python3",
    clientScript = os.getenv("HOME") .. "/MyProjects/whisper_hotkey/whisper_client.py",
    serverScript = os.getenv("HOME") .. "/MyProjects/whisper_hotkey/whisper_server.py",
    
    -- Whisper settings
    modelSize = "base",  -- tiny, base, small, medium, large
    language = "en",     -- en, hi, auto, etc.
    
    -- Hotkey: Cmd+Shift+V
    hotkey = { mods = {"cmd", "shift"}, key = "V" },
    
    -- Feedback
    playSound = true,
    debug = true
}

local state = {
    isRecording = false,
    currentTask = nil,
    menubar = nil,
    canvas = nil
}

function log(msg)
    if config.debug then print("[Whisper] " .. msg) end
end

-- ═══════════════════════════════════════
-- VISUAL FEEDBACK (Fullscreen Compatible)
-- ═══════════════════════════════════════

function createOverlay(message, duration, color)
    duration = duration or 2
    color = color or {red = 0.15, green = 0.15, blue = 0.15, alpha = 0.9}
    
    if state.canvas then
        state.canvas:delete()
        state.canvas = nil
    end
    
    local screen = hs.screen.mainScreen()
    local frame = screen:fullFrame()
    
    -- Subtle pill at top center
    local width = 200
    local height = 40
    local x = frame.x + (frame.w - width) / 2
    local y = frame.y + 50
    
    state.canvas = hs.canvas.new({x = x, y = y, w = width, h = height})
    state.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + 
                          hs.canvas.windowBehaviors.stationary)
    state.canvas:level(hs.canvas.windowLevels.overlay)
    
    -- Background
    state.canvas:appendElements({
        type = "rectangle",
        action = "fill",
        roundedRectRadii = {xRadius = 10, yRadius = 10},
        fillColor = color
    })
    
    -- Text
    state.canvas:appendElements({
        type = "text",
        text = message,
        textAlignment = "center",
        textColor = {white = 1, alpha = 1},
        textSize = 15,
        textFont = ".AppleSystemUIFont",
        frame = {x = 0, y = 10, w = width, h = height - 10}
    })
    
    state.canvas:show()
    
    hs.timer.doAfter(duration, function()
        if state.canvas then
            state.canvas:delete()
            state.canvas = nil
        end
    end)
end

function updateMenubar(status)
    if not state.menubar then
        state.menubar = hs.menubar.new()
        state.menubar:setMenu(function()
            return {
                {title = "🎤 Start Dictation (⌘⇧V)", fn = startDictation},
                {title = "-"},
                {title = "Start Server", fn = startServer},
                {title = "Stop Server", fn = stopServer},
                {title = "Server Status", fn = checkServerStatus},
                {title = "-"},
                {title = "Open Console", fn = function() hs.openConsole() end}
            }
        end)
    end
    
    local icons = {
        ready = "🎙️",
        recording = "🎤",
        transcribing = "🤖",
        error = "❌",
        server_off = "⚪"
    }
    state.menubar:setTitle(icons[status] or "🎙️")
end

function playSound(name)
    if config.playSound then
        local s = hs.sound.getByName(name)
        if s then s:play() end
    end
end

-- ═══════════════════════════════════════
-- SERVER MANAGEMENT
-- ═══════════════════════════════════════

function isServerRunning()
    return hs.fs.attributes("/tmp/whisper_server.sock") ~= nil
end

function startServer()
    if isServerRunning() then
        createOverlay("Server already running", 2)
        return
    end
    
    log("Starting server...")
    createOverlay("🚀 Starting server...", 3)
    
    local task = hs.task.new(
        config.pythonPath,
        function(code, out, err)
            log("Server exited: " .. code)
        end,
        {config.serverScript, config.modelSize, config.language}
    )
    task:start()
    
    -- Check if started
    hs.timer.doAfter(5, function()
        if isServerRunning() then
            createOverlay("✅ Server ready!", 2, {red = 0.1, green = 0.5, blue = 0.1, alpha = 0.9})
            updateMenubar("ready")
        else
            createOverlay("❌ Server failed", 3, {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.9})
        end
    end)
end

function stopServer()
    if not isServerRunning() then
        createOverlay("Server not running", 2)
        return
    end
    
    -- Send quit command
    local task = hs.task.new("/usr/bin/python3", nil, {"-c", [[
import socket
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/whisper_server.sock')
s.send(b'QUIT')
s.close()
]]})
    task:start()
    
    createOverlay("Server stopped", 2)
    updateMenubar("server_off")
end

function checkServerStatus()
    if isServerRunning() then
        createOverlay("✅ Server running", 2, {red = 0.1, green = 0.5, blue = 0.1, alpha = 0.9})
    else
        createOverlay("⚪ Server not running", 2)
    end
end

-- ═══════════════════════════════════════
-- DICTATION
-- ═══════════════════════════════════════

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
    
    -- Show different message based on server status
    if isServerRunning() then
        createOverlay("🎤 Listening...", 30, {red = 0.1, green = 0.4, blue = 0.1, alpha = 0.9})
    else
        createOverlay("🎤 Listening (slow)...", 30, {red = 0.4, green = 0.3, blue = 0.1, alpha = 0.9})
    end
    playSound("Ping")
    
    -- Use client script (auto-detects server)
    state.currentTask = hs.task.new(
        config.pythonPath,
        function(exitCode, stdOut, stdErr)
            log("Task done: " .. exitCode)
            state.isRecording = false
            state.currentTask = nil
            handleResult(exitCode, stdOut, stdErr)
        end,
        {config.clientScript, config.modelSize, config.language}
    )
    
    if state.currentTask then
        if not state.currentTask:start() then
            log("ERROR: Failed to start")
            state.isRecording = false
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
    
    local jsonStart = stdOut:find("__JSON_OUTPUT__")
    if not jsonStart then
        log("ERROR: No JSON")
        createOverlay("❌ No output", 3, {red = 0.6, green = 0.1, blue = 0.1, alpha = 0.9})
        playSound("Basso")
        updateMenubar("error")
        hs.timer.doAfter(3, function() updateMenubar("ready") end)
        return
    end
    
    local jsonStr = stdOut:sub(jsonStart + 16):match("^%s*(.-)%s*$")
    local success, result = pcall(function() return hs.json.decode(jsonStr) end)
    
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
        
        -- Show speed if available
        local msg = "✅ Done!"
        if result.duration then
            msg = string.format("✅ %.1fs", result.duration)
        end
        createOverlay(msg, 1.5, {red = 0.1, green = 0.5, blue = 0.1, alpha = 0.9})
        playSound("Glass")
        updateMenubar("ready")
        
        hs.timer.doAfter(0.1, function()
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

-- ═══════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════

function cleanup()
    local lockFile = "/tmp/whisper_dictation.lock"
    if hs.fs.attributes(lockFile) then os.remove(lockFile) end
    if state.currentTask and state.currentTask:isRunning() then
        state.currentTask:terminate()
    end
    if state.canvas then state.canvas:delete() end
    state.isRecording = false
    state.currentTask = nil
end

log("Initializing...")
cleanup()

local pythonOK = hs.fs.attributes(config.pythonPath) ~= nil
local clientOK = hs.fs.attributes(config.clientScript) ~= nil

if not pythonOK then
    hs.alert.show("❌ Python not found", 5)
    log("ERROR: Python missing at " .. config.pythonPath)
end

if not clientOK then
    hs.alert.show("❌ Client script not found", 5)
    log("ERROR: Script missing at " .. config.clientScript)
end

if pythonOK and clientOK then
    hs.hotkey.bind(config.hotkey.mods, config.hotkey.key, startDictation)
    
    if isServerRunning() then
        updateMenubar("ready")
        createOverlay("✅ Whisper ready (fast)", 2, {red = 0.1, green = 0.5, blue = 0.1, alpha = 0.9})
    else
        updateMenubar("server_off")
        createOverlay("✅ Ready (start server for speed)", 3)
    end
    playSound("Blow")
    log("Ready!")
else
    log("ERROR: Init failed")
    updateMenubar("error")
end

-- Auto-reload
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            hs.reload()
            return
        end
    end
end):start()
