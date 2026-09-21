local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Routes = require(ReplicatedStorage.Shared.Routes)
local activePaths = Routes.Layouts[1].Paths
local totalWaves = 15
local spawnSequence = 0
local TowerVisuals = require(ReplicatedStorage.Shared.TowerVisuals)

local function newInstance(className, name, parent)
	local instance = Instance.new(className)
	instance.Name, instance.Parent = name, parent
	return instance
end

local remotes = newInstance("Folder", "TowerDefenseRemotes", ReplicatedStorage)
local placeTowerRemote = newInstance("RemoteEvent", "PlaceTower", remotes)
local towerActionRemote = newInstance("RemoteEvent", "TowerAction", remotes)
local readyRemote = newInstance("RemoteEvent", "ToggleReady", remotes)
local notifyRemote = newInstance("RemoteEvent", "Notify", remotes)

local gameState = newInstance("Folder", "GameState", ReplicatedStorage)
gameState:SetAttribute("State", "Waiting")
gameState:SetAttribute("Wave", 0)
gameState:SetAttribute("BaseHealth", Config.BaseHealth)
gameState:SetAttribute("Status", "กด Ready เพื่อเริ่มเกม")
gameState:SetAttribute("PlayerCount", 0)

local enemies = newInstance("Folder", "Enemies", workspace)
local towers = newInstance("Folder", "Towers", workspace)
local map = newInstance("Folder", "GeneratedMap", workspace)

-- Weak tables to prevent memory leaks (issue #2)
local activeMoves = setmetatable({}, { __mode = "k" })
local damageLedgers = setmetatable({}, { __mode = "k" })
local towerRuntime = {}
local participants = {}

local enemyTemplates = ServerStorage:FindFirstChild("Assets")
	and ServerStorage.Assets:FindFirstChild("Enemies")

local function removeEmbeddedScripts(container)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
end

if enemyTemplates then
	removeEmbeddedScripts(enemyTemplates)
end

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
local routeFolder = newInstance("Folder", "Routes", map)
local function rebuildRoutes()
	routeFolder:ClearAllChildren()
	local layout = Routes.Layouts[math.random(1, #Routes.Layouts)]
	activePaths = layout.Paths
	spawnSequence = 0
	gameState:SetAttribute("Layout", layout.Name)
	gameState:SetAttribute("RouteCount", #activePaths)
	for routeIndex, path in activePaths do
		for i=1,#path-1 do
			local a,b=path[i],path[i+1]
			local road=makePart("Path",Vector3.new(14,0.35,(b-a).Magnitude+12),(a+b)/2-Vector3.new(0,0.8,0),Color3.fromRGB(194,163,112),Enum.Material.Ground,routeFolder)
			road.CFrame=CFrame.lookAt(road.Position, b-Vector3.new(0,0.8,0))
		end
		local marker=makePart("Spawn"..routeIndex,Vector3.new(2,6,2),path[1]+Vector3.new(0,2,0),Color3.fromRGB(210,75,80),Enum.Material.Neon,routeFolder)
		local gui=newInstance("BillboardGui","SpawnLabel",marker)
		gui.Size,gui.StudsOffset,gui.AlwaysOnTop=UDim2.fromOffset(160,36),Vector3.new(0,5,0),true
		local label=newInstance("TextLabel","Label",gui)
		label.Size,label.BackgroundTransparency,label.TextScaled=UDim2.fromScale(1,1),0.25,true
		label.TextColor3=Color3.new(1,1,1)
		label.Text="SPAWN "..routeIndex..(routeIndex>1 and " • WAVE 6+" or "")
	end
end
rebuildRoutes()

local base = makePart("Base", Vector3.new(16, 12, 16), activePaths[1][#activePaths[1]] + Vector3.new(0, 5, 0), Color3.fromRGB(55, 112, 190), Enum.Material.Metal, map)
local baseBillboard = newInstance("BillboardGui", "Health", base)
baseBillboard.Size, baseBillboard.StudsOffset, baseBillboard.AlwaysOnTop = UDim2.fromOffset(160, 42), Vector3.new(0, 9, 0), true
local baseLabel = newInstance("TextLabel", "Label", baseBillboard)
baseLabel.Size, baseLabel.BackgroundColor3, baseLabel.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(20, 29, 45), 0.15
baseLabel.TextColor3, baseLabel.Font, baseLabel.TextScaled = Color3.new(1, 1, 1), Enum.Font.GothamBold, true
baseLabel.Text = "ฐาน: " .. Config.BaseHealth
gameState:GetAttributeChangedSignal("BaseHealth"):Connect(function() baseLabel.Text = "ฐาน: " .. gameState:GetAttribute("BaseHealth") end)

local function setupPlayer(player)
	if player:FindFirstChild("leaderstats") then return end
	local leaderstats = newInstance("Folder", "leaderstats", player)
	local cash = newInstance("IntValue", "Cash", leaderstats)
	cash.Value = Config.StartingCash
	player:SetAttribute("Ready", false)
	player:SetAttribute("Participating", false)
	player:SetAttribute("TowersPlaced", 0)
	player:SetAttribute("Damage", 0)
	player:SetAttribute("Kills", 0)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do setupPlayer(player) end

local function getPlayerByUserId(userId)
	for _, player in Players:GetPlayers() do if player.UserId == userId then return player end end
	return nil
end

local function getReadyPlayers()
	local ready = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Ready") and #ready < Config.MaxPlayers then table.insert(ready, player) end
	end
	return ready
end

local function updatePlayerCount()
	local count = 0
	for player in participants do if player.Parent then count += 1 end end
	gameState:SetAttribute("PlayerCount", count)
end

readyRemote.OnServerEvent:Connect(function(player)
	local state = gameState:GetAttribute("State")
	if state ~= "Waiting" and state ~= "Countdown" then
		notifyRemote:FireClient(player, "รอเข้าร่วมเกมรอบถัดไป")
		return
	end
	if not player:GetAttribute("Ready") and #getReadyPlayers() >= Config.MaxPlayers then
		notifyRemote:FireClient(player, "แมตช์นี้มีผู้เล่นครบแล้ว")
		return
	end
	player:SetAttribute("Ready", not player:GetAttribute("Ready"))
end)

local function distanceToSegment(point, a, b)
	local ab = b - a
	return (point - (a + ab * math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1))).Magnitude
end

local function canPlaceTower(position)
	if math.abs(position.X) > 113 or math.abs(position.Z) > 63 then return false, "วางป้อมภายในพื้นที่หญ้าเท่านั้น" end
	for _, path in activePaths do
		for i=1,#path-1 do
			if Routes.Distance(position,path[i],path[i+1]) < 10 then return false,"วางป้อมบนเส้นทางไม่ได้" end
		end
	end
	for _, tower in towers:GetChildren() do
		if tower.PrimaryPart and (tower.PrimaryPart.Position - position).Magnitude < Config.Footprint then return false, "ป้อมอยู่ใกล้กันเกินไป" end
	end
	return true
end

local function canTarget(towerData, enemy)
	local movement = enemy:GetAttribute("Movement")
	return towerData.Target == "Both" or towerData.Target == movement
end

local function awardEnemy(enemy, enemyData)
	-- Prevent memory leak: remove ledger after awarding rewards
	-- Weak table ensures old entries are GC'd automatically
	local ledger = damageLedgers[enemy]
	if not ledger then return end
	local totalDamage = 0
	for _, damage in ledger do totalDamage += damage end
	if totalDamage > 0 then
		for userId, damage in ledger do
			local player = getPlayerByUserId(userId)
			if player and participants[player] then
				local cash = player.leaderstats and player.leaderstats:FindFirstChild("Cash")
				if cash then cash.Value += math.max(1, math.round(enemyData.Reward * damage / totalDamage)) end
			end
		end
	end
	local lastHit = enemy:GetAttribute("LastHitUserId")
	local killer = lastHit and getPlayerByUserId(lastHit)
	if killer then killer:SetAttribute("Kills", (killer:GetAttribute("Kills") or 0) + 1) end
	-- Manual cleanup for weak table (optional, since __mode="k" does it)
	damageLedgers[enemy] = nil
end

local function damageEnemy(enemy, requestedDamage, owner)
	local health = enemy:GetAttribute("Health")
	if not health or health <= 0 or not enemy.Parent then return end
	local actualDamage = math.min(health, requestedDamage)
	local ledger = damageLedgers[enemy]
	if owner and ledger then
		ledger[owner.UserId] = (ledger[owner.UserId] or 0) + actualDamage
		owner:SetAttribute("Damage", math.round((owner:GetAttribute("Damage") or 0) + actualDamage))
		enemy:SetAttribute("LastHitUserId", owner.UserId)
	end
	enemy:SetAttribute("Health", math.max(0, health - requestedDamage))
end

local function showShot(origin, destination, color)
	local beam = makePart("Shot", Vector3.new(0.22, 0.22, (destination - origin).Magnitude), (origin + destination) / 2, color, Enum.Material.Neon, workspace)
	beam.CanCollide, beam.CanQuery = false, false
	beam.CFrame = CFrame.lookAt(beam.Position, destination)
	task.delay(0.08, function() if beam.Parent then beam:Destroy() end end)
end

local function attack(runtime, target, origin, owner)
	if not target.PrimaryPart then return end
	local targetPosition = target.PrimaryPart.Position
	showShot(origin, targetPosition, runtime.Color)
	TowerVisuals.Pulse(origin, runtime.Color, 0.9 + (runtime.VisualLevel or 1) * 0.25)
	if runtime.SplashRadius or runtime.SlowMultiplier then
		TowerVisuals.Pulse(targetPosition, runtime.Color, runtime.SplashRadius and 5 or 3)
	end
	damageEnemy(target, runtime.Damage, owner)
	if runtime.SplashRadius then
		for _, other in enemies:GetChildren() do
			if other ~= target and other.PrimaryPart and other:GetAttribute("Movement") == "Ground" and (other.PrimaryPart.Position - targetPosition).Magnitude <= runtime.SplashRadius then
				damageEnemy(other, runtime.Damage * 0.65, owner)
			end
		end
	end
	if runtime.SlowMultiplier and target.Parent then
		target:SetAttribute("SlowMultiplier", runtime.SlowMultiplier)
		target:SetAttribute("SlowUntil", workspace:GetServerTimeNow() + runtime.SlowDuration)
	end
end

local function createTower(position, owner, towerType, towerData)
	local model = Instance.new("Model")
	model.Name = towerType
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("OwnerName", owner.DisplayName)
	model:SetAttribute("TowerType", towerType)
	model:SetAttribute("Level", 1)
	model:SetAttribute("Paid", towerData.Cost)
	model:SetAttribute("Damage", towerData.Damage)
	model:SetAttribute("Range", towerData.Range)
	local pedestal = makePart("Base", Vector3.new(5, 2, 5), position + Vector3.new(0, 1, 0), Color3.fromRGB(70, 74, 82), Enum.Material.Slate, model)
	local head = makePart("Head", Vector3.new(3.4, 3.4, 3.4), position + Vector3.new(0, 3.7, 0), towerData.Color, Enum.Material.Metal, model)
	head.Shape = towerType == "Cannon" and Enum.PartType.Block or Enum.PartType.Ball
	local barrels = {}
	for index = 1, (towerType == "AntiAir" and 2 or 1) do
		local offset = towerType == "AntiAir" and (index == 1 and -0.75 or 0.75) or 0
		local barrel = makePart("Barrel", Vector3.new(0.65, 0.65, towerType == "Cannon" and 5 or 4), position + Vector3.new(offset, 3.7, -2.5), Color3.fromRGB(35, 42, 52), Enum.Material.Metal, model)
		table.insert(barrels, { Part = barrel, Offset = offset })
	end
	local runtime = table.clone(towerData)
	towerRuntime[model] = runtime
	model.PrimaryPart, model.Parent = pedestal, towers
	local visual = TowerVisuals.Build(model, head, towerType, towerData.Color, 1)
	model:GetAttributeChangedSignal("Level"):Connect(function()
		runtime.VisualLevel = model:GetAttribute("Level")
		visual = TowerVisuals.Build(model, head, towerType, towerData.Color, runtime.VisualLevel)
		TowerVisuals.Pulse(head.Position, towerData.Color, 8)
	end)
	owner:SetAttribute("TowersPlaced", (owner:GetAttribute("TowersPlaced") or 0) + 1)

	task.spawn(function()
		while model.Parent and gameState:GetAttribute("State") == "Playing" do
			local target, bestProgress = nil, -math.huge
			for _, enemy in enemies:GetChildren() do
				local root, health = enemy.PrimaryPart, enemy:GetAttribute("Health")
				if root and health and health > 0 and canTarget(runtime, enemy) and (root.Position - head.Position).Magnitude <= runtime.Range then
					local progress = enemy:GetAttribute("Progress") or 0
					if progress > bestProgress then target, bestProgress = enemy, progress end
				end
			end
			if target and target.PrimaryPart then
				local targetPosition = target.PrimaryPart.Position
				local flatTarget = Vector3.new(targetPosition.X, head.Position.Y, targetPosition.Z)
				head.CFrame = CFrame.lookAt(head.Position, flatTarget)
				for _, barrelInfo in barrels do barrelInfo.Part.CFrame = head.CFrame * CFrame.new(barrelInfo.Offset, 0, -2.5) end
				visual:Aim()
				attack(runtime, target, visual:Muzzle(), owner)
			end
			task.wait(runtime.Cooldown)
		end
	end)
end

-- Security fix (issue #1): เพิ่ม owner check ก่อนดำเนินการใดๆ
placeTowerRemote.OnServerEvent:Connect(function(player, towerType, requestedPosition)
	-- Prevent RemoteExploitation: ตรวจสอบว่าผู้เล่นอยู่ใน match และ state เป็น Playing
	if gameState:GetAttribute("State") ~= "Playing" or not participants[player] then
		notifyRemote:FireClient(player, "คุณไม่ได้อยู่ในแมตช์นี้")
		return
	end
	
	-- Security: Validate inputs (ป้องกัน type confusion attacks)
	if typeof(towerType) ~= "string" or typeof(requestedPosition) ~= "Vector3" then return end
	
	-- Security: ตรวจสอบ towerData ก่อนใช้ (ป้องกัน nil access)
	local towerData = Config.Towers[towerType]
	if not towerData then return end

	if typeof(towerType) ~= "string" or typeof(requestedPosition) ~= "Vector3" then return end
	local towerData = Config.Towers[towerType]
	if not towerData then return end
	if (player:GetAttribute("TowersPlaced") or 0) >= Config.MaxTowersPerPlayer then notifyRemote:FireClient(player, "วางป้อมครบจำนวนสูงสุดแล้ว") return end
	local cash = player.leaderstats and player.leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < towerData.Cost then notifyRemote:FireClient(player, "เงินไม่พอสำหรับ " .. towerData.Name) return end
	local position = Vector3.new(math.round(requestedPosition.X), 0, math.round(requestedPosition.Z))
	local allowed, reason = canPlaceTower(position)
	if not allowed then notifyRemote:FireClient(player, reason) return end
	cash.Value -= towerData.Cost
	createTower(position, player, towerType, towerData)
	notifyRemote:FireClient(player, "สร้าง " .. towerData.Name .. " สำเร็จ")
end)

towerActionRemote.OnServerEvent:Connect(function(player, action, tower)
	if typeof(action) ~= "string" or typeof(tower) ~= "Instance" or not tower:IsDescendantOf(towers) then return end
	if tower:GetAttribute("OwnerUserId") ~= player.UserId then notifyRemote:FireClient(player, "เฉพาะเจ้าของป้อมเท่านั้น") return end
	local cash = player.leaderstats and player.leaderstats:FindFirstChild("Cash")
	if not cash then return end
	if action == "Sell" then
		cash.Value += math.round((tower:GetAttribute("Paid") or 0) * Config.SellRefundRatio)
		player:SetAttribute("TowersPlaced", math.max(0, (player:GetAttribute("TowersPlaced") or 1) - 1))
		towerRuntime[tower] = nil
		tower:Destroy()
	elseif action == "Upgrade" then
		local level = tower:GetAttribute("Level") or 1
		if level >= Config.MaxTowerLevel then notifyRemote:FireClient(player, "ป้อมนี้เลเวลสูงสุดแล้ว") return end
		local baseData = Config.Towers[tower:GetAttribute("TowerType")]
		local cost = math.round(baseData.Cost * (0.65 + level * 0.35))
		if cash.Value < cost then notifyRemote:FireClient(player, "เงินไม่พอสำหรับอัปเกรด") return end
		cash.Value -= cost
		local runtime = towerRuntime[tower]
		runtime.Damage *= Config.UpgradeDamageMultiplier
		runtime.Range += Config.UpgradeRangePerLevel
		tower:SetAttribute("Level", level + 1)
		tower:SetAttribute("Paid", (tower:GetAttribute("Paid") or 0) + cost)
		tower:SetAttribute("Damage", math.round(runtime.Damage))
		tower:SetAttribute("Range", runtime.Range)
		notifyRemote:FireClient(player, "อัปเกรดเป็นเลเวล " .. (level + 1))
	end
end)

local function createEnemyModel(enemyType, data, spawnPosition)
	local template = data.Model and enemyTemplates and enemyTemplates:FindFirstChild(data.Model)
	if not template or not template:IsA("Model") then
		local fallback = Instance.new("Model")
		fallback.Name = enemyType
		local root = makePart("Root", Vector3.new(data.Size, data.Size, data.Size), spawnPosition, data.Color, data.Movement == "Air" and Enum.Material.Neon or Enum.Material.SmoothPlastic, fallback)
		root.Shape, root.CanCollide, fallback.PrimaryPart = Enum.PartType.Ball, false, root
		if data.Movement == "Air" then
			makePart("LeftWing", Vector3.new(6, 0.4, 2), root.Position + Vector3.new(-3.5, 0, 0), data.Color, Enum.Material.Neon, fallback)
			makePart("RightWing", Vector3.new(6, 0.4, 2), root.Position + Vector3.new(3.5, 0, 0), data.Color, Enum.Material.Neon, fallback)
		end
		return fallback, root
	end

	local model = template:Clone()
	model.Name = enemyType
	removeEmbeddedScripts(model)
	local root = model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChild("Torso", true) or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		model:Destroy()
		local fallbackData = table.clone(data)
		fallbackData.Model = nil
		return createEnemyModel(enemyType, fallbackData, spawnPosition)
	end
	model.PrimaryPart = root
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = descendant ~= root
		end
	end
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		if data.WalkAnimation then
			local animator = humanoid:FindFirstChildOfClass("Animator") or newInstance("Animator", "Animator", humanoid)
			local animation = newInstance("Animation", "WalkAnimation", model)
			animation.AnimationId = data.WalkAnimation
			task.defer(function()
				local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
				if ok then
					track.Looped = true
					track.Priority = Enum.AnimationPriority.Movement
					track:Play(0.2)
				end
			end)
		end
	end
	model:PivotTo(CFrame.new(spawnPosition))
	return model, root
end

local function createEnemy(enemyType, healthMultiplier, path, routeIndex)
	local data = Config.Enemies[enemyType]
	local maxHealth = math.round(data.Health * healthMultiplier)
	local altitude = data.Movement == "Air" and 12 or (data.Model and 3 or data.Size / 2)
	local model, root = createEnemyModel(enemyType, data, path[1] + Vector3.new(0, altitude, 0))
	model:SetAttribute("RouteIndex", routeIndex)
	model:SetAttribute("EnemyType", enemyType)
	model:SetAttribute("Movement", data.Movement)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Progress", 0)
	model:SetAttribute("SlowMultiplier", 1)
	local gui = newInstance("BillboardGui", "Health", root)
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop = UDim2.fromOffset(64, 10), Vector3.new(0, data.Size / 2 + 1.3, 0), true
	local healthBar = newInstance("Frame", "Bar", gui)
	healthBar.Size, healthBar.BackgroundColor3, healthBar.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(70, 210, 100), 0
	damageLedgers[model] = {}
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		healthBar.Size = UDim2.fromScale(math.max(0, health / maxHealth), 1)
		if health <= 0 and model.Parent then awardEnemy(model, data) model:Destroy() end
	end)
	model.Parent = enemies
	return model, data, altitude
end

RunService.Heartbeat:Connect(function(deltaTime)
	if gameState:GetAttribute("State") ~= "Playing" then return end
	for enemy, moveState in activeMoves do
		local health = enemy.Parent and enemy:GetAttribute("Health")
		if not health or health <= 0 then activeMoves[enemy] = nil continue end
		local target = moveState.Path[moveState.Waypoint] + Vector3.new(0, moveState.Altitude, 0)
		local root, offset = enemy.PrimaryPart, target - enemy.PrimaryPart.Position
		local multiplier = (enemy:GetAttribute("SlowUntil") or 0) > workspace:GetServerTimeNow() and enemy:GetAttribute("SlowMultiplier") or 1
		local step = moveState.Speed * multiplier * deltaTime
		if offset.Magnitude <= step then
			enemy:PivotTo(enemy:GetPivot() + offset)
			moveState.Waypoint += 1
			if moveState.Waypoint > #moveState.Path then
				activeMoves[enemy], damageLedgers[enemy] = nil, nil
				gameState:SetAttribute("BaseHealth", math.max(0, gameState:GetAttribute("BaseHealth") - moveState.BaseDamage))
				enemy:Destroy()
			end
		else
			enemy:PivotTo(CFrame.lookAt(root.Position + offset.Unit * step, target))
			enemy:SetAttribute("Progress", -(offset.Magnitude + Routes.Length(moveState.Path, moveState.Waypoint)))
		end
	end
end)

local function clearMatch()
	for _, child in enemies:GetChildren() do child:Destroy() end
	for _, child in towers:GetChildren() do child:Destroy() end
	table.clear(activeMoves)
	table.clear(damageLedgers)
	table.clear(towerRuntime)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Participating", false)
		player:SetAttribute("TowersPlaced", 0)
	end
	table.clear(participants)
	updatePlayerCount()
end

Players.PlayerRemoving:Connect(function(player)
	participants[player] = nil
	for _, tower in towers:GetChildren() do
		if tower:GetAttribute("OwnerUserId") == player.UserId then
			towerRuntime[tower] = nil
			tower:Destroy()
		end
	end
	updatePlayerCount()
end)

task.spawn(function()
	while true do
		rebuildRoutes()
		gameState:SetAttribute("State", "Waiting")
		gameState:SetAttribute("Status", "กด Ready เพื่อเริ่มเกม")
		gameState:SetAttribute("Wave", 0)
		gameState:SetAttribute("BaseHealth", Config.BaseHealth)
		repeat task.wait(0.5) until #getReadyPlayers() > 0

		gameState:SetAttribute("State", "Countdown")
		local cancelled = false
		for seconds = Config.LobbyCountdown, 1, -1 do
			if #getReadyPlayers() == 0 then cancelled = true break end
			gameState:SetAttribute("Status", "เกมเริ่มใน " .. seconds .. " วินาที")
			task.wait(1)
		end
		if cancelled then continue end

		for _, player in getReadyPlayers() do
			participants[player] = true
			player:SetAttribute("Participating", true)
			player:SetAttribute("Ready", false)
			player:SetAttribute("TowersPlaced", 0)
			player:SetAttribute("Damage", 0)
			player:SetAttribute("Kills", 0)
			player.leaderstats.Cash.Value = Config.StartingCash
		end
		updatePlayerCount()
		local participantCount = gameState:GetAttribute("PlayerCount")
		local healthMultiplier = 1 + 0.45 * (participantCount - 1)
		local countMultiplier = 1 + 0.20 * (participantCount - 1)
		gameState:SetAttribute("State", "Playing")

		for waveNumber = 1, totalWaves do
			local groups = Routes.Wave(waveNumber, Config)
			if gameState:GetAttribute("BaseHealth") <= 0 or gameState:GetAttribute("PlayerCount") <= 0 then break end
			gameState:SetAttribute("Wave", waveNumber)
			gameState:SetAttribute("Status", "เวฟ " .. waveNumber .. "/" .. totalWaves .. (waveNumber > 10 and " — ศัตรูเลือกเส้นทางตามแนวป้องกัน!" or waveNumber > 5 and " — หลายจุดเกิด!" or " กำลังมา!"))
			for _, group in groups do
				for _ = 1, math.ceil(group.Count * countMultiplier) do
					if gameState:GetAttribute("BaseHealth") <= 0 or gameState:GetAttribute("PlayerCount") <= 0 then break end
					spawnSequence += 1
					local routeIndex = Routes.Choose(activePaths, waveNumber, Config.Enemies[group.Type].Movement, towers, Config, spawnSequence)
					local path = activePaths[routeIndex]
					local enemy, data, altitude = createEnemy(group.Type, healthMultiplier * (1 + math.max(0, waveNumber-5)*0.08), path, routeIndex)
					activeMoves[enemy] = { Path = path, Waypoint = 2, Speed = data.Speed, BaseDamage = data.BaseDamage, Altitude = altitude }
					task.wait(group.Spacing)
				end
			end
			repeat task.wait(0.5) until #enemies:GetChildren() == 0 or gameState:GetAttribute("BaseHealth") <= 0 or gameState:GetAttribute("PlayerCount") <= 0
			if waveNumber < totalWaves and gameState:GetAttribute("BaseHealth") > 0 then
				for seconds = Config.TimeBetweenWaves, 1, -1 do gameState:SetAttribute("Status", "เวฟถัดไปใน " .. seconds .. " วินาที") task.wait(1) end
			end
		end

		gameState:SetAttribute("State", "Results")
		if gameState:GetAttribute("PlayerCount") <= 0 then
			gameState:SetAttribute("Status", "แมตช์จบ — ผู้เล่นออกจากเกมทั้งหมด")
		elseif gameState:GetAttribute("BaseHealth") > 0 then
			gameState:SetAttribute("Status", "ชนะแล้ว! ป้องกันฐานสำเร็จ")
		else
			gameState:SetAttribute("Status", "เกมจบ — ฐานถูกทำลาย")
		end
		task.wait(Config.ResultDuration)
		clearMatch()
	end
end)
