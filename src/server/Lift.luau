-- Der Schilift: Sessel fahren in einer Endlosschleife den Berg hinauf und wieder hinunter.
-- Einsteigen: unten auf die gruene Flaeche stellen. Aussteigen: jederzeit springen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local World = require(script.Parent:WaitForChild("World"))

local Lift = {}

local LIFT_SPEED = 55 -- Studs pro Sekunde
local CHAIR_COUNT = 16
local UP_X = 60 -- Spur bergauf
local DOWN_X = 72 -- Spur bergab
local CABLE_HEIGHT = 16 -- Hoehe der Sessel ueber dem Boden
local BOARD_Z = 40 -- Einstieg in der Lobby
local BOARD_HEIGHT = 3.2
local BOARD_RADIUS = 7

local points = {} -- Eckpunkte der Schleife
local cumulative = {} -- Streckenlaenge bis zu jedem Eckpunkt
local totalLength = 0
local topDistance = 0 -- Streckenposition der Bergstation
local chairs = {}

local function buildPath()
	local up = {}
	table.insert(up, Vector3.new(UP_X, BOARD_HEIGHT, BOARD_Z))
	table.insert(up, Vector3.new(UP_X, CABLE_HEIGHT, Config.SLOPE_START_Z))
	for zoneIndex = 1, Config.ZONE_COUNT do
		local terraceZ, terraceY = Config.terraceStart(zoneIndex)
		table.insert(up, Vector3.new(UP_X, terraceY + CABLE_HEIGHT, terraceZ))
		if zoneIndex < Config.ZONE_COUNT then
			table.insert(up, Vector3.new(UP_X, terraceY + CABLE_HEIGHT, terraceZ + Config.TERRACE_LENGTH))
		else
			table.insert(up, Vector3.new(UP_X, terraceY + CABLE_HEIGHT, terraceZ + Config.TERRACE_LENGTH - 25))
		end
	end

	for _, p in ipairs(up) do
		table.insert(points, p)
	end
	local topIndex = #points
	for i = #up, 1, -1 do
		local p = up[i]
		table.insert(points, Vector3.new(DOWN_X, p.Y, p.Z))
	end

	totalLength = 0
	for i = 1, #points do
		cumulative[i] = totalLength
		local nextPoint = points[i % #points + 1]
		totalLength = totalLength + (nextPoint - points[i]).Magnitude
	end
	topDistance = cumulative[topIndex]
end

-- Position und Fahrtrichtung fuer eine Streckenposition
local function sample(distance)
	distance = distance % totalLength
	local count = #points
	for i = count, 1, -1 do
		if distance >= cumulative[i] then
			local a = points[i]
			local b = points[i % count + 1]
			local segment = (b - a).Magnitude
			local alpha = 0
			if segment > 0 then
				alpha = (distance - cumulative[i]) / segment
			end
			return a + (b - a) * alpha, b - a
		end
	end
	return points[1], points[2] - points[1]
end

local function buildDecoration(folder)
	local cableColor = Color3.fromRGB(40, 40, 45)
	local count = #points
	for i = 1, count do
		local a = points[i] + Vector3.new(0, 9, 0)
		local b = points[i % count + 1] + Vector3.new(0, 9, 0)
		local length = (b - a).Magnitude
		if length > 0.1 then
			World.part({
				Name = "Cable",
				Size = Vector3.new(0.4, 0.4, length),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = cableColor,
				CanCollide = false,
			}, folder)
		end
	end

	-- Stuetzen zwischen den beiden Spuren
	local pylonX = (UP_X + DOWN_X) / 2
	for i = 1, count / 2 do
		local p = points[i]
		local ground = Config.groundHeight(p.Z)
		local top = p.Y + 9
		local height = top - ground
		if height > 2 then
			World.part({
				Name = "Pylon",
				Size = Vector3.new(1.6, height, 1.6),
				Position = Vector3.new(pylonX, ground + height / 2, p.Z),
				Color = Color3.fromRGB(70, 75, 90),
				Material = Enum.Material.Metal,
				CanCollide = false,
			}, folder)
			World.part({
				Name = "PylonArm",
				Size = Vector3.new(DOWN_X - UP_X + 3, 0.8, 0.8),
				Position = Vector3.new(pylonX, top, p.Z),
				Color = Color3.fromRGB(70, 75, 90),
				Material = Enum.Material.Metal,
				CanCollide = false,
			}, folder)
		end
	end

	-- Einstiegsflaeche
	local pad = World.part({
		Name = "BoardingPad",
		Size = Vector3.new(BOARD_RADIUS * 2, 0.3, BOARD_RADIUS * 2),
		Position = Vector3.new(UP_X, 0.1, BOARD_Z),
		Color = Color3.fromRGB(60, 220, 110),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, folder)
	World.billboard(pad, "SKI LIFT\nstand here", 16, 6, 14, Color3.fromRGB(120, 255, 160))
end

local function buildChair(folder, index)
	local model = Instance.new("Model")
	model.Name = "Chair" .. index

	local seat = World.make("Seat", {
		Name = "Seat",
		Anchored = true,
		Size = Vector3.new(4, 1, 3),
		Color = Color3.fromRGB(220, 60, 60),
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		CFrame = CFrame.new(0, 0, 0),
	}, model)
	World.part({
		Name = "Back",
		Size = Vector3.new(4, 3, 0.5),
		CFrame = CFrame.new(0, 1.5, 1.6),
		Color = Color3.fromRGB(200, 50, 50),
		CanCollide = false,
	}, model)
	World.part({
		Name = "Hanger",
		Size = Vector3.new(0.4, 8, 0.4),
		CFrame = CFrame.new(0, 5, 1.8),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, model)

	model.PrimaryPart = seat
	model.Parent = folder

	-- Mit einem Ei in der Hand darf man nicht bequem mit dem Lift fliehen
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if not humanoid then
			return
		end
		local player = Players:GetPlayerFromCharacter(humanoid.Parent)
		if player and player:GetAttribute("Carrying") then
			task.defer(function()
				humanoid.Sit = false
			end)
		end
	end)

	return { model = model, seat = seat, distance = (index - 1) / CHAIR_COUNT * totalLength }
end

-- Sucht einen wartenden Spieler auf der Einstiegsflaeche
local function findWaitingRider()
	local boardPosition = points[1]
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not humanoid.Sit and not player:GetAttribute("Carrying") then
			local dx = root.Position.X - boardPosition.X
			local dz = root.Position.Z - boardPosition.Z
			if dx * dx + dz * dz <= BOARD_RADIUS * BOARD_RADIUS and root.Position.Y < 12 then
				return humanoid
			end
		end
	end
	return nil
end

function Lift.build(mapFolder)
	local folder = World.make("Folder", { Name = "Lift" }, mapFolder)
	buildPath()
	buildDecoration(folder)
	for i = 1, CHAIR_COUNT do
		chairs[i] = buildChair(folder, i)
	end
	Lift.update(0)
end

function Lift.update(dt)
	local step = LIFT_SPEED * dt
	for _, chair in ipairs(chairs) do
		local before = chair.distance
		local after = before + step
		local wrapped = after >= totalLength
		chair.distance = after % totalLength

		local position, direction = sample(chair.distance)
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.001 then
			flat = Vector3.new(0, 0, 1)
		end
		chair.model:PivotTo(CFrame.lookAt(position, position + flat))

		-- Bergstation: Fahrgast steigt automatisch aus
		if before < topDistance and after >= topDistance then
			local occupant = chair.seat.Occupant
			if occupant then
				occupant.Sit = false
			end
		end

		-- Talstation: wartenden Spieler mitnehmen
		if wrapped and not chair.seat.Occupant then
			local humanoid = findWaitingRider()
			if humanoid then
				chair.seat:Sit(humanoid)
			end
		end
	end
end

return Lift
