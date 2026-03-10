local module = {}

local connection

function module.Start()

    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local VIM = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")

    local LIVE = Workspace:WaitForChild("Live")

    local function click()
        VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end

    connection = UIS.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        if input.KeyCode == Enum.KeyCode.One
        or input.KeyCode == Enum.KeyCode.Two
        or input.KeyCode == Enum.KeyCode.Three
        or input.KeyCode == Enum.KeyCode.Four then

            local cutter

            local guiConn
            guiConn = LIVE.DescendantAdded:Connect(function(inst)

                if inst.Name ~= "NanamiCutGUI" then return end

                local bar = inst:FindFirstChild("MainBar")
                local c = bar and bar:FindFirstChild("Cutter")

                if c then
                    cutter = c
                    guiConn:Disconnect()
                end

            end)

            local hb
            hb = RunService.Heartbeat:Connect(function()

                if not cutter then return end

                if cutter.Position.X.Scale >= 0.7 then
                    click()
                    hb:Disconnect()
                end

            end)

        end

    end)

end

function module.Stop()

    if connection then
        connection:Disconnect()
        connection = nil
    end

end

return module
