-- Baut die gesamte Karte beim Serverstart: Lobby, Berg, Zonen, Dekoration.
-- Dadurch funktioniert das Spiel auch in einem voellig leeren Platz.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local World = {}

-- Kleine Hilfsfunktion: Instanz anlegen, Eigenschaften setzen, einhaengen.
function World.make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local make = World.make

-- Verankertes Bauteil mit sinnvollen Standardwerten
function World.part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Schwebender Text ueber einem Bauteil. Gibt das TextLabel zurueck.
function World.billboard(parent, text, width, height, offsetY, color)
	local gui = make("BillboardGui", {
		Size = UDim2.new(width, 0, height, 0),
		StudsOffset = Vector3.new(0, offsetY, 0),
		MaxDistance = 250,
		AlwaysOnTop = false,
		LightInfluence = 0,
	}, parent)
	local label = make("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
	}, gui)
	return label
end

local SNOW = Color3.fromRGB(245, 248, 255)

local function buildLobby(folder)
	local width = Config.LOBBY_MAX_X - Config.LOBBY_MIN_X
	local depth = Config.LOBBY_MAX_Z - Config.LOBBY_MIN_Z
	local centerZ = (Config.LOBBY_MAX_Z + Config.LOBBY_MIN_Z) / 2

	World.part({
		Name = "LobbyFloor",
		Size = Vector3.new(width, 4, depth),
		Position = Vector3.new(0, -2, centerZ),
		Color = SNOW,
		Material = Enum.Material.Snow,
	}, folder)

	-- Mittelweg, damit die Lobby nicht nur weiss ist
	World.part({
		Name = "Path",
		Size = Vector3.new(40, 0.2, depth),
		Position = Vector3.new(0, 0.05, centerZ),
		Color = Color3.fromRGB(150, 160, 175),
		Material = Enum.Material.Slate,
		CanCollide = false,
	}, folder)

	make("SpawnLocation", {
		Name = "Spawn",
		Anchored = true,
		Size = Vector3.new(14, 1, 14),
		Position = Vector3.new(0, 0.5, -50),
		Color = Color3.fromRGB(80, 170, 255),
		Material = Enum.Material.Neon,
		Duration = 0,
		Neutral = true,
		TopSurface = Enum.SurfaceType.Smooth,
	}, folder)

	-- Unsichtbare Begrenzungen der Lobby
	local wallHeight = 120
	local function wall(size, position)
		World.part({
			Name = "Barrier",
			Size = size,
			Position = position,
			Transparency = 1,
		}, folder)
	end
	wall(Vector3.new(2, wallHeight, depth), Vector3.new(Config.LOBBY_MIN_X - 1, wallHeight / 2, centerZ))
	wall(Vector3.new(2, wallHeight, depth), Vector3.new(Config.LOBBY_MAX_X + 1, wallHeight / 2, centerZ))
	wall(Vector3.new(width, wallHeight, 2), Vector3.new(0, wallHeight / 2, Config.LOBBY_MIN_Z - 1))
	local sideWidth = Config.LOBBY_MAX_X - Config.SLOPE_HALF_WIDTH
	local sideCenter = Config.SLOPE_HALF_WIDTH + sideWidth / 2
	wall(Vector3.new(sideWidth, wallHeight, 2), Vector3.new(sideCenter, wallHeight / 2, Config.LOBBY_MAX_Z + 1))
	wall(Vector3.new(sideWidth, wallHeight, 2), Vector3.new(-sideCenter, wallHeight / 2, Config.LOBBY_MAX_Z + 1))

	-- Erklaertafel beim Spawn
	local board = World.part({
		Name = "HowToPlay",
		Size = Vector3.new(34, 16, 1),
		Position = Vector3.new(0, 11, -90),
		Color = Color3.fromRGB(40, 50, 80),
	}, folder)
	World.part({
		Name = "BoardPost",
		Size = Vector3.new(2, 4, 1),
		Position = Vector3.new(0, 2, -90),
		Color = Color3.fromRGB(90, 70, 50),
		Material = Enum.Material.Wood,
	}, folder)
	local surface = make("SurfaceGui", {
		Face = Enum.NormalId.Back,
		CanvasSize = Vector2.new(680, 320),
	}, board)
	make("TextLabel", {
		Size = UDim2.new(1, -30, 1, -30),
		Position = UDim2.new(0, 15, 0, 15),
		BackgroundTransparency = 1,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "HOW TO PLAY\n1. Ride the ski lift up the mountain\n2. Steal an egg from a nest\n3. Ski down - the mother will chase you!\n4. Bring the egg to your base to earn cash\n5. Buy speed to reach higher zones",
	}, surface)
end

local function buildMountain(folder)
	local width = Config.SLOPE_HALF_WIDTH * 2
	local thickness = 6
	local run = Config.SLOPE_RUN
	local rise = Config.SLOPE_RISE
	local length = math.sqrt(run * run + rise * rise)

	for zoneIndex = 1, Config.ZONE_COUNT do
		local terraceZ, terraceY = Config.terraceStart(zoneIndex)
		local z0 = terraceZ - run
		local y0 = terraceY - rise

		-- Hang
		local mid = Vector3.new(0, (y0 + terraceY) / 2, (z0 + terraceZ) / 2)
		local top = Vector3.new(0, terraceY, terraceZ)
		World.part({
			Name = "Slope" .. zoneIndex,
			Size = Vector3.new(width, thickness, length + 0.5),
			CFrame = CFrame.lookAt(mid, top) * CFrame.new(0, -thickness / 2, 0),
			Color = SNOW,
			Material = Enum.Material.Snow,
		}, folder)

		-- Flache Zone mit den Nestern
		local zone = Config.ZONES[zoneIndex]
		World.part({
			Name = "Terrace" .. zoneIndex,
			Size = Vector3.new(width, thickness, Config.TERRACE_LENGTH),
			Position = Vector3.new(0, terraceY - thickness / 2, terraceZ + Config.TERRACE_LENGTH / 2),
			Color = SNOW,
			Material = Enum.Material.Snow,
		}, folder)

		-- Farbstreifen, damit man die Zone von weitem erkennt
		World.part({
			Name = "ZoneStripe" .. zoneIndex,
			Size = Vector3.new(width, 0.2, 4),
			Position = Vector3.new(0, terraceY + 0.05, terraceZ + 2),
			Color = zone.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, folder)

		-- Zonenschild
		local post = World.part({
			Name = "ZoneSign" .. zoneIndex,
			Size = Vector3.new(1, 12, 1),
			Position = Vector3.new(90, terraceY + 6, terraceZ + Config.TERRACE_LENGTH - 6),
			Color = Color3.fromRGB(90, 70, 50),
			Material = Enum.Material.Wood,
		}, folder)
		World.billboard(post, "ZONE " .. zoneIndex .. "\n" .. zone.name, 26, 9, 11, zone.color)
	end

	-- Unsichtbare Seitenwaende und Rueckwand, damit niemand vom Berg faellt
	local mountainLength = Config.MOUNTAIN_END_Z - Config.SLOPE_START_Z
	local topY = Config.ZONE_COUNT * rise
	local wallHeight = topY + 200
	local centerZ = Config.SLOPE_START_Z + mountainLength / 2
	for _, side in ipairs({ -1, 1 }) do
		World.part({
			Name = "MountainWall",
			Size = Vector3.new(2, wallHeight, mountainLength),
			Position = Vector3.new(side * (Config.SLOPE_HALF_WIDTH + 1), wallHeight / 2 - 20, centerZ),
			Transparency = 1,
		}, folder)
	end
	World.part({
		Name = "MountainBackWall",
		Size = Vector3.new(width, 260, 2),
		Position = Vector3.new(0, topY + 110, Config.MOUNTAIN_END_Z + 1),
		Transparency = 1,
	}, folder)

	-- Sichtbare Felswand hinter dem Gipfel
	World.part({
		Name = "Peak",
		Size = Vector3.new(width, 90, 30),
		Position = Vector3.new(0, topY + 30, Config.MOUNTAIN_END_Z + 17),
		Color = Color3.fromRGB(120, 125, 140),
		Material = Enum.Material.Rock,
	}, folder)

	-- Baeume am linken Pistenrand (rechts faehrt der Lift)
	local treeFolder = make("Folder", { Name = "Trees" }, folder)
	local z = Config.SLOPE_START_Z + 20
	local toggle = false
	while z < Config.MOUNTAIN_END_Z - 10 do
		local y = Config.groundHeight(z)
		local x = -(Config.SLOPE_HALF_WIDTH - (toggle and 5 or 9))
		World.part({
			Name = "Trunk",
			Size = Vector3.new(1.5, 6, 1.5),
			Position = Vector3.new(x, y + 3, z),
			Color = Color3.fromRGB(100, 70, 45),
			Material = Enum.Material.Wood,
			CanCollide = false,
		}, treeFolder)
		World.part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 9, 9),
			Position = Vector3.new(x, y + 9, z),
			Color = Color3.fromRGB(40, 110, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
		}, treeFolder)
		World.part({
			Name = "SnowCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(6, 6, 6),
			Position = Vector3.new(x, y + 12.5, z),
			Color = SNOW,
			Material = Enum.Material.Snow,
			CanCollide = false,
		}, treeFolder)
		toggle = not toggle
		z = z + 38
	end
end

function World.build()
	local folder = make("Folder", { Name = "Map" }, workspace)

	-- Eine eventuell vorhandene Standard-Bodenplatte wuerde stoeren
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	buildLobby(folder)
	buildMountain(folder)

	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(150, 160, 180)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 170, 190)

	return folder
end

return World
