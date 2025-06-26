local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sendDataEvent = ReplicatedStorage:FindFirstChild("SendData")
local startEvent = ReplicatedStorage:FindFirstChild("Start")
local parameterChangeEvent = ReplicatedStorage:WaitForChild("ParameterChange")
local versionChangeEvent = ReplicatedStorage:FindFirstChild("VersionChange")

local PatchGrid = require(ReplicatedStorage.Modules.PatchGrid)
local Sheep = require(ReplicatedStorage.Modules.Sheep)
local Wolf = require(ReplicatedStorage.Modules.Wolf)

local grid
local grass = false
local sheepList, wolfList = {}, {}
local simulationRunning = false
local simulationPaused = false

local graphData = {
	time = {},
	sheep = {},
	wolves = {}
}

local parameters = {
	InitWolves = 50,  -- default wolf count
	InitSheep = 100,   -- default sheep count
	GrassRegrowthTime = 30,   -- default grass regrowth time
	SheepGain = 4,   -- default sheep gain from food value
	WolfGain = 20,   -- default wolf gain from food value
	SheepReproduce = 4,   -- default sheep reproduce rate
	WolfReproduce = 5   -- default wolf reproduce rate
}

parameterChangeEvent.OnServerEvent:Connect(function(player, paramName, value)
	if parameters[paramName] ~= nil then
		parameters[paramName] = value
		print(`[Server] Updated parameter {paramName} to {value}`)
	end
end)

versionChangeEvent.OnServerEvent:Connect(function(player, versionSent)
	print(`[Server] Updated version to {versionSent}`)
	if versionSent == "sheep-wolves-grass" then
		grass = true
	else
		grass = false
	end
end)

local function updateGraphData(reset)
	local currentTime = #graphData.time
	table.insert(graphData.time, currentTime)
	table.insert(graphData.sheep, #sheepList)
	table.insert(graphData.wolves, #wolfList)
	
	if reset then
		sendDataEvent:FireAllClients(graphData, true)
	else
		sendDataEvent:FireAllClients(graphData)
	end
end

local function clearSimulation()
	simulationRunning = false -- stop the loop
	task.wait(0.2) -- allow the current loop to exit cleanly

	-- clear all agents from workspace
	if workspace:FindFirstChild("AgentFolder") then
		workspace.AgentFolder:ClearAllChildren()
	end
	
	if workspace:FindFirstChild("PatchesFolder") then
		workspace.PatchesFolder:ClearAllChildren()
	end

	-- clear agent lists
	table.clear(sheepList)
	table.clear(wolfList)

	-- clear graph data
	graphData = {
		time = {},
		sheep = {},
		wolves = {}
	}

	-- reset the grid
	grid = nil
	
	updateGraphData(true)
end

local function setupSimulation()
	clearSimulation()

	grid = PatchGrid.new(50, 50, parameters.GrassRegrowthTime, grass)

	-- spawn sheep
	for i = 1, parameters.InitSheep do
		local patch = grid:GetRandomEmptyPatch()
		local model = ReplicatedStorage.Agents.Sheep:Clone()
		local startingCFrame = CFrame.new(patch.model.Position + Vector3.new(0, 2, 0))
		model:PivotTo(startingCFrame)
		model.Parent = workspace.AgentFolder
		local sheep = Sheep.new(model, grid, startingCFrame.Position, false, parameters.SheepGain)
		table.insert(sheepList, sheep)
	end

	-- spawn wolves
	for i = 1, parameters.InitWolves do
		local patch = grid:GetRandomEmptyPatch()
		local model = ReplicatedStorage.Agents.Wolf:Clone()
		local startingCFrame = CFrame.new(patch.model.Position + Vector3.new(0, 2, 0))
		model:PivotTo(startingCFrame)
		model.Parent = workspace.AgentFolder
		local wolf = Wolf.new(model, grid, startingCFrame.Position, false, parameters.WolfGain)
		table.insert(wolfList, wolf)
	end
end

local function shuffleList(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function runSimulation()
	while simulationRunning do
		if not simulationPaused then
			shuffleList(sheepList)
			shuffleList(wolfList)

			for i = #sheepList, 1, -1 do
				local sheep = sheepList[i]
				if sheep.alive then
					if math.random() * 100 < parameters.SheepReproduce then
						sheep:Reproduce(sheep, sheepList, grid)
					end

					if grass then
						sheep:Step(grass)
						sheep:Eat(parameters.GrassRegrowthTime, parameters.SheepGain)
					end

					sheep:Step()
				else
					table.remove(sheepList, i)
				end
			end

			for i = #wolfList, 1, -1 do
				local wolf = wolfList[i]
				if wolf.alive then
					if math.random() * 100 < parameters.WolfReproduce then
						wolf:Reproduce(wolf, wolfList, grid)
					end

					wolf:Eat(parameters.WolfGain)
					wolf:Step()
				else
					table.remove(wolfList, i)
				end
			end

			grid:UpdateGrassRegrowth(parameters.GrassRegrowthTime)
			updateGraphData(false)
		end
		task.wait(0.15)
	end
end

startEvent.OnServerEvent:Connect(function(player, action)
	if action == "Setup" then
		setupSimulation()
	elseif action == "Begin" then
		if not simulationRunning then
			simulationRunning = true
			simulationPaused = false
			task.spawn(runSimulation)
		else
			simulationPaused = not simulationPaused
		end
	end
end)