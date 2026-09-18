local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Config = require(ReplicatedStorage.Shared.GameConfig)
local remotes = ReplicatedStorage:WaitForChild("TowerDefenseRemotes")
local gameState = ReplicatedStorage:WaitForChild("GameState")

local screenGui = Instance.new("ScreenGui")
screenGui.Name, screenGui.ResetOnSpawn, screenGui.Parent = "TowerDefenseUI", false, player:WaitForChild("PlayerGui")

local function makeLabel(parent, size, position, labelText, textSize)
	local label = Instance.new("TextLabel")
	label.Size, label.Position = size, position
	label.BackgroundColor3, label.BackgroundTransparency, label.BorderSizePixel = Color3.fromRGB(19, 27, 42), 0.12, 0
	label.TextColor3, label.Font, label.TextSize, label.Text = Color3.new(1, 1, 1), Enum.Font.GothamBold, textSize, labelText
	label.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 9), label
	return label
end

local status = makeLabel(screenGui, UDim2.fromOffset(390, 48), UDim2.new(0.5, -195, 0, 18), "", 20)
local stats = makeLabel(screenGui, UDim2.fromOffset(260, 44), UDim2.fromOffset(18, 18), "", 18)
local buildButton = Instance.new("TextButton")
buildButton.Size, buildButton.Position = UDim2.fromOffset(230, 66), UDim2.new(0.5, -115, 1, -88)
buildButton.BackgroundColor3, buildButton.TextColor3 = Color3.fromRGB(42, 129, 205), Color3.new(1, 1, 1)
buildButton.Font, buildButton.TextSize = Enum.Font.GothamBold, 19
buildButton.Text = string.format("สร้างป้อม  $%d\n[คลิกแล้วเลือกตำแหน่ง]", Config.Tower.Cost)
buildButton.Parent = screenGui
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius, buttonCorner.Parent = UDim.new(0, 12), buildButton
local toast = makeLabel(screenGui, UDim2.fromOffset(330, 42), UDim2.new(0.5, -165, 0.78, 0), "", 17)
toast.Visible = false

local placing = false
local preview = Instance.new("Part")
preview.Name, preview.Size, preview.Anchored = "TowerPreview", Vector3.new(5, 0.4, 5), true
preview.CanCollide, preview.CanQuery = false, false
preview.Material, preview.Color, preview.Transparency = Enum.Material.ForceField, Color3.fromRGB(80, 220, 120), 1
preview.Parent = workspace

local function refreshStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	stats.Text = string.format("$%d    ฐาน %d", cash and cash.Value or 0, gameState:GetAttribute("BaseHealth") or 0)
	status.Text = gameState:GetAttribute("Status") or ""
end

task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	cash:GetPropertyChangedSignal("Value"):Connect(refreshStats)
	refreshStats()
end)
gameState:GetAttributeChangedSignal("BaseHealth"):Connect(refreshStats)
gameState:GetAttributeChangedSignal("Status"):Connect(refreshStats)

local toastVersion = 0
remotes.Notify.OnClientEvent:Connect(function(message)
	toastVersion += 1
	local thisVersion = toastVersion
	toast.Text, toast.Visible = message, true
	task.delay(2, function() if toastVersion == thisVersion then toast.Visible = false end end)
end)

local function stopPlacing()
	placing, preview.Transparency = false, 1
	buildButton.BackgroundColor3 = Color3.fromRGB(42, 129, 205)
end

buildButton.Activated:Connect(function()
	placing = not placing
	preview.Transparency = placing and 0.45 or 1
	buildButton.BackgroundColor3 = placing and Color3.fromRGB(230, 151, 44) or Color3.fromRGB(42, 129, 205)
end)
mouse.Move:Connect(function()
	if placing then
		local position = mouse.Hit.Position
		preview.Position = Vector3.new(math.round(position.X), 0.25, math.round(position.Z))
	end
end)
mouse.Button1Down:Connect(function()
	if placing and not UserInputService:GetFocusedTextBox() then
		remotes.PlaceTower:FireServer(preview.Position)
		stopPlacing()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape then stopPlacing() end
end)
