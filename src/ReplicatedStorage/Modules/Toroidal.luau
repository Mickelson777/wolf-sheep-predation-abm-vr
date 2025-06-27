local Toroidal = {}

function Toroidal.wrapPosition(pos, gridWidth, gridHeight, patchSize) -- revised for inexact movement (not center of patch)
	local minX = patchSize
	local maxX = gridWidth * patchSize
	local minZ = patchSize
	local maxZ = gridHeight * patchSize

	local x = ((pos.X - minX) % (maxX - minX)) + minX
	local z = ((pos.Z - minZ) % (maxZ - minZ)) + minZ

	return Vector3.new(x, pos.Y, z)
end

function Toroidal.snapToGrid(pos, patchSize)
	local x = math.round(pos.X / patchSize) * patchSize
	local z = math.round(pos.Z / patchSize) * patchSize
	return Vector3.new(x, pos.Y, z)
end

return Toroidal