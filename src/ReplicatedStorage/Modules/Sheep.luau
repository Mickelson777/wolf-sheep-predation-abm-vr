local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AgentBase = require(script.Parent.AgentBase)
local Toroidal = require(game.ReplicatedStorage.Modules.Toroidal)
local Sheep = setmetatable({}, AgentBase)
Sheep.__index = Sheep

function Sheep.new(model, grid, startingPos)
	local self = AgentBase.new(model, grid, startingPos)
	setmetatable(self, Sheep)
	self.energy = 0
	self.type = "Sheep"
	return self
end

function Sheep:Move()
	local currentPos = self.model:GetPivot().Position

	local offset = Vector3.new(math.random(-1, 1) * 4, 0, math.random(-1, 1) * 4)
	local newPos = currentPos + offset

	local wrappedPos = Toroidal.wrapPosition(newPos, 50, 50, 4)
	local snappedPos = Toroidal.snapToGrid(wrappedPos, 4)

	self.model:PivotTo(CFrame.new(snappedPos))
	
	self:UpdatePatchTracking(snappedPos)
end

function Sheep:Step() -- wolves-sheep iteration (will implement grass version later)
	self:Move()
	
	--[[self.energy -= 1
	if self.energy <= 0 then
		self.alive = false
		self.model:Destroy()
	end]]
end

function Sheep:Reproduce(parent, list, grid)
	local model =  ReplicatedStorage.Agents.Sheep:Clone()
	local startingCFrame = CFrame.new(parent.model.PrimaryPart.Position)
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder
	local sheep = Sheep.new(model, grid, startingCFrame.Position)
	table.insert(list, sheep)
	sheep:Move()
	
	local dividedEnergy = parent.energy / 2
	parent.energy = dividedEnergy
	sheep.energy = dividedEnergy
end

return Sheep