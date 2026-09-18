local GameConfig = {}

GameConfig.StartingCash = 650
GameConfig.BaseHealth = 20
GameConfig.TimeBetweenWaves = 7
GameConfig.Footprint = 7

GameConfig.Towers = {
	MachineGun = {
		Name = "Machine Gun", Cost = 120, Range = 28, Damage = 8, Cooldown = 0.28,
		Target = "Ground", Color = Color3.fromRGB(65, 150, 230),
	},
	AntiAir = {
		Name = "Anti-Air", Cost = 180, Range = 42, Damage = 24, Cooldown = 0.7,
		Target = "Air", Color = Color3.fromRGB(242, 174, 50),
	},
	Cannon = {
		Name = "Cannon", Cost = 260, Range = 34, Damage = 38, Cooldown = 1.6,
		Target = "Ground", SplashRadius = 12, Color = Color3.fromRGB(190, 78, 66),
	},
	Frost = {
		Name = "Frost", Cost = 210, Range = 30, Damage = 5, Cooldown = 0.9,
		Target = "Both", SlowMultiplier = 0.55, SlowDuration = 2.5, Color = Color3.fromRGB(100, 225, 240),
	},
}

GameConfig.Enemies = {
	Grunt = { Name = "Grunt", Movement = "Ground", Health = 50, Speed = 8, Reward = 18, BaseDamage = 1, Color = Color3.fromRGB(214, 76, 70), Size = 4 },
	Runner = { Name = "Runner", Movement = "Ground", Health = 32, Speed = 14, Reward = 22, BaseDamage = 1, Color = Color3.fromRGB(239, 198, 68), Size = 3.2 },
	Tank = { Name = "Tank", Movement = "Ground", Health = 240, Speed = 5, Reward = 55, BaseDamage = 3, Color = Color3.fromRGB(92, 100, 112), Size = 6 },
	Flyer = { Name = "Flyer", Movement = "Air", Health = 70, Speed = 11, Reward = 32, BaseDamage = 1, Color = Color3.fromRGB(164, 95, 225), Size = 4 },
	Boss = { Name = "Boss", Movement = "Ground", Health = 1400, Speed = 4.5, Reward = 350, BaseDamage = 8, Color = Color3.fromRGB(120, 35, 40), Size = 9 },
}

GameConfig.Waves = {
	{ { Type = "Grunt", Count = 7, Spacing = 0.9 } },
	{ { Type = "Grunt", Count = 7, Spacing = 0.65 }, { Type = "Runner", Count = 5, Spacing = 0.55 } },
	{ { Type = "Flyer", Count = 7, Spacing = 0.8 }, { Type = "Grunt", Count = 6, Spacing = 0.7 } },
	{ { Type = "Tank", Count = 4, Spacing = 1.2 }, { Type = "Runner", Count = 10, Spacing = 0.4 }, { Type = "Flyer", Count = 6, Spacing = 0.65 } },
	{ { Type = "Boss", Count = 1, Spacing = 1 }, { Type = "Flyer", Count = 10, Spacing = 0.55 }, { Type = "Tank", Count = 5, Spacing = 0.9 } },
}

GameConfig.Waypoints = {
	Vector3.new(-105, 1, -55), Vector3.new(-55, 1, -55), Vector3.new(-55, 1, 15),
	Vector3.new(5, 1, 15), Vector3.new(5, 1, -35), Vector3.new(65, 1, -35),
	Vector3.new(65, 1, 45), Vector3.new(110, 1, 45),
}

return GameConfig
