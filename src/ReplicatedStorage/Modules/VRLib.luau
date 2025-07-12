--[[VR ModuleScript: Player Character Setup, Movement, CFrame Syncing, Pointer Generation]]

local VRService = game:GetService("VRService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VRLib = {}

--[[CFrame Calculation Methods]]

-- Converts local user CFrames to world space using the camera CFrame
function VRLib.CalculateUserCFrames(HeadCFrame, RightCFrame, LeftCFrame, CameraCFrame)
	local Head = CameraCFrame * HeadCFrame
	local Right = CameraCFrame * RightCFrame
	local Left = CameraCFrame * LeftCFrame

	return Head, Right, Left
end

-- Applies user CFrames to character parts
function VRLib.ApplyUserCFrames(headObj, leftHandObj, rightHandObj, HeadCFrame, RightCFrame, LeftCFrame)
	headObj.CFrame = HeadCFrame
	leftHandObj.CFrame = LeftCFrame * CFrame.fromEulerAnglesXYZ(math.rad(115), 0, math.rad(30))
	rightHandObj.CFrame = RightCFrame * CFrame.fromEulerAnglesXYZ(math.rad(115), 0, math.rad(-30))
end

-- Retrieves raw local user CFrames from VRService
function VRLib.GetUserCFrames()
	local HeadCFrame = VRService:GetUserCFrame(Enum.UserCFrame.Head)
	local RightCFrame = VRService:GetUserCFrame(Enum.UserCFrame.RightHand)
	local LeftCFrame = VRService:GetUserCFrame(Enum.UserCFrame.LeftHand)
	return HeadCFrame, RightCFrame, LeftCFrame
end

--[[VR Character Setup]]

-- Creates and configures a VR character
-- Parameters: Player, uniform scale factor, and whether to load avatar appearance
function VRLib.CreateCharacter(plr, scale, getAvatarAppearance)
	local id = plr.UserId
	local isVR = Instance.new("BoolValue", plr)
	isVR.Name = "IsVR"

	local char = ReplicatedStorage:WaitForChild("VRBaseCharacter"):Clone()
	char.Name = plr.Name
	char.Parent = workspace
	plr.Character = char

	-- Apply scaling
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("MeshPart") or part:IsA("Part") then
			part.Size *= Vector3.new(scale, scale, scale)
			if part:FindFirstChild("Mesh") then
				part.Mesh.Scale *= Vector3.new(scale, scale, scale)
			end
		end
	end

	-- Load avatar appearance
	if getAvatarAppearance then
		local appearance = game.Players:GetCharacterAppearanceAsync(id)
		for _, item in ipairs(appearance:GetChildren()) do
			if item:IsA("Shirt") then
				item.Parent = char
			elseif item:IsA("Decal") then
				char.Head.face.Texture = item.Texture
			elseif item:IsA("BodyColors") then
				item.Parent = char
			end
		end
	end
end

--[[VR Movement Control]]

-- Moves the player relative to the specified reference (Head, LeftHand, RightHand)
function VRLib.MoveCharacter(camera, char, movementType, thumbstickVector, speedDivider)
	local moveVector
	if movementType == "Head" then
		moveVector = (-char.Head.CFrame.LookVector * thumbstickVector.Z + char.Head.CFrame.RightVector * thumbstickVector.X)
	elseif movementType == "LeftHand" then
		moveVector = (-char.LeftHand.CFrame.LookVector * thumbstickVector.Z + char.LeftHand.CFrame.RightVector * thumbstickVector.X)
	elseif movementType == "RightHand" then
		moveVector = (-char.RightHand.CFrame.LookVector * thumbstickVector.Z + char.RightHand.CFrame.RightVector * thumbstickVector.X)
	end
	camera.CFrame += moveVector / speedDivider
end

return VRLib