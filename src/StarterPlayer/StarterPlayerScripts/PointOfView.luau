local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local agentFolder = workspace:WaitForChild("AgentFolder")

local currentHighlight = nil
local hoveredModel = nil
local followConnection = nil

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
local function resetCameraToPlayer()
	RunService:UnbindFromRenderStep("FollowAgentHead")

	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end

	local character = player.Character
	if character and character:FindFirstChild("Humanoid") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = character:FindFirstChild("Humanoid")
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

-- on click, switch to first-person camera inside the agent's head
mouse.Button1Down:Connect(function()
	if hoveredModel and hoveredModel:FindFirstChild("Head") then
		-- reset camera first to clean up any existing bindings
		resetCameraToPlayer()

		disableControls()

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