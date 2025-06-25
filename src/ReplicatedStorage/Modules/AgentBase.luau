local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PatchGrid = require(ReplicatedStorage.Modules.PatchGrid)

local AgentBase = {}
AgentBase.__index = AgentBase

function AgentBase.new(model, grid, startingPos)
	local self = setmetatable({}, AgentBase)
	self.model = model
	self.grid = grid
	self.alive = true
	self.energy = 0
	self.currentPatch = grid:GetPatchFromWorldPosition(startingPos)
	self.type = "Agent"
	
	return self
end

function AgentBase:UpdatePatchTracking(newWorldPos)
	if self.currentPatch then
		PatchGrid:RemoveOccupant(self.currentPatch, self)
	end

	local newPatch = self.grid:GetPatchFromWorldPosition(newWorldPos)

	if newPatch then
		PatchGrid:AddOccupant(newPatch, self)
		self.currentPatch = newPatch
	end
end

function AgentBase:Move() end  -- subclasses take over
function AgentBase:Step() end  -- time-step behavior

return AgentBase