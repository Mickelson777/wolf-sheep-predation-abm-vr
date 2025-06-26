local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AgentBase = require(script.Parent.AgentBase)
local Toroidal = require(game.ReplicatedStorage.Modules.Toroidal)
local Wolf = setmetatable({}, AgentBase)
Wolf.__index = Wolf

function Wolf.new(model, grid, startingPos, reproduce, energyVar)
	local self = AgentBase.new(model, grid, startingPos)
	setmetatable(self, Wolf)
	self.type = "Wolf"
	
	if reproduce then
		self.energy = energyVar
	else
		self.energy = math.random(0, energyVar * 2)
	end
	
	return self
end

function Wolf:Move()
	local currentPos = self.model:GetPivot().Position

	-- all 8 possible surrounding patches
	local dx, dz
	repeat
		dx = math.random(-1, 1)
		dz = math.random(-1, 1)
	until dx ~= 0 or dz ~= 0 -- prevent not moving

	local offset = Vector3.new(dx * 4, 0, dz * 4)
	local newPos = currentPos + offset

	local wrappedPos = Toroidal.wrapPosition(newPos, 50, 50, 4)
	local snappedPos = Toroidal.snapToGrid(wrappedPos, 4)

	self.model:PivotTo(CFrame.new(snappedPos))
	self:UpdatePatchTracking(snappedPos)
end

function Wolf:Eat(wolfGainFromFood)
	for i, agent in ipairs(self.currentPatch.occupant) do
		if agent ~= self and agent.alive and agent.type == "Sheep" then
			agent.alive = false
			agent.model:Destroy()

			self.grid:RemoveOccupant(self.currentPatch, agent)

			self.energy += wolfGainFromFood

			return
		end
	end
end

function Wolf:Step()
	self:Move()
	self.energy -= 1
	if self.energy <= 0 then
		self.alive = false
		self.model:Destroy()
	end
end

function Wolf:Reproduce(parent, list, grid)
	if not parent.model or not parent.model.PrimaryPart then -- check for existence in case of parent dying midway through
		return
	end

	local model = ReplicatedStorage.Agents.Wolf:Clone()
	local startingCFrame = CFrame.new(parent.model.PrimaryPart.Position)
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder

	local wolf = Wolf.new(model, grid, startingCFrame.Position, true, parent.energy / 2)
	table.insert(list, wolf)
	wolf:Move()

	parent.energy /= 2
end

return Wolf