local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sendDataEvent = ReplicatedStorage:FindFirstChild("SendData")

local PatchGrid = require(ReplicatedStorage.Modules.PatchGrid)
local Sheep = require(ReplicatedStorage.Modules.Sheep)
local Wolf = require(ReplicatedStorage.Modules.Wolf)

local grid = PatchGrid.new(50, 50)
local sheepList, wolfList = {}, {}

local graphData = {
	time = {},
	sheep = {},
	wolves = {}
}

task.wait(1)

function updateGraphData(sheepList, wolfList)
	local currentTime = #graphData.time

	table.insert(graphData.time, currentTime)
	table.insert(graphData.sheep, #sheepList)
	table.insert(graphData.wolves, #wolfList)

	sendDataEvent:FireAllClients(graphData)
end

-- spawn sheep and wolves
for i = 1, 100 do
	local patch = grid:GetRandomEmptyPatch()
	local model = ReplicatedStorage.Agents.Sheep:Clone()
	local startingCFrame = CFrame.new(patch.model.Position + Vector3.new(0, 2, 0))
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder
	local sheep = Sheep.new(model, grid, startingCFrame.Position)
	table.insert(sheepList, sheep)
end

for i = 1, 50 do
	local patch = grid:GetRandomEmptyPatch()
	local model =  ReplicatedStorage.Agents.Wolf:Clone()
	local startingCFrame = CFrame.new(patch.model.Position + Vector3.new(0, 2, 0))
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder
	local wolf = Wolf.new(model, grid, startingCFrame.Position)
	table.insert(wolfList, wolf)
end

while true do
	for i = #sheepList, 1, -1 do
		local sheep = sheepList[i]
		if sheep.alive then
			if math.random() * 100 < 4 then
				sheep:Reproduce(sheep, sheepList, grid)
			end
			sheep:Step()
		else
			table.remove(sheepList, i)
		end
	end

	for i = #wolfList, 1, -1 do
		local wolf = wolfList[i]
		if wolf.alive then
			if math.random() * 100 < 5 then
				wolf:Reproduce(wolf, wolfList, grid)
			end
			wolf:Step()
		else
			table.remove(wolfList, i)
		end
	end
	
	task.wait(0.1)
	
	updateGraphData(sheepList, wolfList)
end