local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Visuals = {}
local dark = Color3.fromRGB(30, 39, 53)
local steel = Color3.fromRGB(89, 105, 123)

local function part(parent, name, size, cf, color, shape, neon)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanTouch = true, false, false
	p.Material = neon and Enum.Material.Neon or Enum.Material.Metal
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Visuals.Pulse(position, color, size)
	local p = part(workspace, "TowerPulse", Vector3.one * 0.4, CFrame.new(position), color, Enum.PartType.Ball, true)
	p.CanQuery, p.CastShadow, p.Transparency = false, false, 0.35
	TweenService:Create(p, TweenInfo.new(0.3), {Size = Vector3.one * size, Transparency = 1}):Play()
	Debris:AddItem(p, 0.35)
end

function Visuals.Build(model, head, towerType, color, level)
	local old = model:FindFirstChild("TowerDetails")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "TowerDetails", model
	local moving = {}
	local baseCF = model.PrimaryPart.CFrame
	local function fixed(name, size, offset, tint, shape, neon)
		return part(folder, name, size, baseCF * offset, tint, shape, neon)
	end
	local function movingPart(name, size, offset, tint, shape, neon)
		local p = part(folder, name, size, head.CFrame * offset, tint, shape, neon)
		table.insert(moving, {Part = p, Offset = offset})
		return p
	end
	head.Shape, head.Size, head.Color = Enum.PartType.Block, Vector3.new(2.6, 1.5, 2.5), dark
	for _, child in model:GetChildren() do
		if child.Name == "Barrel" then child.Transparency = 1 end
	end
	model.PrimaryPart.Size = Vector3.new(4.8, 1.2, 4.8)
	model.PrimaryPart.Color = dark
	fixed("Bearing", Vector3.new(0.6, 3.4, 3.4), CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi/2), steel, Enum.PartType.Cylinder)
	for _, x in {-1, 1} do
		for _, z in {-1, 1} do
			fixed("Foot", Vector3.new(1.1, 0.65, 1.1), CFrame.new(x*2, -0.25, z*2), steel)
		end
		movingPart("Armor", Vector3.new(0.35 + level*0.12, 1.5, 2.6), CFrame.new(x*1.45, 0, 0), color)
	end
	for i = 1, level do
		fixed("RankLight", Vector3.new(0.45, 0.22, 0.15), CFrame.new((i-(level+1)/2)*0.7, 0, -2.43), color, nil, true)
	end
	local muzzle = CFrame.new(0, 0, -4)
	if towerType == "MachineGun" then
		for i = 1, level + 1 do
			local x = (i-(level+2)/2)*0.5
			movingPart("GunTube", Vector3.new(0.32, 0.32, 3.5), CFrame.new(x, 0, -2.4), steel)
			movingPart("Muzzle", Vector3.new(0.42, 0.42, 0.35), CFrame.new(x, 0, -4.1), dark)
		end
		movingPart("AmmoBox", Vector3.new(1, 1.3, 1.5), CFrame.new(1.95, -0.1, 0.5), color)
		movingPart("Sight", Vector3.new(0.5, 0.35, 0.6), CFrame.new(0, 1, -0.4), color, nil, true)
	elseif towerType == "AntiAir" then
		for _, x in {-1, 1} do
			movingPart("Launcher", Vector3.new(1, 1+level*0.25, 2.8), CFrame.new(x*1.5, 0.5, -1), color)
			for i = 1, level do
				movingPart("RocketPort", Vector3.new(0.55, 0.3, 0.12), CFrame.new(x*1.5, (i-1)*0.4, -2.45), dark)
			end
		end
		movingPart("RadarMast", Vector3.new(0.2, 1.4, 0.2), CFrame.new(0, 1.3, 0.7), steel)
		movingPart("Radar", Vector3.new(1.7+level*0.25, 0.7, 0.25), CFrame.new(0, 2, 0.7)*CFrame.Angles(0, 0, 0.2), color)
		muzzle = CFrame.new(1.5, 0.5, -2.5)
	elseif towerType == "Cannon" then
		movingPart("Breech", Vector3.new(2, 1.9, 2.4), CFrame.new(0, 0.25, 0), color)
		movingPart("HeavyBarrel", Vector3.new(0.85+level*0.15, 0.85+level*0.15, 3.2), CFrame.new(0, 0.25, -2.4), steel)
		movingPart("MuzzleBrake", Vector3.new(1.6, 1.3, 0.6), CFrame.new(0, 0.25, -4), dark)
		movingPart("Bore", Vector3.new(0.7, 0.7, 0.04), CFrame.new(0, 0.25, -4.32), Color3.new(0.02,0.02,0.02))
		muzzle = CFrame.new(0, 0.25, -4.35)
	else
		head.Transparency = 1
		movingPart("Reactor", Vector3.new(1.6, 2.7+level*0.3, 1.6), CFrame.new(0, 0.4, 0)*CFrame.Angles(0, 0, math.pi/4), color, nil, true)
		for i = 1, level+2 do
			local angle = i*math.pi*2/(level+2)
			movingPart("CoolingFin", Vector3.new(0.4, 2.5, 0.65), CFrame.new(math.cos(angle)*1.6, 0.25, math.sin(angle)*1.6)*CFrame.Angles(0, -angle, 0), steel)
		end
		muzzle = CFrame.new(0, 1.6, 0)
	end
	if level >= 2 then
		movingPart("TopArmor", Vector3.new(2.8, 0.25, 1.8), CFrame.new(0, 1, 0.3), steel)
	end
	if level >= 3 then
		for _, x in {-1,1} do
			movingPart("ElitePowerCell", Vector3.new(0.35, 0.65, 1.4), CFrame.new(x*1.9, 0.6, 0.4), color, nil, true)
		end
	end
	local state = {}
	function state:Aim()
		for _, info in moving do info.Part.CFrame = head.CFrame * info.Offset end
	end
	function state:Muzzle()
		return (head.CFrame * muzzle).Position
	end
	return state
end
return Visuals

