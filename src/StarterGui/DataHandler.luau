local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sendDataEvent = ReplicatedStorage:WaitForChild("SendData")

local GraphModule = require(ReplicatedStorage.Modules.Graph)

local dataGUI = script.Parent.Data
local graphGUI = script.Parent.GraphFrame

local populationData = {
	Wolves = {},
	Sheep = {}
}

graphGUI.UIStroke.Enabled = true
local GraphHandler = GraphModule.new(graphGUI)
GraphHandler.Resolution = 100  -- arbitrary default
GraphHandler.BaselineZero = true

sendDataEvent.OnClientEvent:Connect(function(data, reset)
	local t = #data.time

	dataGUI.WolfPopulation.Text = "Wolves: " .. data.wolves[t]
	dataGUI.SheepPopulation.Text = "Sheep: " .. data.sheep[t]
	dataGUI.TimePassed.Text = "Time: " .. data.time[t]

	for i = 1, t do
		populationData.Wolves[i] = data.wolves[i]
		populationData.Sheep[i] = data.sheep[i]
	end
	
	if reset then
		GraphHandler:Clear()
		
		populationData = {
			Wolves = {},
			Sheep = {}
		}
	else
		GraphHandler.Data = populationData
	end
end)