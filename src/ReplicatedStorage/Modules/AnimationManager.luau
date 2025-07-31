local AnimationManager = {}

-- safely get a child with timeout
local function safeWaitForChild(parent, childName, timeout)
	if not parent then return nil end
	return parent:FindFirstChild(childName) or parent:WaitForChild(childName, timeout or 2)
end

-- getting/creating a specified animation track for an object
function AnimationManager.setAnimation(object, animName)
	if not object or not object:IsDescendantOf(game) then return nil end

	local humanoid = safeWaitForChild(object, "Humanoid")
	local animationsFolder = safeWaitForChild(object, "Animations")

	if humanoid and animationsFolder then
		local animationObject = animationsFolder:FindFirstChild(animName)
		if animationObject then
			local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator")
			animator.Name = "Animator"
			animator.Parent = humanoid

			-- check if animation is already playing
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Name == animName then
					return track
				end
			end

			local animationTrack = animator:LoadAnimation(animationObject)
			animationTrack.Name = animName
			return animationTrack
		end
	end
	return nil
end

-- function to play specified animation
function AnimationManager.playAnimation(object, animName)
	local animationTrack = AnimationManager.setAnimation(object, animName)

	if animationTrack then
		animationTrack:Play()
		return true
	else
		-- warn("Animation '" .. animName .. "' doesn't exist for object: " .. (object and object.Name or "nil"))
		return false
	end
end

-- function to stop specified animation
function AnimationManager.stopAnimation(object, animName)
	local animationTrack = AnimationManager.setAnimation(object, animName)
	if animationTrack then
		animationTrack:Stop()
	end
end

--[[
-- function to control walking animation based on movement speed
function AnimationManager.bindWalkAnimation(object, animName)
	local humanoid = safeWaitForChild(object, "Humanoid")
	local animator = safeWaitForChild(humanoid, "Animator")
	local animationsFolder = safeWaitForChild(object, "Animations")
	local animationObject = animationsFolder and animationsFolder:FindFirstChild(animName)

	if humanoid and animator and animationObject then
		local walkTrack = animator:LoadAnimation(animationObject)
		walkTrack.Name = animName

		humanoid.Running:Connect(function(speed)
			if speed > 0 then
				if not walkTrack.IsPlaying then
					walkTrack:Play()
				end
			else
				if walkTrack.IsPlaying then
					walkTrack:Stop()
				end
			end
		end)
	end
end
]]

return AnimationManager