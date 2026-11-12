-- Herzstueck des Spiels: Nester, Eier, das Tragen und Abliefern, das Stehlen
-- aus fremden Basen und die Muetter, die den Dieb verfolgen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local World = require(script.Parent:WaitForChild("World"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Data = require(script.Parent:WaitForChild("Data"))

local Eggs = {}

Eggs.notify = function() end -- wird von Main gesetzt

local NEST_X = { -80, -58, -36, -14, 8, 30 }
local RETURN_SPEED = 160

local nests = {}
local carried = {} -- [player] = Ei-Datensatz
local lastFullWarning = {} -- [player] = Zeitpunkt der letzten "Basis voll"-Meldung
local eggFolder = nil

-- ---------------------------------------------------------------------------
-- Ei-Datensaetze
-- Zustand "Nest": liegt im Nest. "Carried": wird getragen. "Base": steht in einer Basis.
-- ---------------------------------------------------------------------------

local function eggSize(def)
	local scale = 1 + (def.zone - 1) * 0.15
	return Vector3.new(2.6 * scale, 3.4 * scale, 2.6 * scale)
end

local function onPrompt(record, player) end -- wird weiter unten definiert

local function createRecord(def)
	local size = eggSize(def)
	local part = World.part({
		Name = "Egg",
		Size = size,
		Color = def.color,
		Material = def.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		CanCollide = false,
		Massless = true,
	}, eggFolder)
	World.make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, part)

	local income = "$" .. Config.formatNumber(def.income) .. "/s"
	World.billboard(part, def.name .. "\n" .. income, 9, 3, size.Y / 2 + 2, def.color)

	local prompt = World.make("ProximityPrompt", {
		ActionText = "Steal",
		ObjectText = def.name,
		HoldDuration = 0.3,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
	}, part)

	local record = {
		def = def,
		part = part,
		prompt = prompt,
		state = "Nest",
		nest = nil,
		base = nil,
		slot = nil,
		carrier = nil,
		weld = nil,
	}

	prompt.Triggered:Connect(function(player)
		onPrompt(record, player)
	end)

	return record
end

local function detach(record)
	if record.weld then
		record.weld:Destroy()
		record.weld = nil
	end
	record.part.Anchored = true
	local player = record.carrier
	if player then
		if carried[player] == record then
			carried[player] = nil
		end
		player:SetAttribute("Carrying", nil)
		player:SetAttribute("Chased", nil)
		player:SetAttribute("MotherDistance", nil)
	end
	record.carrier = nil
end

local function attach(record, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	record.state = "Carried"
	record.carrier = player
	carried[player] = record
	record.prompt.Enabled = false

	record.part.Anchored = false
	record.part.CFrame = root.CFrame * CFrame.new(0, 3 + record.part.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = record.part
	weld.Parent = record.part
	record.weld = weld

	player:SetAttribute("Carrying", record.def.name)
	return true
end

local function toNest(record)
	local nest = record.nest
	detach(record)
	record.state = "Nest"
	record.part.CFrame = CFrame.new(nest.eggPosition + Vector3.new(0, record.part.Size.Y / 2, 0))
	record.part:SetAttribute("OwnerId", 0)
	record.prompt.HoldDuration = 0.3
	record.prompt.Enabled = true
	nest.egg = record
end

local function toSlot(record, base, slot)
	detach(record)
	if record.base and (record.base ~= base or record.slot ~= slot) then
		if record.base.slots[record.slot] == record then
			record.base.slots[record.slot] = nil
		end
	end
	record.nest = nil
	record.base = base
	record.slot = slot
	base.slots[slot] = record
	record.state = "Base"
	record.part.CFrame = CFrame.new(base.slotPositions[slot] + Vector3.new(0, record.part.Size.Y / 2, 0))
	record.part:SetAttribute("OwnerId", base.owner and base.owner.UserId or 0)
	record.prompt.HoldDuration = 1.2
	record.prompt.Enabled = true
end

local function destroyRecord(record)
	detach(record)
	if record.base and record.base.slots[record.slot] == record then
		record.base.slots[record.slot] = nil
	end
	record.base = nil
	record.state = "Gone"
	record.part:Destroy()
end

-- ---------------------------------------------------------------------------
-- Nester und Muetter
-- ---------------------------------------------------------------------------

local function pickEgg(zone)
	local total = 0
	for _, egg in ipairs(zone.eggs) do
		total = total + egg.weight
	end
	local roll = math.random() * total
	for _, egg in ipairs(zone.eggs) do
		roll = roll - egg.weight
		if roll <= 0 then
			return egg
		end
	end
	return zone.eggs[1]
end

local function spawnEgg(nest)
	local record = createRecord(pickEgg(nest.zone))
	record.nest = nest
	toNest(record)
end

local function buildMother(folder, zone)
	local info = zone.mother
	local s = info.size
	local model = Instance.new("Model")
	model.Name = info.name

	local function piece(name, size, offset, color, shape)
		return World.part({
			Name = name,
			Shape = shape or Enum.PartType.Block,
			Size = size * s,
			CFrame = CFrame.new(offset * s),
			Color = color,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		}, model)
	end

	-- Blickrichtung des Modells ist -Z
	local body = piece("Body", Vector3.new(6, 6, 6), Vector3.new(0, 0, 0), info.color, Enum.PartType.Ball)
	piece("Head", Vector3.new(4, 4, 4), Vector3.new(0, 4, -2), info.color, Enum.PartType.Ball)
	piece("Beak", Vector3.new(1.2, 1, 2), Vector3.new(0, 3.8, -4.4), Color3.fromRGB(255, 170, 40))
	piece("EyeL", Vector3.new(0.8, 0.8, 0.8), Vector3.new(-1, 4.8, -3.6), Color3.fromRGB(255, 40, 40), Enum.PartType.Ball)
	piece("EyeR", Vector3.new(0.8, 0.8, 0.8), Vector3.new(1, 4.8, -3.6), Color3.fromRGB(255, 40, 40), Enum.PartType.Ball)
	piece("WingL", Vector3.new(1, 3.5, 4.5), Vector3.new(-3.3, 0.5, 0.3), info.color)
	piece("WingR", Vector3.new(1, 3.5, 4.5), Vector3.new(3.3, 0.5, 0.3), info.color)
	piece("Tail", Vector3.new(2.5, 2, 2), Vector3.new(0, 1.5, 3.5), info.color)
	piece("LegL", Vector3.new(0.7, 2.5, 0.7), Vector3.new(-1.2, -3.6, 0), Color3.fromRGB(255, 170, 40))
	piece("LegR", Vector3.new(0.7, 2.5, 0.7), Vector3.new(1.2, -3.6, 0), Color3.fromRGB(255, 170, 40))

	model.PrimaryPart = body
	World.billboard(body, info.name, 12 * s, 3 * s, 8 * s, Color3.fromRGB(255, 90, 90))
	model.Parent = folder
	return model
end

local function placeMother(nest, position, lookDirection)
	-- Die Fuesse stehen 4.85 * Groesse unter der Koerpermitte
	local y = Config.groundHeight(position.Z) + 4.85 * nest.zone.mother.size
	local center = Vector3.new(position.X, y, position.Z)
	local flat = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if flat.Magnitude < 0.001 then
		flat = Vector3.new(0, 0, -1)
	end
	nest.motherPosition = Vector3.new(position.X, 0, position.Z)
	nest.model:PivotTo(CFrame.lookAt(center, center + flat))
end

local function buildNests(mapFolder)
	local folder = World.make("Folder", { Name = "Nests" }, mapFolder)
	eggFolder = World.make("Folder", { Name = "Eggs" }, mapFolder)

	for zoneIndex, zone in ipairs(Config.ZONES) do
		local terraceZ, terraceY = Config.terraceStart(zoneIndex)
		local nestZ = terraceZ + Config.TERRACE_LENGTH / 2 - 5
		for _, x in ipairs(NEST_X) do
			World.part({
				Name = "Nest",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, 7, 7),
				CFrame = CFrame.new(x, terraceY + 0.5, nestZ) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(140, 105, 60),
				Material = Enum.Material.Wood,
				CanCollide = false,
			}, folder)

			local nest = {
				zone = zone,
				zoneIndex = zoneIndex,
				eggPosition = Vector3.new(x, terraceY + 1, nestZ),
				home = Vector3.new(x, 0, nestZ + 14),
				model = buildMother(folder, zone),
				motherPosition = Vector3.new(x, 0, nestZ + 14),
				motherState = "Idle",
				target = nil,
				targetRecord = nil,
				wakeAt = 0,
				egg = nil,
				respawnAt = nil,
			}
			placeMother(nest, nest.home, Vector3.new(0, 0, -1))
			table.insert(nests, nest)
			spawnEgg(nest)
		end
	end
end

local function stun(player)
	player:SetAttribute("Stunned", true)
	task.delay(Config.STUN_TIME, function()
		if player.Parent then
			player:SetAttribute("Stunned", nil)
		end
	end)
end

local function updateMother(nest, dt)
	local state = nest.motherState
	if state == "Idle" then
		return
	end

	if state == "Wake" then
		if os.clock() >= nest.wakeAt then
			nest.motherState = "Chase"
		end
		return
	end

	if state == "Chase" then
		local player = nest.target
		local record = nest.targetRecord
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or record.carrier ~= player or record.state ~= "Carried" then
			nest.motherState = "Return"
			return
		end

		local targetPosition = root.Position
		if targetPosition.Z < Config.SLOPE_START_Z - 2 then
			-- Der Dieb hat die Lobby erreicht: entkommen
			player:SetAttribute("Chased", nil)
			player:SetAttribute("MotherDistance", nil)
			Eggs.notify(player, "You escaped the " .. nest.zone.mother.name .. "! Bring the egg to your base.", "good")
			nest.motherState = "Return"
			return
		end

		local flatTarget = Vector3.new(targetPosition.X, 0, targetPosition.Z)
		local offset = flatTarget - nest.motherPosition
		local distance = offset.Magnitude
		local catchRadius = 4 + 3 * nest.zone.mother.size
		local motherY = Config.groundHeight(nest.motherPosition.Z)

		if distance <= catchRadius and math.abs(targetPosition.Y - motherY) < 30 then
			toNest(record)
			stun(player)
			Eggs.notify(player, "The " .. nest.zone.mother.name .. " caught you and took her egg back!", "bad")
			nest.motherState = "Return"
			return
		end

		local step = math.min(nest.zone.mother.speed * dt, distance)
		local direction = offset.Unit
		placeMother(nest, nest.motherPosition + direction * step, direction)
		player:SetAttribute("MotherDistance", math.floor(distance))
		return
	end

	if state == "Return" then
		nest.target = nil
		nest.targetRecord = nil
		local offset = nest.home - nest.motherPosition
		local distance = offset.Magnitude
		if distance < 1 then
			placeMother(nest, nest.home, Vector3.new(0, 0, -1))
			nest.motherState = "Idle"
			return
		end
		local step = math.min(RETURN_SPEED * dt, distance)
		local direction = offset.Unit
		placeMother(nest, nest.motherPosition + direction * step, direction)
	end
end

-- ---------------------------------------------------------------------------
-- Aktionen der Spieler
-- ---------------------------------------------------------------------------

onPrompt = function(record, player)
	if record.state == "Nest" then
		if carried[player] then
			Eggs.notify(player, "You can only carry one egg at a time!", "bad")
			return
		end
		local nest = record.nest
		if not attach(record, player) then
			return
		end
		nest.egg = nil
		nest.respawnAt = nil
		nest.target = player
		nest.targetRecord = record
		nest.wakeAt = os.clock() + Config.MOTHER_WAKE_TIME
		nest.motherState = "Wake"
		player:SetAttribute("Chased", true)
		Eggs.notify(player, "The " .. nest.zone.mother.name .. " is angry! SKI DOWN!", "bad")
		return
	end

	if record.state == "Base" then
		local base = record.base
		local owner = base.owner

		if owner == player then
			-- Eigenes Ei verkaufen
			local value = record.def.income * Config.SELL_SECONDS
			destroyRecord(record)
			Data.addCash(player, value)
			Eggs.notify(player, "Sold " .. record.def.name .. " for $" .. Config.formatNumber(value), "good")
			return
		end

		if Bases.isLocked(base) then
			Eggs.notify(player, "This base is locked!", "bad")
			return
		end
		if carried[player] then
			Eggs.notify(player, "You can only carry one egg at a time!", "bad")
			return
		end
		if not Bases.of(player) then
			return
		end
		if attach(record, player) then
			Eggs.notify(player, "You stole a " .. record.def.name .. "! Run to your base!", "good")
			if owner then
				Eggs.notify(owner, player.DisplayName .. " is stealing your " .. record.def.name .. "! Touch them to get it back!", "bad")
			end
		end
	end
end

-- Ei verlieren (Tod, Verlassen des Spiels): zurueck dorthin, wo es herkam
function Eggs.drop(player)
	local record = carried[player]
	if not record then
		return
	end
	if record.nest then
		toNest(record)
	elseif record.base and record.base.owner then
		toSlot(record, record.base, record.slot)
	else
		destroyRecord(record)
	end
end

local function checkCarriers()
	for player, record in pairs(carried) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local position = root.Position
			local delivered = false

			-- Abliefern in der eigenen Basis
			local ownBase = Bases.of(player)
			if ownBase and Bases.contains(ownBase, position) then
				local slot = Bases.freeSlot(ownBase)
				if slot then
					local nest = record.nest
					if nest then
						nest.respawnAt = os.clock() + Config.NEST_RESPAWN
					end
					local victim = record.base and record.base.owner
					toSlot(record, ownBase, slot)
					delivered = true
					Eggs.notify(player, record.def.name .. " secured! +$" .. Config.formatNumber(record.def.income) .. "/s", "good")
					if victim and victim ~= player then
						Eggs.notify(victim, player.DisplayName .. " stole your " .. record.def.name .. "!", "bad")
					end
				else
					local now = os.clock()
					if not lastFullWarning[player] or now - lastFullWarning[player] > 4 then
						lastFullWarning[player] = now
						Eggs.notify(player, "Your base is full! Sell an egg first.", "bad")
					end
				end
			end

			-- Besitzer holt sein gestohlenes Ei zurueck
			if not delivered and record.base and record.base.owner and record.base.owner ~= player then
				local owner = record.base.owner
				local ownerRoot = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
				if ownerRoot and (ownerRoot.Position - position).Magnitude <= Config.RECAPTURE_RADIUS then
					toSlot(record, record.base, record.slot)
					stun(player)
					Eggs.notify(owner, "You got your " .. record.def.name .. " back!", "good")
					Eggs.notify(player, owner.DisplayName .. " caught you!", "bad")
				end
			end
		end
	end
end

local function payIncome()
	for _, base in ipairs(Bases.all()) do
		local owner = base.owner
		if owner then
			local total = 0
			for slot = 1, Config.BASE_SLOTS do
				local record = base.slots[slot]
				if record and record.state == "Base" then
					total = total + record.def.income
				end
			end
			if total > 0 then
				local profile = Data.get(owner)
				if profile then
					Data.addCash(owner, total * Config.incomeMultiplier(profile.Rebirths))
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Schnittstelle fuer Main
-- ---------------------------------------------------------------------------

function Eggs.build(mapFolder)
	buildNests(mapFolder)
end

-- Gespeicherte Eier beim Betreten wieder in die Basis stellen
function Eggs.restore(player, eggIds)
	local base = Bases.of(player)
	if not base then
		return
	end
	for _, id in ipairs(eggIds) do
		local def = Config.EGGS_BY_ID[id]
		local slot = Bases.freeSlot(base)
		if def and slot then
			toSlot(createRecord(def), base, slot)
		end
	end
end

-- Liste der Eier, die einem Spieler gehoeren (zum Speichern)
function Eggs.listFor(player)
	local list = {}
	local base = Bases.of(player)
	if base then
		for slot = 1, Config.BASE_SLOTS do
			local record = base.slots[slot]
			if record then
				table.insert(list, record.def.id)
			end
		end
	end
	return list
end

-- Alle Eier einer Basis entfernen (Spieler geht oder macht eine Wiedergeburt)
function Eggs.clearBase(player)
	local base = Bases.of(player)
	if not base then
		return
	end
	for slot = 1, Config.BASE_SLOTS do
		local record = base.slots[slot]
		if record then
			local thief = record.carrier
			destroyRecord(record)
			if thief and thief ~= player then
				Eggs.notify(thief, "The owner left - the egg vanished.", "bad")
			end
		end
	end
end

function Eggs.forget(player)
	lastFullWarning[player] = nil
end

local carrierTimer = 0
local incomeTimer = 0

function Eggs.update(dt)
	local now = os.clock()
	for _, nest in ipairs(nests) do
		updateMother(nest, dt)
		if not nest.egg and nest.respawnAt and now >= nest.respawnAt and nest.motherState == "Idle" then
			nest.respawnAt = nil
			spawnEgg(nest)
		end
	end

	carrierTimer = carrierTimer + dt
	if carrierTimer >= 0.15 then
		carrierTimer = 0
		checkCarriers()
	end

	incomeTimer = incomeTimer + dt
	if incomeTimer >= 1 then
		incomeTimer = incomeTimer - 1
		payIncome()
		Bases.tick()
	end
end

return Eggs
