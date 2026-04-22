local m={}local P=game:GetService("Players")local R=game:GetService("RunService")local W=game:GetService("Workspace")local p=P.LocalPlayer local h local c local s="D"local v0=0 local d local running=false local function f()return h and h:GetState()==Enum.HumanoidStateType.Freefall end

-- 🔥 LIFT (UNCHANGED)
local function l()local x=p.Character if not x then return end local r=x:FindFirstChild("HumanoidRootPart")if not r then return end r.AssemblyLinearVelocity=Vector3.new(0,32,0)local t=os.clock()task.spawn(function()while running and os.clock()-t<0.1 do if not r or not r.Parent then return end r.AssemblyLinearVelocity=Vector3.new(0,32,0)R.Heartbeat:Wait()end end)end

-- 🔥 DELTA FOLLOW (1 SECOND)
local function followDelta()
	local char=p.Character if not char then return end
	local root=char:FindFirstChild("HumanoidRootPart")if not root then return end
	local live=W:FindFirstChild("Live")if not live then return end

	local closest local dist=math.huge
	for _,m2 in pairs(live:GetChildren())do
		if m2~=char and m2:IsA("Model")then
			local hrp=m2:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d2=(hrp.Position-root.Position).Magnitude
				if d2<dist then dist=d2 closest=hrp end
			end
		end
	end

	if not closest or dist>15 then return end

	local lastCF=closest.CFrame
	local start=os.clock()

	task.spawn(function()
		while running and os.clock()-start<1 do -- 🔥 1 second follow
			if not root or not closest or not closest.Parent then return end

			local currentCF=closest.CFrame
			local delta=lastCF:ToObjectSpace(currentCF)

			root.CFrame=root.CFrame*delta
			lastCF=currentCF

			R.Heartbeat:Wait()
		end
	end)
end

local function reset()s="D"if d then d:Disconnect()d=nil end end

-- 🔥 DAMAGE SCAN
local function ds()task.spawn(function()while running do task.wait(0.1)if s~="D"then continue end local a=p:FindFirstChild("Stats")local b=a and a:FindFirstChild("Damage")if b then v0=b.Value d=b.Changed:Connect(function()if not running then return end if b.Value-v0>=4 and b.Value-v0<=9 and s=="D"then s="A"if d then d:Disconnect()d=nil end end end)end end end)end

-- 🔥 ANIMATION HOOK
local function hk(x)if c then c:Disconnect()end h=x:WaitForChild("Humanoid")c=h.AnimationPlayed:Connect(function(t)
	if not running then return end
	if f()then return end
	if s~="A"then return end
	if not t.Animation then return end

	local i=t.Animation.AnimationId

	if i=="rbxassetid://2"or i=="rbxassetid://1461137417"then
		
		-- 🔥 STEP 1: JUMP IMMEDIATELY WHEN ANIMATION PLAYS
		l()

		-- 🔥 STEP 2: AFTER ANIMATION ENDS → FOLLOW
		t.Stopped:Once(function()
			if not running then return end
			followDelta()
			reset()
		end)
	end
end)end

function m.Start()if running then return end running=true if p.Character then hk(p.Character)end p.CharacterAdded:Connect(hk)ds()end
function m.Stop()running=false s="D"if c then c:Disconnect()c=nil end if d then d:Disconnect()d=nil end h=nil end
return m
