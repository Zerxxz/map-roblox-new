--!strict
-- ToolGiver.lua
-- Memberi pemain 1 alat survival: Flashlight (senter).
-- Toggle on/off via klik/activate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ToolGiver = {}

local function buildFlashlight(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Tool.FlashlightName
	tool.ToolTip = "Senter Survival - klik untuk menyalakan/matikan"
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
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	head.CFrame = handle.CFrame * CFrame.new(0, 0, -1.2)
	weld.Parent = head

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

	local onAttr = Instance.new("BoolValue")
	onAttr.Name = "IsOn"
	onAttr.Value = false
	onAttr.Parent = tool

	-- Script yang menempel di tool (child Script untuk handle activation di server)
	local serverLogic = Instance.new("Script")
	serverLogic.Name = "FlashlightServer"
	serverLogic.Source = [[
		local tool = script.Parent
		local head = tool:FindFirstChild("LightHead")
		local spot = head and head:FindFirstChild("Beam")
		local onVal = tool:FindFirstChild("IsOn")
		if not (spot and onVal) then return end

		tool.Activated:Connect(function()
			onVal.Value = not onVal.Value
			spot.Enabled = onVal.Value
		end)

		tool.Unequipped:Connect(function()
			-- jangan matikan beam; tapi kalau mau, boleh:
			-- spot.Enabled = false
		end)
	]]
	serverLogic.Parent = tool

	return tool
end

function ToolGiver.giveTo(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	-- Hindari duplikat
	if backpack:FindFirstChild(Config.Tool.FlashlightName) then return end
	local char = player.Character
	if char and char:FindFirstChild(Config.Tool.FlashlightName) then return end

	local tool = buildFlashlight()
	tool.Parent = backpack
end

function ToolGiver.init()
	local function onCharacter(player: Player)
		-- Tunggu character siap sebentar
		task.wait(0.5)
		ToolGiver.giveTo(player)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			onCharacter(player)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function() onCharacter(player) end)
		if player.Character then onCharacter(player) end
	end
end

return ToolGiver
