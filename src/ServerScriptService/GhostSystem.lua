--!strict
-- GhostSystem.lua
-- Dua jenis hantu:
--  (a) Jumpscare Ghost: muncul random di dekat pemain, kaget, lalu hilang.
--  (b) Hunter Ghost: model hantu dengan Humanoid, mengejar pemain terdekat & attack.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Utils = require(Shared:WaitForChild("Utils"))
local Remotes = require(Shared:WaitForChild("RemoteEvents"))

local GhostSystem = {}

local rng = Random.new()
local ghostsFolder: Folder

local roomsRef: {any} = {}
local activeHunters: {Model} = {}

-- Buat model hantu sederhana (R15-like minimal, tapi kita pakai Humanoid + rigged-lite)
local function buildGhostModel(name: string, isHunter: boolean): Model
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Massless = true
	root.Parent = model

	local torso = Utils.createPart({
		Name = "Torso",
		Size = Vector3.new(2, 2, 1),
		Color = Color3.fromRGB(230, 230, 240),
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CanCollide = false,
	})
	torso.Massless = true
	torso.Anchored = false
	torso.Parent = model

	local head = Utils.createPart({
		Name = "Head",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = false,
	})
	head.Massless = true
	head.Anchored = false
	head.Shape = Enum.PartType.Ball
	head.Parent = model

	-- Mata merah menyala
	for _, off in ipairs({-0.3, 0.3}) do
		local eye = Utils.createPart({
			Name = "Eye",
			Size = Vector3.new(0.2, 0.2, 0.2),
			Color = Color3.fromRGB(255, 30, 30),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0,
		})
		eye.Massless = true
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		eye.CFrame = head.CFrame * CFrame.new(off, 0.1, -0.55)
		weld.Parent = eye
	end

	-- Weld torso & head ke root
	local weld1 = Instance.new("WeldConstraint")
	weld1.Part0 = root
	weld1.Part1 = torso
	torso.CFrame = root.CFrame
	weld1.Parent = torso

	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = torso
	weld2.Part1 = head
	head.CFrame = torso.CFrame * CFrame.new(0, 1.6, 0)
	weld2.Parent = head

	-- PointLight biar atmosfernya jelas
	local pl = Instance.new("PointLight")
	pl.Range = 10
	pl.Brightness = 1.5
	pl.Color = Color3.fromRGB(150, 0, 0)
	pl.Parent = head

	model.PrimaryPart = root

	if isHunter then
		local humanoid = Instance.new("Humanoid")
		humanoid.WalkSpeed = Config.Ghost.HunterSpeed
		humanoid.MaxHealth = 500
		humanoid.Health = 500
		humanoid.HipHeight = 2
		humanoid.AutoRotate = true
		humanoid.BreakJointsOnDeath = false
		humanoid.DisplayName = "Hantu Pengejar"
		humanoid.Parent = model

		-- Root sebagai Humanoid root part butuh nama yang benar
		root.Size = Vector3.new(2, 2, 1)
	end

	return model
end

-- ========================================================
-- JUMPSCARE GHOST
-- ========================================================
local function spawnJumpscareFor(player: Player)
	local hrp = Utils.getHRP(player)
	if not hrp then return end

	-- Posisi di depan kamera pemain
	local offsetAngle = rng:NextNumber(-0.4, 0.4)
	local dist = rng:NextNumber(7, 12)
	local dir = hrp.CFrame.LookVector
	dir = CFrame.Angles(0, offsetAngle, 0):VectorToWorldSpace(dir)
	local pos = hrp.Position + dir * dist + Vector3.new(0, 1, 0)

	local ghost = buildGhostModel("JumpscareGhost", false)
	ghost.Parent = ghostsFolder;
	(ghost.PrimaryPart :: BasePart).Anchored = true;
	(ghost :: any):SetPrimaryPartCFrame(CFrame.new(pos, hrp.Position))

	-- Trigger jumpscare di client
	Remotes.TriggerJumpscare:FireClient(player, "jumpscare", pos)

	-- Fade-out & hapus
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

local function jumpscareLoop()
	task.spawn(function()
		while true do
			local wait = rng:NextNumber(Config.Ghost.JumpscareIntervalMin, Config.Ghost.JumpscareIntervalMax)
			task.wait(wait)
			local players = Players:GetPlayers()
			if #players > 0 then
				local target = players[rng:NextInteger(1, #players)]
				pcall(spawnJumpscareFor, target)
			end
		end
	end)
end

-- ========================================================
-- HUNTER GHOST
-- ========================================================
local function findNearestPlayer(fromPos: Vector3): (Player?, number)
	local nearest: Player? = nil
	local best = math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = Utils.getHRP(p)
		local hum = Utils.getHumanoid(p)
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - fromPos).Magnitude
			if d < best then
				best = d
				nearest = p
			end
		end
	end
	return nearest, best
end

local function runHunterAI(hunter: Model)
	local root = hunter.PrimaryPart
	local humanoid = hunter:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local lastAttack = 0
	local alive = true

	hunter.AncestryChanged:Connect(function(_, parent)
		if not parent then alive = false end
	end)

	task.spawn(function()
		while alive and humanoid.Parent do
			local target, dist = findNearestPlayer(root.Position)
			if target and dist <= Config.Ghost.HunterSightRange then
				local hrp = Utils.getHRP(target)
				if hrp then
					-- Notify client bila sangat dekat
					if dist < 20 then
						Remotes.HunterNear:FireClient(target, dist)
					end

					-- Pathfinding sederhana: MoveTo target
					humanoid:MoveTo(hrp.Position)

					-- Attack bila range
					if dist <= Config.Ghost.HunterAttackRange and tick() - lastAttack > Config.Ghost.HunterAttackCooldown then
						lastAttack = tick()
						local hum = Utils.getHumanoid(target)
						if hum and hum.Health > 0 then
							hum:TakeDamage(Config.Ghost.HunterDamage)
							Remotes.TriggerJumpscare:FireClient(target, "attack", root.Position)
						end
					end
				end
			else
				-- Wander
				local wanderOffset = Vector3.new(
					rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)
				)
				humanoid:MoveTo(root.Position + wanderOffset)
			end
			task.wait(0.5)
		end
	end)
end

local function spawnHunter()
	if #activeHunters >= Config.Ghost.MaxHuntersPerServer then return end
	if #roomsRef == 0 then return end
	local room = roomsRef[rng:NextInteger(1, #roomsRef)]
	local hunter = buildGhostModel("HunterGhost_" .. tostring(#activeHunters + 1), true)
	hunter.Parent = ghostsFolder;
	(hunter :: any):SetPrimaryPartCFrame(CFrame.new(room.GhostSpawn + Vector3.new(0, 3, 0)))
	table.insert(activeHunters, hunter)
	runHunterAI(hunter)

	hunter.AncestryChanged:Connect(function(_, parent)
		if not parent then
			local idx = table.find(activeHunters, hunter)
			if idx then table.remove(activeHunters, idx) end
		end
	end)
end

-- ========================================================
-- INIT
-- ========================================================
function GhostSystem.init(rooms: {any})
	roomsRef = rooms
	ghostsFolder = Instance.new("Folder")
	ghostsFolder.Name = "Ghosts"
	ghostsFolder.Parent = workspace

	-- Mulai jumpscare loop
	jumpscareLoop()

	-- Spawn hunter bertahap
	task.spawn(function()
		task.wait(Config.Ghost.HunterSpawnAfter)
		spawnHunter()
		while true do
			task.wait(rng:NextNumber(60, 120))
			if #Players:GetPlayers() > 0 then
				spawnHunter()
			end
		end
	end)
end

return GhostSystem
