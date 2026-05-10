--[[
	HauntedServer.server.lua
	============================================================
	SATU file Script untuk Server. Cara pakai:
	1. Di Roblox Studio, klik kanan pada ServerScriptService.
	2. Insert Object -> Script.
	3. Rename jadi "HauntedServer" (terserah, yang penting Script, bukan ModuleScript).
	4. Paste seluruh isi file ini ke dalamnya.
	5. Tekan Play. Lihat menu View -> Output untuk log.
	============================================================
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local RunService        = game:GetService("RunService")

print("[HauntedServer] script dimulai")

-- ============================================================
-- KONFIGURASI
-- ============================================================
local Config = {
	Map = {
		Floors            = 3,
		RoomsPerFloor     = 6,
		RoomSize          = Vector3.new(28, 14, 28),
		WallThickness     = 1,
		CorridorWidth     = 8,
		Origin            = Vector3.new(0, 0, 0),
		WallColor         = Color3.fromRGB(110, 95, 80),
		FloorColor        = Color3.fromRGB(85, 70, 55),
		CeilingColor      = Color3.fromRGB(60, 52, 45),
		WallMaterial      = Enum.Material.Brick,
		FloorMaterial     = Enum.Material.WoodPlanks,
		CeilingMaterial   = Enum.Material.Concrete,
	},
	Quest = {
		LanternCount           = 5,
		LanternColor           = Color3.fromRGB(255, 180, 70),
		LanternLightRange      = 14,
		LanternLightBrightness = 2,
	},
	Tool = {
		FlashlightName       = "Flashlight",
		FlashlightRange      = 90,
		FlashlightAngle      = 60,
		FlashlightBrightness = 4,
		FlashlightColor      = Color3.fromRGB(255, 245, 220),
	},
	Ghost = {
		JumpscareIntervalMin = 25,
		JumpscareIntervalMax = 60,
		JumpscareDuration    = 2.0,
		HunterSpawnAfter     = 45,
		HunterSpeed          = 14,
		HunterDamage         = 35,
		HunterAttackRange    = 4,
		HunterAttackCooldown = 1.2,
		MaxHuntersPerServer  = 2,
		HunterSightRange     = 55,
	},
	Puzzle = {
		LockedRoomsPerFloor = 2,
		CodeDigits          = 3,
		HintsPerPuzzle      = 3,
	},
	Alliance = {
		MaxMembers         = 4,
		InviteTimeout      = 20,
		ShareQuestProgress = true,
	},
	Atmosphere = {
		AmbientSoundId   = "rbxassetid://9046862592",
		HeartbeatSoundId = "rbxassetid://9125402735",
		WhisperSoundId   = "rbxassetid://5591815081",
		ThunderSoundId   = "rbxassetid://5987742857",
		JumpscareSoundId = "rbxassetid://12222030",
	},
}

local rng = Random.new(tick())

-- ============================================================
-- HELPERS
-- ============================================================
local function createPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function getHRP(player)
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- REMOTE EVENTS (otomatis dibuat di ReplicatedStorage/Remotes)
-- ============================================================
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function makeEvent(name)
	local e = remotesFolder:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = remotesFolder
	end
	return e
end

local function makeFunction(name)
	local f = remotesFolder:FindFirstChild(name)
	if not f then
		f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = remotesFolder
	end
	return f
end

local R = {
	QuestUpdate       = makeEvent("QuestUpdate"),
	QuestComplete     = makeEvent("QuestComplete"),
	TriggerJumpscare  = makeEvent("TriggerJumpscare"),
	HunterNear        = makeEvent("HunterNear"),
	PuzzlePrompt      = makeEvent("PuzzlePrompt"),
	PuzzleSubmit      = makeFunction("PuzzleSubmit"),
	AllianceInvite    = makeEvent("AllianceInvite"),
	AllianceRespond   = makeEvent("AllianceRespond"),
	AllianceRequest   = makeEvent("AllianceRequest"),
	AllianceUpdate    = makeEvent("AllianceUpdate"),
	AllianceLeave     = makeEvent("AllianceLeave"),
	AtmosphereCue     = makeEvent("AtmosphereCue"),
	Notify            = makeEvent("Notify"),
}

print("[HauntedServer] Remotes siap")

-- ============================================================
-- LIGHTING & ATMOSPHERE
-- ============================================================
local function setupLighting()
	-- Lebih terang tapi tetap dingin/mencekam
	Lighting.Ambient = Color3.fromRGB(55, 55, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 80)
	Lighting.Brightness = 2
	Lighting.ClockTime = 5.5         -- fajar redup, bukan tengah malam pekat
	Lighting.ExposureCompensation = 0.3
	Lighting.GlobalShadows = true

	-- Fog lebih tipis & jauh supaya ruangan tidak kabut total
	Lighting.FogEnd = 260
	Lighting.FogStart = 40
	Lighting.FogColor = Color3.fromRGB(70, 75, 90)

	local existingAtmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmos then existingAtmos:Destroy() end
	local atmos = Instance.new("Atmosphere")
	atmos.Density = 0.25             -- sebelumnya 0.6 (terlalu pekat)
	atmos.Offset = 0.1
	atmos.Color = Color3.fromRGB(140, 150, 170)
	atmos.Decay = Color3.fromRGB(90, 95, 110)
	atmos.Glare = 0
	atmos.Haze = 0.8
	atmos.Parent = Lighting

	local oldCC = Lighting:FindFirstChild("HorrorColor")
	if oldCC then oldCC:Destroy() end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HorrorColor"
	cc.Brightness = 0                -- jangan kurangi brightness lagi
	cc.Contrast = 0.1
	cc.Saturation = -0.2
	cc.TintColor = Color3.fromRGB(220, 230, 245)
	cc.Parent = Lighting

	local oldBlur = Lighting:FindFirstChild("HorrorBlur")
	if oldBlur then oldBlur:Destroy() end
	local b = Instance.new("BlurEffect")
	b.Name = "HorrorBlur"
	b.Size = 0                       -- tidak blur default, hanya saat hantu dekat
	b.Parent = Lighting
end

local function setupAmbientSounds()
	local folder = Instance.new("Folder")
	folder.Name = "AmbientSounds"
	folder.Parent = workspace

	local function newLoop(id, vol)
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

	task.spawn(function()
		while true do
			task.wait(math.random(20, 60))
			local s = Instance.new("Sound")
			s.SoundId = Config.Atmosphere.ThunderSoundId
			s.Volume = 0.8
			s.Parent = folder
			s:Play()
			s.Ended:Connect(function() s:Destroy() end)
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
				R.AtmosphereCue:FireClient(p, "whisper")
			end
		end
	end)
end

-- ============================================================
-- MAP GENERATOR
-- ============================================================
local function buildRoom(parent, center, size, hasDoorN, hasDoorS, hasDoorE, hasDoorW)
	local roomModel = Instance.new("Model")
	roomModel.Name = "Room"
	roomModel.Parent = parent

	local wallT = Config.Map.WallThickness
	local halfX = size.X / 2
	local halfY = size.Y / 2
	local halfZ = size.Z / 2
	local doorW = 5
	local doorH = 8

	local floor = createPart({
		Name = "Floor",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = CFrame.new(center + Vector3.new(0, -halfY, 0)),
		Color = Config.Map.FloorColor,
		Material = Config.Map.FloorMaterial,
	})
	floor.Parent = roomModel

	local ceiling = createPart({
		Name = "Ceiling",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = CFrame.new(center + Vector3.new(0, halfY, 0)),
		Color = Config.Map.CeilingColor,
		Material = Config.Map.CeilingMaterial,
	})
	ceiling.Parent = roomModel

	local function buildWall(axis, sign, hasDoor)
		local isX = axis == "X"
		local length = isX and size.X or size.Z
		local wallCenter
		if isX then
			wallCenter = center + Vector3.new(0, 0, sign * halfZ)
		else
			wallCenter = center + Vector3.new(sign * halfX, 0, 0)
		end
		local wallSize
		if isX then
			wallSize = Vector3.new(length, size.Y, wallT)
		else
			wallSize = Vector3.new(wallT, size.Y, length)
		end
		if not hasDoor then
			local w = createPart({
				Name = "Wall", Size = wallSize, CFrame = CFrame.new(wallCenter),
				Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
			})
			w.Parent = roomModel
			return
		end
		local sideLen = (length - doorW) / 2
		if isX then
			local left = createPart({
				Name = "Wall", Size = Vector3.new(sideLen, size.Y, wallT),
				CFrame = CFrame.new(wallCenter + Vector3.new(-(doorW/2 + sideLen/2), 0, 0)),
				Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
			})
			left.Parent = roomModel
			local right = createPart({
				Name = "Wall", Size = Vector3.new(sideLen, size.Y, wallT),
				CFrame = CFrame.new(wallCenter + Vector3.new(doorW/2 + sideLen/2, 0, 0)),
				Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
			})
			right.Parent = roomModel
			local topH = size.Y - doorH
			if topH > 0 then
				local top = createPart({
					Name = "WallTop", Size = Vector3.new(doorW, topH, wallT),
					CFrame = CFrame.new(wallCenter + Vector3.new(0, size.Y/2 - topH/2, 0)),
					Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
				})
				top.Parent = roomModel
			end
		else
			local left = createPart({
				Name = "Wall", Size = Vector3.new(wallT, size.Y, sideLen),
				CFrame = CFrame.new(wallCenter + Vector3.new(0, 0, -(doorW/2 + sideLen/2))),
				Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
			})
			left.Parent = roomModel
			local right = createPart({
				Name = "Wall", Size = Vector3.new(wallT, size.Y, sideLen),
				CFrame = CFrame.new(wallCenter + Vector3.new(0, 0, doorW/2 + sideLen/2)),
				Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
			})
			right.Parent = roomModel
			local topH = size.Y - doorH
			if topH > 0 then
				local top = createPart({
					Name = "WallTop", Size = Vector3.new(wallT, topH, doorW),
					CFrame = CFrame.new(wallCenter + Vector3.new(0, size.Y/2 - topH/2, 0)),
					Color = Config.Map.WallColor, Material = Config.Map.WallMaterial,
				})
				top.Parent = roomModel
			end
		end
	end

	buildWall("X",  1, hasDoorN)
	buildWall("X", -1, hasDoorS)
	buildWall("Z",  1, hasDoorE)
	buildWall("Z", -1, hasDoorW)

	local doorPart = nil
	local function placeDoor(axis, sign)
		local isX = axis == "X"
		local pos
		if isX then
			pos = center + Vector3.new(0, -halfY + doorH/2, sign * halfZ)
		else
			pos = center + Vector3.new(sign * halfX, -halfY + doorH/2, 0)
		end
		local sz = isX and Vector3.new(doorW - 0.2, doorH - 0.2, 0.5) or Vector3.new(0.5, doorH - 0.2, doorW - 0.2)
		local d = createPart({
			Name = "Door", Size = sz, CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(60, 40, 30), Material = Enum.Material.Wood,
			Transparency = 1, CanCollide = false,
		})
		d.Parent = roomModel
		return d
	end
	if hasDoorN then doorPart = placeDoor("X",  1) end
	if (not doorPart) and hasDoorS then doorPart = placeDoor("X", -1) end
	if (not doorPart) and hasDoorE then doorPart = placeDoor("Z",  1) end
	if (not doorPart) and hasDoorW then doorPart = placeDoor("Z", -1) end

	-- Lampu plafon: 2 titik untuk ruangan besar, lebih terang, kedipan sangat halus
	local function makeBulb(offsetX, offsetZ)
		local bulb = createPart({
			Name = "CeilingBulb", Size = Vector3.new(1.2, 0.4, 1.2),
			CFrame = CFrame.new(center + Vector3.new(offsetX, halfY - 1, offsetZ)),
			Color = Color3.fromRGB(255, 240, 210), Material = Enum.Material.Neon,
			Transparency = 0.1, CanCollide = false,
		})
		bulb.Parent = roomModel
		local pl = Instance.new("PointLight")
		pl.Range = 28                -- sebelumnya 14
		pl.Brightness = 2.2          -- sebelumnya 0.8
		pl.Color = Color3.fromRGB(255, 230, 190)
		pl.Shadows = false           -- biar lebih terang, tidak terblok perabot
		pl.Parent = bulb
		-- Kedipan halus: brightness bervariasi, tidak benar-benar mati
		task.spawn(function()
			while bulb.Parent do
				pl.Brightness = 1.9 + rng:NextNumber(0, 0.6)
				task.wait(rng:NextNumber(0.3, 1.2))
			end
		end)
		return bulb
	end

	makeBulb(-size.X * 0.25, 0)
	makeBulb( size.X * 0.25, 0)

	-- Jarang-jarang salah satu lampu sepenuhnya mati (efek horror singkat)
	task.spawn(function()
		while roomModel.Parent do
			task.wait(rng:NextNumber(20, 45))
			local bulbs = {}
			for _, c in ipairs(roomModel:GetChildren()) do
				if c.Name == "CeilingBulb" then table.insert(bulbs, c) end
			end
			if #bulbs > 0 then
				local b = bulbs[rng:NextInteger(1, #bulbs)]
				local l = b:FindFirstChildOfClass("PointLight")
				if l then
					l.Enabled = false
					task.wait(rng:NextNumber(0.5, 1.5))
					l.Enabled = true
				end
			end
		end
	end)

	return roomModel, floor, doorPart
end

local function buildCorridor(parent, from, to)
	local mid = (from + to) / 2
	local dir = to - from
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local angle = math.atan2(flat.X, flat.Z)
	local floor = createPart({
		Name = "CorridorFloor",
		Size = Vector3.new(Config.Map.CorridorWidth, 1, math.max(1, flat.Magnitude)),
		CFrame = CFrame.new(Vector3.new(mid.X, from.Y, mid.Z)) * CFrame.Angles(0, angle, 0),
		Color = Config.Map.FloorColor, Material = Config.Map.FloorMaterial,
	})
	floor.Parent = parent
end

local function buildStairs(parent, bottom, top)
	local mid = (bottom + top) / 2
	local dir = top - bottom
	local len = dir.Magnitude
	local angle = math.atan2(dir.X, dir.Z)
	local pitch = math.atan2(dir.Y, Vector3.new(dir.X, 0, dir.Z).Magnitude)
	local slab = createPart({
		Name = "Stairs",
		Size = Vector3.new(Config.Map.CorridorWidth, 1, len),
		CFrame = CFrame.new(mid) * CFrame.Angles(0, angle, 0) * CFrame.Angles(-pitch, 0, 0),
		Color = Color3.fromRGB(60, 50, 40), Material = Enum.Material.WoodPlanks,
	})
	slab.Parent = parent
end

local function generateMap()
	local mapModel = Instance.new("Model")
	mapModel.Name = "HauntedBuilding"
	mapModel.Parent = workspace

	local roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = mapModel
	local corridorsFolder = Instance.new("Folder")
	corridorsFolder.Name = "Corridors"
	corridorsFolder.Parent = mapModel

	local rooms = {}
	local floorHeight = Config.Map.RoomSize.Y + 2
	local cellSpacingX = Config.Map.RoomSize.X + 6
	local cellSpacingZ = Config.Map.RoomSize.Z + 6
	local roomsPerFloor = Config.Map.RoomsPerFloor

	for floorIdx = 1, Config.Map.Floors do
		local yBase = Config.Map.Origin.Y + (floorIdx - 1) * floorHeight + Config.Map.RoomSize.Y / 2
		local prevCenter = nil
		for ri = 1, roomsPerFloor do
			local gx = ri
			local gz = ((floorIdx + ri) % 2 == 0) and 1 or 2
			local center = Vector3.new(
				Config.Map.Origin.X + (gx - 1) * cellSpacingX,
				yBase,
				Config.Map.Origin.Z + (gz - 1) * cellSpacingZ
			)
			local hasDoorW = ri > 1
			local hasDoorE = ri < roomsPerFloor
			local hasDoorN = (gz == 1)
			local hasDoorS = (gz == 2)

			local roomModel, floorPart, doorPart = buildRoom(
				roomsFolder, center, Config.Map.RoomSize,
				hasDoorN, hasDoorS, hasDoorE, hasDoorW
			)
			roomModel.Name = string.format("Room_F%d_R%d", floorIdx, ri)

			local room = {
				Index = #rooms + 1,
				Floor = floorIdx,
				Center = center,
				FloorPart = floorPart,
				Model = roomModel,
				IsLocked = false,
				DoorPart = doorPart,
				LanternAnchor = center + Vector3.new(
					rng:NextNumber(-Config.Map.RoomSize.X/2 + 3, Config.Map.RoomSize.X/2 - 3),
					-Config.Map.RoomSize.Y/2 + 3,
					rng:NextNumber(-Config.Map.RoomSize.Z/2 + 3, Config.Map.RoomSize.Z/2 - 3)
				),
				GhostSpawn = center + Vector3.new(
					rng:NextNumber(-Config.Map.RoomSize.X/2 + 2, Config.Map.RoomSize.X/2 - 2),
					-Config.Map.RoomSize.Y/2 + 3,
					rng:NextNumber(-Config.Map.RoomSize.Z/2 + 2, Config.Map.RoomSize.Z/2 - 2)
				),
			}
			table.insert(rooms, room)

			if prevCenter then
				buildCorridor(corridorsFolder,
					prevCenter + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0),
					center + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0)
				)
			end
			prevCenter = center
		end

		if floorIdx < Config.Map.Floors then
			local lastOfThisFloor = rooms[#rooms]
			local firstNextCenter = Vector3.new(Config.Map.Origin.X, yBase + floorHeight, Config.Map.Origin.Z)
			buildStairs(corridorsFolder,
				lastOfThisFloor.Center + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0),
				firstNextCenter + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0)
			)
		end
	end

	local spawnPoint = rooms[1].Center + Vector3.new(0, -Config.Map.RoomSize.Y/2 + 4, 0)

	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "BuildingSpawn"
	spawnLoc.Size = Vector3.new(6, 1, 6)
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Neutral = true
	spawnLoc.Transparency = 1
	spawnLoc.TopSurface = Enum.SurfaceType.Smooth
	spawnLoc.Position = spawnPoint
	spawnLoc.Parent = mapModel

	return { Model = mapModel, Rooms = rooms, SpawnPoint = spawnPoint }
end

-- ============================================================
-- QUEST SYSTEM
-- ============================================================
local questProgress = {} -- [userId] = collected
local lanternsFolder

local allianceGetAllies -- forward-declared

local function broadcastQuest(player)
	R.QuestUpdate:FireClient(player, {
		collected = questProgress[player.UserId] or 0,
		total     = Config.Quest.LanternCount,
	})
end

local function giveQuestProgress(player)
	questProgress[player.UserId] = math.min(Config.Quest.LanternCount, (questProgress[player.UserId] or 0) + 1)
	broadcastQuest(player)
	if questProgress[player.UserId] >= Config.Quest.LanternCount then
		R.QuestComplete:FireClient(player)
		R.Notify:FireClient(player, "Kamu berhasil keluar dari gedung terkutuk!", Color3.fromRGB(120, 255, 120))
	end
end

local function createLantern(index, anchor)
	local model = Instance.new("Model")
	model.Name = "AncientLantern_" .. index

	local base = createPart({
		Name = "Base", Size = Vector3.new(1.2, 0.3, 1.2),
		Color = Color3.fromRGB(90, 60, 30), Material = Enum.Material.WoodPlanks,
		CFrame = CFrame.new(anchor),
	})
	base.Parent = model

	local glass = createPart({
		Name = "Glass", Size = Vector3.new(1, 1.6, 1),
		Color = Config.Quest.LanternColor, Material = Enum.Material.Neon,
		Transparency = 0.25, CanCollide = false,
		CFrame = CFrame.new(anchor + Vector3.new(0, 1, 0)),
	})
	glass.Parent = model

	local cap = createPart({
		Name = "Cap", Size = Vector3.new(1.3, 0.25, 1.3),
		Color = Color3.fromRGB(80, 60, 30), Material = Enum.Material.Metal,
		CFrame = CFrame.new(anchor + Vector3.new(0, 1.9, 0)),
	})
	cap.Parent = model

	local light = Instance.new("PointLight")
	light.Range = Config.Quest.LanternLightRange
	light.Brightness = Config.Quest.LanternLightBrightness
	light.Color = Config.Quest.LanternColor
	light.Parent = glass

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
	return model, prompt
end

local function initQuest(rooms)
	lanternsFolder = Instance.new("Folder")
	lanternsFolder.Name = "Lanterns"
	lanternsFolder.Parent = workspace

	local pool = {}
	for i = 1, #rooms do table.insert(pool, i) end
	shuffle(pool)
	local count = math.min(Config.Quest.LanternCount, #pool)
	for i = 1, count do
		local room = rooms[pool[i]]
		local lantern, prompt = createLantern(i, room.LanternAnchor)
		lantern.Parent = lanternsFolder
		prompt.Triggered:Connect(function(player)
			giveQuestProgress(player)
			R.Notify:FireClient(player, "Kamu menemukan sebuah Lampu Kuno.", Color3.fromRGB(255, 200, 100))
			if Config.Alliance.ShareQuestProgress and allianceGetAllies then
				for _, mate in ipairs(allianceGetAllies(player)) do
					if mate ~= player then
						giveQuestProgress(mate)
						R.Notify:FireClient(mate,
							string.format("Rekan aliansimu (%s) menemukan Lampu Kuno.", player.DisplayName or player.Name),
							Color3.fromRGB(200, 220, 255))
					end
				end
			end
			lantern:Destroy()
		end)
	end
	print(string.format("[HauntedServer] %d Lampu Kuno ditempatkan", count))
end

-- ============================================================
-- ALLIANCE SYSTEM
-- ============================================================
local alliances = {}
local playerToAlliance = {}
local pendingInvites = {}
local allianceCounter = 0

local function memberListOf(id)
	local out = {}
	local a = alliances[id]
	if not a then return out end
	for uid, _ in pairs(a.members) do
		local p = Players:GetPlayerByUserId(uid)
		if p then table.insert(out, p) end
	end
	return out
end

local function broadcastAlliance(id)
	local a = alliances[id]
	if not a then return end
	local names, ids = {}, {}
	for uid, _ in pairs(a.members) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			table.insert(names, p.DisplayName or p.Name)
			table.insert(ids, uid)
		end
	end
	for _, m in ipairs(memberListOf(id)) do
		R.AllianceUpdate:FireClient(m, {
			allianceId = id, leader = a.leader,
			memberNames = names, memberIds = ids,
		})
	end
end

local function createAlliance(leader)
	allianceCounter = allianceCounter + 1
	local id = "A" .. tostring(allianceCounter)
	alliances[id] = { leader = leader.UserId, members = { [leader.UserId] = true } }
	playerToAlliance[leader.UserId] = id
	broadcastAlliance(id)
	return id
end

local function removeFromAlliance(player)
	local id = playerToAlliance[player.UserId]
	if not id then return end
	local a = alliances[id]
	if not a then
		playerToAlliance[player.UserId] = nil
		return
	end
	a.members[player.UserId] = nil
	playerToAlliance[player.UserId] = nil
	local remaining = 0
	for _ in pairs(a.members) do remaining = remaining + 1 end
	if remaining == 0 then
		alliances[id] = nil
	else
		if a.leader == player.UserId then
			for uid, _ in pairs(a.members) do a.leader = uid; break end
		end
		broadcastAlliance(id)
	end
	R.AllianceUpdate:FireClient(player, { allianceId = nil, leader = nil, memberNames = {}, memberIds = {} })
end

allianceGetAllies = function(player)
	local id = playerToAlliance[player.UserId]
	if not id then return { player } end
	return memberListOf(id)
end

R.AllianceRequest.OnServerEvent:Connect(function(from, targetName)
	if typeof(targetName) ~= "string" then return end
	local target = Players:FindFirstChild(targetName)
	if not target or target == from then
		R.Notify:FireClient(from, "Target aliansi tidak ditemukan.", Color3.fromRGB(255, 120, 120))
		return
	end
	if playerToAlliance[target.UserId] then
		R.Notify:FireClient(from, (target.DisplayName or target.Name) .. " sudah di aliansi lain.", Color3.fromRGB(255, 180, 120))
		return
	end
	local fromId = playerToAlliance[from.UserId]
	if not fromId then fromId = createAlliance(from) end
	pendingInvites[target.UserId] = { from = from.UserId, ts = tick() }
	R.AllianceInvite:FireClient(target, {
		fromUserId = from.UserId,
		fromName = from.DisplayName or from.Name,
		allianceId = fromId,
	})
	R.Notify:FireClient(from, "Undangan dikirim ke " .. (target.DisplayName or target.Name), Color3.fromRGB(180, 220, 255))
end)

R.AllianceRespond.OnServerEvent:Connect(function(target, payload)
	if typeof(payload) ~= "table" then return end
	local fromUserId = payload.fromUserId
	local accept = payload.accept
	if typeof(fromUserId) ~= "number" then return end
	local invite = pendingInvites[target.UserId]
	if not invite or invite.from ~= fromUserId then return end
	if tick() - invite.ts > Config.Alliance.InviteTimeout then
		pendingInvites[target.UserId] = nil
		R.Notify:FireClient(target, "Undangan kadaluarsa.", Color3.fromRGB(255, 180, 120))
		return
	end
	pendingInvites[target.UserId] = nil
	local fromPlayer = Players:GetPlayerByUserId(fromUserId)
	if not fromPlayer then return end
	if not accept then
		R.Notify:FireClient(fromPlayer, (target.DisplayName or target.Name) .. " menolak aliansi.", Color3.fromRGB(255, 160, 160))
		return
	end
	local aid = playerToAlliance[fromUserId] or createAlliance(fromPlayer)
	local a = alliances[aid]
	local count = 0
	for _ in pairs(a.members) do count = count + 1 end
	if count >= Config.Alliance.MaxMembers then
		R.Notify:FireClient(target, "Aliansi penuh.", Color3.fromRGB(255, 180, 120))
		return
	end
	a.members[target.UserId] = true
	playerToAlliance[target.UserId] = aid
	broadcastAlliance(aid)
	R.Notify:FireClient(target, "Bergabung dengan aliansi!", Color3.fromRGB(160, 255, 160))
	R.Notify:FireClient(fromPlayer, (target.DisplayName or target.Name) .. " bergabung.", Color3.fromRGB(160, 255, 160))
end)

R.AllianceLeave.OnServerEvent:Connect(function(player)
	removeFromAlliance(player)
	R.Notify:FireClient(player, "Kamu keluar dari aliansi.", Color3.fromRGB(200, 200, 200))
end)

Players.PlayerRemoving:Connect(function(p)
	removeFromAlliance(p)
	pendingInvites[p.UserId] = nil
end)

-- ============================================================
-- PUZZLE SYSTEM
-- ============================================================
local puzzleById = {}

local function generateCode(digits)
	local s = ""
	for i = 1, digits do s = s .. tostring(rng:NextInteger(0, 9)) end
	return s
end

local function generateHints(answer, count)
	local hints = {}
	local digits = {}
	for i = 1, #answer do digits[i] = tonumber(string.sub(answer, i, i)) end
	local posNames = {"pertama", "kedua", "ketiga", "keempat", "kelima"}
	local templates = {
		function(i, d) return string.format("Angka %s adalah %d.", posNames[i], d) end,
		function(i, d)
			if d == 0 then return string.format("Angka %s tidak ada (kosong).", posNames[i]) end
			return string.format("Angka %s = %d kali sesuatu yang sederhana.", posNames[i], d)
		end,
		function(i, d)
			local parity = (d % 2 == 0) and "genap" or "ganjil"
			return string.format("Angka %s adalah bilangan %s.", posNames[i], parity)
		end,
	}
	local usedPos = {}
	for _ = 1, count do
		local pos
		for _ = 1, 10 do
			pos = rng:NextInteger(1, #answer)
			if not usedPos[pos] then break end
		end
		usedPos[pos] = true
		local t = templates[rng:NextInteger(1, #templates)]
		table.insert(hints, t(pos, digits[pos]))
	end
	return hints
end

local function createHintBoard(parent, pos, text)
	local board = createPart({
		Name = "HintBoard", Size = Vector3.new(6, 3, 0.3),
		Color = Color3.fromRGB(40, 30, 20), Material = Enum.Material.WoodPlanks,
		CFrame = CFrame.new(pos),
	})
	board.Parent = parent
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.CanvasSize = Vector2.new(600, 300)
	sg.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(220, 200, 150)
	label.TextSize = 36
	label.TextWrapped = true
	label.Font = Enum.Font.Antique
	label.Parent = sg
end

local function lockDoor(door)
	door.Transparency = 0
	door.CanCollide = true
	door.Color = Color3.fromRGB(60, 40, 30)
	door.Material = Enum.Material.Wood
end

local function unlockDoor(door)
	task.spawn(function()
		local start = door.CFrame
		for i = 1, 20 do
			door.CFrame = start + Vector3.new(0, i * 0.3, 0)
			task.wait(0.03)
		end
		door.CanCollide = false
		door.Transparency = 1
	end)
end

local function createCodePanel(door, puzzleId)
	local panel = createPart({
		Name = "CodePanel", Size = Vector3.new(1.5, 2, 0.3),
		Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal,
		CFrame = door.CFrame * CFrame.new(2, 0, 0),
	})
	panel.Parent = door.Parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Masukkan Kode"
	prompt.ObjectText = "Panel Kunci"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	prompt.Triggered:Connect(function(player)
		local data = puzzleById[puzzleId]
		if not data or data.solved then return end
		R.PuzzlePrompt:FireClient(player, puzzleId, data.hints)
	end)
end

local function initPuzzles(rooms)
	local byFloor = {}
	for _, r in ipairs(rooms) do
		byFloor[r.Floor] = byFloor[r.Floor] or {}
		table.insert(byFloor[r.Floor], r)
	end
	local counter = 0
	for _, list in pairs(byFloor) do
		shuffle(list)
		local n = math.min(Config.Puzzle.LockedRoomsPerFloor, #list)
		for i = 1, n do
			local room = list[i]
			if room.DoorPart then
				counter = counter + 1
				local pid = "puzzle_" .. counter
				local answer = generateCode(Config.Puzzle.CodeDigits)
				local hints = generateHints(answer, Config.Puzzle.HintsPerPuzzle)
				room.IsLocked = true
				lockDoor(room.DoorPart)
				puzzleById[pid] = { answer = answer, hints = hints, door = room.DoorPart, solved = false }

				local others = {}
				for _, r in ipairs(rooms) do
					if r ~= room then table.insert(others, r) end
				end
				shuffle(others)
				for h = 1, math.min(#hints, #others) do
					local place = others[h]
					createHintBoard(place.Model,
						place.Center + Vector3.new(
							rng:NextNumber(-Config.Map.RoomSize.X/2 + 1, Config.Map.RoomSize.X/2 - 1),
							0,
							Config.Map.RoomSize.Z/2 - 1
						),
						string.format("[Puzzle %s]\n%s", pid, hints[h])
					)
				end
				createCodePanel(room.DoorPart, pid)
			end
		end
	end
	R.PuzzleSubmit.OnServerInvoke = function(player, puzzleId, answer)
		if typeof(puzzleId) ~= "string" or typeof(answer) ~= "string" then return false end
		local data = puzzleById[puzzleId]
		if not data then return false end
		if data.solved then return true end
		if answer == data.answer then
			data.solved = true
			unlockDoor(data.door)
			R.Notify:FireAllClients(
				string.format("Pintu %s berhasil dibuka oleh %s!", puzzleId, player.DisplayName or player.Name),
				Color3.fromRGB(120, 255, 160)
			)
			return true
		end
		return false
	end
	print(string.format("[HauntedServer] %d puzzle dibuat", counter))
end

-- ============================================================
-- GHOST SYSTEM
-- ============================================================
local ghostsFolder
local activeHunters = {}

local function buildGhostModel(name, isHunter)
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Massless = true
	root.Parent = model

	local torso = createPart({
		Name = "Torso", Size = Vector3.new(2, 2, 1),
		Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.ForceField,
		Transparency = 0.35, CanCollide = false,
	})
	torso.Massless = true
	torso.Anchored = false
	torso.Parent = model

	local head = createPart({
		Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2),
		Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.ForceField,
		Transparency = 0.2, CanCollide = false,
	})
	head.Massless = true
	head.Anchored = false
	head.Shape = Enum.PartType.Ball
	head.Parent = model

	for _, off in ipairs({-0.3, 0.3}) do
		local eye = createPart({
			Name = "Eye", Size = Vector3.new(0.2, 0.2, 0.2),
			Color = Color3.fromRGB(255, 30, 30), Material = Enum.Material.Neon,
			CanCollide = false, Transparency = 0,
		})
		eye.Massless = true
		eye.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = head; w.Part1 = eye
		eye.CFrame = head.CFrame * CFrame.new(off, 0.1, -0.55)
		w.Parent = eye
	end

	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = root; w1.Part1 = torso
	torso.CFrame = root.CFrame
	w1.Parent = torso

	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = torso; w2.Part1 = head
	head.CFrame = torso.CFrame * CFrame.new(0, 1.6, 0)
	w2.Parent = head

	local pl = Instance.new("PointLight")
	pl.Range = 10
	pl.Brightness = 1.5
	pl.Color = Color3.fromRGB(150, 0, 0)
	pl.Parent = head

	model.PrimaryPart = root

	if isHunter then
		local h = Instance.new("Humanoid")
		h.WalkSpeed = Config.Ghost.HunterSpeed
		h.MaxHealth = 500
		h.Health = 500
		h.HipHeight = 2
		h.AutoRotate = true
		h.BreakJointsOnDeath = false
		h.DisplayName = "Hantu Pengejar"
		h.Parent = model
	end

	return model
end

local function spawnJumpscareFor(player)
	local hrp = getHRP(player)
	if not hrp then return end
	local offsetAngle = rng:NextNumber(-0.4, 0.4)
	local dist = rng:NextNumber(7, 12)
	local dir = hrp.CFrame.LookVector
	dir = CFrame.Angles(0, offsetAngle, 0):VectorToWorldSpace(dir)
	local pos = hrp.Position + dir * dist + Vector3.new(0, 1, 0)
	local ghost = buildGhostModel("JumpscareGhost", false)
	ghost.Parent = ghostsFolder
	ghost.PrimaryPart.Anchored = true
	ghost:PivotTo(CFrame.new(pos, hrp.Position))
	R.TriggerJumpscare:FireClient(player, "jumpscare", pos)
	task.spawn(function()
		local t0 = tick()
		while tick() - t0 < Config.Ghost.JumpscareDuration do
			for _, p in ipairs(ghost:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = math.min(1, p.Transparency + 0.04)
				end
			end
			task.wait(0.05)
		end
		ghost:Destroy()
	end)
end

local function findNearestPlayer(fromPos)
	local nearest, best = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = getHRP(p)
		local hum = getHumanoid(p)
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - fromPos).Magnitude
			if d < best then best = d; nearest = p end
		end
	end
	return nearest, best
end

local function runHunterAI(hunter)
	local root = hunter.PrimaryPart
	local humanoid = hunter:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	local lastAttack = 0
	local alive = true
	hunter.AncestryChanged:Connect(function(_, parent) if not parent then alive = false end end)
	task.spawn(function()
		while alive and humanoid.Parent do
			local target, dist = findNearestPlayer(root.Position)
			if target and dist <= Config.Ghost.HunterSightRange then
				local hrp = getHRP(target)
				if hrp then
					if dist < 20 then R.HunterNear:FireClient(target, dist) end
					humanoid:MoveTo(hrp.Position)
					if dist <= Config.Ghost.HunterAttackRange and tick() - lastAttack > Config.Ghost.HunterAttackCooldown then
						lastAttack = tick()
						local hum = getHumanoid(target)
						if hum and hum.Health > 0 then
							hum:TakeDamage(Config.Ghost.HunterDamage)
							R.TriggerJumpscare:FireClient(target, "attack", root.Position)
						end
					end
				end
			else
				humanoid:MoveTo(root.Position + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
			end
			task.wait(0.5)
		end
	end)
end

local function spawnHunter(rooms)
	if #activeHunters >= Config.Ghost.MaxHuntersPerServer then return end
	if #rooms == 0 then return end
	local room = rooms[rng:NextInteger(1, #rooms)]
	local hunter = buildGhostModel("HunterGhost_" .. tostring(#activeHunters + 1), true)
	hunter.Parent = ghostsFolder
	hunter:PivotTo(CFrame.new(room.GhostSpawn + Vector3.new(0, 3, 0)))
	table.insert(activeHunters, hunter)
	runHunterAI(hunter)
	hunter.AncestryChanged:Connect(function(_, parent)
		if not parent then
			local idx = table.find(activeHunters, hunter)
			if idx then table.remove(activeHunters, idx) end
		end
	end)
end

local function initGhosts(rooms)
	ghostsFolder = Instance.new("Folder")
	ghostsFolder.Name = "Ghosts"
	ghostsFolder.Parent = workspace

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(Config.Ghost.JumpscareIntervalMin, Config.Ghost.JumpscareIntervalMax))
			local list = Players:GetPlayers()
			if #list > 0 then
				pcall(spawnJumpscareFor, list[rng:NextInteger(1, #list)])
			end
		end
	end)

	task.spawn(function()
		task.wait(Config.Ghost.HunterSpawnAfter)
		spawnHunter(rooms)
		while true do
			task.wait(rng:NextNumber(60, 120))
			if #Players:GetPlayers() > 0 then spawnHunter(rooms) end
		end
	end)
end

-- ============================================================
-- TOOL: FLASHLIGHT
-- ============================================================
local function giveFlashlight(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild(Config.Tool.FlashlightName) then return end
	local char = player.Character
	if char and char:FindFirstChild(Config.Tool.FlashlightName) then return end

	local tool = Instance.new("Tool")
	tool.Name = Config.Tool.FlashlightName
	tool.ToolTip = "Senter Survival - klik untuk nyala/mati"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 2)
	handle.Color = Color3.fromRGB(40, 40, 40)
	handle.Material = Enum.Material.Metal
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "LightHead"
	head.Size = Vector3.new(0.8, 0.8, 0.3)
	head.Color = Color3.fromRGB(240, 240, 240)
	head.Material = Enum.Material.Neon
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle; w.Part1 = head
	head.CFrame = handle.CFrame * CFrame.new(0, 0, -1.2)
	w.Parent = head

	local spot = Instance.new("SpotLight")
	spot.Name = "Beam"
	spot.Range = Config.Tool.FlashlightRange
	spot.Brightness = Config.Tool.FlashlightBrightness
	spot.Angle = Config.Tool.FlashlightAngle
	spot.Color = Config.Tool.FlashlightColor
	spot.Face = Enum.NormalId.Front
	spot.Shadows = true
	spot.Enabled = false
	spot.Parent = head

	tool.Activated:Connect(function()
		spot.Enabled = not spot.Enabled
	end)

	tool.Parent = backpack
end

-- ============================================================
-- BOOT
-- ============================================================
setupLighting()
setupAmbientSounds()

local map = generateMap()
print(string.format("[HauntedServer] Gedung selesai: %d ruangan", #map.Rooms))

initQuest(map.Rooms)
initPuzzles(map.Rooms)
initGhosts(map.Rooms)

local function teleportAndGive(player, char)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.CFrame = CFrame.new(map.SpawnPoint + Vector3.new(0, 4, 0))
	end
	task.wait(0.3)
	giveFlashlight(player)
	questProgress[player.UserId] = questProgress[player.UserId] or 0
	broadcastQuest(player)
	R.Notify:FireClient(player,
		"Kamu terdampar di gedung tua terkutuk. Temukan 5 Lampu Kuno dan selamatkan dirimu!",
		Color3.fromRGB(255, 210, 140))
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		teleportAndGive(player, char)
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then teleportAndGive(p, p.Character) end
	p.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		teleportAndGive(p, char)
	end)
end

Players.PlayerRemoving:Connect(function(p)
	questProgress[p.UserId] = nil
end)

print("[HauntedServer] SIAP. Cek dunia Workspace untuk melihat gedung.")
