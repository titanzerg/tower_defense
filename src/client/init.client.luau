local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Config = require(ReplicatedStorage.Shared.GameConfig)
local remotes = ReplicatedStorage:WaitForChild("TowerDefenseRemotes")
local gameState = ReplicatedStorage:WaitForChild("GameState")

local screenGui = Instance.new("ScreenGui")
screenGui.Name, screenGui.ResetOnSpawn, screenGui.Parent = "TowerDefenseUI", false, player:WaitForChild("PlayerGui")

local function addCorner(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, radius), guiObject
end

local function style(guiObject, color)
	guiObject.BackgroundColor3, guiObject.BorderSizePixel = color or Color3.fromRGB(19, 27, 42), 0
	guiObject.TextColor3, guiObject.Font = Color3.new(1, 1, 1), Enum.Font.GothamBold
	addCorner(guiObject, 9)
end

local function makeLabel(parent, size, position, labelText, textSize)
	local label = Instance.new("TextLabel")
	label.Size, label.Position, label.Text, label.TextSize = size, position, labelText, textSize
	style(label)
	label.BackgroundTransparency, label.Parent = 0.12, parent
	return label
end

local status = makeLabel(screenGui, UDim2.fromOffset(440, 48), UDim2.new(0.5, -220, 0, 18), "", 20)
local stats = makeLabel(screenGui, UDim2.fromOffset(330, 44), UDim2.fromOffset(18, 18), "", 17)
local toast = makeLabel(screenGui, UDim2.fromOffset(380, 42), UDim2.new(0.5, -190, 0.72, 0), "", 17)
toast.Visible = false

local roster = makeLabel(screenGui, UDim2.fromOffset(230, 130), UDim2.new(1, -248, 0, 18), "", 15)
roster.TextXAlignment, roster.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
roster.TextWrapped = true

local readyButton = Instance.new("TextButton")
readyButton.Size, readyButton.Position, readyButton.TextSize = UDim2.fromOffset(190, 52), UDim2.new(0.5, -95, 0, 78), 19
readyButton.Text = "READY"
style(readyButton, Color3.fromRGB(47, 176, 98))
readyButton.Parent = screenGui
readyButton.Activated:Connect(function() remotes.ToggleReady:FireServer() end)

local towerBar = Instance.new("Frame")
towerBar.Size, towerBar.Position = UDim2.fromOffset(660, 92), UDim2.new(0.5, -330, 1, -108)
towerBar.BackgroundColor3, towerBar.BackgroundTransparency, towerBar.BorderSizePixel = Color3.fromRGB(16, 23, 36), 0.08, 0
towerBar.Parent = screenGui
addCorner(towerBar, 14)
local layout = Instance.new("UIListLayout")
layout.FillDirection, layout.HorizontalAlignment, layout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
layout.Padding, layout.Parent = UDim.new(0, 9), towerBar

local towerOrder = { "MachineGun", "AntiAir", "Cannon", "Frost" }
local buttons = {}
local selectedTowerType = nil
local selectedTowerModel = nil
local placing = false

for _, towerType in towerOrder do
	local data = Config.Towers[towerType]
	local button = Instance.new("TextButton")
	button.Name, button.Size, button.TextSize = towerType, UDim2.fromOffset(150, 72), 15
	button.Text = string.format("%s  $%d\n%s | DMG %d", data.Name, data.Cost, data.Target, data.Damage)
	style(button, data.Color)
	button.Parent = towerBar
	buttons[towerType] = button
end

local towerPanel = makeLabel(screenGui, UDim2.fromOffset(270, 190), UDim2.new(1, -288, 0.5, -95), "", 16)
towerPanel.TextYAlignment, towerPanel.Visible = Enum.TextYAlignment.Top, false
local upgradeButton = Instance.new("TextButton")
upgradeButton.Size, upgradeButton.Position, upgradeButton.TextSize = UDim2.fromOffset(230, 42), UDim2.fromOffset(20, 92), 16
upgradeButton.Text = "อัปเกรด"
style(upgradeButton, Color3.fromRGB(48, 133, 214))
upgradeButton.Parent = towerPanel
local sellButton = Instance.new("TextButton")
sellButton.Size, sellButton.Position, sellButton.TextSize = UDim2.fromOffset(230, 42), UDim2.fromOffset(20, 140), 16
sellButton.Text = "ขายป้อม"
style(sellButton, Color3.fromRGB(190, 73, 65))
sellButton.Parent = towerPanel

local preview = Instance.new("Part")
preview.Name, preview.Size, preview.Anchored = "TowerPreview", Vector3.new(5, 0.4, 5), true
preview.CanCollide, preview.CanQuery = false, false
preview.Material, preview.Transparency, preview.Parent = Enum.Material.ForceField, 1, workspace
local rangePreview = Instance.new("Part")
rangePreview.Name, rangePreview.Shape, rangePreview.Anchored = "RangePreview", Enum.PartType.Cylinder, true
rangePreview.CanCollide, rangePreview.CanQuery = false, false
rangePreview.Material, rangePreview.Color, rangePreview.Transparency = Enum.Material.ForceField, Color3.fromRGB(100, 190, 255), 1
rangePreview.Parent = workspace

local function stopPlacing()
	placing, selectedTowerType = false, nil
	preview.Transparency, rangePreview.Transparency = 1, 1
	for towerType, button in buttons do button.BackgroundColor3 = Config.Towers[towerType].Color end
end

for towerType, button in buttons do
	button.Activated:Connect(function()
		if gameState:GetAttribute("State") ~= "Playing" or not player:GetAttribute("Participating") then return end
		if placing and selectedTowerType == towerType then stopPlacing() return end
		placing, selectedTowerType, selectedTowerModel = true, towerType, nil
		towerPanel.Visible = false
		preview.Color, preview.Transparency, rangePreview.Transparency = Config.Towers[towerType].Color, 0.4, 0.72
		for otherType, otherButton in buttons do otherButton.BackgroundColor3 = otherType == towerType and Color3.fromRGB(245, 180, 55) or Config.Towers[otherType].Color end
	end)
end

local function refreshTowerPanel()
	local tower = selectedTowerModel
	if not tower or not tower.Parent then towerPanel.Visible, selectedTowerModel = false, nil return end
	local towerType = tower:GetAttribute("TowerType")
	local data, level = Config.Towers[towerType], tower:GetAttribute("Level") or 1
	local isOwner = tower:GetAttribute("OwnerUserId") == player.UserId
	towerPanel.Text = string.format("%s  Lv.%d\nเจ้าของ: %s\nDMG %d   Range %d", data.Name, level, tower:GetAttribute("OwnerName") or "?", tower:GetAttribute("Damage") or data.Damage, tower:GetAttribute("Range") or data.Range)
	upgradeButton.Visible, sellButton.Visible = isOwner, isOwner
	if level >= Config.MaxTowerLevel then
		upgradeButton.Text, upgradeButton.AutoButtonColor = "เลเวลสูงสุด", false
	else
		local cost = math.round(data.Cost * (0.65 + level * 0.35))
		upgradeButton.Text, upgradeButton.AutoButtonColor = "อัปเกรด  $" .. cost, true
	end
	sellButton.Text = "ขาย  $" .. math.round((tower:GetAttribute("Paid") or 0) * Config.SellRefundRatio)
	towerPanel.Visible = true
end

upgradeButton.Activated:Connect(function()
	if selectedTowerModel then remotes.TowerAction:FireServer("Upgrade", selectedTowerModel) task.delay(0.15, refreshTowerPanel) end
end)
sellButton.Activated:Connect(function()
	if selectedTowerModel then remotes.TowerAction:FireServer("Sell", selectedTowerModel) end
	towerPanel.Visible, selectedTowerModel = false, nil
end)

RunService.RenderStepped:Connect(function()
	if not placing or not selectedTowerType then return end
	local hit = mouse.Hit.Position
	local position = Vector3.new(math.round(hit.X), 0.25, math.round(hit.Z))
	preview.Position = position
	local range = Config.Towers[selectedTowerType].Range
	rangePreview.Size = Vector3.new(0.18, range * 2, range * 2)
	rangePreview.CFrame = CFrame.new(position - Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
end)

local function refreshHud()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	stats.Text = string.format("$%d | ฐาน %d | เวฟ %d | ป้อม %d/%d", cash and cash.Value or 0, gameState:GetAttribute("BaseHealth") or 0, gameState:GetAttribute("Wave") or 0, player:GetAttribute("TowersPlaced") or 0, Config.MaxTowersPerPlayer)
	status.Text = gameState:GetAttribute("Status") or ""
	local state = gameState:GetAttribute("State")
	readyButton.Visible = state == "Waiting" or state == "Countdown"
	readyButton.Text = player:GetAttribute("Ready") and "READY ✓" or (state == "Countdown" and "เข้าร่วมรอบถัดไป" or "READY")
	readyButton.BackgroundColor3 = player:GetAttribute("Ready") and Color3.fromRGB(42, 122, 72) or Color3.fromRGB(47, 176, 98)
	towerBar.Visible = state == "Playing" and player:GetAttribute("Participating")
	if not towerBar.Visible then stopPlacing() end
end

local function refreshRoster()
	local lines = { "ผู้เล่นในเซิร์ฟเวอร์" }
	for _, other in Players:GetPlayers() do
		local marker = other:GetAttribute("Participating") and "เล่น" or (other:GetAttribute("Ready") and "พร้อม" or "รอ")
		table.insert(lines, string.format("%s — %s | DMG %d | K %d", other.DisplayName, marker, other:GetAttribute("Damage") or 0, other:GetAttribute("Kills") or 0))
	end
	roster.Text = table.concat(lines, "\n")
end

task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	cash:GetPropertyChangedSignal("Value"):Connect(refreshHud)
	while screenGui.Parent do refreshHud() refreshRoster() refreshTowerPanel() task.wait(0.5) end
end)
for _, attribute in { "BaseHealth", "Status", "Wave", "State" } do gameState:GetAttributeChangedSignal(attribute):Connect(refreshHud) end

local toastVersion = 0
remotes.Notify.OnClientEvent:Connect(function(message)
	toastVersion += 1
	local version = toastVersion
	toast.Text, toast.Visible = message, true
	task.delay(2, function() if version == toastVersion then toast.Visible = false end end)
end)

mouse.Button1Down:Connect(function()
	local mousePosition = UserInputService:GetMouseLocation()
	if #player.PlayerGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y) > 0 or UserInputService:GetFocusedTextBox() then return end
	if placing and selectedTowerType then
		remotes.PlaceTower:FireServer(selectedTowerType, preview.Position)
		stopPlacing()
		return
	end
	local target = mouse.Target
	local model = target and target:FindFirstAncestorOfClass("Model")
	if model and model.Parent == workspace:FindFirstChild("Towers") then
		selectedTowerModel = model
		refreshTowerPanel()
	else
		towerPanel.Visible, selectedTowerModel = false, nil
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape then stopPlacing() towerPanel.Visible, selectedTowerModel = false, nil end
end)
