--!strict
-- MapGenerator.lua
-- Membangun gedung tua terbengkalai secara prosedural.
-- Setiap lantai berisi grid ruangan yang terhubung koridor, dengan dinding,
-- pintu, lampu rusak, debu, dan titik spawn untuk Lampu Kuno & hantu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Utils = require(Shared:WaitForChild("Utils"))

local MapGenerator = {}

export type Room = {
	Index: number,
	Floor: number,
	GridX: number,
	GridZ: number,
	Center: Vector3,
	FloorPart: Part,
	Model: Model,
	IsLocked: boolean,
	DoorPart: Part?,
	LanternAnchor: Vector3,
	GhostSpawn: Vector3,
}

export type GeneratedMap = {
	Model: Model,
	Rooms: {Room},
	SpawnPoint: Vector3,
	ExitRoom: Room,
}

local rng = Random.new(tick())

local function newFolder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Buat satu ruangan kotak di posisi tertentu
local function buildRoom(
	parent: Instance,
	center: Vector3,
	size: Vector3,
	hasDoorN: boolean,
	hasDoorS: boolean,
	hasDoorE: boolean,
	hasDoorW: boolean
): (Model, Part, Part?)
	local roomModel = Instance.new("Model")
	roomModel.Name = "Room"
	roomModel.Parent = parent

	local wallT = Config.Map.WallThickness
	local halfX = size.X / 2
	local halfY = size.Y / 2
	local halfZ = size.Z / 2
	local doorW = 5
	local doorH = 8

	-- LANTAI
	local floor = Utils.createPart({
		Name = "Floor",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = CFrame.new(center + Vector3.new(0, -halfY, 0)),
		Color = Config.Map.FloorColor,
		Material = Config.Map.FloorMaterial,
	})
	floor.Parent = roomModel

	-- CEILING
	local ceiling = Utils.createPart({
		Name = "Ceiling",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = CFrame.new(center + Vector3.new(0, halfY, 0)),
		Color = Config.Map.CeilingColor,
		Material = Config.Map.CeilingMaterial,
	})
	ceiling.Parent = roomModel

	-- Fungsi bangun dinding dengan opsi pintu (lubang)
	local function buildWall(axis: string, sign: number, hasDoor: boolean)
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
			local w = Utils.createPart({
				Name = "Wall",
				Size = wallSize,
				CFrame = CFrame.new(wallCenter),
				Color = Config.Map.WallColor,
				Material = Config.Map.WallMaterial,
			})
			w.Parent = roomModel
			return
		end

		-- Dengan pintu: buat dinding terpisah jadi 3 bagian (kiri, kanan, atas pintu)
		local sideLen = (length - doorW) / 2
		if isX then
			-- kiri
			local left = Utils.createPart({
				Name = "Wall",
				Size = Vector3.new(sideLen, size.Y, wallT),
				CFrame = CFrame.new(wallCenter + Vector3.new(-(doorW/2 + sideLen/2), 0, 0)),
				Color = Config.Map.WallColor,
				Material = Config.Map.WallMaterial,
			})
			left.Parent = roomModel
			-- kanan
			local right = Utils.createPart({
				Name = "Wall",
				Size = Vector3.new(sideLen, size.Y, wallT),
				CFrame = CFrame.new(wallCenter + Vector3.new(doorW/2 + sideLen/2, 0, 0)),
				Color = Config.Map.WallColor,
				Material = Config.Map.WallMaterial,
			})
			right.Parent = roomModel
			-- atas pintu
			local topH = size.Y - doorH
			if topH > 0 then
				local top = Utils.createPart({
					Name = "WallTop",
					Size = Vector3.new(doorW, topH, wallT),
					CFrame = CFrame.new(wallCenter + Vector3.new(0, size.Y/2 - topH/2, 0)),
					Color = Config.Map.WallColor,
					Material = Config.Map.WallMaterial,
				})
				top.Parent = roomModel
			end
		else
			local left = Utils.createPart({
				Name = "Wall",
				Size = Vector3.new(wallT, size.Y, sideLen),
				CFrame = CFrame.new(wallCenter + Vector3.new(0, 0, -(doorW/2 + sideLen/2))),
				Color = Config.Map.WallColor,
				Material = Config.Map.WallMaterial,
			})
			left.Parent = roomModel
			local right = Utils.createPart({
				Name = "Wall",
				Size = Vector3.new(wallT, size.Y, sideLen),
				CFrame = CFrame.new(wallCenter + Vector3.new(0, 0, doorW/2 + sideLen/2)),
				Color = Config.Map.WallColor,
				Material = Config.Map.WallMaterial,
			})
			right.Parent = roomModel
			local topH = size.Y - doorH
			if topH > 0 then
				local top = Utils.createPart({
					Name = "WallTop",
					Size = Vector3.new(wallT, topH, doorW),
					CFrame = CFrame.new(wallCenter + Vector3.new(0, size.Y/2 - topH/2, 0)),
					Color = Config.Map.WallColor,
					Material = Config.Map.WallMaterial,
				})
				top.Parent = roomModel
			end
		end
	end

	buildWall("X",  1, hasDoorN)
	buildWall("X", -1, hasDoorS)
	buildWall("Z",  1, hasDoorE)
	buildWall("Z", -1, hasDoorW)

	-- Pintu interaktif (sebagai Part berdiri; default terbuka, dipakai puzzle sebagai "locked door")
	-- Kita letakkan di pintu pertama yang ada (prioritas N > S > E > W)
	local doorPart: Part? = nil
	local function placeDoor(axis: string, sign: number)
		local isX = axis == "X"
		local pos
		if isX then
			pos = center + Vector3.new(0, -halfY + doorH/2, sign * halfZ)
		else
			pos = center + Vector3.new(sign * halfX, -halfY + doorH/2, 0)
		end
		local sz = isX and Vector3.new(doorW - 0.2, doorH - 0.2, 0.5) or Vector3.new(0.5, doorH - 0.2, doorW - 0.2)
		local d = Utils.createPart({
			Name = "Door",
			Size = sz,
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(60, 40, 30),
			Material = Enum.Material.Wood,
			Transparency = 1,
			CanCollide = false,
		})
		d.Parent = roomModel
		return d
	end

	if hasDoorN then doorPart = placeDoor("X",  1) end
	if (not doorPart) and hasDoorS then doorPart = placeDoor("X", -1) end
	if (not doorPart) and hasDoorE then doorPart = placeDoor("Z",  1) end
	if (not doorPart) and hasDoorW then doorPart = placeDoor("Z", -1) end

	-- Lampu rusak (kedip-kedip) di langit-langit
	local bulb = Utils.createPart({
		Name = "BrokenBulb",
		Size = Vector3.new(1.2, 0.4, 1.2),
		CFrame = CFrame.new(center + Vector3.new(0, halfY - 1, 0)),
		Color = Color3.fromRGB(180, 170, 120),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	bulb.Parent = roomModel

	local pl = Instance.new("PointLight")
	pl.Range = 14
	pl.Brightness = 0.8
	pl.Color = Color3.fromRGB(255, 220, 170)
	pl.Parent = bulb

	-- Kedip-kedip
	task.spawn(function()
		while bulb.Parent do
			pl.Enabled = rng:NextNumber() > 0.25
			task.wait(rng:NextNumber(0.1, 0.9))
		end
	end)

	return roomModel, floor, doorPart
end

-- Bangun koridor penghubung antar 2 ruangan (tangga disederhanakan tangga langsung)
local function buildCorridor(parent: Instance, from: Vector3, to: Vector3)
	local mid = (from + to) / 2
	local dir = to - from
	local len = dir.Magnitude
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local angle = math.atan2(flat.X, flat.Z)
	local floor = Utils.createPart({
		Name = "CorridorFloor",
		Size = Vector3.new(Config.Map.CorridorWidth, 1, math.max(1, flat.Magnitude)),
		CFrame = CFrame.new(Vector3.new(mid.X, from.Y, mid.Z)) * CFrame.Angles(0, angle, 0),
		Color = Config.Map.FloorColor,
		Material = Config.Map.FloorMaterial,
	})
	floor.Parent = parent
end

-- Tangga antar lantai (slope)
local function buildStairs(parent: Instance, bottom: Vector3, top: Vector3)
	local mid = (bottom + top) / 2
	local dir = top - bottom
	local len = dir.Magnitude
	local angle = math.atan2(dir.X, dir.Z)
	local pitch = math.atan2(dir.Y, Vector3.new(dir.X, 0, dir.Z).Magnitude)
	local slab = Utils.createPart({
		Name = "Stairs",
		Size = Vector3.new(Config.Map.CorridorWidth, 1, len),
		CFrame = CFrame.new(mid) * CFrame.Angles(0, angle, 0) * CFrame.Angles(-pitch, 0, 0),
		Color = Color3.fromRGB(60, 50, 40),
		Material = Enum.Material.WoodPlanks,
	})
	slab.Parent = parent
end

function MapGenerator.generate(): GeneratedMap
	local mapModel = Instance.new("Model")
	mapModel.Name = "HauntedBuilding"
	mapModel.Parent = workspace

	local roomsFolder = newFolder("Rooms", mapModel)
	local corridorsFolder = newFolder("Corridors", mapModel)

	local rooms: {Room} = {}
	local floorHeight = Config.Map.RoomSize.Y + 2
	local cellSpacingX = Config.Map.RoomSize.X + 6
	local cellSpacingZ = Config.Map.RoomSize.Z + 6

	-- Grid sederhana: RoomsPerFloor di sumbu X dengan zig-zag supaya terasa koridor
	local roomsPerFloor = Config.Map.RoomsPerFloor

	for floorIdx = 1, Config.Map.Floors do
		local yBase = Config.Map.Origin.Y + (floorIdx - 1) * floorHeight + Config.Map.RoomSize.Y / 2
		local prevCenter: Vector3? = nil
		for ri = 1, roomsPerFloor do
			local gx = ri
			local gz = ((floorIdx + ri) % 2 == 0) and 1 or 2
			local center = Vector3.new(
				Config.Map.Origin.X + (gx - 1) * cellSpacingX,
				yBase,
				Config.Map.Origin.Z + (gz - 1) * cellSpacingZ
			)

			-- Pintu: hubungkan ke ruangan sebelumnya & berikutnya di lantai yang sama
			local hasDoorW = ri > 1
			local hasDoorE = ri < roomsPerFloor
			local hasDoorN = (gz == 1)    -- biar koridor zig-zag nyambung
			local hasDoorS = (gz == 2)

			local roomModel, floorPart, doorPart = buildRoom(
				roomsFolder, center, Config.Map.RoomSize,
				hasDoorN, hasDoorS, hasDoorE, hasDoorW
			)
			roomModel.Name = string.format("Room_F%d_R%d", floorIdx, ri)

			local room: Room = {
				Index = #rooms + 1,
				Floor = floorIdx,
				GridX = gx,
				GridZ = gz,
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

			-- Koridor ke ruangan sebelumnya di lantai yang sama
			if prevCenter then
				buildCorridor(corridorsFolder,
					prevCenter + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0),
					center + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0)
				)
			end
			prevCenter = center
		end

		-- Tangga antar lantai (dari ruangan terakhir lantai ini ke ruangan pertama lantai atas)
		if floorIdx < Config.Map.Floors then
			local lastOfThisFloor = rooms[#rooms]
			local firstNextCenter = Vector3.new(
				Config.Map.Origin.X,
				yBase + floorHeight,
				Config.Map.Origin.Z
			)
			buildStairs(
				corridorsFolder,
				lastOfThisFloor.Center + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0),
				firstNextCenter + Vector3.new(0, -Config.Map.RoomSize.Y/2, 0)
			)
		end
	end

	-- Spawn point = tengah ruangan pertama lantai 1
	local spawnPoint = rooms[1].Center + Vector3.new(0, -Config.Map.RoomSize.Y/2 + 4, 0)

	-- Exit room = ruangan terakhir lantai terakhir
	local exitRoom = rooms[#rooms]

	-- Buat SpawnLocation supaya pemain respawn di gedung
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

	-- Hancurkan SpawnLocation default yang mungkin ada
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("SpawnLocation") and inst ~= spawnLoc then
			inst.Neutral = true
		end
	end

	return {
		Model = mapModel,
		Rooms = rooms,
		SpawnPoint = spawnPoint,
		ExitRoom = exitRoom,
	}
end

return MapGenerator
