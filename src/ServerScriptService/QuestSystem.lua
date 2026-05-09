--!strict
-- QuestSystem.lua
-- Quest: cari 5 Lampu Kuno tersebar di ruangan acak.
-- Progress per-pemain, opsional dibagi ke anggota aliansi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Utils = require(Shared:WaitForChild("Utils"))
local Remotes = require(Shared:WaitForChild("RemoteEvents"))

local QuestSystem = {}

local rng = Random.new()

-- progress[userId] = {collected = n}
local progress: {[number]: {collected: number}} = {}
local totalLanterns = Config.Quest.LanternCount
local lanternsFolder: Folder
local allianceRef -- di-inject oleh Main

-- Buat 1 model Lantern interaktif
local function createLantern(index: number, anchor: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "AncientLantern_" .. index

	local base = Utils.createPart({
		Name = "Base",
		Size = Vector3.new(1.2, 0.3, 1.2),
		Color = Color3.fromRGB(90, 60, 30),
		Material = Enum.Material.WoodPlanks,
		CFrame = CFrame.new(anchor),
	})
	base.Parent = model

	local glass = Utils.createPart({
		Name = "Glass",
		Size = Vector3.new(1, 1.6, 1),
		Color = Config.Quest.LanternColor,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CFrame = CFrame.new(anchor + Vector3.new(0, 1, 0)),
	})
	glass.Parent = model

	local cap = Utils.createPart({
		Name = "Cap",
		Size = Vector3.new(1.3, 0.25, 1.3),
		Color = Color3.fromRGB(80, 60, 30),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(anchor + Vector3.new(0, 1.9, 0)),
	})
	cap.Parent = model

	local light = Instance.new("PointLight")
	light.Range = Config.Quest.LanternLightRange
	light.Brightness = Config.Quest.LanternLightBrightness
	light.Color = Config.Quest.LanternColor
	light.Parent = glass

	-- Animasi berkedip halus
	task.spawn(function()
		while glass.Parent do
			light.Brightness = Config.Quest.LanternLightBrightness + rng:NextNumber(-0.4, 0.4)
			task.wait(0.2)
		end
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ambil Lampu Kuno"
	prompt.ObjectText = "Lampu Kuno"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	model.PrimaryPart = base
	return model
end

function QuestSystem.getProgress(player: Player): {collected: number, total: number}
	local p = progress[player.UserId]
	if not p then
		p = { collected = 0 }
		progress[player.UserId] = p
	end
	return { collected = p.collected, total = totalLanterns }
end

local function broadcastProgress(player: Player)
	local info = QuestSystem.getProgress(player)
	Remotes.QuestUpdate:FireClient(player, info)
end

local function giveProgressTo(player: Player)
	local p = progress[player.UserId]
	if not p then
		p = { collected = 0 }
		progress[player.UserId] = p
	end
	p.collected = math.min(totalLanterns, p.collected + 1)
	broadcastProgress(player)
	if p.collected >= totalLanterns then
		Remotes.QuestComplete:FireClient(player)
		Remotes.Notify:FireClient(player, Config.Quest.CompleteRewardMsg, Color3.fromRGB(120, 255, 120))
	end
end

local function handleLanternTaken(player: Player, lanternModel: Model)
	-- Beri progress ke pengambil
	giveProgressTo(player)
	Remotes.Notify:FireClient(player, "Kamu menemukan sebuah Lampu Kuno.", Color3.fromRGB(255, 200, 100))

	-- Jika dalam aliansi & berbagi progress, beri juga ke member lain
	if allianceRef and Config.Alliance.ShareQuestProgress then
		local mates = allianceRef.getAllies(player) or {}
		for _, mate in ipairs(mates) do
			if mate ~= player then
				giveProgressTo(mate)
				Remotes.Notify:FireClient(mate,
					string.format("Rekan aliansimu (%s) menemukan Lampu Kuno.", player.DisplayName or player.Name),
					Color3.fromRGB(200, 220, 255))
			end
		end
	end

	lanternModel:Destroy()
end

function QuestSystem.init(rooms: {any}, alliance: any?)
	allianceRef = alliance
	lanternsFolder = Instance.new("Folder")
	lanternsFolder.Name = "Lanterns"
	lanternsFolder.Parent = workspace

	-- Pilih `LanternCount` ruangan random yang berbeda untuk lokasi lampu
	local pool = {}
	for i, room in ipairs(rooms) do table.insert(pool, i) end
	Utils.shuffle(pool, rng)

	local count = math.min(totalLanterns, #pool)
	for i = 1, count do
		local room = rooms[pool[i]]
		local lantern = createLantern(i, room.LanternAnchor)
		lantern.Parent = lanternsFolder
		local prompt = lantern:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				handleLanternTaken(player, lantern)
			end)
		end
	end

	-- Initialize progress saat pemain join
	Players.PlayerAdded:Connect(function(player)
		progress[player.UserId] = { collected = 0 }
		player.CharacterAdded:Connect(function()
			task.wait(1)
			broadcastProgress(player)
		end)
	end)

	-- Hapus progress saat keluar
	Players.PlayerRemoving:Connect(function(player)
		progress[player.UserId] = nil
	end)

	-- Init untuk player yang sudah terlanjur ada
	for _, player in ipairs(Players:GetPlayers()) do
		progress[player.UserId] = progress[player.UserId] or { collected = 0 }
		task.delay(2, function() broadcastProgress(player) end)
	end
end

return QuestSystem
