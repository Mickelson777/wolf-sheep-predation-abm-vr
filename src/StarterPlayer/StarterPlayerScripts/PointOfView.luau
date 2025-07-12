local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local VRService = game:GetService("VRService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local agentFolder = workspace:WaitForChild("AgentFolder")

-- highlighting and spectating variables
local currentHighlight = nil
local hoveredModel = nil
local followConnection = nil

--[[POSSESSION GLOBAL/LOCAL VARIABLES]]
_G.ControlledAgent = nil

-- direction of movement
local moveDirection = Vector3.zero

-- track pressed keys for diagonal movement
local pressedKeys = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false
}

-- looking up and down
local pitch = 0
local minPitch = math.rad(-75)
local maxPitch = math.rad(75)

-- functions to manage movement direction
local function updateMovementDirection()
	local dir = Vector3.zero

	-- check all pressed keys and combine directions
	if pressedKeys[Enum.KeyCode.W] then dir += Vector3.new(0, 0, -1) end
	if pressedKeys[Enum.KeyCode.S] then dir += Vector3.new(0, 0, 1) end
	if pressedKeys[Enum.KeyCode.A] then dir += Vector3.new(-1, 0, 0) end
	if pressedKeys[Enum.KeyCode.D] then dir += Vector3.new(1, 0, 0) end

	-- normalize diagonal movement (so moving diagonally isn't faster)
	if dir.Magnitude > 0 then
		dir = dir.Unit
	end

	moveDirection = dir
end

local function resetMovementKeys()
	for key, _ in pairs(pressedKeys) do
		pressedKeys[key] = false
	end
	
	moveDirection = Vector3.zero
end

-- create a highlight for the selected agent
local function highlightModel(model)
	if currentHighlight then
		currentHighlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = Color3.new(1, 0.768627, 0.956863)
	highlight.OutlineColor = Color3.new(1, 0.305882, 0.490196)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	currentHighlight = highlight
end

-- remove the highlight
local function clearHighlight()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	hoveredModel = nil
end

-- check if an instance is a child of the AgentFolder
local function isAgentModel(instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	return model and model:IsDescendantOf(agentFolder) and model:FindFirstChild("Head")
end

-- functions to disable/enable movement inputs
local function disableControls()
	ContextActionService:BindAction("DisableMovement", function()
		return Enum.ContextActionResult.Sink
	end, false,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
end

local function enableControls()
	ContextActionService:UnbindAction("DisableMovement")
end

-- button press to reset to player's camera
function resetCameraToPlayer()
	RunService:UnbindFromRenderStep("FollowAgentHead")

	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChild("Humanoid")

	if VRService.VREnabled and UserInputService.VREnabled then
		-- ensure the camera snaps back to the VR body, not vice versa
		if head then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CameraSubject = nil
			camera.CFrame = head.CFrame
		end

		_G.IsInAgentPOV = false
	end

	if humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end

	enableControls()
end

-- update mouse target every frame
RunService.RenderStepped:Connect(function()
	local target = mouse.Target
	if target and isAgentModel(target) then
		local model = target:FindFirstAncestorOfClass("Model")
		if model ~= hoveredModel then
			hoveredModel = model
			highlightModel(model)
		end
	else
		clearHighlight()
	end
end)

-- on left click, switch to first-person camera inside the agent's head
mouse.Button1Down:Connect(function()
	if hoveredModel and hoveredModel:FindFirstChild("Head") then
		-- reset camera first to clean up any existing bindings
		resetCameraToPlayer()

		disableControls()

		-- set global variable to true to notify that player is spectating agent
		if VRService.VREnabled and UserInputService.VREnabled then
			_G.IsInAgentPOV = true
		end

		local head = hoveredModel.Head
		local model = hoveredModel
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = head.CFrame

		-- follow the head every frame
		RunService:BindToRenderStep("FollowAgentHead", Enum.RenderPriority.Camera.Value, function()
			if head and head.Parent and model.Parent then
				camera.CFrame = head.CFrame
			else
				-- agent died or head removed
				resetCameraToPlayer()
			end
		end)

		-- listen for model removal
		followConnection = model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				-- reset camera
				resetCameraToPlayer()
			end
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- x key (keyboard)
	if input.KeyCode == Enum.KeyCode.X then
		resetCameraToPlayer()
	end

	-- x button (vr left controller)
	if input.KeyCode == Enum.KeyCode.ButtonX then
		resetCameraToPlayer()
	end
end)

-- on right click, become the agent!
mouse.Button2Down:Connect(function()
	if hoveredModel and hoveredModel:FindFirstChild("Head") then
		ReplicatedStorage.Remote.BecomeAgentRemote.RequestPossession:FireServer(hoveredModel)
	end
end)

-- recieve server notice(s)
ReplicatedStorage.Remote.BecomeAgentRemote.PossessionConfirmed.OnClientEvent:Connect(function(agentModel)
	-- set the global controlled agent's value to the requested agent model to possess
	_G.ControlledAgent = agentModel
	resetMovementKeys()
	
	-- clean up any previous connection first
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end

	-- monitor if the agent model is removed from the world
	followConnection = agentModel.AncestryChanged:Connect(function(_, parent)
		if not parent then
			-- automatically unpossess and reset when agent is destroyed
			ReplicatedStorage.Remote.BecomeAgentRemote.RequestUnpossession:FireServer()
			warn("AGENT DIED!")
		end
	end)

	-- lock mouse and set up camera lock
	RunService.RenderStepped:Wait()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	-- movement system with diagonal support
	ContextActionService:BindAction("PlayerAgentMovement", function(_, state, input)
		local keyCode = input.KeyCode

		-- update pressed state
		if state == Enum.UserInputState.Begin then
			pressedKeys[keyCode] = true
		elseif state == Enum.UserInputState.End then
			pressedKeys[keyCode] = false
		end

		-- update movement direction based on currently pressed keys
		updateMovementDirection()

		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D)

	-- R Key: unpossess the agent
	ContextActionService:BindAction("UnpossessAgent", function(_, state)
		if state == Enum.UserInputState.Begin and _G.ControlledAgent then
			ReplicatedStorage.Remote.BecomeAgentRemote.RequestUnpossession:FireServer()
		end
	end, false, Enum.KeyCode.R)

	-- E Key: eat (whether wolf or sheep)
	ContextActionService:BindAction("EatAction", function(_, state)
		if state == Enum.UserInputState.Begin and _G.ControlledAgent then
			ReplicatedStorage.Remote.BecomeAgentRemote.Eat:FireServer()
		end
	end, false, Enum.KeyCode.E)
end)

ReplicatedStorage.Remote.BecomeAgentRemote.Unpossessed.OnClientEvent:Connect(function()
	-- set the global controlled agent's value to nil
	_G.ControlledAgent = nil
	resetMovementKeys()
	
	-- revert mouse settings
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	
	-- unbind all contexts
	ContextActionService:UnbindAction("PlayerAgentMovement")
	ContextActionService:UnbindAction("UnpossessAgent")
	ContextActionService:UnbindAction("EatAction")
	
	-- reset camera
	resetCameraToPlayer()
end)

-- tracking movement input
RunService.Heartbeat:Connect(function(dt)
	-- retrieve the currently possessed agent
	local agentModel = _G.ControlledAgent
	
	if agentModel then
		-- rotate agent with mouse
		local delta = UserInputService:GetMouseDelta()
		
		-- send x-rotation to server instead of applying directly
		if delta.X ~= 0 then
			ReplicatedStorage.Remote.BecomeAgentRemote.Rotate:FireServer(-delta.X * 0.002)
		end
		
		-- manage y-rotation on client (server doesn't need it for anything)
		pitch -= delta.Y * 0.0025
		pitch = math.clamp(pitch, minPitch, maxPitch)

		--[[first-person camera inside the agent's head
		local head = agentModel:FindFirstChild("Head")
		if head then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = head.CFrame * CFrame.Angles(pitch, 0, 0)
		end]]
		
		-- third-person camera based on humanoid root part
		local cameraOffset = Vector3.new(0, 4.5, 7) -- (up, back)

		local rootPart = agentModel:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local lookVector = rootPart.CFrame.LookVector
			local thirdPersonPos = rootPart.Position - (lookVector * cameraOffset.Z) + Vector3.new(0, cameraOffset.Y, 0)
			
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(thirdPersonPos, rootPart.Position)
		end

		-- send movement input to server to replicate
		if moveDirection.Magnitude > 0 then
			ReplicatedStorage.Remote.BecomeAgentRemote.Move:FireServer(moveDirection)
		end
	end
end)