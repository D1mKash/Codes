local _0xA = {}
local _0x1 = nil -- Stores all event connections
local _0x20 = 0 -- Cancellation token for active threads

function _0xA.Start()
    local Players = game:GetService("Players")
    local VIM = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")
    local Live = Workspace:WaitForChild("Live")
    local plr = Players.LocalPlayer

    local backpack = plr:FindFirstChild("Backpack")
    if not backpack then
        backpack = plr:WaitForChild("Backpack") -- Wait for it if not loaded
    end

    -- The core logic: wait for the Nanami Cut GUI and click the bar at 0.7
    local function triggerCut()
        -- Cancel any previously running cut watcher (prevents spam/multiple clicks)
        _0x20 = _0x20 + 1
        local myToken = _0x20

        task.spawn(function()
            local cutter = nil
            local cutGUI = Live:FindFirstChild("NanamiCutGUI")

            if cutGUI then
                local mainBar = cutGUI:FindFirstChild("MainBar")
                if mainBar then
                    cutter = mainBar:FindFirstChild("Cutter")
                end
            end

            -- If the GUI isn't there yet, wait for it (max 1.5 seconds)
            local timeout = tick() + 1.5
            while not cutter and tick() < timeout do
                if myToken ~= _0x20 then return end -- Canceled by a new ability use
                cutGUI = Live:FindFirstChild("NanamiCutGUI")
                if cutGUI then
                    local mainBar = cutGUI:FindFirstChild("MainBar")
                    if mainBar then
                        cutter = mainBar:FindFirstChild("Cutter")
                    end
                end
                task.wait(0.05) -- ~20 checks/second, uses 0% CPU
            end

            if not cutter then return end

            -- Wait for the bar to reach 0.7
            while cutter and cutter.Position.X.Scale < 0.7 do
                if myToken ~= _0x20 then return end -- Canceled
                task.wait(0.05)
            end

            -- Click the cutter!
            if cutter and cutter.Position.X.Scale >= 0.7 then
                VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end
        end)
    end

    -- List of Nanami's abilities (exactly as named in the Backpack)
    local abilityNames = {"Bisecting Slash", "7:3 Combo", "Hair Grab", "Retirement Kick"}
    local connections = {}

    for _, name in ipairs(abilityNames) do
        local config = backpack:FindFirstChild(name)

        if config and config:IsA("Configuration") then
            -- Store the current cooldown value (default to 20 if missing)
            local lastValue = config:GetAttribute("COOLDOWN")
            if lastValue == nil then lastValue = 20 end

            -- Listen for cooldown changes
            local conn = config:GetAttributeChangedSignal("COOLDOWN"):Connect(function()
                local newValue = config:GetAttribute("COOLDOWN")

                -- If it was READY (20) and NOW it's ON COOLDOWN (< 20), the move just fired!
                if lastValue == 20 and newValue ~= nil and newValue < 20 then
                    triggerCut() -- Start the Nanami Cut sequence
                end

                -- Update the stored value for the next change
                lastValue = newValue
            end)

            table.insert(connections, conn)
        else
            warn("[Nanami] Could not find ability in Backpack:", name)
        end
    end

    _0x1 = connections
end

function _0xA.Stop()
    -- Disconnect all attribute listeners
    if _0x1 then
        for _, conn in ipairs(_0x1) do
            if conn then pcall(conn.Disconnect, conn) end
        end
        _0x1 = nil
    end

    -- Increment token to instantly kill any waiting threads
    _0x20 = _0x20 + 1
end

return _0xA
