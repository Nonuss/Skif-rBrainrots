-- Die Basen in der Lobby: jeder Spieler bekommt eine. Dort stehen seine Eier
-- und verdienen Geld. Andere Spieler koennen sie stehlen, solange die Basis
-- nicht gesperrt ist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local World = require(script.Parent:WaitForChild("World"))

local Bases = {}

local BASE_SIZE = 60
local HALF = BASE_SIZE / 2
local BASE_CENTER_X = 115
local BASE_Z = { -160, -90, -20, 50 }

local bases = {}
local byPlayer = {}

Bases.notify = function() end -- wird von Main gesetzt

local function buildBase(folder, index, side, centerZ)
	local centerX = side * BASE_CENTER_X
	local model = World.make("Folder", { Name = "Base" .. index }, folder)

	World.part({
		Name = "Floor",
		Size = Vector3.new(BASE_SIZE, 0.4, BASE_SIZE),
		Position = Vector3.new(centerX, 0.2, centerZ),
		Color = Color3.fromRGB(70, 80, 110),
		Material = Enum.Material.Concrete,
	}, model)

	-- Rueckwand und Seitenwaende (vorne offen)
	local wallColor = Color3.fromRGB(50, 58, 85)
	World.part({
		Name = "BackWall",
		Size = Vector3.new(1, 12, BASE_SIZE),
		Position = Vector3.new(centerX + side * (HALF - 0.5), 6, centerZ),
		Color = wallColor,
	}, model)
	for _, zSide in ipairs({ -1, 1 }) do
		World.part({
			Name = "SideWall",
			Size = Vector3.new(BASE_SIZE, 12, 1),
			Position = Vector3.new(centerX, 6, centerZ + zSide * (HALF - 0.5)),
			Color = wallColor,
		}, model)
	end

	-- Podeste fuer die Eier: 2 Reihen mit je 4 Plaetzen
	local slotPositions = {}
	for row = 0, 1 do
		for column = 0, 3 do
			local x = centerX + side * (2 + row * 15)
			local z = centerZ - 19.5 + column * 13
			World.part({
				Name = "Pedestal",
				Size = Vector3.new(5, 2, 5),
				Position = Vector3.new(x, 1.4, z),
				Color = Color3.fromRGB(200, 205, 220),
				Material = Enum.Material.Marble,
			}, model)
			table.insert(slotPositions, Vector3.new(x, 2.4, z))
		end
	end

	-- Schild mit dem Namen des Besitzers
	local signPost = World.part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(centerX - side * HALF, 14, centerZ),
		Transparency = 1,
		CanCollide = false,
	}, model)
	local label = World.billboard(signPost, "Empty Base", 30, 7, 0, Color3.new(1, 1, 1))

	-- Sperrflaeche am Eingang
	local lockPad = World.part({
		Name = "LockPad",
		Size = Vector3.new(7, 0.3, 7),
		Position = Vector3.new(centerX - side * (HALF - 6), 0.55, centerZ - HALF + 7),
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)
	local lockLabel = World.billboard(lockPad, "LOCK BASE", 10, 3, 4, Color3.fromRGB(255, 120, 120))

	-- Schutzschild, sichtbar solange die Basis gesperrt ist
	local shield = World.part({
		Name = "Shield",
		Size = Vector3.new(BASE_SIZE, 14, BASE_SIZE),
		Position = Vector3.new(centerX, 7, centerZ),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	}, model)

	local base = {
		index = index,
		centerX = centerX,
		centerZ = centerZ,
		owner = nil,
		slots = {},
		slotPositions = slotPositions,
		lockedUntil = 0,
		label = label,
		lockLabel = lockLabel,
		shield = shield,
	}

	lockPad.Touched:Connect(function(hit)
		local owner = base.owner
		if not owner or not owner.Character then
			return
		end
		if not hit:IsDescendantOf(owner.Character) then
			return
		end
		if os.clock() < base.lockedUntil then
			return
		end
		base.lockedUntil = os.clock() + Config.LOCK_DURATION
		base.shield.Transparency = 0.6
		Bases.notify(owner, "Base locked for " .. Config.LOCK_DURATION .. " seconds!", "good")
	end)

	return base
end

function Bases.build(mapFolder)
	local folder = World.make("Folder", { Name = "Bases" }, mapFolder)
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, centerZ in ipairs(BASE_Z) do
			index = index + 1
			bases[index] = buildBase(folder, index, side, centerZ)
		end
	end
end

function Bases.assign(player)
	for _, base in ipairs(bases) do
		if not base.owner then
			base.owner = player
			base.lockedUntil = 0
			base.label.Text = player.DisplayName .. "'s Base"
			byPlayer[player] = base
			return base
		end
	end
	return nil
end

function Bases.release(player)
	local base = byPlayer[player]
	if not base then
		return
	end
	base.owner = nil
	base.slots = {}
	base.lockedUntil = 0
	base.shield.Transparency = 1
	base.label.Text = "Empty Base"
	base.lockLabel.Text = "LOCK BASE"
	byPlayer[player] = nil
end

function Bases.of(player)
	return byPlayer[player]
end

function Bases.all()
	return bases
end

function Bases.isLocked(base)
	return os.clock() < base.lockedUntil
end

function Bases.contains(base, position)
	return math.abs(position.X - base.centerX) <= HALF
		and math.abs(position.Z - base.centerZ) <= HALF
		and position.Y < 20
end

function Bases.freeSlot(base)
	for slot = 1, Config.BASE_SLOTS do
		if not base.slots[slot] then
			return slot
		end
	end
	return nil
end

-- Einmal pro Sekunde: Anzeige der Sperrzeit aktualisieren
function Bases.tick()
	local now = os.clock()
	for _, base in ipairs(bases) do
		if base.owner then
			local remaining = base.lockedUntil - now
			if remaining > 0 then
				base.lockLabel.Text = "LOCKED " .. math.ceil(remaining) .. "s"
			else
				base.lockLabel.Text = "LOCK BASE"
				if base.shield.Transparency ~= 1 then
					base.shield.Transparency = 1
				end
			end
		end
	end
end

return Bases
