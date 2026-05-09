--!strict
-- PuzzleSystem.lua
-- Teka-teki kode di beberapa ruangan. Pemain harus mencari "petunjuk"
-- (3 papan/scroll) lalu masukkan kombinasi 3-digit ke panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Utils = require(Shared:WaitForChild("Utils"))
local Remotes = require(Shared:WaitForChild("RemoteEvents"))

local PuzzleSystem = {}

local rng = Random.new()

-- puzzleById[id] = { answer, hints={..}, door=Part }
local puzzleById: {[string]: {answer: string, hints: {string}, door: Part, solved: boolean}} = {}

local function generateCode(digits: number): string
	local s = ""
	for i = 1, digits do
		s = s .. tostring(rng:NextInteger(0, 9))
	end
	return s
end

local function generateHints(answer: string, count: number): {string}
	-- Hint berbentuk kalimat kabur berisi clue digit.
	-- Contoh: "Digit pertama adalah prima" / "Digit ketiga adalah 4"
	local hints: {string} = {}
	local digits = {}
	for i = 1, #answer do digits[i] = tonumber(string.sub(answer, i, i)) end

	local posNames = {"pertama", "kedua", "ketiga", "keempat", "kelima"}

	local templates = {
		function(i, d) return string.format("Angka %s adalah %d.", posNames[i], d) end,
		function(i, d)
			if d == 0 then return string.format("Angka %s tidak ada sama sekali (kosong).", posNames[i]) end
			return string.format("Angka %s = (%d) kali jumlah jariku.", posNames[i], d)
		end,
		function(i, d)
			local parity = (d % 2 == 0) and "genap" or "ganjil"
			return string.format("Angka %s adalah bilangan %s.", posNames[i], parity)
		end,
		function(i, d)
			return string.format("Jumlahkan %d dengan angka sebelumnya - kamu akan dekati angka %s.", d, posNames[i])
		end,
	}

	-- Pastikan distinct positions
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

-- Papan petunjuk fisik di ruangan
local function createHintBoard(parent: Instance, pos: Vector3, text: string)
	local board = Utils.createPart({
		Name = "HintBoard",
		Size = Vector3.new(6, 3, 0.3),
		Color = Color3.fromRGB(40, 30, 20),
		Material = Enum.Material.WoodPlanks,
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

-- Panel kode (ProximityPrompt) di pintu room
local function createPanel(door: Part, puzzleId: string)
	local panel = Utils.createPart({
		Name = "CodePanel",
		Size = Vector3.new(1.5, 2, 0.3),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
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
		Remotes.PuzzlePrompt:FireClient(player, puzzleId, data.hints)
	end)
end

local function lockDoor(door: Part)
	door.Transparency = 0
	door.CanCollide = true
	door.Color = Color3.fromRGB(60, 40, 30)
	door.Material = Enum.Material.Wood
end

local function unlockDoor(door: Part)
	-- Animate: geser ke atas lalu hapus collision
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

function PuzzleSystem.init(rooms: {any})
	-- Pilih ruangan terkunci per lantai
	local byFloor: {[number]: {any}} = {}
	for _, r in ipairs(rooms) do
		byFloor[r.Floor] = byFloor[r.Floor] or {}
		table.insert(byFloor[r.Floor], r)
	end

	local puzzleCounter = 0
	for floor, list in pairs(byFloor) do
		Utils.shuffle(list, rng)
		local n = math.min(Config.Puzzle.LockedRoomsPerFloor, #list)
		for i = 1, n do
			local room = list[i]
			if not room.DoorPart then continue end
			puzzleCounter += 1
			local pid = "puzzle_" .. tostring(puzzleCounter)
			local answer = generateCode(Config.Puzzle.CodeDigits)
			local hints = generateHints(answer, Config.Puzzle.HintsPerPuzzle)

			room.IsLocked = true
			lockDoor(room.DoorPart)

			puzzleById[pid] = {
				answer = answer,
				hints = hints,
				door = room.DoorPart,
				solved = false,
			}

			-- Sebar 3 papan petunjuk di ruangan lain acak (bukan di ruangan terkunci ini)
			local others = {}
			for _, r in ipairs(rooms) do
				if r ~= room then table.insert(others, r) end
			end
			Utils.shuffle(others, rng)
			for h = 1, math.min(#hints, #others) do
				local place = others[h]
				createHintBoard(
					place.Model,
					place.Center + Vector3.new(
						rng:NextNumber(-Config.Map.RoomSize.X/2 + 1, Config.Map.RoomSize.X/2 - 1),
						0,
						Config.Map.RoomSize.Z/2 - 1
					),
					string.format("[Puzzle %s]\n%s", pid, hints[h])
				)
			end

			createPanel(room.DoorPart, pid)
		end
	end

	-- Client submit jawaban via RemoteFunction
	Remotes.PuzzleSubmit.OnServerInvoke = function(player: Player, puzzleId: any, answer: any): boolean
		if typeof(puzzleId) ~= "string" or typeof(answer) ~= "string" then return false end
		local data = puzzleById[puzzleId]
		if not data then return false end
		if data.solved then return true end
		if answer == data.answer then
			data.solved = true
			unlockDoor(data.door)
			Remotes.Notify:FireAllClients(
				string.format("Pintu %s berhasil dibuka oleh %s!", puzzleId, player.DisplayName or player.Name),
				Color3.fromRGB(120, 255, 160)
			)
			return true
		end
		return false
	end
end

return PuzzleSystem
