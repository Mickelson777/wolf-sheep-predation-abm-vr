local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AgentBase = require(script.Parent.AgentBase)
local Toroidal = require(game.ReplicatedStorage.Modules.Toroidal)
local Wolf = setmetatable({}, AgentBase)
Wolf.__index = Wolf

function Wolf.new(model, grid, startingPos)
	local self = AgentBase.new(model, grid, startingPos)
	setmetatable(self, Wolf)
	self.energy = math.random(0, 40)
	self.type = "Wolf"
	return self
end

function Wolf:Move()
	local currentPos = self.model:GetPivot().Position

	local offset = Vector3.new(math.random(-1, 1) * 4, 0, math.random(-1, 1) * 4)
	local newPos = currentPos + offset

	local wrappedPos = Toroidal.wrapPosition(newPos, 50, 50, 4)
	local snappedPos = Toroidal.snapToGrid(wrappedPos, 4)

	self.model:PivotTo(CFrame.new(snappedPos))
	
	self:UpdatePatchTracking(snappedPos)
end

function Wolf:Eat()
	for i, agent in ipairs(self.currentPatch.occupant) do
		if agent ~= self and agent.alive and agent.type == "Sheep" then
			agent.alive = false
			agent.model:Destroy()

			self.grid:RemoveOccupant(self.currentPatch, agent)

			self.energy += 20

			return
		end
	end
end

function Wolf:Step()
	self:Eat()
	self:Move()
	self.energy -= 1
	if self.energy <= 0 then
		self.alive = false
		self.model:Destroy()
	end
end

function Wolf:Reproduce(parent, list, grid)
	local model =  ReplicatedStorage.Agents.Wolf:Clone()
	local startingCFrame = CFrame.new(parent.model.PrimaryPart.Position)
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder
	local wolf = Wolf.new(model, grid, startingCFrame.Position)
	table.insert(list, wolf)
	wolf:Move()
	
	local dividedEnergy = parent.energy / 2
	parent.energy = dividedEnergy
	wolf.energy = dividedEnergy
end

return Wolf