-- Vereinfachte Nachbildung der Roblox-Umgebung fuer Lua 5.1.
-- Damit laesst sich der Servercode ausserhalb von Roblox Studio probelaufen.
-- Die Nachbildung ist bewusst grob: sie prueft Ablauf und Logik, keine Physik.

local M = {}

-- ---------------------------------------------------------------- Zeit / task
local now = 0
local threads = {} -- { co, wakeAt, args }
local realClock = os.clock
os.clock = function()
	return now
end
M.realClock = realClock

local task = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("Fehler in Hintergrundablauf: " .. tostring(err) .. "\n" .. debug.traceback(co), 0)
	end
end
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	table.insert(threads, { co = coroutine.create(fn), wakeAt = now, args = { ... } })
end
function task.delay(seconds, fn, ...)
	table.insert(threads, { co = coroutine.create(fn), wakeAt = now + seconds, args = { ... } })
end
function task.wait(seconds)
	local co = coroutine.running()
	assert(co, "task.wait ausserhalb eines Ablaufs")
	table.insert(threads, { co = co, wakeAt = now + (seconds or 0), args = {} })
	coroutine.yield()
	return seconds
end
function M.advance(dt)
	now = now + dt
	local due = {}
	local rest = {}
	for _, entry in ipairs(threads) do
		if entry.wakeAt <= now then
			table.insert(due, entry)
		else
			table.insert(rest, entry)
		end
	end
	threads = rest
	for _, entry in ipairs(due) do
		resume(entry.co, unpack(entry.args))
	end
end

-- ---------------------------------------------------------------- Vector3
local Vector3 = {}
local V3 = {}
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
Vector3.new = vec
V3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	error("Vector3 hat kein Feld " .. tostring(key), 2)
end
V3.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return vec(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	return vec(a.X / b, a.Y / b, a.Z / b)
end
V3.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end

-- ---------------------------------------------------------------- CFrame (nur Position, Drehung wird ignoriert)
local CFrame = {}
local CF = {}
local function cframe(position)
	return setmetatable({ Position = position }, CF)
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cframe(x)
	end
	return cframe(vec(x, y, z))
end
function CFrame.lookAt(a, b)
	assert(getmetatable(a) == V3 and getmetatable(b) == V3, "CFrame.lookAt braucht zwei Vector3")
	assert((b - a).Magnitude > 0, "CFrame.lookAt mit identischen Punkten")
	return cframe(a)
end
function CFrame.Angles()
	return cframe(vec(0, 0, 0))
end
CF.__index = function(_, key)
	if key == "LookVector" then
		return vec(0, 0, -1)
	elseif key == "UpVector" then
		return vec(0, 1, 0)
	end
	error("CFrame hat kein Feld " .. tostring(key), 2)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return cframe(a.Position + b.Position)
	end
	return a.Position + b
end

-- ---------------------------------------------------------------- einfache Datentypen
local function record(kind)
	return {
		new = function(...)
			return { kind = kind, ... }
		end,
		fromRGB = function(...)
			return { kind = kind, ... }
		end,
	}
end
local enumMeta = {}
enumMeta.__index = function(t, key)
	local child = setmetatable({ path = t.path .. "." .. key }, enumMeta)
	rawset(t, key, child)
	return child
end
local Enum = setmetatable({ path = "Enum" }, enumMeta)

-- ---------------------------------------------------------------- Signale
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	table.insert(self.handlers, fn)
	return { Disconnect = function() end }
end
function Signal:Fire(...)
	-- wie in Roblox laeuft jeder Empfaenger in einem eigenen Ablauf
	for _, fn in ipairs(self.handlers) do
		task.spawn(fn, ...)
	end
end

local EVENTS = {
	Touched = true, Triggered = true, PlayerAdded = true, PlayerRemoving = true,
	Heartbeat = true, CharacterAdded = true, Died = true, OnServerEvent = true,
}

-- ---------------------------------------------------------------- Instanzen
local Instance = {}
local Inst = {}
local methods = {}

Inst.__index = function(self, key)
	local p = rawget(self, "_p")
	local value = p[key]
	if value ~= nil then
		return value
	end
	local method = methods[key]
	if method then
		return method
	end
	if EVENTS[key] then
		local signal = newSignal()
		p[key] = signal
		return signal
	end
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == key then
			return child
		end
	end
	return nil
end

Inst.__newindex = function(self, key, value)
	local p = rawget(self, "_p")
	if key == "Parent" then
		local old = p.Parent
		if old then
			local list = rawget(old, "_children")
			for i, child in ipairs(list) do
				if child == self then
					table.remove(list, i)
					break
				end
			end
		end
		p.Parent = value
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	local isPart = p.ClassName == "Part" or p.ClassName == "Seat" or p.ClassName == "SpawnLocation"
	if not isPart then
		-- Bedienelemente haben eigene Datentypen fuer Position und Groesse
	elseif key == "Position" then
		assert(getmetatable(value) == V3, "Position muss ein Vector3 sein")
		p.CFrame = cframe(value)
	elseif key == "CFrame" then
		assert(getmetatable(value) == CF, "CFrame muss ein CFrame sein")
		p.Position = value.Position
	elseif key == "Size" then
		assert(getmetatable(value) == V3, "Size muss ein Vector3 sein (" .. tostring(p.ClassName) .. ")")
	end
	p[key] = value
	local signals = rawget(self, "_propSignals")
	if signals[key] then
		signals[key]:Fire()
	end
end

function Instance.new(className)
	local self = {
		_p = { ClassName = className, Name = className },
		_children = {},
		_attributes = {},
		_propSignals = {},
		_attrSignals = {},
	}
	setmetatable(self, Inst)
	if className == "Part" or className == "Seat" or className == "SpawnLocation" then
		self.Position = vec(0, 0, 0)
		self.Size = vec(4, 1, 2)
		self.Transparency = 0
	end
	if className == "Humanoid" then
		self.Health = 100
		self.Sit = false
		self.WalkSpeed = 16
	end
	return self
end

function methods:FindFirstChild(name)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function methods:WaitForChild(name)
	local child = methods.FindFirstChild(self, name)
	assert(child, "WaitForChild wuerde ewig warten: " .. tostring(name) .. " in " .. tostring(self.Name))
	return child
end
function methods:FindFirstChildOfClass(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end
function methods:GetChildren()
	local copy = {}
	for i, child in ipairs(rawget(self, "_children")) do
		copy[i] = child
	end
	return copy
end
function methods:IsA(className)
	return self.ClassName == className
end
function methods:IsDescendantOf(ancestor)
	local current = self.Parent
	while current do
		if current == ancestor then
			return true
		end
		current = current.Parent
	end
	return false
end
function methods:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function methods:SetAttribute(name, value)
	rawget(self, "_attributes")[name] = value
	local signal = rawget(self, "_attrSignals")[name]
	if signal then
		signal:Fire()
	end
end
function methods:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end
function methods:GetPropertyChangedSignal(name)
	local signals = rawget(self, "_propSignals")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function methods:GetAttributeChangedSignal(name)
	local signals = rawget(self, "_attrSignals")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function methods:PivotTo(cf)
	assert(getmetatable(cf) == CF, "PivotTo braucht ein CFrame")
	local primary = self.PrimaryPart
	assert(primary, "PivotTo ohne PrimaryPart")
	primary.CFrame = cf
end
function methods:Sit(humanoid)
	humanoid.Sit = true
	self.Occupant = humanoid
end
function methods:FireClient(player, ...)
	M.onNotify(player, ...)
end
function methods:GetPlayers()
	local list = {}
	for _, child in ipairs(rawget(self, "_children")) do
		if child.ClassName == "Player" then
			table.insert(list, child)
		end
	end
	return list
end
function methods:GetPlayerFromCharacter(character)
	for _, player in ipairs(methods.GetPlayers(self)) do
		if player.Character == character then
			return player
		end
	end
	return nil
end
function methods:BindToClose(fn)
	M.closeHandler = fn
end
local stored = {}
M.stored = stored
function methods:GetDataStore()
	return {
		GetAsync = function(_, key)
			return stored[key]
		end,
		SetAsync = function(_, key, value)
			stored[key] = value
		end,
	}
end

-- ---------------------------------------------------------------- Dienste
local game = Instance.new("DataModel")
local services = {}
function methods:GetService(name)
	if not services[name] then
		local service = Instance.new(name)
		service.Name = name
		service.Parent = game
		services[name] = service
	end
	return services[name]
end
M.onNotify = function() end

local workspace = game:GetService("Workspace")

-- ---------------------------------------------------------------- require
local root = arg and arg[1] or "."
local loaded = {}
local env = {}

local function requireModule(moduleInstance)
	if loaded[moduleInstance] == nil then
		local path = rawget(moduleInstance, "_p")._path
		assert(path, "kein Skriptpfad fuer " .. tostring(moduleInstance.Name))
		local chunk = assert(loadfile(path))
		local moduleEnv = setmetatable({ script = moduleInstance }, { __index = env })
		setfenv(chunk, moduleEnv)
		loaded[moduleInstance] = chunk()
	end
	return loaded[moduleInstance]
end

function M.script(className, name, path, parent)
	local instance = Instance.new(className)
	instance.Name = name
	rawget(instance, "_p")._path = root .. "/" .. path
	instance.Parent = parent
	return instance
end

function M.run(scriptInstance)
	local path = rawget(scriptInstance, "_p")._path
	local chunk = assert(loadfile(path))
	setfenv(chunk, setmetatable({ script = scriptInstance }, { __index = env }))
	task.spawn(chunk)
end

local mathLib = setmetatable({
	clamp = function(x, lo, hi)
		return math.max(lo, math.min(hi, x))
	end,
}, { __index = math })

setmetatable(env, { __index = _G })
env.game = game
env.workspace = workspace
env.Instance = Instance
env.Vector3 = Vector3
env.Vector2 = record("Vector2")
env.CFrame = CFrame
env.Color3 = record("Color3")
env.UDim2 = record("UDim2")
env.UDim = record("UDim")
env.Enum = Enum
env.task = task
env.math = mathLib
env.require = requireModule
env.warn = function(...)
	print("WARN", ...)
end

M.game = game
M.workspace = workspace
M.Instance = Instance
M.Vector3 = Vector3
M.CFrame = CFrame
M.env = env

return M
