-- Zentrale Einstellungen des Spiels.
-- Alles, was man zum Ausbalancieren braucht (Preise, Geschwindigkeiten, Eier), steht hier.

local Config = {}

-- ---------------------------------------------------------------------------
-- Karte
-- ---------------------------------------------------------------------------
Config.LOBBY_MIN_X = -150
Config.LOBBY_MAX_X = 150
Config.LOBBY_MIN_Z = -200
Config.LOBBY_MAX_Z = 100

Config.SLOPE_START_Z = 100 -- ab hier beginnt der Berg (Richtung +Z geht es bergauf)
Config.SLOPE_HALF_WIDTH = 100 -- halbe Pistenbreite
Config.SLOPE_RUN = 220 -- waagrechte Laenge eines Hangstuecks
Config.SLOPE_RISE = 80 -- Hoehengewinn eines Hangstuecks
Config.TERRACE_LENGTH = 70 -- Laenge der flachen Zone mit den Nestern

-- ---------------------------------------------------------------------------
-- Spieler
-- ---------------------------------------------------------------------------
Config.MAX_SPEED_LEVEL = 20
Config.BASE_SLOTS = 8
Config.SELL_SECONDS = 30 -- Verkaufswert = Einkommen pro Sekunde * dieser Wert
Config.LOCK_DURATION = 60 -- Sekunden, die eine Basis gesperrt bleibt
Config.NEST_RESPAWN = 15 -- Sekunden, bis in einem leeren Nest ein neues Ei liegt
Config.STUN_TIME = 2.5 -- Sekunden Betaeubung, wenn die Mutter einen erwischt
Config.MOTHER_WAKE_TIME = 1.2 -- Vorsprung, bevor die Mutter losrennt
Config.RECAPTURE_RADIUS = 7 -- Abstand, in dem ein Besitzer sein Ei zurueckholt

function Config.walkSpeed(level)
	return 16 + level
end

function Config.skiSpeed(level)
	return 36 + 4 * level
end

function Config.upgradeCost(level)
	return math.floor(100 * (1.55 ^ level))
end

function Config.rebirthCost(rebirths)
	return 1000000 * (4 ^ rebirths)
end

function Config.incomeMultiplier(rebirths)
	return 1 + 0.5 * rebirths
end

-- ---------------------------------------------------------------------------
-- Zonen (von unten nach oben). Je hoeher, desto wertvoller die Eier und
-- desto schneller die Mutter.
-- income = Geld pro Sekunde, weight = Haeufigkeit im Nest.
-- ---------------------------------------------------------------------------
Config.ZONES = {
	{
		name = "Pine Valley",
		color = Color3.fromRGB(120, 200, 120),
		mother = { name = "Snow Hen", speed = 30, size = 1.0, color = Color3.fromRGB(245, 245, 245) },
		eggs = {
			{ id = "snow", name = "Snow Egg", income = 2, weight = 60, color = Color3.fromRGB(240, 240, 250) },
			{ id = "pine", name = "Pine Egg", income = 4, weight = 30, color = Color3.fromRGB(90, 160, 90) },
			{ id = "berry", name = "Frostberry Egg", income = 8, weight = 10, color = Color3.fromRGB(200, 70, 110) },
		},
	},
	{
		name = "Frozen Lake",
		color = Color3.fromRGB(110, 190, 240),
		mother = { name = "Ice Goose", speed = 44, size = 1.3, color = Color3.fromRGB(170, 220, 255) },
		eggs = {
			{ id = "ice", name = "Ice Egg", income = 15, weight = 60, color = Color3.fromRGB(150, 210, 255) },
			{ id = "pearl", name = "Pearl Egg", income = 30, weight = 30, color = Color3.fromRGB(250, 235, 255) },
			{ id = "aqua", name = "Deep Aqua Egg", income = 60, weight = 10, color = Color3.fromRGB(0, 150, 200) },
		},
	},
	{
		name = "Crystal Ridge",
		color = Color3.fromRGB(190, 130, 255),
		mother = { name = "Crystal Owl", speed = 60, size = 1.6, color = Color3.fromRGB(190, 140, 255) },
		eggs = {
			{ id = "amethyst", name = "Amethyst Egg", income = 120, weight = 60, color = Color3.fromRGB(160, 90, 220) },
			{ id = "ruby", name = "Ruby Egg", income = 240, weight = 30, color = Color3.fromRGB(220, 40, 60) },
			{ id = "prism", name = "Prism Egg", income = 500, weight = 10, color = Color3.fromRGB(255, 120, 230), neon = true },
		},
	},
	{
		name = "Storm Cliffs",
		color = Color3.fromRGB(255, 190, 70),
		mother = { name = "Thunder Hawk", speed = 80, size = 2.0, color = Color3.fromRGB(90, 90, 110) },
		eggs = {
			{ id = "storm", name = "Storm Egg", income = 1000, weight = 60, color = Color3.fromRGB(90, 100, 130) },
			{ id = "bolt", name = "Lightning Egg", income = 2000, weight = 30, color = Color3.fromRGB(255, 230, 60), neon = true },
			{ id = "gold", name = "Golden Egg", income = 4000, weight = 10, color = Color3.fromRGB(255, 190, 0), neon = true },
		},
	},
	{
		name = "Dragon Summit",
		color = Color3.fromRGB(255, 80, 80),
		mother = { name = "Frost Dragon", speed = 104, size = 2.6, color = Color3.fromRGB(60, 200, 220) },
		eggs = {
			{ id = "dragon", name = "Dragon Egg", income = 8000, weight = 60, color = Color3.fromRGB(200, 50, 50) },
			{ id = "aurora", name = "Aurora Egg", income = 16000, weight = 30, color = Color3.fromRGB(80, 255, 180), neon = true },
			{ id = "void", name = "Void Egg", income = 40000, weight = 10, color = Color3.fromRGB(120, 0, 255), neon = true },
		},
	},
}

Config.ZONE_COUNT = #Config.ZONES

-- Nachschlagetabelle: Ei-Kennung -> Ei-Daten (inklusive Zonennummer)
Config.EGGS_BY_ID = {}
for zoneIndex, zone in ipairs(Config.ZONES) do
	for _, egg in ipairs(zone.eggs) do
		egg.zone = zoneIndex
		Config.EGGS_BY_ID[egg.id] = egg
	end
end

-- ---------------------------------------------------------------------------
-- Gelaendeform. Der Berg ist eine Treppe aus Haengen und flachen Zonen;
-- diese Funktion liefert die Bodenhoehe fuer jede Z-Position.
-- ---------------------------------------------------------------------------
function Config.groundHeight(z)
	local s = z - Config.SLOPE_START_Z
	if s <= 0 then
		return 0
	end
	local segment = Config.SLOPE_RUN + Config.TERRACE_LENGTH
	local index = math.floor(s / segment)
	if index >= Config.ZONE_COUNT then
		return Config.ZONE_COUNT * Config.SLOPE_RISE
	end
	local rest = s - index * segment
	if rest >= Config.SLOPE_RUN then
		return (index + 1) * Config.SLOPE_RISE
	end
	return index * Config.SLOPE_RISE + rest / Config.SLOPE_RUN * Config.SLOPE_RISE
end

-- Anfang (Z) und Hoehe (Y) der flachen Zone mit der Nummer zoneIndex
function Config.terraceStart(zoneIndex)
	local segment = Config.SLOPE_RUN + Config.TERRACE_LENGTH
	local z = Config.SLOPE_START_Z + (zoneIndex - 1) * segment + Config.SLOPE_RUN
	return z, zoneIndex * Config.SLOPE_RISE
end

Config.MOUNTAIN_END_Z = Config.SLOPE_START_Z + Config.ZONE_COUNT * (Config.SLOPE_RUN + Config.TERRACE_LENGTH)

-- Zahlen kurz darstellen: 1500 -> 1.5K
function Config.formatNumber(n)
	n = math.floor(n)
	local units = { "", "K", "M", "B", "T", "Qa" }
	local unit = 1
	local value = n
	while value >= 1000 and unit < #units do
		value = value / 1000
		unit = unit + 1
	end
	if unit == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", value, units[unit])
end

return Config
