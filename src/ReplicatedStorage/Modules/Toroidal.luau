local Toroidal = {}

function Toroidal.wrapPosition(pos, gridWidth, gridHeight, patchSize)
	local minX = patchSize
	local maxX = gridWidth * patchSize
	local minZ = patchSize
	local maxZ = gridHeight * patchSize

	local x = pos.X
	local z = pos.Z

	if x < minX then x = maxX end
	if x > maxX then x = minX end
	if z < minZ then z = maxZ end
	if z > maxZ then z = minZ end

	return Vector3.new(x, pos.Y, z)
end

function Toroidal.snapToGrid(pos, patchSize)
	local x = math.round(pos.X / patchSize) * patchSize
	local z = math.round(pos.Z / patchSize) * patchSize
	return Vector3.new(x, pos.Y, z)
end

return Toroidal