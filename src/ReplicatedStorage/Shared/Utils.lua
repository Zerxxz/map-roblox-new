--!strict
-- Utils.lua
-- Helper umum yang bisa dipakai server & client.

local Utils = {}

-- Create part dengan properti umum
function Utils.createPart(props: {[string]: any}): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

-- Random element dari table array
function Utils.pickRandom<T>(list: {T}, rng: Random?): T
	rng = rng or Random.new()
	return list[(rng :: Random):NextInteger(1, #list)]
end

-- Shuffle array in place
function Utils.shuffle<T>(list: {T}, rng: Random?): {T}
	rng = rng or Random.new()
	for i = #list, 2, -1 do
		local j = (rng :: Random):NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Safe: cari humanoid root part dari player
function Utils.getHRP(player: Player): BasePart?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Utils.getHumanoid(player: Player): Humanoid?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

-- Jarak 2 vector3 (XZ plane saja)
function Utils.flatDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Clamp
function Utils.clamp(v: number, lo: number, hi: number): number
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Weighted choice
function Utils.weightedChoice<T>(weights: {[T]: number}, rng: Random?): T?
	rng = rng or Random.new()
	local total = 0
	for _, w in pairs(weights) do total += w end
	if total <= 0 then return nil end
	local r = (rng :: Random):NextNumber() * total
	local acc = 0
	for k, w in pairs(weights) do
		acc += w
		if r <= acc then return k end
	end
	return nil
end

-- Deep copy table (sederhana)
function Utils.deepCopy<T>(t: T): T
	if typeof(t) ~= "table" then return t end
	local out: any = {}
	for k, v in pairs(t :: any) do
		out[k] = Utils.deepCopy(v)
	end
	return out
end

return Utils
