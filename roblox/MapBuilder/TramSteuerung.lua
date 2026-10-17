-- TramSteuerung.lua
-- Läuft als Script in ServerScriptService (der BuildAll-Schritt "tram" legt es an). Fährt die blaue Tram als Pendel zwischen den Endhaltestellen,
-- lässt Spieler an den Haltestellen mit E einsteigen (Sitz) und mit der Leertaste aussteigen, solange die Bahn hält; unterwegs setzt es sie wieder hin.
-- Strecke, Halte und Fahrdaten stehen als Attribute am Wagenboden "Body" des Vorderwagens (siehe Tram.lua). Die Wagen kollidieren mit nichts.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local map = Workspace:FindFirstChild("Map")
local folder = map and map:FindFirstChild("Tram")
local front = folder and folder:FindFirstChild("TramVorn")
local rear = folder and folder:FindFirstChild("TramHinten")
if not (front and rear and front.PrimaryPart and rear.PrimaryPart) then
	warn("[Tram] Wagen nicht gefunden (Workspace.Map.Tram.TramVorn / TramHinten), Tram fährt nicht")
	return
end

local A = front.PrimaryPart
local route, stops = {}, {}
for x, z, s in string.gmatch(A:GetAttribute("Route"), "(%-?[%d%.]+),(%-?[%d%.]+),([%d%.]+);") do
	route[#route + 1] = { x = tonumber(x), z = tonumber(z), s = tonumber(s) }
end
for s, side, name in string.gmatch(A:GetAttribute("Stops"), "([%d%.]+)|(%-?%d+)|([^;]+);") do
	stops[#stops + 1] = { s = tonumber(s), side = tonumber(side), name = name }
end
local SPACING, VMAX, ACC = A:GetAttribute("Abstand"), A:GetAttribute("Tempo"), A:GetAttribute("Beschl")
local DWELL, DWELL_END, PLATFORM = A:GetAttribute("Halt"), A:GetAttribute("HaltEnde"), A:GetAttribute("Bahnsteig")

-- Punkt und Fahrtrichtung auf der Strecke bei Weg s
local function at(s)
	local lo, hi = 1, #route
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if route[mid].s <= s then lo = mid else hi = mid end
	end
	local a, b = route[lo], route[hi]
	local l = b.s - a.s
	local ux, uz = (b.x - a.x) / l, (b.z - a.z) / l
	local t = math.clamp(s - a.s, 0, l)
	return a.x + ux * t, a.z + uz * t, ux, uz
end

-- Karten-Ursprung aus der Lage des Vorderwagens (steht beim Bauen genau auf Start + Abstand / 2)
local fx0, fz0 = at(A:GetAttribute("Start") + SPACING / 2)
local OX, OZ = A.Position.X - fx0, A.Position.Z - fz0
local YF, YR = A.Position.Y, rear.PrimaryPart.Position.Y

local function place(model, y, s)
	local x, z, ux, uz = at(s)
	model.PrimaryPart.CFrame = CFrame.new(OX + x, y, OZ + z) * CFrame.Angles(0, math.atan2(-uz, ux), 0)
end

-- Sitzmarken werden zu Sitzen, alle Teile hängen per Weld am Wagenboden (nur der bewegt sich)
local seats, doors = {}, {}
local function prepare(model)
	local body = model.PrimaryPart
	for _, m in ipairs(model:GetChildren()) do
		if m:IsA("BasePart") and m.Name == "Sitzmarke" then
			local seat = Instance.new("Seat")
			seat.Name = "Sitz"
			seat.Size, seat.CFrame = m.Size, m.CFrame
			seat.Transparency = 1
			seat.CanCollide, seat.CanTouch = false, false
			seat.Anchored = true
			seat.Parent = model
			m:Destroy()
		elseif m:IsA("BasePart") and m.Name == "Einstieg" then
			doors[#doors + 1] = m
		end
	end
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "Sitz" then seats[#seats + 1] = p end
			if p ~= body then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = body, p
				w.Parent = p
				p.Anchored = false
				p.Massless = true
			end
		end
	end
end
prepare(front)
prepare(rear)

local mode, timer = "halt", 0 -- "halt" = steht an stops[idx], "fahrt" = unterwegs nach stops[target]
local idx, dir, target = 1, 1, 1
local fromS, toS = 0, 0
local sTram = stops[1].s -- Weg der Bahnmitte
local riders = {} -- [Humanoid] = { player, seat, conn, gui, label }
local prompts = {}

local function hintText()
	if mode == "halt" then return stops[idx].name .. "  -  Leertaste: aussteigen" end
	return "Weiter nach " .. stops[target].name .. "  -  aussteigen geht an der Haltestelle"
end

local function showHint(r)
	local pg = r.player:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	if not r.label then
		local gui = Instance.new("ScreenGui")
		gui.Name = "TramHinweis"
		gui.ResetOnSpawn = false
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.fromScale(0.5, 0.93)
		l.Size = UDim2.fromOffset(560, 42)
		l.BackgroundColor3 = Color3.fromRGB(0, 98, 175)
		l.BackgroundTransparency = 0.1
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 20
		l.Parent = gui
		Instance.new("UICorner", l)
		gui.Parent = pg
		r.gui, r.label = gui, l
	end
	r.label.Text = hintText()
end

local function setMode(m)
	mode, timer = m, 0
	for _, pp in ipairs(prompts) do pp.Enabled = m == "halt" end
	for _, r in pairs(riders) do showHint(r) end
end

-- Aussteigen: Spieler auf den Bahnsteig des aktuellen Halts setzen
local function leave(hum, r, toPlatform)
	riders[hum] = nil
	if r.conn then r.conn:Disconnect() end
	if r.gui then r.gui:Destroy() end
	local char = hum.Parent
	if not (toPlatform and char) then return end
	local st = stops[idx]
	local x, z, ux, uz = at(st.s)
	local along = (math.random() - 0.5) * 10
	local tx = OX + x + ux * along - uz * st.side * PLATFORM
	local tz = OZ + z + uz * along + ux * st.side * PLATFORM
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { front, rear, char }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(Vector3.new(tx, YF + 25, tz), Vector3.new(0, -60, 0), params)
	if hit then char:PivotTo(CFrame.new(hit.Position + Vector3.new(0, 3.5, 0))) end
end

local function board(player)
	if mode ~= "halt" then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = hum and hum.RootPart
	if not root or hum.Health <= 0 or riders[hum] then return end
	local best, bd
	for _, seat in ipairs(seats) do
		if not seat.Occupant then
			local d = (seat.Position - root.Position).Magnitude
			if not bd or d < bd then best, bd = seat, d end
		end
	end
	if not best then return end -- alles besetzt
	local r = { player = player, seat = best }
	riders[hum] = r
	best:Sit(hum)
	r.conn = hum.Seated:Connect(function(active)
		if active or riders[hum] ~= r then return end
		if mode == "halt" or hum.Health <= 0 then
			leave(hum, r, hum.Health > 0)
		else -- unterwegs hüpft niemand raus
			task.wait(0.2)
			if riders[hum] == r and mode ~= "halt" and hum.Health > 0 then r.seat:Sit(hum) end
		end
	end)
	showHint(r)
end

for _, part in ipairs(doors) do
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Einsteigen"
	pp.ObjectText = "Tram"
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Enabled = true
	pp.Parent = part
	pp.Triggered:Connect(board)
	prompts[#prompts + 1] = pp
end

-- Weg nach t Sekunden bei Anfahren, Reisetempo und Bremsen (gleichmäßig) über die Strecke D; zweiter Wert = Gesamtdauer
local function profile(D, t)
	local da = VMAX * VMAX / (2 * ACC)
	if 2 * da >= D then
		local T = 2 * math.sqrt(D / ACC)
		if t >= T then return D, T end
		if t < T / 2 then return 0.5 * ACC * t * t, T end
		return D - 0.5 * ACC * (T - t) ^ 2, T
	end
	local ta = VMAX / ACC
	local T = 2 * ta + (D - 2 * da) / VMAX
	if t >= T then return D, T end
	if t < ta then return 0.5 * ACC * t * t, T end
	if t < T - ta then return da + VMAX * (t - ta), T end
	return D - 0.5 * ACC * (T - t) ^ 2, T
end

place(front, YF, sTram + SPACING / 2)
place(rear, YR, sTram - SPACING / 2)
setMode("halt")

RunService.Heartbeat:Connect(function(dt)
	timer += math.min(dt, 0.1)
	if mode == "halt" then
		if timer >= ((idx == 1 or idx == #stops) and DWELL_END or DWELL) then
			if idx + dir < 1 or idx + dir > #stops then dir = -dir end -- am Ende wenden
			target = idx + dir
			fromS, toS = stops[idx].s, stops[target].s
			setMode("fahrt")
		end
	else
		local d, total = profile(math.abs(toS - fromS), timer)
		sTram = fromS + (toS > fromS and d or -d)
		place(front, YF, sTram + SPACING / 2)
		place(rear, YR, sTram - SPACING / 2)
		if timer >= total then
			idx = target
			setMode("halt")
		end
	end
end)
