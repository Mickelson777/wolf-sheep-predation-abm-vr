--[[VR Client-Side Logic: CFrame Sync, Movement, Controls]]
--[[+ Agent Control: Highlighting, Spectating, and Possessing Agents]]

-- services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local VRService = game:GetService("VRService")
local StarterGui = game:GetService("StarterGui")

-- modules (VR specific)
local VRLib = require(ReplicatedStorage.Modules:WaitForChild("VRLib"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local agentFolder = workspace:WaitForChild("AgentFolder")

-- VR detection
local isVR = VRService.VREnabled and UserInputService.VREnabled

-- VR config
local scale = 1
local SpeedDivider = 7.5
local height = 5
local ThumbStick1 = Vector3.new(0, 0, 0)
local rotationConnection -- right controller thumbstick rotation connection
local isRotating = false -- smooth camera turning
local DEADZONE = 0.3 -- prevent accidental drift
local MAX_ROTATION_SPEED = math.rad(90) -- max degrees per second

-- highlighting and spectating variables
local currentHighlight = nil
local hoveredModel = nil
local followConnection = nil

-- global/local variable(s) for spectating and possession
_G.ControlledAgent = nil
_G.IsInAgentPOV = false

local lastControlledAgent = nil

-- direction of movement
local moveDirection = Vector3.zero

-- movement states
local lastSentTime = 0

-- track pressed keys for diagonal movement (keyboard)
local pressedKeys = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false
}

-- VR movement input
local vrThumbstickInput = Vector3.zero

-- looking up and down
local pitch = 0
local minPitch = math.rad(-75)
local maxPitch = math.rad(75)

--[[VR Initialization]]

if isVR then
	print("[" .. player.Name .. "] VR detected")
	ReplicatedStorage.Remote.VRRemote.VR_PlayerJoined:FireServer(true, scale, true)

	-- disable default Roblox VR UI elements
	pcall(function()
		StarterGui:SetCore("VRLaserPointerMode", 0)
		StarterGui:SetCore("VREnableControllerModels", false)
	end)

	-- setup the camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	camera.CFrame = workspace:WaitForChild("SpawnLocation").CFrame * CFrame.new(0, height, 0)
	camera.HeadScale = scale

	-- wait for character and hide the head
	local char = workspace:WaitForChild(player.Name)
	char.Head.Transparency = 1
else
	print("[" .. player.Name .. "] no VR detected")
	ReplicatedStorage.Remote.VRRemote.VR_PlayerJoined:FireServer(false)
end

-- functions to manage movement direction
local function updateMovementDirection()
	local dir = Vector3.zero

	if isVR then
		-- for VR, use thumbstick input directly
		dir = vrThumbstickInput
	else
		-- for keyboard, check all pressed keys and combine directions
		if pressedKeys[Enum.KeyCode.W] then dir += Vector3.new(0, 0, -1) end
		if pressedKeys[Enum.KeyCode.S] then dir += Vector3.new(0, 0, 1) end
		if pressedKeys[Enum.KeyCode.A] then dir += Vector3.new(-1, 0, 0) end
		if pressedKeys[Enum.KeyCode.D] then dir += Vector3.new(1, 0, 0) end
	end

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

	vrThumbstickInput = Vector3.zero
	moveDirection = Vector3.zero
end


-- make head and everything else transparent so it doesn't obstruct view
local function setTransparency(model, value)
	if model.Name == "Sheep" then
		for _, partName in ipairs({"Head", "Hair", "Neck"}) do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.LocalTransparencyModifier = value
			end
		end
	elseif model.Name == "Wolf" then
		for _, partName in ipairs({"Head", "Neck", "Right Ear", "Left Ear"}) do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.LocalTransparencyModifier = value
			end
		end
	end
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

	if isVR then
		-- for VR, resume normal VR camera behavior
		_G.IsInAgentPOV = false
		-- the VR script will handle camera positioning
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = nil
	else
		-- for keyboard/mouse, restore normal camera
		if humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end

	enableControls()
end

--[[Main VR Update Loop]]

if isVR then
	RunService.RenderStepped:Connect(function(deltaTime)
		-- pause all VR camera control if spectating agent OR possessing agent
		if _G.IsInAgentPOV or _G.ControlledAgent then return end

		local HeadCFrame, RightCFrame, LeftCFrame = VRLib.GetUserCFrames()
		local Head, Right, Left = VRLib.CalculateUserCFrames(HeadCFrame, RightCFrame, LeftCFrame, camera.CFrame)

		-- server update & local pose application
		ReplicatedStorage.Remote.VRRemote.VR_UpdatePosition:FireServer(Head, Right, Left)
		VRLib.ApplyUserCFrames(player.Character.Head, player.Character.LeftHand, player.Character.RightHand, Head, Right, Left)

		-- character movement (only when not possessing an agent)
		VRLib.MoveCharacter(camera, player.Character, "Head", ThumbStick1, SpeedDivider)

		-- reapply camera height while maintaining rotation
		camera.CFrame = CFrame.new(camera.CFrame.X, height, camera.CFrame.Z) * camera.CFrame.Rotation

		-- fire server to update collision info
		ReplicatedStorage.Remote.VRRemote.VR_Touching:FireServer(player.Character)
	end)
end

-- update target every frame (mouse and VR share mouse.Target, removing the need for raycasting)
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

-- spectate agent (left click / right trigger)
local function spectateAgent()
	if hoveredModel and hoveredModel:FindFirstChild("Head") then
		-- reset camera first to clean up any existing bindings
		resetCameraToPlayer()
		disableControls()

		-- set global variable to notify that player is spectating agent
		if isVR then
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
end

-- possess agent (right click / grip button)
local function possessAgent()
	if hoveredModel and hoveredModel:FindFirstChild("Head") then
		ReplicatedStorage.Remote.BecomeAgentRemote.RequestPossession:FireServer(hoveredModel)
	end
end

-- mouse controls (for keyboard/mouse users)
if not isVR then
	mouse.Button1Down:Connect(spectateAgent)
	mouse.Button2Down:Connect(possessAgent)
end

-- universal input handling (works for both keyboard and VR)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- reset camera to player (X key for keyboard, X button for VR)
	if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonX then
		resetCameraToPlayer()
	end

	-- specific VR inputs
	if isVR then
		-- right trigger - spectate agent
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonR2 then
			spectateAgent()
		end

		-- right grip - possess agent
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonR1 then
			possessAgent()
		end
	end
end)

--[[Input Bindings]]

-- combined VR movement and agent movement handling
if isVR then
	-- movement: thumbstick 1 (handles both VR movement and agent possession)
	ContextActionService:BindAction("Thumbstick1", function(_, _, input)
		if _G.ControlledAgent then
			-- agent possession movement
			vrThumbstickInput = Vector3.new(input.Position.X, 0, -input.Position.Y)
			updateMovementDirection()
		else
			-- normal VR movement when not possessing an agent
			ThumbStick1 = Vector3.new(input.Position.X, 0, -input.Position.Y)
		end
	end, false, Enum.KeyCode.Thumbstick1)

	-- rotation: thumbstick 2 (handles both VR camera rotation and agent possession rotation)
	ContextActionService:BindAction("Thumbstick2", function(_, _, input)
		local xInput = input.Position.X -- left/right
		if _G.ControlledAgent then
			-- agent possession rotation - use heartbeat for smooth rotation
			if math.abs(xInput) > DEADZONE and not isRotating then
				isRotating = true
				rotationConnection = RunService.Heartbeat:Connect(function(dt)
					-- double-check we're still possessing an agent
					if not _G.ControlledAgent then
						if rotationConnection then
							rotationConnection:Disconnect()
							rotationConnection = nil
						end
						isRotating = false
						return
					end
					local updatedInput = input.Position
					local rotationSpeed = -updatedInput.X * 0.035
					ReplicatedStorage.Remote.BecomeAgentRemote.Rotate:FireServer(rotationSpeed)
				end)
			elseif math.abs(xInput) <= DEADZONE and isRotating then
				isRotating = false
				if rotationConnection then
					rotationConnection:Disconnect()
					rotationConnection = nil
				end
			end
		else
			-- normal VR camera rotation when not possessing an agent
			if math.abs(xInput) > DEADZONE and not isRotating then
				isRotating = true
				rotationConnection = RunService.Heartbeat:Connect(function(dt)
					-- double-check we're still not possessing an agent
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
					local currentCFrame = camera.CFrame
					local rotated = currentCFrame * CFrame.Angles(0, yawSpeed, 0)
					camera.CFrame = rotated
				end)
			elseif math.abs(xInput) <= DEADZONE and isRotating then
				isRotating = false
				if rotationConnection then
					rotationConnection:Disconnect()
					rotationConnection = nil
				end
			end
		end
	end, false, Enum.KeyCode.Thumbstick2)
end

-- receive server notice(s)
ReplicatedStorage.Remote.BecomeAgentRemote.PossessionConfirmed.OnClientEvent:Connect(function(agentModel)
	-- set the global controlled agent's value to the requested agent model to possess (and the local)
	_G.ControlledAgent = agentModel
	lastControlledAgent = agentModel
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

	-- camera and input setup
	if isVR then
		-- for VR: set up first-person camera and controls
		_G.IsInAgentPOV = true

		-- VR controls for possessed agent
		ContextActionService:BindAction("VRUnpossessAgent", function(_, state)
			if state == Enum.UserInputState.Begin and _G.ControlledAgent then
				ReplicatedStorage.Remote.BecomeAgentRemote.RequestUnpossession:FireServer()
			end
		end, false, Enum.KeyCode.ButtonA)

		ContextActionService:BindAction("VREatAction", function(_, state)
			if state == Enum.UserInputState.Begin and _G.ControlledAgent then
				ReplicatedStorage.Remote.BecomeAgentRemote.Eat:FireServer()
			end
		end, false, Enum.KeyCode.ButtonY)
		
		setTransparency(agentModel, 1)
	else
		-- for keyboard/mouse: set up mouse lock and keyboard controls
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
	end
end)

ReplicatedStorage.Remote.BecomeAgentRemote.Unpossessed.OnClientEvent:Connect(function()
	-- revert the controlled agent's transparency
	if isVR and lastControlledAgent then
		setTransparency(lastControlledAgent, 0)
	end

	-- set the global controlled agent's value to nil (and local last controlled agent)
	_G.ControlledAgent = nil
	lastControlledAgent = nil
	resetMovementKeys()

	if isVR then
		-- for VR: clean up VR-specific bindings
		ContextActionService:UnbindAction("VRUnpossessAgent")
		ContextActionService:UnbindAction("VREatAction")
		-- VR movement binding stays active for normal VR movement
	else
		-- for keyboard/mouse: revert mouse settings and clean up bindings
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true

		-- unbind all contexts
		ContextActionService:UnbindAction("PlayerAgentMovement")
		ContextActionService:UnbindAction("UnpossessAgent")
		ContextActionService:UnbindAction("EatAction")
	end

	-- reset camera
	resetCameraToPlayer()
end)

-- tracking movement input
RunService.Heartbeat:Connect(function(dt)
	-- retrieve the currently possessed agent
	local agentModel = _G.ControlledAgent
	local rootPart
	
	if agentModel then
		rootPart = agentModel:FindFirstChild("HumanoidRootPart")
	end
	
	if rootPart then
		if isVR then
			-- VR camera handling - first person view
			local head = agentModel:FindFirstChild("Head")
			if head then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = head.CFrame
			end
		else
			-- keyboard/mouse camera and rotation handling
			local delta = UserInputService:GetMouseDelta()

			-- applying x-rotation directly (significant server delay otherwise)
			if delta.X ~= 0 then
				rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, -delta.X * 0.002, 0)
				ReplicatedStorage.Remote.BecomeAgentRemote.Rotate:FireServer()
			end

			-- manage y-rotation on client (server doesn't need it for anything)
			pitch -= delta.Y * 0.0025
			pitch = math.clamp(pitch, minPitch, maxPitch)

			-- third-person camera based on humanoid root part
			local cameraOffset = Vector3.new(0, 4.5, 7)
			local lookVector = rootPart.CFrame.LookVector
			local thirdPersonPos = rootPart.Position - (lookVector * cameraOffset.Z) + Vector3.new(0, cameraOffset.Y, 0)

			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(thirdPersonPos, rootPart.Position)
		end

		-- applying movement directly (not server!!) (works for both VR and keyboard)
		if moveDirection.Magnitude > 0 then
			local speed = 12
			local worldDir = rootPart.CFrame:VectorToWorldSpace(moveDirection)
			local moveVec = worldDir * dt * speed
			rootPart.CFrame = rootPart.CFrame + moveVec

			if tick() - lastSentTime >= 0.05 then
				ReplicatedStorage.Remote.BecomeAgentRemote.Move:FireServer(moveDirection)
				lastSentTime = tick()
			end
		end
	end
end)