--[[VR Client-Side Logic: Handles CFrame Sync, Movement, Controls]]

-- Services
local ContextActionService = game:GetService("ContextActionService")
local VRService = game:GetService("VRService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local VRLib = require(ReplicatedStorage.Modules:WaitForChild("VRLib"))

-- Player
local plr = Players.LocalPlayer

-- Config
local scale = 1
local SpeedDivider = 7.5
local height = 5
local ThumbStick1 = Vector3.new(0, 0, 0)
local rotationConnection -- right controller thumbstick rotation connection
local isRotating = false -- smooth camera turning
local DEADZONE = 0.3 -- prevent accidental drift
local MAX_ROTATION_SPEED = math.rad(90) -- max degrees per second

-- Global Variable(s)
_G.IsInAgentPOV = false

--[[VR Initialization]]

-- Check for VR support
if VRService.VREnabled and UserInputService.VREnabled then
	print("[" .. plr.Name .. "] VR detected")
	ReplicatedStorage.Remote.VRRemote.VR_PlayerJoined:FireServer(true, scale, true)
else
	print("[" .. plr.Name .. "] no VR detected")
	ReplicatedStorage.Remote.VRRemote.VR_PlayerJoined:FireServer(false)
	return
end

-- Disable default Roblox VR UI elements
pcall(function()
	StarterGui:SetCore("VRLaserPointerMode", 0)
	StarterGui:SetCore("VREnableControllerModels", false)
end)

-- Setup the camera
local Camera = workspace.CurrentCamera
Camera.CameraType = Enum.CameraType.Scriptable
Camera.CameraSubject = nil
Camera.CFrame = workspace:WaitForChild("SpawnLocation").CFrame * CFrame.new(0, height, 0)
Camera.HeadScale = scale

-- Wait for character and hide the head
local char = workspace:WaitForChild(plr.Name)
char.Head.Transparency = 1

--[[Main VR Update Loop]]

RunService.RenderStepped:Connect(function(deltaTime)
	-- Pause all VR camera control if spectating agent OR possessing agent
	if _G.IsInAgentPOV or _G.ControlledAgent then return end

	local HeadCFrame, RightCFrame, LeftCFrame = VRLib.GetUserCFrames()
	local Head, Right, Left = VRLib.CalculateUserCFrames(HeadCFrame, RightCFrame, LeftCFrame, Camera.CFrame)

	-- Server update & local pose application
	ReplicatedStorage.Remote.VRRemote.VR_UpdatePosition:FireServer(Head, Right, Left)
	VRLib.ApplyUserCFrames(char.Head, char.LeftHand, char.RightHand, Head, Right, Left)

	-- Character movement (only when not possessing an agent)
	VRLib.MoveCharacter(Camera, char, "Head", ThumbStick1, SpeedDivider)

	-- Reapply camera height while maintaining rotation
	Camera.CFrame = CFrame.new(Camera.CFrame.X, height, Camera.CFrame.Z) * Camera.CFrame.Rotation

	-- Fire server to update collision info
	ReplicatedStorage.Remote.VRRemote.VR_Touching:FireServer(char)
end)

--[[Input Bindings]]

-- Movement: Thumbstick 1 (no interference with agent possession)
ContextActionService:BindAction("Thumbstick1", function(_, _, input)
	if not _G.ControlledAgent then
		-- Normal VR movement when not possessing an agent
		ThumbStick1 = Vector3.new(input.Position.X, 0, -input.Position.Y)
	end
	-- When possessing an agent, this input is handled by the main client script (PointOfView)
end, false, Enum.KeyCode.Thumbstick1)

-- Rotation: Thumbstick 2 (only active when not possessing an agent)
ContextActionService:BindAction("Thumbstick2", function(_, _, input)
	-- Only allow VR rotation when not possessing an agent
	if _G.ControlledAgent then return end

	local xInput = input.Position.X -- left/right
	if math.abs(xInput) > DEADZONE and not isRotating then
		isRotating = true
		rotationConnection = RunService.Heartbeat:Connect(function(dt)
			-- Double-check we're still not possessing an agent
			if _G.ControlledAgent then
				if rotationConnection then
					rotationConnection:Disconnect()
					rotationConnection = nil
				end
				isRotating = false
				return
			end

			local updatedInput = input.Position
			local yawSpeed = -updatedInput.X * MAX_ROTATION_SPEED * dt -- horizontal rotation only
			local currentCFrame = Camera.CFrame
			local rotated = currentCFrame * CFrame.Angles(0, yawSpeed, 0)
			Camera.CFrame = rotated
		end)
	elseif math.abs(xInput) <= DEADZONE and isRotating then
		isRotating = false
		if rotationConnection then
			rotationConnection:Disconnect()
			rotationConnection = nil
		end
	end
end, false, Enum.KeyCode.Thumbstick2)

--[[Left hand grab
ContextActionService:BindAction("LeftGrip", function(_, state)
	if state == Enum.UserInputState.Begin then
		ReplicatedStorage.Remote.VRRemote.VR_Grabbed:FireServer("LeftHand", "begin")
	elseif state == Enum.UserInputState.End then
		ReplicatedStorage.Remote.VRRemote.VR_Grabbed:FireServer("LeftHand", "end")
	end
end, false, Enum.KeyCode.ButtonL1)

-- Right hand grab
ContextActionService:BindAction("RightGrip", function(_, state)
	if state == Enum.UserInputState.Begin then
		ReplicatedStorage.Remote.VRRemote.VR_Grabbed:FireServer("RightHand", "begin")
	elseif state == Enum.UserInputState.End then
		ReplicatedStorage.Remote.VRRemote.VR_Grabbed:FireServer("RightHand", "end")
	end
end, false, Enum.KeyCode.ButtonR1)]]