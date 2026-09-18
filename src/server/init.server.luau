local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.GameConfig)

local remotes = Instance.new("Folder")
remotes.Name = "TowerDefenseRemotes"
remotes.Parent = ReplicatedStorage
local placeTowerRemote = Instance.new("RemoteEvent")
placeTowerRemote.Name = "PlaceTower"
placeTowerRemote.Parent = remotes
local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes

local gameState = Instance.new("Folder")
gameState.Name = "GameState"
gameState:SetAttribute("Wave", 0)
gameState:SetAttribute("BaseHealth", Config.BaseHealth)
gameState:SetAttribute("Status", "กำลังเตรียมเกม...")
gameState.Parent = ReplicatedStorage

local enemies = Instance.new("Folder")
enemies.Name = "Enemies"
enemies.Parent = workspace
local towers = Instance.new("Folder")
towers.Name = "Towers"
towers.Parent = workspace
local map = Instance.new("Folder")
map.Name = "GeneratedMap"
map.Parent = workspace

local function makePart(name, size, position, color, material, parent)
	local part = Instance.new("Part")
	part.Name, part.Size, part.Position = name, size, position
	part.Anchored, part.Color, part.Material = true, color, material
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local grass = makePart("BuildArea", Vector3.new(240, 2, 140), Vector3.new(0, -1, 0), Color3.fromRGB(69, 125, 64), Enum.Material.Grass, map)
grass:SetAttribute("BuildSurface", true)
for index = 1, #Config.Waypoints - 1 do
	local startPosition, endPosition = Config.Waypoints[index], Config.Waypoints[index + 1]
	local midpoint, distance = (startPosition + endPosition) / 2, (endPosition - startPosition).Magnitude
	local path = makePart("Path", Vector3.new(14, 0.35, distance + 12), midpoint - Vector3.new(0, 0.8, 0), Color3.fromRGB(194, 163, 112), Enum.Material.Ground, map)
	path.CFrame = CFrame.lookAt(path.Position, endPosition)
	path:SetAttribute("NoBuild", true)
end

local base = makePart("Base", Vector3.new(16, 12, 16), Config.Waypoints[#Config.Waypoints] + Vector3.new(0, 5, 0), Color3.fromRGB(55, 112, 190), Enum.Material.Metal, map)
local baseBillboard = Instance.new("BillboardGui")
baseBillboard.Size, baseBillboard.StudsOffset, baseBillboard.AlwaysOnTop = UDim2.fromOffset(160, 42), Vector3.new(0, 9, 0), true
baseBillboard.Parent = base
local baseLabel = Instance.new("TextLabel")
baseLabel.Size, baseLabel.BackgroundColor3, baseLabel.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(20, 29, 45), 0.15
baseLabel.TextColor3, baseLabel.Font, baseLabel.TextScaled = Color3.new(1, 1, 1), Enum.Font.GothamBold, true
baseLabel.Text, baseLabel.Parent = "ฐาน: " .. Config.BaseHealth, baseBillboard
gameState:GetAttributeChangedSignal("BaseHealth"):Connect(function()
	baseLabel.Text = "ฐาน: " .. tostring(gameState:GetAttribute("BaseHealth"))
end)

local function setupPlayer(player)
	if player:FindFirstChild("leaderstats") then return end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name, leaderstats.Parent = "leaderstats", player
	local cash = Instance.new("IntValue")
	cash.Name, cash.Value, cash.Parent = "Cash", Config.StartingCash, leaderstats
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do setupPlayer(player) end

local function distanceToSegment(point, a, b)
	local ab = b - a
	local t = math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (point - (a + ab * t)).Magnitude
end

local function canPlaceTower(position)
	if math.abs(position.X) > 113 or math.abs(position.Z) > 63 then return false, "วางป้อมภายในพื้นที่หญ้าเท่านั้น" end
	for index = 1, #Config.Waypoints - 1 do
		if distanceToSegment(position, Config.Waypoints[index], Config.Waypoints[index + 1]) < 10 then return false, "วางป้อมบนเส้นทางไม่ได้" end
	end
	for _, tower in towers:GetChildren() do
		if tower.PrimaryPart and (tower.PrimaryPart.Position - position).Magnitude < Config.Tower.Footprint then return false, "ป้อมอยู่ใกล้กันเกินไป" end
	end
	return true
end

local function createTower(position, owner)
	local model = Instance.new("Model")
	model.Name = "ArcherTower"
	model:SetAttribute("OwnerUserId", owner.UserId)
	local pedestal = makePart("Base", Vector3.new(5, 2, 5), position + Vector3.new(0, 1, 0), Color3.fromRGB(80, 83, 91), Enum.Material.Slate, model)
	local head = makePart("Head", Vector3.new(3.4, 3.4, 3.4), position + Vector3.new(0, 3.7, 0), Color3.fromRGB(70, 150, 220), Enum.Material.Metal, model)
	head.Shape = Enum.PartType.Ball
	local barrel = makePart("Barrel", Vector3.new(0.8, 0.8, 4), position + Vector3.new(0, 3.7, -2.5), Color3.fromRGB(35, 42, 52), Enum.Material.Metal, model)
	model.PrimaryPart, model.Parent = pedestal, towers
	task.spawn(function()
		while model.Parent and gameState:GetAttribute("BaseHealth") > 0 do
			local target, bestProgress = nil, -math.huge
			for _, enemy in enemies:GetChildren() do
				local root, health = enemy.PrimaryPart, enemy:GetAttribute("Health")
				if root and health and health > 0 and (root.Position - head.Position).Magnitude <= Config.Tower.Range then
					local progress = enemy:GetAttribute("Progress") or 0
					if progress > bestProgress then target, bestProgress = enemy, progress end
				end
			end
			if target and target.PrimaryPart then
				local targetPosition = target.PrimaryPart.Position
				local flatTarget = Vector3.new(targetPosition.X, head.Position.Y, targetPosition.Z)
				head.CFrame = CFrame.lookAt(head.Position, flatTarget)
				barrel.CFrame = CFrame.lookAt(head.Position, flatTarget) * CFrame.new(0, 0, -2.5)
				target:SetAttribute("Health", math.max(0, target:GetAttribute("Health") - Config.Tower.Damage))
			end
			task.wait(Config.Tower.Cooldown)
		end
	end)
end

placeTowerRemote.OnServerEvent:Connect(function(player, requestedPosition)
	if typeof(requestedPosition) ~= "Vector3" then return end
	local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < Config.Tower.Cost then notifyRemote:FireClient(player, "เงินไม่พอสำหรับป้อม") return end
	local position = Vector3.new(math.round(requestedPosition.X), 0, math.round(requestedPosition.Z))
	local allowed, reason = canPlaceTower(position)
	if not allowed then notifyRemote:FireClient(player, reason) return end
	cash.Value -= Config.Tower.Cost
	createTower(position, player)
	notifyRemote:FireClient(player, "สร้างป้อมสำเร็จ")
end)

local function createEnemy(wave)
	local model = Instance.new("Model")
	model.Name = "Enemy"
	model:SetAttribute("Health", wave.health)
	model:SetAttribute("MaxHealth", wave.health)
	model:SetAttribute("Progress", 0)
	local root = makePart("Root", Vector3.new(4, 4, 4), Config.Waypoints[1] + Vector3.new(0, 2, 0), Color3.fromRGB(213, 72, 72), Enum.Material.SmoothPlastic, model)
	root.Shape, root.CanCollide, model.PrimaryPart = Enum.PartType.Ball, false, root
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.Parent = UDim2.fromOffset(54, 8), Vector3.new(0, 3.3, 0), true, root
	local healthBar = Instance.new("Frame")
	healthBar.Size, healthBar.BackgroundColor3, healthBar.BorderSizePixel, healthBar.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(70, 210, 100), 0, gui
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		healthBar.Size = UDim2.fromScale(math.max(0, health / wave.health), 1)
		if health <= 0 and model.Parent then
			for _, player in Players:GetPlayers() do
				local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
				if cash then cash.Value += wave.reward end
			end
			model:Destroy()
		end
	end)
	model.Parent = enemies
	return model
end

local activeMoves = {}
RunService.Heartbeat:Connect(function(deltaTime)
	for enemy, moveState in activeMoves do
		if not enemy.Parent or enemy:GetAttribute("Health") <= 0 then activeMoves[enemy] = nil continue end
		local target = Config.Waypoints[moveState.waypoint] + Vector3.new(0, 2, 0)
		local root, offset = enemy.PrimaryPart, target - enemy.PrimaryPart.Position
		local step = moveState.speed * deltaTime
		if offset.Magnitude <= step then
			root.Position = target
			moveState.waypoint += 1
			if moveState.waypoint > #Config.Waypoints then
				activeMoves[enemy] = nil
				gameState:SetAttribute("BaseHealth", math.max(0, gameState:GetAttribute("BaseHealth") - 1))
				enemy:Destroy()
			end
		else
			root.CFrame = CFrame.lookAt(root.Position + offset.Unit * step, target)
			enemy:SetAttribute("Progress", moveState.waypoint * 1000 - offset.Magnitude)
		end
	end
end)

task.spawn(function()
	task.wait(3)
	for waveNumber, wave in Config.Waves do
		if gameState:GetAttribute("BaseHealth") <= 0 then break end
		gameState:SetAttribute("Wave", waveNumber)
		gameState:SetAttribute("Status", "เวฟ " .. waveNumber .. " กำลังมา!")
		for _ = 1, wave.count do
			local enemy = createEnemy(wave)
			activeMoves[enemy] = { waypoint = 2, speed = wave.speed }
			task.wait(wave.spacing)
		end
		repeat task.wait(0.5) until #enemies:GetChildren() == 0 or gameState:GetAttribute("BaseHealth") <= 0
		if waveNumber < #Config.Waves then
			for seconds = Config.TimeBetweenWaves, 1, -1 do gameState:SetAttribute("Status", "เวฟถัดไปใน " .. seconds .. " วินาที") task.wait(1) end
		end
	end
	gameState:SetAttribute("Status", gameState:GetAttribute("BaseHealth") > 0 and "ชนะแล้ว! ป้องกันฐานสำเร็จ" or "เกมจบ — ฐานถูกทำลาย")
end)
