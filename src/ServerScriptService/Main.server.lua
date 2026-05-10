--!strict
-- Main.server.lua
-- Entry-point server. Menyatukan MapGenerator, Quest, Ghost, Puzzle, Alliance, Tool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("RemoteEvents"))

local MapGenerator  = require(ServerScriptService:WaitForChild("MapGenerator"))
local GhostSystem   = require(ServerScriptService:WaitForChild("GhostSystem"))
local QuestSystem   = require(ServerScriptService:WaitForChild("QuestSystem"))
local PuzzleSystem  = require(ServerScriptService:WaitForChild("PuzzleSystem"))
local AllianceSystem = require(ServerScriptService:WaitForChild("AllianceSystem"))
local ToolGiver     = require(ServerScriptService:WaitForChild("ToolGiver"))

print("[HauntedBuilding] Booting server...")

-- ===== LIGHTING & ATMOSPHERE =====
local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(55, 55, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 80)
	Lighting.Brightness = 2
	Lighting.ClockTime = 5.5
	Lighting.ExposureCompensation = 0.3
	Lighting.FogEnd = 260
	Lighting.FogStart = 40
	Lighting.FogColor = Color3.fromRGB(70, 75, 90)
	Lighting.GlobalShadows = true

	-- Atmosphere effect
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then existing:Destroy() end
	local atmos = Instance.new("Atmosphere")
	atmos.Density = 0.25
	atmos.Offset = 0.1
	atmos.Color = Color3.fromRGB(140, 150, 170)
	atmos.Decay = Color3.fromRGB(90, 95, 110)
	atmos.Glare = 0
	atmos.Haze = 0.8
	atmos.Parent = Lighting

	-- ColorCorrection biar terasa "horror" tapi tidak menggelapkan
	local oldCC = Lighting:FindFirstChild("HorrorColor")
	if oldCC then oldCC:Destroy() end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HorrorColor"
	cc.Brightness = 0
	cc.Contrast = 0.1
	cc.Saturation = -0.2
	cc.TintColor = Color3.fromRGB(220, 230, 245)
	cc.Parent = Lighting

	local oldBlur = Lighting:FindFirstChild("HorrorBlur")
	if oldBlur then oldBlur:Destroy() end
	local b = Instance.new("BlurEffect")
	b.Name = "HorrorBlur"
	b.Size = 0
	b.Parent = Lighting
end

-- ===== AMBIENT SOUNDS (server-owned, 3D global) =====
local function setupAmbientSounds()
	local folder = Instance.new("Folder")
	folder.Name = "AmbientSounds"
	folder.Parent = workspace

	local function newLoop(id: string, vol: number)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Looped = true
		s.Volume = vol
		s.Playing = true
		s.Parent = folder
		return s
	end

	newLoop(Config.Atmosphere.AmbientSoundId, 0.35)
	newLoop(Config.Atmosphere.HeartbeatSoundId, 0.12)

	-- Petir & bisikan random
	task.spawn(function()
		while true do
			task.wait(math.random(20, 60))
			local s = Instance.new("Sound")
			s.SoundId = Config.Atmosphere.ThunderSoundId
			s.Volume = 0.8
			s.Parent = folder
			s:Play()
			s.Ended:Connect(function() s:Destroy() end)
			-- Flash
			local cc = Lighting:FindFirstChild("HorrorColor")
			if cc and cc:IsA("ColorCorrectionEffect") then
				local orig = cc.Brightness
				cc.Brightness = 0.6
				task.wait(0.08)
				cc.Brightness = orig
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(math.random(15, 45))
			for _, p in ipairs(Players:GetPlayers()) do
				Remotes.AtmosphereCue:FireClient(p, "whisper")
			end
		end
	end)
end

-- ===== GENERATE MAP =====
setupLighting()
setupAmbientSounds()

local map = MapGenerator.generate()
print(string.format("[HauntedBuilding] Generated %d rooms.", #map.Rooms))

-- ===== INIT SUBSYSTEMS =====
AllianceSystem.init()
QuestSystem.init(map.Rooms, AllianceSystem)
PuzzleSystem.init(map.Rooms)
GhostSystem.init(map.Rooms)
ToolGiver.init()

-- ===== TELEPORT PEMAIN KE SPAWN SAAT SPAWN =====
local function teleportToStart(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp and hrp:IsA("BasePart") then
		hrp.CFrame = CFrame.new(map.SpawnPoint + Vector3.new(0, 4, 0))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		teleportToStart(char)
		Remotes.Notify:FireClient(player,
			"Kamu terdampar di gedung tua terkutuk. Temukan 5 Lampu Kuno dan selamatkan dirimu!",
			Color3.fromRGB(255, 210, 140)
		)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then teleportToStart(player.Character) end
	player.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		teleportToStart(char)
	end)
end

print("[HauntedBuilding] Server ready.")
