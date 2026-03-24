local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local LIVE_FOLDER = workspace:WaitForChild("Live")

local running = false

------------------------------------------------
-- ANIMATION LIST (PUT FULL LIST)
------------------------------------------------

local triggerAnimations = {
["rbxassetid://1470422387"]=true,
["rbxassetid://1470439852"]=true,
["rbxassetid://1470449816"]=true,
["rbxassetid://1470447472"]=true,
["rbxassetid://1470454728"]=true,
["rbxassetid://1470472673"]=true,
["rbxassetid://1461157246"]=true,
["rbxassetid://1470495207"]=true,
["rbxassetid://1461128166"]=true,
["rbxassetid://1461128859"]=true,
["rbxassetid://1461136273"]=true,
["rbxassetid://1461136875"]=true,
["rbxassetid://1461137417"]=true,
["rbxassetid://1461145506"]=true,
["rbxassetid://1461127258"]=true,
["rbxassetid://1461252313"]=true,
["rbxassetid://1470532199"]=true,
["rbxassetid://1885667765"]=true,
["rbxassetid://1885679702"]=true,
["rbxassetid://1885690040"]=true,
["rbxassetid://1885693880"]=true,
["rbxassetid://1885684657"]=true,
["rbxassetid://1461277837"]=true,
["rbxassetid://1885697841"]=true,
["rbxassetid://8328283823"]=true,
["rbxassetid://1470482438"]=true,
["rbxassetid://2653476254"]=true,
["rbxassetid://2653299927"]=true,
["rbxassetid://2653295985"]=true,
["rbxassetid://2653292053"]=true,
["rbxassetid://2653288957"]=true,
["rbxassetid://2653502848"]=true,
["rbxassetid://17423591514"]=true,
["rbxassetid://17423592816"]=true,
["rbxassetid://17423594220"]=true,
["rbxassetid://17442363923"]=true,
["rbxassetid://17423597575"]=true,
["rbxassetid://8442976984"]=true,
["rbxassetid://8442979908"]=true,
["rbxassetid://8442981940"]=true,
["rbxassetid://3238447426"]=true,
["rbxassetid://3238448310"]=true,
["rbxassetid://3238449301"]=true,
["rbxassetid://3238450309"]=true,
["rbxassetid://3238451124"]=true,
["rbxassetid://6310220913"]=true,
["rbxassetid://3259676248"]=true,
["rbxassetid://6313311620"]=true,
["rbxassetid://6313291164"]=true,
["rbxassetid://6765057406"]=true,
["rbxassetid://6765035204"]=true,
["rbxassetid://128980851549763"]=true,
["rbxassetid://122609664088954"]=true,
["rbxassetid://75267484294449"]=true,
["rbxassetid://133959142839156"]=true,
["rbxassetid://135731170921787"]=true,
["rbxassetid://9068693092"]=true,
["rbxassetid://9068691739"]=true,
["rbxassetid://9068689970"]=true,
["rbxassetid://9068688717"]=true,
["rbxassetid://1947243130"]=true,
["rbxassetid://1947230024"]=true,
["rbxassetid://1947219719"]=true,
["rbxassetid://1947196236"]=true,
["rbxassetid://17306027379"]=true,
["rbxassetid://17306019069"]=true,
["rbxassetid://17306015782"]=true,
["rbxassetid://17306012933"]=true,
["rbxassetid://17306010161"]=true,
["rbxassetid://10005583738"]=true,
["rbxassetid://10005508646"]=true,
["rbxassetid://10005462854"]=true,
["rbxassetid://10005430027"]=true,
["rbxassetid://10005397081"]=true,
["rbxassetid://8321564926"]=true,
["rbxassetid://8321532463"]=true,
["rbxassetid://8320258247"]=true,
["rbxassetid://8319862463"]=true,
["rbxassetid://1730640014"]=true,
["rbxassetid://1730629532"]=true,
["rbxassetid://1730618971"]=true,
["rbxassetid://1730606513"]=true,
["rbxassetid://1730596371"]=true,
["rbxassetid://99173747030368"]=true,
["rbxassetid://92901308072582"]=true,
["rbxassetid://127300553109664"]=true,
["rbxassetid://128720585309367"]=true,
["rbxassetid://112322786810921"]=true,
["rbxassetid://9941396095"]=true,
["rbxassetid://9941247556"]=true,
["rbxassetid://9941176251"]=true,
["rbxassetid://9941073313"]=true,
["rbxassetid://9941010371"]=true,
["rbxassetid://9941585929"]=true,
["rbxassetid://129856070992547"]=true,
["rbxassetid://106548325298957"]=true,
["rbxassetid://108198644371262"]=true,
["rbxassetid://84395905295585"]=true,
["rbxassetid://73339319281540"]=true,
["rbxassetid://90516165020038"]=true,
["rbxassetid://100004180935781"]=true,
["rbxassetid://131393003451623"]=true,
["rbxassetid://110197522831021"]=true,
["rbxassetid://99546053454432"]=true,
["rbxassetid://107926540272877"]=true,
["rbxassetid://79609428936371"]=true,
["rbxassetid://73143578122310"]=true,
["rbxassetid://133473825347270"]=true,
["rbxassetid://101164322856955"]=true,
["rbxassetid://115956710243429"]=true,
["rbxassetid://2653512402"]=true,
["rbxassetid://10599154316"]=true,
["rbxassetid://10599110274"]=true,
["rbxassetid://10599128601"]=true,
["rbxassetid://10599060714"]=true,
["rbxassetid://10598162443"]=true,
["rbxassetid://14437197600"]=true,
["rbxassetid://14437152064"]=true,
["rbxassetid://14437150122"]=true,
["rbxassetid://14437148019"]=true,
["rbxassetid://14437145085"]=true,
["rbxassetid://14436312737"]=true,
	-- (keep your full list here)
}

------------------------------------------------
-- PRESS F (HOLD 0.2s)
------------------------------------------------

local function holdF()
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
	task.wait(0.2)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
end

------------------------------------------------
-- RANGE CHECK (15 STUDS)
------------------------------------------------

local function inRange(enemyRoot)
	local char = player.Character
	if not char then return false end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	return (enemyRoot.Position - root.Position).Magnitude <= 18
end

------------------------------------------------
-- TRACK MEMORY (NO DUPLICATES)
------------------------------------------------

local triggeredTracks = {} -- [track] = true

------------------------------------------------
-- MAIN SCANNER
------------------------------------------------

local function scan()

	for _, model in ipairs(LIVE_FOLDER:GetChildren()) do

		if not model:IsA("Model") then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root then continue end
		if not inRange(root) then continue end

		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then continue end

		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do

			if not track.Animation then continue end

			local id = track.Animation.AnimationId

			if triggerAnimations[id] then

				-- ONLY trigger at animation start
				if track.TimePosition < 0.05 then

					-- prevent double trigger on same track
					if not triggeredTracks[track] then
						triggeredTracks[track] = true
						task.spawn(holdF)
						return -- stop after first valid trigger
					end

				end
			end
		end
	end
end

------------------------------------------------
-- CLEANUP OLD TRACKS (IMPORTANT)
------------------------------------------------

RunService.RenderStepped:Connect(function()
	for track,_ in pairs(triggeredTracks) do
		if not track.IsPlaying then
			triggeredTracks[track] = nil
		end
	end
end)

------------------------------------------------
-- START
------------------------------------------------

function module.Start()

	running = true

	RunService.RenderStepped:Connect(function()
		if running then
			scan()
		end
	end)

end

------------------------------------------------
-- STOP
------------------------------------------------

function module.Stop()
	running = false
end

return module
