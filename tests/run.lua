-- Probelauf des Servercodes in der nachgebildeten Umgebung.
-- Aufruf im Projektordner:  lua5.1 tests/run.lua .

package.path = (arg[1] or ".") .. "/tests/?.lua;" .. package.path
local M = require("mock")
local game, Instance, Vector3 = M.game, M.Instance, M.Vector3

local messages = {}
M.onNotify = function(player, text, kind)
	table.insert(messages, { player = player, text = text, kind = kind })
end
local function lastMessage(player)
	for i = #messages, 1, -1 do
		if messages[i].player == player then
			return messages[i].text
		end
	end
	return ""
end

local passed = 0
local function check(condition, label)
	if not condition then
		error("FEHLGESCHLAGEN: " .. label, 2)
	end
	passed = passed + 1
	print("  ok  " .. label)
end

-- Skriptbaum wie in der Platzdatei
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local configModule = M.script("ModuleScript", "Config", "src/shared/Config.luau", shared)

local server = Instance.new("Folder")
server.Name = "Server"
server.Parent = ServerScriptService
for _, name in ipairs({ "World", "Lift", "Bases", "Data", "Eggs" }) do
	M.script("ModuleScript", name, "src/server/" .. name .. ".luau", server)
end
local main = M.script("Script", "Main", "src/server/Main.server.luau", server)

-- Eine alte Bodenplatte soll entfernt werden
local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Parent = M.workspace

local DT = 1 / 30
local function step(seconds)
	local steps = math.floor(seconds / DT + 0.5)
	for _ = 1, steps do
		M.advance(DT)
		RunService.Heartbeat:Fire(DT)
	end
end

local function addPlayer(name, userId)
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	player.Parent = Players
	Players.PlayerAdded:Fire(player)

	local character = Instance.new("Model")
	character.Name = name
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(0, 3, -50)
	root.Parent = character
	for _, footName in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = Instance.new("Part")
		foot.Name = footName
		foot.Parent = character
	end
	character.Parent = M.workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return player, root, humanoid
end

local function removePlayer(player)
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

print("Start des Servers")
M.run(main)
local Config = M.env.require(configModule)

local map = M.workspace:FindFirstChild("Map")
check(map ~= nil, "Karte wurde gebaut")
check(M.workspace:FindFirstChild("Baseplate") == nil, "alte Bodenplatte entfernt")
local eggFolder = map:FindFirstChild("Eggs")
check(#eggFolder:GetChildren() == Config.ZONE_COUNT * 6, "in jedem Nest liegt ein Ei (" .. #eggFolder:GetChildren() .. ")")
check(#map:FindFirstChild("Bases"):GetChildren() == 8, "acht Basen vorhanden")

-- Gelaendeform
check(Config.groundHeight(50) == 0, "Lobby liegt auf Hoehe 0")
check(math.abs(Config.groundHeight(100 + 110) - 40) < 0.001, "Hangmitte der ersten Zone auf Hoehe 40")
check(Config.groundHeight(100 + 250) == 80, "erste flache Zone auf Hoehe 80")
check(Config.groundHeight(5000) == 400, "Gipfel auf Hoehe 400")

local function eggInZone(zoneIndex)
	local terraceZ = Config.terraceStart(zoneIndex)
	for _, egg in ipairs(eggFolder:GetChildren()) do
		local z = egg.Position.Z
		if egg:GetAttribute("OwnerId") == 0 and z > terraceZ and z < terraceZ + Config.TERRACE_LENGTH then
			return egg
		end
	end
	error("kein Ei in Zone " .. zoneIndex)
end
local function trigger(egg, player)
	egg:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player)
end

print("Spieler 1 betritt das Spiel")
local p1, root1, hum1 = addPlayer("Noah", 101)
step(1)
check(p1:GetAttribute("Cash") == 0, "Startgeld 0")
check(p1:GetAttribute("SkiSpeed") == 36, "Schi-Tempo Stufe 0 = 36")
check(p1.leaderstats ~= nil and p1.leaderstats.Cash ~= nil, "Bestenliste angelegt")
local skis = 0
for _, child in ipairs(p1.Character:GetChildren()) do
	if child.Name == "Ski" then
		skis = skis + 1
	end
end
check(skis == 2, "zwei Schi am Charakter")

print("Lift")
root1.Position = Vector3.new(60, 3, 40)
step(8)
check(hum1.Sit == true, "wartender Spieler wird vom Sessel mitgenommen")
hum1.Sit = false

print("Ei stehlen und entkommen")
local egg = eggInZone(1)
root1.Position = egg.Position + Vector3.new(0, 2, -4)
trigger(egg, p1)
check(p1:GetAttribute("Carrying") ~= nil, "Spieler traegt das Ei")
check(p1:GetAttribute("Chased") == true, "Mutter nimmt die Verfolgung auf")
check(egg:FindFirstChildOfClass("ProximityPrompt").Enabled == false, "getragenes Ei ist nicht anklickbar")
local skiSpeed = p1:GetAttribute("SkiSpeed")
local guard = 0
while root1.Position.Z > 95 do
	local z = root1.Position.Z - skiSpeed * DT
	root1.Position = Vector3.new(0, Config.groundHeight(z) + 3, z)
	step(DT)
	guard = guard + 1
	assert(guard < 5000, "Abfahrt endet nicht")
end
check(p1:GetAttribute("Carrying") ~= nil, "Stufe 0 ist schnell genug fuer Zone 1")
check(p1:GetAttribute("Chased") == nil, "in der Lobby endet die Verfolgung")

print("Abliefern und Einkommen")
root1.Position = Vector3.new(-115, 3, -160)
step(0.5)
check(p1:GetAttribute("Carrying") == nil, "Ei wurde abgeliefert")
check(egg:GetAttribute("OwnerId") == 101, "Ei gehoert jetzt Spieler 1")
step(5)
check(p1:GetAttribute("Cash") > 0, "Ei bringt Geld (" .. p1:GetAttribute("Cash") .. ")")
step(Config.NEST_RESPAWN + 12)
check(#eggFolder:GetChildren() == Config.ZONE_COUNT * 6 + 1, "leeres Nest wurde neu befuellt")

print("Von der Mutter erwischt werden")
local egg2 = eggInZone(2)
root1.Position = egg2.Position + Vector3.new(0, 2, -4)
trigger(egg2, p1)
step(6)
check(p1:GetAttribute("Carrying") == nil, "Mutter holt das Ei zurueck, wenn man stehen bleibt")
check(egg2:GetAttribute("OwnerId") == 0, "Ei liegt wieder im Nest")
check(lastMessage(p1):find("caught you") ~= nil, "Meldung ueber das Erwischtwerden")
check(p1:GetAttribute("Stunned") == nil, "Betaeubung ist nach kurzer Zeit vorbei")

print("Zu langsam fuer eine hoehere Zone")
local egg3 = eggInZone(3)
root1.Position = egg3.Position + Vector3.new(0, 2, -4)
trigger(egg3, p1)
guard = 0
while root1.Position.Z > 95 and p1:GetAttribute("Carrying") do
	local z = root1.Position.Z - skiSpeed * DT
	root1.Position = Vector3.new(0, Config.groundHeight(z) + 3, z)
	step(DT)
	guard = guard + 1
	assert(guard < 5000, "Abfahrt endet nicht")
end
check(p1:GetAttribute("Carrying") == nil, "mit Stufe 0 holt die Mutter aus Zone 3 einen ein")
step(15)

print("Spieler 2 stiehlt aus der Basis")
local p2, root2 = addPlayer("Dieb", 202)
step(1)
root1.Position = Vector3.new(0, 3, -50)
root2.Position = egg.Position
trigger(egg, p2)
check(p2:GetAttribute("Carrying") ~= nil, "Spieler 2 traegt das gestohlene Ei")
root2.Position = Vector3.new(0, 3, 0)
step(0.5)
root1.Position = Vector3.new(2, 3, 0)
step(0.5)
check(p2:GetAttribute("Carrying") == nil, "Besitzer holt sein Ei durch Beruehren zurueck")
check(egg:GetAttribute("OwnerId") == 101, "Ei steht wieder in der Basis von Spieler 1")
step(4)

trigger(egg, p2)
root2.Position = Vector3.new(-115, 3, -90)
root1.Position = Vector3.new(0, 3, -50)
step(0.5)
check(egg:GetAttribute("OwnerId") == 202, "erfolgreicher Diebstahl: Ei gehoert Spieler 2")

print("Basis sperren")
local base2
for _, folder in ipairs(map:FindFirstChild("Bases"):GetChildren()) do
	local floor = folder:FindFirstChild("Floor")
	if floor.Position.X == -115 and floor.Position.Z == -90 then
		base2 = folder
	end
end
base2.LockPad.Touched:Fire(p2.Character.HumanoidRootPart)
check(base2.Shield.Transparency < 1, "Schutzschild sichtbar")
root1.Position = egg.Position
trigger(egg, p1)
check(p1:GetAttribute("Carrying") == nil, "aus gesperrter Basis kann nicht gestohlen werden")
step(Config.LOCK_DURATION + 2)
check(base2.Shield.Transparency == 1, "Sperre laeuft ab")

print("Verkaufen und Geschwindigkeit kaufen")
local before = p2:GetAttribute("Cash")
trigger(egg, p2)
check(p2:GetAttribute("Cash") > before, "eigenes Ei verkauft")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local Data = M.env.require(server.Data)
Data.addCash(p1, 1000)
remotes.BuySpeed.OnServerEvent:Fire(p1)
check(p1:GetAttribute("SpeedLevel") == 1, "Geschwindigkeit auf Stufe 1")
check(p1:GetAttribute("SkiSpeed") == 40, "Schi-Tempo gestiegen")
step(1)
remotes.Rebirth.OnServerEvent:Fire(p1)
check(p1:GetAttribute("Rebirths") == 0, "Wiedergeburt ohne genug Geld abgelehnt")
Data.addCash(p1, Config.rebirthCost(0))
step(1)
remotes.Rebirth.OnServerEvent:Fire(p1)
check(p1:GetAttribute("Rebirths") == 1 and p1:GetAttribute("Cash") == 0, "Wiedergeburt setzt Geld zurueck")

print("Speichern und Wiederkommen")
local egg4 = eggInZone(1)
root1.Position = egg4.Position
trigger(egg4, p1)
root1.Position = Vector3.new(-115, 3, -160)
step(3)
removePlayer(p1)
local saved = M.stored["P_101"]
check(saved ~= nil and saved.Rebirths == 1 and #saved.Eggs == 1, "Spielstand gespeichert (1 Ei, 1 Wiedergeburt)")
local countBefore = #eggFolder:GetChildren()
local p1b = addPlayer("Noah", 101)
step(1)
check(p1b:GetAttribute("Rebirths") == 1, "Spielstand wieder geladen")
check(#eggFolder:GetChildren() == countBefore + 1, "gespeichertes Ei steht wieder in der Basis")

removePlayer(p2)
removePlayer(p1b)
step(130)
M.closeHandler()

print(string.format("\nAlle %d Pruefungen bestanden.", passed))
