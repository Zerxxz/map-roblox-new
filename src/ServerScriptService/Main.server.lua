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
	Lighting.Ambient = Color3.fromRGB(15, 15, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(25, 25, 30)
	Lighting.Brightness = 1
	Lighting.ClockTime = 0 -- malam
	Lighting.FogEnd = 80
	Lighting.FogStart = 5
	Lighting.FogColor = Color3.fromRGB(20, 20, 25)
	Lighting.GlobalShadows = true

	-- Atmosphere effect
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmos = Instance.new("Atmosphere")
		atmos.Density = 0.6
		atmos.Offset = 0.25
		atmos.Color = Color3.fromRGB(60, 60, 70)
		atmos.Decay = Color3.fromRGB(30, 30, 40)
		atmos.Glare = 0
		atmos.Haze = 2
		atmos.Parent = Lighting
	end

	-- ColorCorrection biar terasa "horror"
	if not Lighting:FindFirstChild("HorrorColor") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "HorrorColor"
		cc.Brightness = -0.15
		cc.Contrast = 0.15
		cc.Saturation = -0.35
		cc.TintColor = Color3.fromRGB(200, 220, 255)
		cc.Parent = Lighting
	end

	if not Lighting:FindFirstChild("HorrorBlur") then
		local b = Instance.new("BlurEffect")
		b.Name = "HorrorBlur"
		b.Size = 4
		b.Parent = Lighting
	end
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
