local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallThrowEvent = ReplicatedStorage:WaitForChild("BallThrowEvent")
local ReleaseBallEvent = ReplicatedStorage:WaitForChild("ReleaseBallEvent")

local holdingPlayers = {} 
local debouncedPlayers = {}

local function onBallTouched(other, ball)
	local player = Players:GetPlayerFromCharacter(other.Parent)

	if player and not debouncedPlayers[player] and not ball:GetAttribute("Respawning") then
		local existingWeld = ball:FindFirstChildWhichIsA("Motor6D")
		local ballOwner = ball:GetAttribute("Owner")

		local goodending = (existingWeld and ballOwner == player.Name)
		local badending = (existingWeld and ballOwner ~= player.Name and player.canSteal)

		-- Check if the ball has an owner but no weld and the owner touches it
		if not existingWeld or goodending or badending then
			if not existingWeld and ballOwner == player.Name then
				holdingPlayers[player] = ball
			elseif not holdingPlayers[player] then
				holdingPlayers[player] = ball
				ball:SetAttribute("Owner", player.Name)
			else
				return -- Skip further processing if the ball is already held by someone else
			end

			if existingWeld then
				existingWeld:Destroy()
			end

			local weld = Instance.new("Motor6D")
			weld.Part0 = ball
			weld.Part1 = player.Character:WaitForChild("Right Arm")
			weld.Parent = ball
			weld.C0 = CFrame.new(0, 0, 2)

			ball.CanCollide = false
			ball.Highlight.OutlineColor = player.TeamColor.Color

			debouncedPlayers[player] = true
			task.delay(0.5, function()
				debouncedPlayers[player] = nil
			end)
		end
	end
end

local function removeOverheadArrow(player)
	local character = player.Character
	if character then
		local arrow = character:FindFirstChild("ArrowGui")
		if arrow then
			arrow:Destroy()
		end
	end
end

local function throwBall(player, mousePos, power, ball)
	if holdingPlayers[player] ~= ball then
		return -- Ignore if the player is not the one holding this ball
	end

	local throwDirection = (mousePos - ball.Position).Unit
	local throwForce = power * 2

	local weld = ball:FindFirstChildWhichIsA("Motor6D")
	if weld then
		weld:Destroy()
	end

	removeOverheadArrow(player)
	
	ball.CFrame = CFrame.new(ball.CFrame.Position + (throwDirection * 3))
	ball.Velocity = throwDirection * throwForce
	ball.CanCollide = true

	holdingPlayers[player] = nil
	debouncedPlayers[player] = true
	task.delay(0.5, function()
		debouncedPlayers[player] = nil
	end)
end

ReleaseBallEvent.OnServerEvent:Connect(function(player, ball)
	if holdingPlayers[player] == ball then
		throwBall(player, player.Character.HumanoidRootPart.Position + Vector3.new(0, 20, 0), 70, ball)
	end
end)

BallThrowEvent.OnServerEvent:Connect(function(player, mousePos, power, ball)
	if holdingPlayers[player] == ball and power <= 100 and power >= 10 then
		throwBall(player, mousePos, power, ball)
	end
end)

local function updateBalls()
	local balls = CollectionService:GetTagged("ball")
	for _, ball in ipairs(balls) do
		ball.Touched:Connect(function(other)
			onBallTouched(other, ball)
		end)
	end
end

CollectionService:GetInstanceAddedSignal("ball"):Connect(function(ball)
	ball.Touched:Connect(function(other)
		onBallTouched(other, ball)
	end)
	updateBalls()
end)

CollectionService:GetInstanceRemovedSignal("ball"):Connect(updateBalls)

updateBalls()
