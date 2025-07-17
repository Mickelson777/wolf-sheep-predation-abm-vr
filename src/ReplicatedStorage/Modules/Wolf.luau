local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFXEvent = ReplicatedStorage.Remote.VisualRemote:WaitForChild("VFXEvent")
local AnimateAgentEvent = ReplicatedStorage.Remote.VisualRemote:WaitForChild("AnimateAgent")

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
	
	model:SetAttribute("Energy", self.energy)

	model:GetAttributeChangedSignal("Energy"):Connect(function()
		local newEnergy = model:GetAttribute("Energy")

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

function Wolf:Eat(wolfGainFromFood)
	for i = #self.currentPatch.occupant, 1, -1 do
		local agent = self.currentPatch.occupant[i]
		if agent ~= self and agent.alive and agent.type == "Sheep" then
			agent.alive = false
			self.grid:RemoveOccupant(self.currentPatch, agent)
			
			VFXEvent:FireAllClients(agent.model:GetPivot(), "BloodSplatter")
			agent.model:Destroy()

			self.energy += wolfGainFromFood
			self.model:SetAttribute("Energy", self.energy)
			
			AnimateAgentEvent:FireAllClients(self.model, "Eat")
			return
		end
	end
end

function Wolf:Reproduce(parent, list, grid)
	if not parent.model or not parent.model.PrimaryPart then
		return
	end

	local model = ReplicatedStorage.Agents.Wolf:Clone()
	local startingCFrame = CFrame.new(parent.model.PrimaryPart.Position)
	model:PivotTo(startingCFrame)
	model.Parent = workspace.AgentFolder

	parent.energy = math.floor(parent.energy / 2 + 0.5)
	parent.model:SetAttribute("Energy", parent.energy)

	local wolf = Wolf.new(model, grid, startingCFrame.Position, true, parent.energy)
	table.insert(list, wolf)
	wolf:Move()
end

return Wolf