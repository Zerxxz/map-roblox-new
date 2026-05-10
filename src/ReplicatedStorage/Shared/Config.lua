--!strict
-- Config.lua
-- Pusat konfigurasi game. Ubah nilai di sini untuk tweaking tanpa menyentuh logic.

local Config = {}

-- ========= MAP =========
Config.Map = {
	Floors              = 3,      -- jumlah lantai gedung
	RoomsPerFloor       = 6,      -- ruangan per lantai
	RoomSize            = Vector3.new(28, 14, 28),
	WallThickness       = 1,
	CorridorWidth       = 8,
	Origin              = Vector3.new(0, 0, 0),
	WallColor           = Color3.fromRGB(110, 95, 80),
	FloorColor          = Color3.fromRGB(85, 70, 55),
	CeilingColor        = Color3.fromRGB(60, 52, 45),
	WallMaterial        = Enum.Material.Brick,
	FloorMaterial       = Enum.Material.WoodPlanks,
	CeilingMaterial     = Enum.Material.Concrete,
}

-- ========= QUEST =========
Config.Quest = {
	LanternCount        = 5,
	LanternColor        = Color3.fromRGB(255, 180, 70),
	LanternLightRange   = 14,
	LanternLightBrightness = 2,
	CompleteRewardMsg   = "Kamu berhasil keluar dari gedung terkutuk!",
}

-- ========= TOOL =========
Config.Tool = {
	FlashlightName      = "Flashlight",
	FlashlightRange     = 90,
	FlashlightAngle     = 60,
	FlashlightBrightness = 4,
	FlashlightColor     = Color3.fromRGB(255, 245, 220),
}

-- ========= GHOST =========
Config.Ghost = {
	JumpscareIntervalMin = 25,   -- detik
	JumpscareIntervalMax = 60,
	JumpscareDuration    = 2.0,
	HunterSpawnAfter     = 45,   -- hunter mulai muncul setelah sekian detik pemain join
	HunterSpeed          = 14,
	HunterDamage         = 35,
	HunterAttackRange    = 4,
	HunterAttackCooldown = 1.2,
	MaxHuntersPerServer  = 2,
	HunterSightRange     = 55,
}

-- ========= PUZZLE =========
Config.Puzzle = {
	LockedRoomsPerFloor  = 2,   -- berapa ruangan per lantai yang terkunci butuh puzzle
	CodeDigits           = 3,   -- 3 digit kode (0-9)
	HintsPerPuzzle       = 3,
}

-- ========= ALLIANCE =========
Config.Alliance = {
	MaxMembers           = 4,
	InviteTimeout        = 20,
	FriendlyFire         = false,
	ShareQuestProgress   = true,
}

-- ========= ATMOSPHERE =========
Config.Atmosphere = {
	AmbientSoundId       = "rbxassetid://9046862592", -- wind ambient (placeholder, boleh diganti)
	HeartbeatSoundId     = "rbxassetid://9125402735",
	WhisperSoundId       = "rbxassetid://5591815081",
	ThunderSoundId       = "rbxassetid://5987742857",
	JumpscareSoundId     = "rbxassetid://12222030",
	FootstepSoundId      = "rbxassetid://9113643652",
}

return Config
