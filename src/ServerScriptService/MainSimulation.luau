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
		local randomYRotation = math.rad(math.random(0, 359))
		local position = patch.model.Position + Vector3.new(0, 2.25, 0)
		local orientation = CFrame.Angles(0, randomYRotation, 0)
		local startingCFrame = CFrame.new(position) * orientation

		local model = ReplicatedStorage.Agents.Sheep:Clone()
		model:PivotTo(startingCFrame)
		model.Parent = workspace.AgentFolder

		local sheep = Sheep.new(model, grid, startingCFrame.Position, false, parameters.SheepGain)
		table.insert(sheepList, sheep)
	end

	-- spawn wolves
	for i = 1, parameters.InitWolves do
		local patch = grid:GetRandomEmptyPatch()
		local randomYRotation = math.rad(math.random(0, 359))
		local position = patch.model.Position + Vector3.new(0, 4, 0)
		local orientation = CFrame.Angles(0, randomYRotation, 0)
		local startingCFrame = CFrame.new(position) * orientation

		local model = ReplicatedStorage.Agents.Wolf:Clone()
		model:PivotTo(startingCFrame)
		model.Parent = workspace.AgentFolder

		local wolf = Wolf.new(model, grid, startingCFrame.Position, false, parameters.WolfGain)
		table.insert(wolfList, wolf)
	end
end

local function shuffleList(list)
	if #list <= 1 then return end
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
			
			for x = 1, grid.width do
				for y = 1, grid.height do
					local patch = grid.grid[x][y]
					if patch.occupant and #patch.occupant > 1 then
						shuffleList(patch.occupant)
					end
				end
			end

			for i = #sheepList, 1, -1 do
				local sheep = sheepList[i]
				if sheep.alive then
					task.spawn(function()
						sheep:Move()

						task.wait(0.15)

						if grass then
							sheep.energy -= 1
							
							sheep:Eat(parameters.GrassRegrowthTime, parameters.SheepGain)

							if sheep.energy <= 0 then
								sheep.alive = false
								sheep.model:Destroy()
							end
						end

						if math.random() * 100 < parameters.SheepReproduce then
							sheep:Reproduce(sheep, sheepList, grid)
						end
					end)
				else
					table.remove(sheepList, i)
				end
			end

			for i = #wolfList, 1, -1 do
				local wolf = wolfList[i]
				if wolf.alive then
					task.spawn(function()
						wolf:Move()

						task.wait(0.15)

						wolf.energy -= 1

						wolf:Eat(parameters.WolfGain)

						if wolf.energy <= 0 then
							wolf.alive = false
							wolf.model:Destroy()
						end

						if math.random() * 100 < parameters.WolfReproduce then
							wolf:Reproduce(wolf, wolfList, grid)
						end
					end)
				else
					table.remove(wolfList, i)
				end
			end

			grid:UpdateGrassRegrowth(parameters.GrassRegrowthTime)
			updateGraphData(false)
		end
		task.wait(0.25)
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