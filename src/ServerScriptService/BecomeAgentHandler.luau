local BecomeAgentHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Toroidal = require(ReplicatedStorage.Modules:WaitForChild("Toroidal"))

local Remotes = ReplicatedStorage.Remote:WaitForChild("BecomeAgentRemote")

local possessedAgents = {} -- [player] = agent (Sheep or Wolf object)
local lastEnergyDrain = {} -- [agent] = tick()

local connections = {} -- all the connections must be tracked to disconnect later

local sheepList = nil
local wolfList = nil
local parameters = nil
local isGrass = nil

local function findAgentFromModel(model)
	for _, agent in ipairs(sheepList) do
		if agent.model == model then return agent end
	end

	for _, agent in ipairs(wolfList) do
		if agent.model == model then return agent end
	end

	return nil
end

function BecomeAgentHandler.Initialize(sheep, wolves, paramTable, grass)
	-- disconnect everything
	for _, conn in ipairs(connections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	connections = {}
	
	sheepList = sheep
	wolfList = wolves
	parameters = paramTable
	isGrass = grass

	-- possession request
	table.insert(connections, Remotes.RequestPossession.OnServerEvent:Connect(function(player, model)
		local agent = findAgentFromModel(model)
		if not agent or not agent.alive then return end

		if not agent.model:IsDescendantOf(workspace) then
			agent.model.Parent = workspace
		end

		task.defer(function()
			local hrp = agent.model.PrimaryPart
			if hrp then
				hrp:SetNetworkOwner(player)
				print("[Possession] Network owner set for", player.Name)
			end
		end)

		agent.isPossessed = true
		possessedAgents[player] = agent
		Remotes.PossessionConfirmed:FireClient(player, agent.model)
	end))

	-- unpossession request	
	table.insert(connections, Remotes.RequestUnpossession.OnServerEvent:Connect(function(player)
		local agent = possessedAgents[player]
		if not agent then return end

		local hrp = agent.model.PrimaryPart
		if hrp then
			hrp:SetNetworkOwner(nil)
		end

		agent.isPossessed = false
		possessedAgents[player] = nil
		Remotes.Unpossessed:FireClient(player)
	end))

	-- eat
	table.insert(connections, Remotes.Eat.OnServerEvent:Connect(function(player)
		local agent = possessedAgents[player]
		if not agent or not agent.alive then return end

		if agent.type == "Sheep" and isGrass then
			agent:Eat(parameters.GrassRegrowthTime, parameters.SheepGain)
		elseif agent.type == "Wolf" then
			agent:Eat(parameters.WolfGain)
		end
	end))
	
	-- rotation (no longer applied server-side)
	table.insert(connections, Remotes.Rotate.OnServerEvent:Connect(function(player)
		local agent = possessedAgents[player]
		if not agent or not agent.alive then return end

		-- rotation is now purely visual on the client.
		-- i'm keeping this function for future syncing/debug if needed.
	end))

	-- movement (no longer directly modifying cframe)
	table.insert(connections, Remotes.Move.OnServerEvent:Connect(function(player)
		local agent = possessedAgents[player]
		if not agent or not agent.alive then return end

		local humanoidRootPart = agent.model:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end
		
			-- toroidal wrapping
		local currentPos  = humanoidRootPart.Position
		local wrappedPos = Toroidal.wrapPosition(currentPos, 50, 50, 4)

		-- only teleport if wrapping occurred
		if (wrappedPos - currentPos).Magnitude > 1e-2 then
			humanoidRootPart.CFrame = CFrame.new(wrappedPos) * humanoidRootPart.CFrame.Rotation
		end

		-- update patch position
		agent:UpdatePatchTracking(humanoidRootPart.Position)

		--[[energy drain - only every 0.25 seconds (as that's the main simulation time step)
			always have wolves lose energy, sheep only when it's the grass simulation]]
		if agent.type == "Wolf" or (agent.type == "Sheep" and isGrass) then
			local currentTime = tick()
			if not lastEnergyDrain[agent] or currentTime - lastEnergyDrain[agent] >= 0.25 then
				agent.energy -= 1
				agent.model:SetAttribute("Energy", agent.energy)
				lastEnergyDrain[agent] = currentTime

				if agent.energy <= 0 then
					agent.alive = false
					agent.model:Destroy()

					-- clean up everything for specifically dead possessed agents
					possessedAgents[player] = nil
					lastEnergyDrain[agent] = nil
					Remotes.Unpossessed:FireClient(player)

					warn("AGENT DIED!")
				end
			end
		end
	end))
end

return BecomeAgentHandler