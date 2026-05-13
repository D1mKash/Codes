local function smoothFollowAboveTarget(targetModel)
	local char = getCharacter()
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)

	if not myRoot or not targetRoot then return end

	local lastSawChrolloStop = os.clock()

	while running do
		char = getCharacter()
		myRoot = getRoot(char)
		targetRoot = getRoot(targetModel)

		if not char or not myRoot or not targetRoot then
			return
		end

		if hasInCharacter("ChrolloStop") then
			lastSawChrolloStop = os.clock()
		else
			if os.clock() - lastSawChrolloStop >= CHROLLO_STOP_AFTER_GONE then
				return
			end
		end

		-- Match target's X and Z, stay above their head on Y
		local targetPos = targetRoot.Position
		local goalPosition = Vector3.new(
			targetPos.X,
			targetPos.Y + CHROLLO_HEIGHT,
			targetPos.Z
		)

		-- Face same horizontal direction as target
		local look = targetRoot.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)

		if look.Magnitude < 0.05 then
			look = Vector3.new(0, 0, -1)
		end

		local goal = CFrame.new(goalPosition, goalPosition + look)

		myRoot.CFrame = myRoot.CFrame:Lerp(goal, CHROLLO_LERP_ALPHA)

		myRoot.AssemblyLinearVelocity = Vector3.zero
		myRoot.AssemblyAngularVelocity = Vector3.zero

		RunService.Heartbeat:Wait()
	end
end
