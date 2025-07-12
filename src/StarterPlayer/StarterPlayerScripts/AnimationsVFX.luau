local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local VFXStorage = ReplicatedStorage:WaitForChild("VFX")

local VFXEvent = ReplicatedStorage.Remote.VisualRemote:WaitForChild("VFXEvent")
local AnimateAgentEvent = ReplicatedStorage.Remote.VisualRemote:WaitForChild("AnimateAgent")

local AnimationManager = require(ReplicatedStorage.Modules:WaitForChild("AnimationManager"))

local agentFolder = workspace:WaitForChild("AgentFolder")

local function emitParticles(effect)
	for i, particles in pairs(effect:GetDescendants()) do
		if particles:IsA("ParticleEmitter") then
			particles:Emit(particles:GetAttribute("EmitCount"))
		end
	end
end

VFXEvent.OnClientEvent:Connect(function(cframe)
	local BloodSplatter = VFXStorage:FindFirstChild("BloodSplatter"):Clone()
	BloodSplatter.CFrame = cframe
	BloodSplatter.Parent = workspace.Fx
	
	emitParticles(BloodSplatter)
	Debris:AddItem(BloodSplatter, 2)
end)

AnimateAgentEvent.OnClientEvent:Connect(function(model, animName)
	if model and animName then
		AnimationManager.playAnimation(model, animName)
	end
end)

agentFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		AnimationManager.playAnimation(child, "Move")
	end
end)