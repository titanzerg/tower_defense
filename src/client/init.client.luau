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

local function makeLabel(parent, size, position, labelText, textSize)
	local label = Instance.new("TextLabel")
	label.Size, label.Position = size, position
	label.BackgroundColor3, label.BackgroundTransparency, label.BorderSizePixel = Color3.fromRGB(19, 27, 42), 0.12, 0
	label.TextColor3, label.Font, label.TextSize, label.Text = Color3.new(1, 1, 1), Enum.Font.GothamBold, textSize, labelText
	label.Parent = parent
	addCorner(label, 9)
	return label
end

local status = makeLabel(screenGui, UDim2.fromOffset(420, 48), UDim2.new(0.5, -210, 0, 18), "", 20)
local stats = makeLabel(screenGui, UDim2.fromOffset(260, 44), UDim2.fromOffset(18, 18), "", 18)
local toast = makeLabel(screenGui, UDim2.fromOffset(360, 42), UDim2.new(0.5, -180, 0.73, 0), "", 17)
toast.Visible = false

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
local selectedTower = nil
local placing = false

for _, towerType in towerOrder do
	local data = Config.Towers[towerType]
	local button = Instance.new("TextButton")
	button.Name, button.Size = towerType, UDim2.fromOffset(150, 72)
	button.BackgroundColor3, button.TextColor3, button.BorderSizePixel = data.Color, Color3.new(1, 1, 1), 0
	button.Font, button.TextSize = Enum.Font.GothamBold, 15
	button.Text = string.format("%s  $%d\n%s | DMG %d", data.Name, data.Cost, data.Target, data.Damage)
	button.Parent = towerBar
	addCorner(button, 10)
	buttons[towerType] = button
end

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
	placing, selectedTower = false, nil
	preview.Transparency, rangePreview.Transparency = 1, 1
	for towerType, button in buttons do button.BackgroundColor3 = Config.Towers[towerType].Color end
end

for towerType, button in buttons do
	button.Activated:Connect(function()
		if placing and selectedTower == towerType then stopPlacing() return end
		placing, selectedTower = true, towerType
		preview.Color, preview.Transparency = Config.Towers[towerType].Color, 0.4
		rangePreview.Transparency = 0.72
		for otherType, otherButton in buttons do
			otherButton.BackgroundColor3 = otherType == towerType and Color3.fromRGB(245, 180, 55) or Config.Towers[otherType].Color
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not placing or not selectedTower then return end
	local hit = mouse.Hit.Position
	local position = Vector3.new(math.round(hit.X), 0.25, math.round(hit.Z))
	preview.Position = position
	local range = Config.Towers[selectedTower].Range
	rangePreview.Size = Vector3.new(0.18, range * 2, range * 2)
	rangePreview.CFrame = CFrame.new(position - Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
end)

local function refreshStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	stats.Text = string.format("$%d    ฐาน %d    เวฟ %d", cash and cash.Value or 0, gameState:GetAttribute("BaseHealth") or 0, gameState:GetAttribute("Wave") or 0)
	status.Text = gameState:GetAttribute("Status") or ""
end
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	cash:GetPropertyChangedSignal("Value"):Connect(refreshStats)
	refreshStats()
end)
for _, attribute in { "BaseHealth", "Status", "Wave" } do gameState:GetAttributeChangedSignal(attribute):Connect(refreshStats) end

local toastVersion = 0
remotes.Notify.OnClientEvent:Connect(function(message)
	toastVersion += 1
	local version = toastVersion
	toast.Text, toast.Visible = message, true
	task.delay(2, function() if version == toastVersion then toast.Visible = false end end)
end)

mouse.Button1Down:Connect(function()
	local mousePosition = UserInputService:GetMouseLocation()
	local isOverInterface = #player.PlayerGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y) > 0
	if placing and selectedTower and not isOverInterface and not UserInputService:GetFocusedTextBox() then
		remotes.PlaceTower:FireServer(selectedTower, preview.Position)
		stopPlacing()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape then stopPlacing() end
end)
