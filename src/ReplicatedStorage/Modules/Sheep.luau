local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AgentBase = require(script.Parent.AgentBase)
local Toroidal = require(game.ReplicatedStorage.Modules.Toroidal)
local Sheep = setmetatable({}, AgentBase)
Sheep.__index = Sheep

function Sheep.new(model, grid, startingPos, reproduce, energyVar)
	local self = AgentBase.new(model, grid, startingPos)
	setmetatable(self, Sheep)
	self.type = "Sheep"
	
	if reproduce then
		self.energy = energyVar
	else
		self.energy = math.random(0, energyVar * 2)
	end
	
	return self
end

function Sheep:Move()
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

function Sheep:Step(grass)
	self:Move()
	
	if grass then
		self.energy -= 1
		if self.energy <= 0 then
			self.alive = false
			self.model:Destroy()
		end
	end
end

function Sheep:Eat(grassRegrowthTime, sheepGainFromFood)
	local patch = self.currentPatch

	if patch.hasGrass then
		patch.hasGrass = false

		local r = math.random(75, 100)
		local g = math.random(40, 60)
		local b = math.random(10, 25)
		patch.model.Color = Color3.fromRGB(r, g, b)

		self.energy += sheepGainFromFood
	end
end

function Sheep:Reproduce(parent, list, grid)
	if not parent.model or not parent.model.PrimaryPart then -- check for existence in case of parent dying midway through
		return
	end

	local model = ReplicatedStorage.Agents.Sheep:Clone()
	local startingCFrame = CFrame.new(parent.model.PrimaryPart.Position)
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder

	local sheep = Sheep.new(model, grid, startingCFrame.Position, true, parent.energy / 2)
	table.insert(list, sheep)
	sheep:Move()

	parent.energy /= 2
end

return Sheep