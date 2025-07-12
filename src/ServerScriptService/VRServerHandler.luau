--[[VR Server-Side Logic: Player Initialization, CFrame Updates, Collision Networking, Grabbing]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

-- Modules
local VRLib = require(ReplicatedStorage.Modules:WaitForChild("VRLib"))

--[[Utility/Helper Function(s)]]

-- Handles touching logic, assigns network ownership to touched parts
local function NetworkTouch(player, character, hit)
	pcall(function()
		if hit and hit:IsA("BasePart") and hit.CanCollide then
			if hit.Anchored then
				hit.Anchored = false
				hit:SetNetworkOwner(player)
				hit.Anchored = true
			else
				hit:SetNetworkOwner(player)
			end
		end
	end)
end

--[[Player Joined (Character Creation)]]

ReplicatedStorage.Remote.VRRemote.VR_PlayerJoined.OnServerEvent:Connect(function(player, isVR, scale, getAvatarAppearance)
	if isVR then
		print("Loading custom VR character model!")
		VRLib.CreateCharacter(player, scale, getAvatarAppearance)

		local char = workspace:WaitForChild(player.Name)

		-- Bind touch events to both hands and their grips
		for _, partName in pairs({"LeftHand", "RightHand"}) do
			local hand = char:FindFirstChild(partName)
			if hand then
				hand.Touched:Connect(function(hit)
					NetworkTouch(player, char, hit)
				end)

				local grip = hand:FindFirstChild("Grip")
				if grip then
					grip.Touched:Connect(function(hit)
						NetworkTouch(player, char, hit)
					end)
				end
			end
		end
	else
		print("Loading player's regular/default character!")
		player:LoadCharacter()
	end
end)

--[[Player Movement & Position Updates]]

ReplicatedStorage.Remote.VRRemote.VR_UpdatePosition.OnServerEvent:Connect(function(player, HeadCFrame, RightCFrame, LeftCFrame)
	local char = workspace:FindFirstChild(player.Name)
	if char then
		VRLib.ApplyUserCFrames(char:FindFirstChild("Head"), char:FindFirstChild("LeftHand"), char:FindFirstChild("RightHand"), HeadCFrame, RightCFrame, LeftCFrame)
	end
end)

--[[Object Grabbing Logic]]

ReplicatedStorage.Remote.VRRemote.VR_Grabbed.OnServerEvent:Connect(function(player, handName, state)
	local char = workspace:FindFirstChild(player.Name)
	if not char then return end

	local hand = char:FindFirstChild(handName)
	if not hand then return end

	local grip = hand:FindFirstChild("Grip")
	if not grip then return end

	if state == "begin" then
		for _, part in pairs(grip:GetTouchingParts()) do
			if part:FindFirstChild("Grabbable") then
				NetworkTouch(player, char, part)

				local weld = Instance.new("WeldConstraint")
				weld.Name = "Weld"
				weld.Part0 = grip
				weld.Part1 = part
				weld.Parent = grip

				if part:FindFirstChild("ResetOrientationOnGrab") then
					part.Position = hand.Position
					part.Orientation = hand.Orientation
				end
				break
			end
		end
	elseif state == "end" then
		local existingWeld = grip:FindFirstChild("Weld")
		if existingWeld then
			existingWeld:Destroy()
		end
	end
end)

--[[Touch Scan (Manual Invocation)]]

ReplicatedStorage.Remote.VRRemote.VR_Touching.OnServerEvent:Connect(function(player, char)
	for _, part in pairs(char.LeftHand:GetTouchingParts()) do
		NetworkTouch(player, char, part)
	end
	for _, part in pairs(char.RightHand:GetTouchingParts()) do
		NetworkTouch(player, char, part)
	end
end)