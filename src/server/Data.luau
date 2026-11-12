-- Spielstand: Geld, Geschwindigkeitsstufe, Wiedergeburten und Eier.
-- Wird dauerhaft gespeichert, sobald das Spiel veroeffentlicht ist und in Studio
-- unter "Game Settings > Security" der Zugriff auf API-Dienste erlaubt wurde.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Data = {}

local STORE_NAME = "SkiEggHeist_v1"
local profiles = {} -- [player] = Profil
local store = nil

-- Wird von Main gesetzt: liefert die aktuelle Ei-Liste eines Spielers
Data.collectEggs = nil

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		else
			store = false
			warn("[Data] Speichern nicht verfuegbar: " .. tostring(result))
		end
	end
	return store or nil
end

local function publish(player, profile)
	player:SetAttribute("Cash", profile.Cash)
	player:SetAttribute("SpeedLevel", profile.SpeedLevel)
	player:SetAttribute("Rebirths", profile.Rebirths)
	player:SetAttribute("WalkSpeed", Config.walkSpeed(profile.SpeedLevel))
	player:SetAttribute("SkiSpeed", Config.skiSpeed(profile.SpeedLevel))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local cash = stats:FindFirstChild("Cash")
		local rebirths = stats:FindFirstChild("Rebirths")
		if cash then
			cash.Value = math.floor(profile.Cash)
		end
		if rebirths then
			rebirths.Value = profile.Rebirths
		end
	end
end

function Data.load(player)
	local profile = { Cash = 0, SpeedLevel = 0, Rebirths = 0, Eggs = {}, canSave = false }

	local dataStore = getStore()
	if dataStore then
		local ok, saved = pcall(function()
			return dataStore:GetAsync("P_" .. player.UserId)
		end)
		if ok then
			profile.canSave = true
			if type(saved) == "table" then
				profile.Cash = tonumber(saved.Cash) or 0
				profile.SpeedLevel = math.min(tonumber(saved.SpeedLevel) or 0, Config.MAX_SPEED_LEVEL)
				profile.Rebirths = tonumber(saved.Rebirths) or 0
				if type(saved.Eggs) == "table" then
					for _, id in ipairs(saved.Eggs) do
						if Config.EGGS_BY_ID[id] then
							table.insert(profile.Eggs, id)
						end
					end
				end
			end
		else
			-- Laden fehlgeschlagen: nicht speichern, sonst wuerde der alte Stand ueberschrieben
			warn("[Data] Laden fehlgeschlagen fuer " .. player.Name .. ": " .. tostring(saved))
		end
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player

	profiles[player] = profile
	publish(player, profile)
	return profile
end

function Data.get(player)
	return profiles[player]
end

function Data.save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave then
		return
	end
	local dataStore = getStore()
	if not dataStore then
		return
	end
	if Data.collectEggs then
		profile.Eggs = Data.collectEggs(player)
	end
	local payload = {
		Cash = math.floor(profile.Cash),
		SpeedLevel = profile.SpeedLevel,
		Rebirths = profile.Rebirths,
		Eggs = profile.Eggs,
	}
	local ok, err = pcall(function()
		dataStore:SetAsync("P_" .. player.UserId, payload)
	end)
	if not ok then
		warn("[Data] Speichern fehlgeschlagen fuer " .. player.Name .. ": " .. tostring(err))
	end
end

function Data.release(player)
	profiles[player] = nil
end

function Data.saveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		Data.save(player)
	end
end

function Data.addCash(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Cash = profile.Cash + amount
	publish(player, profile)
end

-- Kauft die naechste Geschwindigkeitsstufe. Gibt true und einen Text zurueck.
function Data.buySpeed(player)
	local profile = profiles[player]
	if not profile then
		return false, ""
	end
	if profile.SpeedLevel >= Config.MAX_SPEED_LEVEL then
		return false, "Speed is already at maximum!"
	end
	local cost = Config.upgradeCost(profile.SpeedLevel)
	if profile.Cash < cost then
		return false, "Not enough cash! You need $" .. Config.formatNumber(cost)
	end
	profile.Cash = profile.Cash - cost
	profile.SpeedLevel = profile.SpeedLevel + 1
	publish(player, profile)
	return true, "Speed upgraded to level " .. profile.SpeedLevel .. "!"
end

-- Prueft und bezahlt die Wiedergeburt. Das Leeren der Basis uebernimmt Main.
function Data.rebirth(player)
	local profile = profiles[player]
	if not profile then
		return false, ""
	end
	local cost = Config.rebirthCost(profile.Rebirths)
	if profile.Cash < cost then
		return false, "Rebirth costs $" .. Config.formatNumber(cost)
	end
	profile.Cash = 0
	profile.SpeedLevel = 0
	profile.Rebirths = profile.Rebirths + 1
	profile.Eggs = {}
	publish(player, profile)
	return true, "Rebirth " .. profile.Rebirths .. "! Income x" .. Config.incomeMultiplier(profile.Rebirths)
end

return Data
