local GameConfig = {}

GameConfig.StartingCash = 350
GameConfig.BaseHealth = 20
GameConfig.TimeBetweenWaves = 7

GameConfig.Tower = { Cost = 150, Range = 32, Damage = 12, Cooldown = 0.65, Footprint = 7 }

GameConfig.Waves = {
	{ count = 6, health = 35, speed = 8, reward = 18, spacing = 1.0 },
	{ count = 9, health = 55, speed = 9, reward = 22, spacing = 0.85 },
	{ count = 12, health = 85, speed = 10, reward = 26, spacing = 0.75 },
	{ count = 15, health = 125, speed = 11, reward = 30, spacing = 0.65 },
	{ count = 1, health = 900, speed = 6, reward = 300, spacing = 1 },
}

GameConfig.Waypoints = {
	Vector3.new(-105, 1, -55), Vector3.new(-55, 1, -55), Vector3.new(-55, 1, 15),
	Vector3.new(5, 1, 15), Vector3.new(5, 1, -35), Vector3.new(65, 1, -35),
	Vector3.new(65, 1, 45), Vector3.new(110, 1, 45),
}

return GameConfig
