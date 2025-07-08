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

	local randomAngleDeg = math.random(-50, 50)
	local randomAngleRad = math.rad(randomAngleDeg)

	local forward = self.model:GetPivot().LookVector
	local direction = Vector3.new(
		math.cos(randomAngleRad) * forward.X - math.sin(randomAngleRad) * forward.Z,
		0,
		math.sin(randomAngleRad) * forward.X + math.cos(randomAngleRad) * forward.Z
	).Unit

	local newPos = currentPos + direction * 4
	local wrappedPos = Toroidal.wrapPosition(newPos, 50, 50, 4)

	-- self.model:PivotTo(CFrame.lookAt(wrappedPos, wrappedPos + direction))
	self.model:FindFirstChildOfClass("Humanoid"):MoveTo(wrappedPos)

	self:UpdatePatchTracking(wrappedPos)
end

function Wolf:Eat(wolfGainFromFood)
	for i = #self.currentPatch.occupant, 1, -1 do
		local agent = self.currentPatch.occupant[i]
		if agent ~= self and agent.alive and agent.type == "Sheep" then
			agent.alive = false
			self.grid:RemoveOccupant(self.currentPatch, agent)

			agent.model:Destroy()

			self.energy += wolfGainFromFood
			return
		end
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

	parent.energy /= 2

	local wolf = Wolf.new(model, grid, startingCFrame.Position, true, parent.energy)
	table.insert(list, wolf)
	wolf:Move()
end

return Wolf