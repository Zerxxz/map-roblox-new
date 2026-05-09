--!strict
-- RemoteEvents.lua
-- Membuat & menyediakan akses ke semua RemoteEvent/RemoteFunction secara terpusat.
-- Bisa di-require dari server MAUPUN client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local container = ReplicatedStorage:FindFirstChild("Remotes")
if not container then
	container = Instance.new("Folder")
	container.Name = "Remotes"
	container.Parent = ReplicatedStorage
end

local function getOrCreateEvent(name: string): RemoteEvent
	local r = container:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = container
	end
	return r :: RemoteEvent
end

local function getOrCreateFunction(name: string): RemoteFunction
	local r = container:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = container
	end
	return r :: RemoteFunction
end

-- Quest
RemoteEvents.QuestUpdate        = getOrCreateEvent("QuestUpdate")        -- server -> client: {collected, total}
RemoteEvents.QuestComplete      = getOrCreateEvent("QuestComplete")      -- server -> client

-- Jumpscare / Ghost
RemoteEvents.TriggerJumpscare   = getOrCreateEvent("TriggerJumpscare")   -- server -> client (ghostType, position)
RemoteEvents.HunterNear         = getOrCreateEvent("HunterNear")         -- server -> client (distance)

-- Puzzle
RemoteEvents.PuzzlePrompt       = getOrCreateEvent("PuzzlePrompt")       -- server -> client (puzzleId, hints)
RemoteEvents.PuzzleSubmit       = getOrCreateFunction("PuzzleSubmit")    -- client -> server (puzzleId, answer) -> bool

-- Alliance
RemoteEvents.AllianceInvite     = getOrCreateEvent("AllianceInvite")     -- server -> client (fromPlayer)
RemoteEvents.AllianceRespond    = getOrCreateEvent("AllianceRespond")    -- client -> server (fromPlayer, accept)
RemoteEvents.AllianceRequest    = getOrCreateEvent("AllianceRequest")    -- client -> server (targetPlayer)
RemoteEvents.AllianceUpdate     = getOrCreateEvent("AllianceUpdate")     -- server -> client (members)
RemoteEvents.AllianceLeave      = getOrCreateEvent("AllianceLeave")      -- client -> server

-- Atmosphere
RemoteEvents.AtmosphereCue      = getOrCreateEvent("AtmosphereCue")      -- server -> client (cueName)

-- Notification / toast
RemoteEvents.Notify             = getOrCreateEvent("Notify")             -- server -> client (text, color)

return RemoteEvents
