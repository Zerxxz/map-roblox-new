--!strict
-- ClientMain.client.lua
-- UI Quest, UI Aliansi, Jumpscare effect, Puzzle input, Notify toast, Atmosphere cue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =============================================================
-- ROOT GUI
-- =============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HauntedUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- =============================================================
-- QUEST HUD
-- =============================================================
local questFrame = Instance.new("Frame")
questFrame.Name = "QuestHUD"
questFrame.Size = UDim2.new(0, 260, 0, 54)
questFrame.Position = UDim2.new(0, 16, 0, 16)
questFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
questFrame.BackgroundTransparency = 0.3
questFrame.BorderSizePixel = 0
questFrame.Parent = screenGui
local uiCorner = Instance.new("UICorner", questFrame)
uiCorner.CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", questFrame)
stroke.Color = Color3.fromRGB(180, 150, 80)
stroke.Thickness = 1.5

local questTitle = Instance.new("TextLabel")
questTitle.Size = UDim2.new(1, -20, 0, 22)
questTitle.Position = UDim2.new(0, 10, 0, 4)
questTitle.BackgroundTransparency = 1
questTitle.Text = "QUEST: Kumpulkan Lampu Kuno"
questTitle.Font = Enum.Font.GothamBold
questTitle.TextSize = 14
questTitle.TextColor3 = Color3.fromRGB(255, 210, 140)
questTitle.TextXAlignment = Enum.TextXAlignment.Left
questTitle.Parent = questFrame

local questProgress = Instance.new("TextLabel")
questProgress.Size = UDim2.new(1, -20, 0, 22)
questProgress.Position = UDim2.new(0, 10, 0, 26)
questProgress.BackgroundTransparency = 1
questProgress.Text = "0 / 5"
questProgress.Font = Enum.Font.Gotham
questProgress.TextSize = 16
questProgress.TextColor3 = Color3.fromRGB(220, 220, 220)
questProgress.TextXAlignment = Enum.TextXAlignment.Left
questProgress.Parent = questFrame

Remotes.QuestUpdate.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then return end
	questProgress.Text = string.format("%d / %d", info.collected or 0, info.total or Config.Quest.LanternCount)
end)

Remotes.QuestComplete.OnClientEvent:Connect(function()
	questTitle.Text = "QUEST SELESAI!"
	questProgress.Text = "Kamu menemukan semua Lampu Kuno!"
	stroke.Color = Color3.fromRGB(120, 255, 150)
end)

-- =============================================================
-- TOAST / NOTIFY
-- =============================================================
local toastContainer = Instance.new("Frame")
toastContainer.Name = "Toasts"
toastContainer.Size = UDim2.new(0, 380, 1, -100)
toastContainer.Position = UDim2.new(1, -400, 0, 80)
toastContainer.BackgroundTransparency = 1
toastContainer.Parent = screenGui
local list = Instance.new("UIListLayout", toastContainer)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.VerticalAlignment = Enum.VerticalAlignment.Top

local function showToast(text: string, color: Color3?)
	local t = Instance.new("Frame")
	t.Size = UDim2.new(1, 0, 0, 46)
	t.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	t.BackgroundTransparency = 0.2
	t.BorderSizePixel = 0
	t.Parent = toastContainer
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 6)
	local st = Instance.new("UIStroke", t)
	st.Color = color or Color3.fromRGB(255, 255, 255)
	st.Thickness = 1.5
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -14, 1, 0)
	lbl.Position = UDim2.new(0, 7, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 14
	lbl.TextWrapped = true
	lbl.TextColor3 = color or Color3.fromRGB(240, 240, 240)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = t

	task.delay(5, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		tw:Play()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.wait(0.6)
		t:Destroy()
	end)
end

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	if typeof(text) ~= "string" then return end
	showToast(text, color)
end)

-- =============================================================
-- JUMPSCARE
-- =============================================================
local jumpscareFrame = Instance.new("Frame")
jumpscareFrame.Size = UDim2.new(1, 0, 1, 0)
jumpscareFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
jumpscareFrame.BackgroundTransparency = 1
jumpscareFrame.BorderSizePixel = 0
jumpscareFrame.Visible = false
jumpscareFrame.Parent = screenGui
jumpscareFrame.ZIndex = 50

local jumpscareImg = Instance.new("ImageLabel")
jumpscareImg.Size = UDim2.new(1, 0, 1, 0)
jumpscareImg.BackgroundTransparency = 1
jumpscareImg.Image = "rbxassetid://7743875961" -- placeholder horror face, ganti kalau punya asset sendiri
jumpscareImg.ScaleType = Enum.ScaleType.Fit
jumpscareImg.ImageTransparency = 1
jumpscareImg.ZIndex = 51
jumpscareImg.Parent = jumpscareFrame

local jumpscareSound = Instance.new("Sound")
jumpscareSound.SoundId = Config.Atmosphere.JumpscareSoundId
jumpscareSound.Volume = 1.6
jumpscareSound.Parent = SoundService

Remotes.TriggerJumpscare.OnClientEvent:Connect(function(kind, _pos)
	jumpscareFrame.Visible = true
	jumpscareFrame.BackgroundTransparency = 0
	jumpscareImg.ImageTransparency = 0
	jumpscareSound:Play()

	-- Shake kamera sedikit
	local cam = workspace.CurrentCamera
	local origCF = cam.CFrame
	task.spawn(function()
		local t0 = tick()
		while tick() - t0 < 0.6 do
			pcall(function()
				cam.CFrame = origCF * CFrame.new(
					math.random(-20, 20) / 100,
					math.random(-20, 20) / 100,
					0
				)
			end)
			task.wait(0.03)
		end
	end)

	task.delay(0.9, function()
		TweenService:Create(jumpscareImg, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
		TweenService:Create(jumpscareFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.wait(0.55)
		jumpscareFrame.Visible = false
	end)
end)

-- =============================================================
-- HUNTER NEAR warning (heartbeat boost)
-- =============================================================
Remotes.HunterNear.OnClientEvent:Connect(function(dist)
	local blur = Lighting:FindFirstChild("HorrorBlur")
	if blur and blur:IsA("BlurEffect") then
		blur.Size = 12
		task.delay(0.8, function()
			if blur and blur.Parent then blur.Size = 4 end
		end)
	end
end)

-- =============================================================
-- ATMOSPHERE CUES
-- =============================================================
local whisperSound = Instance.new("Sound")
whisperSound.SoundId = Config.Atmosphere.WhisperSoundId
whisperSound.Volume = 0.6
whisperSound.Parent = SoundService

Remotes.AtmosphereCue.OnClientEvent:Connect(function(cue)
	if cue == "whisper" then
		whisperSound:Play()
	end
end)

-- =============================================================
-- PUZZLE UI
-- =============================================================
local puzzleGui: Frame? = nil
local function buildPuzzleGui(puzzleId: string, hints: {string})
	if puzzleGui then puzzleGui:Destroy() end

	local frame = Instance.new("Frame")
	frame.Name = "PuzzleGui"
	frame.Size = UDim2.new(0, 420, 0, 360)
	frame.Position = UDim2.new(0.5, -210, 0.5, -180)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", frame)
	s.Color = Color3.fromRGB(255, 200, 120)
	s.Thickness = 2

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "PANEL KUNCI - " .. puzzleId
	title.TextColor3 = Color3.fromRGB(255, 210, 140)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hintBox = Instance.new("TextLabel")
	hintBox.Size = UDim2.new(1, -20, 0, 180)
	hintBox.Position = UDim2.new(0, 10, 0, 44)
	hintBox.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	hintBox.BackgroundTransparency = 0.2
	hintBox.BorderSizePixel = 0
	hintBox.TextColor3 = Color3.fromRGB(220, 220, 220)
	hintBox.Font = Enum.Font.Gotham
	hintBox.TextSize = 13
	hintBox.TextWrapped = true
	hintBox.TextXAlignment = Enum.TextXAlignment.Left
	hintBox.TextYAlignment = Enum.TextYAlignment.Top
	hintBox.Text = "Petunjuk yang kamu temukan di ruangan-ruangan:\n\n- " .. table.concat(hints, "\n- ")
	hintBox.Parent = frame
	Instance.new("UICorner", hintBox).CornerRadius = UDim.new(0, 6)

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, -20, 0, 40)
	input.Position = UDim2.new(0, 10, 0, 234)
	input.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.PlaceholderText = "Masukkan 3 digit angka..."
	input.Font = Enum.Font.GothamBold
	input.TextSize = 20
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Parent = frame
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

	local submit = Instance.new("TextButton")
	submit.Size = UDim2.new(0.5, -15, 0, 38)
	submit.Position = UDim2.new(0, 10, 0, 284)
	submit.Text = "Coba Kode"
	submit.Font = Enum.Font.GothamBold
	submit.TextSize = 16
	submit.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
	submit.TextColor3 = Color3.fromRGB(255, 255, 255)
	submit.BorderSizePixel = 0
	submit.Parent = frame
	Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 6)

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0.5, -15, 0, 38)
	close.Position = UDim2.new(0.5, 5, 0, 284)
	close.Text = "Tutup"
	close.Font = Enum.Font.Gotham
	close.TextSize = 16
	close.BackgroundColor3 = Color3.fromRGB(100, 60, 60)
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.BorderSizePixel = 0
	close.Parent = frame
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

	local result = Instance.new("TextLabel")
	result.Size = UDim2.new(1, -20, 0, 20)
	result.Position = UDim2.new(0, 10, 1, -26)
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.Gotham
	result.TextSize = 13
	result.TextColor3 = Color3.fromRGB(255, 120, 120)
	result.Text = ""
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.Parent = frame

	submit.MouseButton1Click:Connect(function()
		local ok = false
		local success, res = pcall(function()
			return Remotes.PuzzleSubmit:InvokeServer(puzzleId, input.Text)
		end)
		if success then ok = res == true end
		if ok then
			result.TextColor3 = Color3.fromRGB(120, 255, 160)
			result.Text = "BENAR! Pintu terbuka."
			task.delay(1.2, function() if frame and frame.Parent then frame:Destroy() end end)
		else
			result.TextColor3 = Color3.fromRGB(255, 120, 120)
			result.Text = "Salah. Coba periksa petunjuk lagi."
		end
	end)

	close.MouseButton1Click:Connect(function()
		frame:Destroy()
	end)

	puzzleGui = frame
end

Remotes.PuzzlePrompt.OnClientEvent:Connect(function(puzzleId, hints)
	if typeof(puzzleId) == "string" and typeof(hints) == "table" then
		buildPuzzleGui(puzzleId, hints)
	end
end)

-- =============================================================
-- ALLIANCE UI
-- =============================================================
local allianceFrame = Instance.new("Frame")
allianceFrame.Name = "AllianceHUD"
allianceFrame.Size = UDim2.new(0, 260, 0, 180)
allianceFrame.Position = UDim2.new(0, 16, 0, 82)
allianceFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
allianceFrame.BackgroundTransparency = 0.3
allianceFrame.BorderSizePixel = 0
allianceFrame.Parent = screenGui
Instance.new("UICorner", allianceFrame).CornerRadius = UDim.new(0, 8)
local allianceStroke = Instance.new("UIStroke", allianceFrame)
allianceStroke.Color = Color3.fromRGB(120, 180, 255)
allianceStroke.Thickness = 1.5

local allianceTitle = Instance.new("TextLabel")
allianceTitle.Size = UDim2.new(1, -20, 0, 22)
allianceTitle.Position = UDim2.new(0, 10, 0, 4)
allianceTitle.BackgroundTransparency = 1
allianceTitle.Text = "ALIANSI"
allianceTitle.Font = Enum.Font.GothamBold
allianceTitle.TextSize = 14
allianceTitle.TextColor3 = Color3.fromRGB(180, 220, 255)
allianceTitle.TextXAlignment = Enum.TextXAlignment.Left
allianceTitle.Parent = allianceFrame

local membersList = Instance.new("TextLabel")
membersList.Size = UDim2.new(1, -20, 0, 80)
membersList.Position = UDim2.new(0, 10, 0, 26)
membersList.BackgroundTransparency = 1
membersList.Text = "(Kamu solo)"
membersList.Font = Enum.Font.Gotham
membersList.TextSize = 13
membersList.TextColor3 = Color3.fromRGB(220, 220, 220)
membersList.TextXAlignment = Enum.TextXAlignment.Left
membersList.TextYAlignment = Enum.TextYAlignment.Top
membersList.TextWrapped = true
membersList.Parent = allianceFrame

local inviteBox = Instance.new("TextBox")
inviteBox.Size = UDim2.new(1, -100, 0, 30)
inviteBox.Position = UDim2.new(0, 10, 1, -72)
inviteBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
inviteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteBox.PlaceholderText = "Nama pemain..."
inviteBox.Font = Enum.Font.Gotham
inviteBox.TextSize = 14
inviteBox.BorderSizePixel = 0
inviteBox.ClearTextOnFocus = false
inviteBox.Parent = allianceFrame
Instance.new("UICorner", inviteBox).CornerRadius = UDim.new(0, 6)

local inviteBtn = Instance.new("TextButton")
inviteBtn.Size = UDim2.new(0, 80, 0, 30)
inviteBtn.Position = UDim2.new(1, -90, 1, -72)
inviteBtn.Text = "Undang"
inviteBtn.Font = Enum.Font.GothamBold
inviteBtn.TextSize = 13
inviteBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 200)
inviteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteBtn.BorderSizePixel = 0
inviteBtn.Parent = allianceFrame
Instance.new("UICorner", inviteBtn).CornerRadius = UDim.new(0, 6)

local leaveBtn = Instance.new("TextButton")
leaveBtn.Size = UDim2.new(1, -20, 0, 30)
leaveBtn.Position = UDim2.new(0, 10, 1, -36)
leaveBtn.Text = "Keluar Aliansi"
leaveBtn.Font = Enum.Font.Gotham
leaveBtn.TextSize = 13
leaveBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
leaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
leaveBtn.BorderSizePixel = 0
leaveBtn.Parent = allianceFrame
Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 6)

inviteBtn.MouseButton1Click:Connect(function()
	local name = inviteBox.Text
	if name ~= "" then
		Remotes.AllianceRequest:FireServer(name)
		inviteBox.Text = ""
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.AllianceLeave:FireServer()
end)

Remotes.AllianceUpdate.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then return end
	if not info.allianceId or #info.memberNames <= 1 then
		membersList.Text = "(Kamu solo)"
	else
		local lines = {}
		for _, n in ipairs(info.memberNames) do
			table.insert(lines, "- " .. tostring(n))
		end
		membersList.Text = table.concat(lines, "\n")
	end
end)

-- Invite dialog
Remotes.AllianceInvite.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then return end
	local dlg = Instance.new("Frame")
	dlg.Size = UDim2.new(0, 360, 0, 130)
	dlg.Position = UDim2.new(0.5, -180, 0, 100)
	dlg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	dlg.BorderSizePixel = 0
	dlg.Parent = screenGui
	Instance.new("UICorner", dlg).CornerRadius = UDim.new(0, 8)
	local st = Instance.new("UIStroke", dlg)
	st.Color = Color3.fromRGB(120, 180, 255)
	st.Thickness = 2

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 0, 70)
	lbl.Position = UDim2.new(0, 10, 0, 10)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.format("%s mengundangmu bergabung dalam aliansi.", tostring(info.fromName or "Seseorang"))
	lbl.TextColor3 = Color3.fromRGB(240, 240, 240)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 15
	lbl.TextWrapped = true
	lbl.Parent = dlg

	local accept = Instance.new("TextButton")
	accept.Size = UDim2.new(0.5, -15, 0, 34)
	accept.Position = UDim2.new(0, 10, 1, -42)
	accept.Text = "Terima"
	accept.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
	accept.TextColor3 = Color3.fromRGB(255, 255, 255)
	accept.Font = Enum.Font.GothamBold
	accept.TextSize = 14
	accept.BorderSizePixel = 0
	accept.Parent = dlg
	Instance.new("UICorner", accept).CornerRadius = UDim.new(0, 6)

	local decline = Instance.new("TextButton")
	decline.Size = UDim2.new(0.5, -15, 0, 34)
	decline.Position = UDim2.new(0.5, 5, 1, -42)
	decline.Text = "Tolak"
	decline.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	decline.TextColor3 = Color3.fromRGB(255, 255, 255)
	decline.Font = Enum.Font.Gotham
	decline.TextSize = 14
	decline.BorderSizePixel = 0
	decline.Parent = dlg
	Instance.new("UICorner", decline).CornerRadius = UDim.new(0, 6)

	accept.MouseButton1Click:Connect(function()
		Remotes.AllianceRespond:FireServer({ fromUserId = info.fromUserId, accept = true })
		dlg:Destroy()
	end)
	decline.MouseButton1Click:Connect(function()
		Remotes.AllianceRespond:FireServer({ fromUserId = info.fromUserId, accept = false })
		dlg:Destroy()
	end)

	task.delay(Config.Alliance.InviteTimeout, function()
		if dlg and dlg.Parent then dlg:Destroy() end
	end)
end)

-- =============================================================
-- TIPS saat pertama kali spawn
-- =============================================================
task.delay(2, function()
	showToast("Kontrol: [Klik senter] untuk nyala/mati. Hindari hantu. Temukan 5 Lampu Kuno.", Color3.fromRGB(255, 220, 160))
end)

print("[HauntedBuilding] Client UI ready.")
