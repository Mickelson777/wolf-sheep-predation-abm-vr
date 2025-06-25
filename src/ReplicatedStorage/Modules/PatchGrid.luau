local PatchGrid = {}
PatchGrid.__index = PatchGrid

function PatchGrid.new(width, height)
	local self = setmetatable({}, PatchGrid)
	self.width = width
	self.height = height
	self.grid = {}

	for x = 1, width do
		self.grid[x] = {}
		for y = 1, height do
			local patch = Instance.new("Part")
			patch.Anchored = true
			patch.Size = Vector3.new(4, 1, 4)
			patch.Position = Vector3.new(x * 4, 0, y * 4)
			patch.Name = "Patch"
			patch.Material = Enum.Material.SmoothPlastic
			
			local r = math.random(15, 30)
			local g = math.random(70, 100)
			local b = math.random(15, 20)

			patch.Color = Color3.fromRGB(r, g, b)

			patch.Parent = workspace.PatchesFolder

			self.grid[x][y] = {
				model = patch,
				x = x,
				y = y,
				hasGrass = true,
				occupant = {}
			}
		end
	end

	return self
end

function PatchGrid:GetRandomEmptyPatch()
	local tries = 100
	while tries > 0 do
		local x = math.random(1, self.width)
		local y = math.random(1, self.height)
		local patch = self.grid[x][y]
		
		if next(patch.occupant) == nil then
			return patch
		end
		
		tries -= 1
	end
	
	return nil
end

function PatchGrid:GetPatchFromWorldPosition(pos)
	local patchSize = 4
	local xIndex = math.floor(pos.X / patchSize + 0.5)
	local yIndex = math.floor(pos.Z / patchSize + 0.5)

	if self.grid[xIndex] and self.grid[xIndex][yIndex] then
		return self.grid[xIndex][yIndex]
	end
	
	return nil
end

function PatchGrid:AddOccupant(patch, agent)
	if patch and agent then
		table.insert(patch.occupant, agent)
	end
end

function PatchGrid:RemoveOccupant(patch, agent)
	if patch and agent then
		for i, occ in ipairs(patch.occupant) do
			if occ == agent then
				table.remove(patch.occupant, i)
				break
			end
		end
	end
end

return PatchGrid