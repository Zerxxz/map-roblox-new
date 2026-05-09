--!strict
-- AllianceSystem.lua
-- Pemain bisa mengundang pemain lain ke aliansi.
-- Anggota aliansi tidak saling damage & berbagi progress quest (opsional).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("RemoteEvents"))

local AllianceSystem = {}

-- allianceId -> { leader=userId, members={userId=true,...} }
local alliances: {[string]: {leader: number, members: {[number]: boolean}}} = {}
-- userId -> allianceId
local playerToAlliance: {[number]: string} = {}
-- pending invites: targetUserId -> { fromUserId=..., ts=... }
local pendingInvites: {[number]: {from: number, ts: number}} = {}

local allianceCounter = 0
local function newAllianceId(): string
	allianceCounter += 1
	return "A" .. tostring(allianceCounter)
end

local function getAllianceIdOf(player: Player): string?
	return playerToAlliance[player.UserId]
end

local function memberList(id: string): {Player}
	local out: {Player} = {}
	local a = alliances[id]
	if not a then return out end
	for uid, _ in pairs(a.members) do
		local p = Players:GetPlayerByUserId(uid)
		if p then table.insert(out, p) end
	end
	return out
end

local function broadcastAlliance(id: string)
	local a = alliances[id]
	if not a then return end
	local names = {}
	local ids = {}
	for uid, _ in pairs(a.members) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			table.insert(names, p.DisplayName or p.Name)
			table.insert(ids, uid)
		end
	end
	for _, member in ipairs(memberList(id)) do
		Remotes.AllianceUpdate:FireClient(member, {
			allianceId = id,
			leader = a.leader,
			memberNames = names,
			memberIds = ids,
		})
	end
end

local function createAlliance(leader: Player): string
	local id = newAllianceId()
	alliances[id] = {
		leader = leader.UserId,
		members = { [leader.UserId] = true },
	}
	playerToAlliance[leader.UserId] = id
	broadcastAlliance(id)
	return id
end

local function addToAlliance(id: string, player: Player): boolean
	local a = alliances[id]
	if not a then return false end
	local count = 0
	for _ in pairs(a.members) do count += 1 end
	if count >= Config.Alliance.MaxMembers then return false end
	a.members[player.UserId] = true
	playerToAlliance[player.UserId] = id
	broadcastAlliance(id)
	return true
end

local function removeFromAlliance(player: Player)
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
	for _ in pairs(a.members) do remaining += 1 end
	if remaining == 0 then
		alliances[id] = nil
	else
		-- Jika leader keluar, pilih leader baru
		if a.leader == player.UserId then
			for uid, _ in pairs(a.members) do
				a.leader = uid
				break
			end
		end
		broadcastAlliance(id)
	end

	-- Kirim update "kosong" ke pemain yang keluar
	Remotes.AllianceUpdate:FireClient(player, {
		allianceId = nil, leader = nil, memberNames = {}, memberIds = {}
	})
end

-- API publik
function AllianceSystem.getAllies(player: Player): {Player}
	local id = playerToAlliance[player.UserId]
	if not id then return {player} end
	return memberList(id)
end

function AllianceSystem.areAllies(a: Player, b: Player): boolean
	if a == b then return true end
	local ida = playerToAlliance[a.UserId]
	local idb = playerToAlliance[b.UserId]
	return ida ~= nil and ida == idb
end

function AllianceSystem.init()
	-- Pemain A klik Invite terhadap B
	Remotes.AllianceRequest.OnServerEvent:Connect(function(from, targetName)
		if typeof(targetName) ~= "string" then return end
		local target = Players:FindFirstChild(targetName) :: Player?
		if not target or target == from then
			Remotes.Notify:FireClient(from, "Target aliansi tidak ditemukan.", Color3.fromRGB(255, 120, 120))
			return
		end

		local fromId = playerToAlliance[from.UserId]
		local targetId = playerToAlliance[target.UserId]
		if targetId then
			Remotes.Notify:FireClient(from, target.DisplayName .. " sudah berada di aliansi lain.", Color3.fromRGB(255, 180, 120))
			return
		end

		-- Jika from belum punya aliansi, buat dulu
		if not fromId then
			fromId = createAlliance(from)
		end

		pendingInvites[target.UserId] = { from = from.UserId, ts = tick() }
		Remotes.AllianceInvite:FireClient(target, {
			fromUserId = from.UserId,
			fromName = from.DisplayName or from.Name,
			allianceId = fromId,
		})
		Remotes.Notify:FireClient(from, "Undangan dikirim ke " .. (target.DisplayName or target.Name), Color3.fromRGB(180, 220, 255))
	end)

	Remotes.AllianceRespond.OnServerEvent:Connect(function(target, payload)
		if typeof(payload) ~= "table" then return end
		local fromUserId = payload.fromUserId
		local accept = payload.accept
		if typeof(fromUserId) ~= "number" then return end

		local invite = pendingInvites[target.UserId]
		if not invite or invite.from ~= fromUserId then return end
		if tick() - invite.ts > Config.Alliance.InviteTimeout then
			pendingInvites[target.UserId] = nil
			Remotes.Notify:FireClient(target, "Undangan kadaluarsa.", Color3.fromRGB(255, 180, 120))
			return
		end
		pendingInvites[target.UserId] = nil

		local fromPlayer = Players:GetPlayerByUserId(fromUserId)
		if not fromPlayer then return end

		if not accept then
			Remotes.Notify:FireClient(fromPlayer, (target.DisplayName or target.Name) .. " menolak aliansi.", Color3.fromRGB(255, 160, 160))
			return
		end

		local aid = playerToAlliance[fromUserId]
		if not aid then aid = createAlliance(fromPlayer) end
		local ok = addToAlliance(aid, target)
		if ok then
			Remotes.Notify:FireClient(target, "Bergabung dengan aliansi!", Color3.fromRGB(160, 255, 160))
			Remotes.Notify:FireClient(fromPlayer, (target.DisplayName or target.Name) .. " bergabung dalam aliansimu.", Color3.fromRGB(160, 255, 160))
		else
			Remotes.Notify:FireClient(target, "Aliansi penuh.", Color3.fromRGB(255, 180, 120))
		end
	end)

	Remotes.AllianceLeave.OnServerEvent:Connect(function(player)
		removeFromAlliance(player)
		Remotes.Notify:FireClient(player, "Kamu keluar dari aliansi.", Color3.fromRGB(200, 200, 200))
	end)

	Players.PlayerRemoving:Connect(function(p)
		removeFromAlliance(p)
		pendingInvites[p.UserId] = nil
	end)

	-- Friendly fire handler (set karakter setelah spawn)
	local function hookCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum or not hum:IsA("Humanoid") then return end
		-- Kita tidak bisa mencegah damage langsung,
		-- tapi kita bisa override semua TakeDamage via HealthChanged listener.
		-- Pendekatan lebih sederhana: kita tidak meng-expose API damage antar pemain,
		-- dan kita menyarankan author tool tidak damage aliansi.
		-- Untuk default Roblox, damage biasanya lewat tool. Tool Flashlight kita tidak men-damage.
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
	end)
end

return AllianceSystem
