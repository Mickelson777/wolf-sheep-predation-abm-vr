local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimateAgentEvent = ReplicatedStorage.Remote.VisualRemote:WaitForChild("AnimateAgent")

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
	
	model:SetAttribute("Energy", self.energy)
	
	-- update billboard gui for the energy
	model:GetAttributeChangedSignal("Energy"):Connect(function()
		local newEnergy = model:GetAttribute("Energy")

		-- retrieve head safely
		local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 3)
		if head then
			local billboardGui = head:FindFirstChild("BillboardGui")
			if billboardGui then
				billboardGui.Frame.TextLabel.Text = "Energy: " .. newEnergy
			end
		end
	end)
	
	return self
end

--[[
rather than doing a randomized selection of the 8 surrounding patches and moving towards the exact center of each,
randomly pick an angle between 50 degrees left and 50 degrees right, then move forward one patch in that direction.
]]
function Sheep:Move()
	local currentPos = self.model:GetPivot().Position

	-- calculate random turning angle
	local randomAngleDeg = math.random(-50, 50)
	local randomAngleRad = math.rad(randomAngleDeg)

	-- get current forward direction
	local forward = self.model:GetPivot().LookVector
	local direction = Vector3.new(
		math.cos(randomAngleRad) * forward.X - math.sin(randomAngleRad) * forward.Z,
		0,
		math.sin(randomAngleRad) * forward.X + math.cos(randomAngleRad) * forward.Z
	).Unit

	-- calculate new position and apply toroidal wrapping
	local newPos = currentPos + direction * 4
	local wrappedPos = Toroidal.wrapPosition(newPos, 50, 50, 4)

	-- teleportation vs. smooth movement
	-- if distance is too large, then we know it wrapped and must teleport
	if (wrappedPos - currentPos).Magnitude > 8 then
		self.model:PivotTo(CFrame.lookAt(wrappedPos, wrappedPos + direction))
		self:UpdatePatchTracking(wrappedPos)
		return false
	else
		self.model:FindFirstChildOfClass("Humanoid"):MoveTo(wrappedPos)
		self:UpdatePatchTracking(wrappedPos)
		return true
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
		self.model:SetAttribute("Energy", self.energy)
		
		AnimateAgentEvent:FireAllClients(self.model, "Eat")
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
	
	parent.energy = math.floor(parent.energy / 2 + 0.5)
	parent.model:SetAttribute("Energy", parent.energy)

	local sheep = Sheep.new(model, grid, startingCFrame.Position, true, parent.energy)
	table.insert(list, sheep)
	sheep:Move()
end

return Sheep