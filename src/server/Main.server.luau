-- Startpunkt des Servers: baut die Welt und verbindet alle Teile miteinander.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local World = require(script.Parent:WaitForChild("World"))
local Lift = require(script.Parent:WaitForChild("Lift"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Data = require(script.Parent:WaitForChild("Data"))
local Eggs = require(script.Parent:WaitForChild("Eggs"))

-- ---------------------------------------------------------------------------
-- Verbindungen zwischen Server und Spieler
-- ---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes
local buySpeedRemote = Instance.new("RemoteEvent")
buySpeedRemote.Name = "BuySpeed"
buySpeedRemote.Parent = remotes
local rebirthRemote = Instance.new("RemoteEvent")
rebirthRemote.Name = "Rebirth"
rebirthRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local function notify(player, text, kind)
	if player and player.Parent then
		notifyRemote:FireClient(player, text, kind or "info")
	end
end

Bases.notify = notify
Eggs.notify = notify
Data.collectEggs = Eggs.listFor

-- ---------------------------------------------------------------------------
-- Welt aufbauen
-- ---------------------------------------------------------------------------
local map = World.build()
Lift.build(map)
Bases.build(map)
Eggs.build(map)

-- ---------------------------------------------------------------------------
-- Schi an den Fuessen (nur auf dem Berg sichtbar)
-- ---------------------------------------------------------------------------
local function addSkis(character)
	local feet = {
		character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg"),
		character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg"),
	}
	for _, foot in pairs(feet) do
		local ski = Instance.new("Part")
		ski.Name = "Ski"
		ski.Size = Vector3.new(0.6, 0.15, 5)
		ski.Color = Color3.fromRGB(230, 60, 60)
		ski.Material = Enum.Material.SmoothPlastic
		ski.CanCollide = false
		ski.CanTouch = false
		ski.CanQuery = false
		ski.Massless = true
		ski.Transparency = 1
		ski.CFrame = foot.CFrame * CFrame.new(0, -foot.Size.Y / 2 - 0.08, -0.8)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = foot
		weld.Part1 = ski
		weld.Parent = ski
		ski.Parent = character
	end
end

local function updateSkis()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local onMountain = root.Position.Z > Config.SLOPE_START_Z
			local transparency = onMountain and 0 or 1
			for _, child in ipairs(character:GetChildren()) do
				if child.Name == "Ski" and child.Transparency ~= transparency then
					child.Transparency = transparency
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Spieler kommen und gehen
-- ---------------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	humanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
	humanoid.Died:Connect(function()
		Eggs.drop(player)
	end)
	task.wait(0.5) -- kurz warten, bis alle Koerperteile da sind
	if character.Parent then
		addSkis(character)
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	local profile = Data.load(player)
	if not player.Parent then
		Data.release(player)
		return
	end

	local base = Bases.assign(player)
	if base then
		Eggs.restore(player, profile.Eggs)
	else
		notify(player, "All bases are taken - set the server size to 8 players.", "bad")
	end

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	notify(player, "Welcome! Ride the ski lift, steal an egg and ski back down.", "info")
end

local function onPlayerRemoving(player)
	Eggs.drop(player)
	Data.save(player)
	Eggs.clearBase(player)
	Eggs.forget(player)
	Bases.release(player)
	Data.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ---------------------------------------------------------------------------
-- Kaeufe
-- ---------------------------------------------------------------------------
local lastRequest = {}
local function tooFast(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.15 then
		return true
	end
	lastRequest[player] = now
	return false
end
Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

buySpeedRemote.OnServerEvent:Connect(function(player)
	if tooFast(player) then
		return
	end
	local ok, message = Data.buySpeed(player)
	notify(player, message, ok and "good" or "bad")
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	if tooFast(player) then
		return
	end
	local ok, message = Data.rebirth(player)
	if ok then
		Eggs.drop(player)
		Eggs.clearBase(player)
	end
	notify(player, message, ok and "good" or "bad")
end)

-- ---------------------------------------------------------------------------
-- Spielschleife
-- ---------------------------------------------------------------------------
local skiTimer = 0
RunService.Heartbeat:Connect(function(dt)
	Lift.update(dt)
	Eggs.update(dt)
	skiTimer = skiTimer + dt
	if skiTimer >= 0.3 then
		skiTimer = 0
		updateSkis()
	end
end)

-- Regelmaessig und beim Herunterfahren speichern
task.spawn(function()
	while true do
		task.wait(120)
		Data.saveAll()
	end
end)

game:BindToClose(function()
	Data.saveAll()
end)
