local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local startEvent = ReplicatedStorage.Remote.GameRemote:WaitForChild("Start")
local versionChangeEvent = ReplicatedStorage.Remote.GameRemote:WaitForChild("VersionChange")
local parameterChangeEvent = ReplicatedStorage.Remote.GameRemote:WaitForChild("ParameterChange")

-- Model Selection UI
----------------------------------------------------------------------------
local tweenInfo = TweenInfo.new(
	0.2, 
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)

local guiSelect = script.Parent.SurfaceGui.ModelVersion

local open = false

local openDropdownTween = TweenService:Create(guiSelect.Menu, tweenInfo, {Size = UDim2.new(1, 0, 2, 0)})

local closeDropdownTween = TweenService:Create(guiSelect.Menu, tweenInfo, {Size = UDim2.new(1, 0, 0, 0)})

guiSelect.Activated:Connect(function()
	if not open then
		openDropdownTween:Play()
		open = true
		guiSelect.Menu.Visible = true
	else
		closeDropdownTween:Play()
		open = false
		task.wait(0.3)
		guiSelect.Menu.Visible = false
	end
end)

guiSelect.Menu.WolvesSheep.Activated:Connect(function()
	guiSelect.Text = guiSelect.Menu.WolvesSheep.Text
	versionChangeEvent:FireServer("sheep-wolves")
end)

guiSelect.Menu.WolvesSheepGrass.Activated:Connect(function()
	guiSelect.Text = guiSelect.Menu.WolvesSheepGrass.Text
	versionChangeEvent:FireServer("sheep-wolves-grass")
end)

----------------------------------------------------------------------------

-- Starting Buttons
----------------------------------------------------------------------------
local guiMain = script.Parent.SurfaceGui

guiMain.SetUp.Activated:Connect(function()
	startEvent:FireServer("Setup")
end)

guiMain.Go.Activated:Connect(function()
	startEvent:FireServer("Begin")
end)
----------------------------------------------------------------------------

-- Sliders for Parameters
----------------------------------------------------------------------------
local UIPart = workspace:WaitForChild("VRGui")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local activeSlider = nil

local function CalculateScalePosition(Part, Axis)
	local Mouse3DPosition = Mouse.Hit.Position
	local StartAxis = Part.Position[Axis] - (Part.Size[Axis] / 2)
	local EndAxis = Part.Position[Axis] + (Part.Size[Axis] / 2)
	local Range = EndAxis - StartAxis
	local Distance = Mouse3DPosition[Axis] - StartAxis
	local Percentage = math.clamp(Distance / Range, 0, 1)

	if Axis == "Y" then
		Percentage = 1 - Percentage
	end

	return Percentage
end

local function setupSlider(InputSliderGui, InputMaxVal, InputMinVal)
	local Slider = InputSliderGui
	local Fill = Slider.Fill
	local Trigger = Slider.Trigger
	local OutputLabel = Slider.Label
	local Output = Slider.Output

	local MaxValue = InputMaxVal
	local MinValue = InputMinVal
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad)

	-- Init fill size
	Fill.Size = UDim2.fromScale((Output.Value - MinValue) / (MaxValue - MinValue), 1)
	OutputLabel.Text = tostring(math.round(Output.Value))

	local function updateSlider()
		local normalized = CalculateScalePosition(UIPart, "X") -- horizontal sliders
		local clampedValue = MinValue + normalized * (MaxValue - MinValue)

		TweenService:Create(Fill, tweenInfo, {
			Size = UDim2.fromScale(normalized, 1)
		}):Play()

		Output.Value = clampedValue
		OutputLabel.Text = tostring(math.round(clampedValue))
	end

	local function ActivateSlider()
		while activeSlider == Slider do
			updateSlider()
			RunService.RenderStepped:Wait()
		end
	end

	Trigger.MouseButton1Down:Connect(function()
		activeSlider = Slider
		ActivateSlider()
	end)
end

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if activeSlider then
			local Output = activeSlider:FindFirstChild("Output")
			
			if Output and Output:IsA("NumberValue") then
				local rounded = math.round(Output.Value)
				parameterChangeEvent:FireServer(activeSlider.Name, rounded)
			end
			activeSlider = nil
		end
	end
end)

setupSlider(guiMain.InitWolves, 250, 0)
setupSlider(guiMain.InitSheep, 250, 0)
setupSlider(guiMain.GrassRegrowthTime, 100, 0)
setupSlider(guiMain.SheepGain, 50, 0)
setupSlider(guiMain.WolfGain, 100, 0)
setupSlider(guiMain.SheepReproduce, 20, 1)
setupSlider(guiMain.WolfReproduce, 20, 0)	
----------------------------------------------------------------------------