-- Anzeige fuer den Spieler: Geld, Kaufknoepfe, Warnungen und Meldungen.
-- Ausserdem wird hier die Laufgeschwindigkeit gesetzt (bergab auf Schi schneller).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify")
local buySpeedRemote = remotes:WaitForChild("BuySpeed")
local rebirthRemote = remotes:WaitForChild("Rebirth")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local FONT = Enum.Font.FredokaOne

-- ---------------------------------------------------------------------------
-- Aufbau der Anzeige
-- ---------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
}, playerGui)

local cashLabel = make("TextLabel", {
	Name = "Cash",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0, 280, 0, 48),
	BackgroundColor3 = Color3.fromRGB(20, 30, 45),
	BackgroundTransparency = 0.25,
	Text = "$0",
	TextScaled = true,
	Font = FONT,
	TextColor3 = Color3.fromRGB(110, 255, 140),
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, cashLabel)

local statusLabel = make("TextLabel", {
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.new(0, 520, 0, 34),
	BackgroundTransparency = 1,
	Text = "",
	TextScaled = true,
	Font = FONT,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0,
}, gui)

local function makeButton(name, order, color)
	local button = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, (order - 1) * 78 - 39),
		Size = UDim2.new(0, 200, 0, 68),
		BackgroundColor3 = color,
		Text = name,
		TextScaled = true,
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		AutoButtonColor = true,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, button)
	return button
end

local speedButton = makeButton("Speed", 1, Color3.fromRGB(40, 140, 255))
local rebirthButton = makeButton("Rebirth", 2, Color3.fromRGB(190, 80, 255))

local toastHolder = make("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.new(0, 480, 0, 200),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
}, toastHolder)

-- ---------------------------------------------------------------------------
-- Meldungen
-- ---------------------------------------------------------------------------
local TOAST_COLORS = {
	good = Color3.fromRGB(110, 255, 140),
	bad = Color3.fromRGB(255, 110, 110),
	info = Color3.fromRGB(255, 255, 255),
}
local toastCount = 0

local function showToast(text, kind)
	toastCount = toastCount + 1
	local label = make("TextLabel", {
		LayoutOrder = toastCount,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(20, 30, 45),
		BackgroundTransparency = 0.3,
		Text = text,
		TextScaled = true,
		Font = FONT,
		TextColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
	}, toastHolder)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, label)
	task.delay(4, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tween:Play()
		task.wait(0.55)
		label:Destroy()
	end)
end

notifyRemote.OnClientEvent:Connect(showToast)

-- ---------------------------------------------------------------------------
-- Werte anzeigen
-- ---------------------------------------------------------------------------
local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	local level = player:GetAttribute("SpeedLevel") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0

	cashLabel.Text = "$" .. Config.formatNumber(cash)

	if level >= Config.MAX_SPEED_LEVEL then
		speedButton.Text = "SPEED MAX"
	else
		speedButton.Text = "SPEED Lv " .. level .. "\n$" .. Config.formatNumber(Config.upgradeCost(level))
	end
	rebirthButton.Text = "REBIRTH " .. rebirths .. "\n$" .. Config.formatNumber(Config.rebirthCost(rebirths))
end

local function refreshStatus()
	local carrying = player:GetAttribute("Carrying")
	local chased = player:GetAttribute("Chased")
	local distance = player:GetAttribute("MotherDistance")
	if player:GetAttribute("Stunned") then
		statusLabel.Text = "CAUGHT!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	elseif chased then
		if distance then
			statusLabel.Text = "THE MOTHER IS " .. distance .. " STUDS BEHIND YOU - SKI DOWN!"
		else
			statusLabel.Text = "THE MOTHER IS CHASING YOU - SKI DOWN!"
		end
		statusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	elseif carrying then
		statusLabel.Text = "Carrying " .. carrying .. " - bring it to your base!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 230, 110)
	else
		statusLabel.Text = ""
	end
end

for _, name in ipairs({ "Cash", "SpeedLevel", "Rebirths" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
for _, name in ipairs({ "Carrying", "Chased", "MotherDistance", "Stunned" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshStatus)
end
refresh()
refreshStatus()

speedButton.Activated:Connect(function()
	buySpeedRemote:FireServer()
end)
rebirthButton.Activated:Connect(function()
	rebirthRemote:FireServer()
end)

-- Beim eigenen Ei steht "Sell", bei fremden "Steal"
ProximityPromptService.PromptShown:Connect(function(prompt)
	local part = prompt.Parent
	if part and part.Name == "Egg" then
		if part:GetAttribute("OwnerId") == player.UserId then
			prompt.ActionText = "Sell"
		else
			prompt.ActionText = "Steal"
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Geschwindigkeit: in der Lobby normal, bergab auf dem Berg mit Schi-Tempo
-- ---------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	local speed = player:GetAttribute("WalkSpeed") or 16
	if player:GetAttribute("Stunned") then
		speed = 0
	elseif root.Position.Z > Config.SLOPE_START_Z and humanoid.MoveDirection.Z < -0.3 then
		speed = player:GetAttribute("SkiSpeed") or 36
	end

	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end)
