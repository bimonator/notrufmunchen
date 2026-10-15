-- Ampel.lua
-- Schaltet alle Ampeln der Karte (Tag "TrafficLight", Attribute Group/Axis/Lamp) und die Fußgängerampeln (Tag "PedLight").
-- Kreuzungen: Achse NS grün, gelb, Räumzeit, dann Querstraße grün, gelb, Räumzeit. Jede Kreuzung startet versetzt.
-- Feuerwache (Gruppen "Wache_*"): grün für den Verkehr, bis workspace:SetAttribute("WacheAlarm", true) gesetzt wird.
-- Dann gelb, rot und der Verkehr steht; mit SetAttribute("WacheAlarm", false) wieder grün.
-- Als eigenes Script in ServerScriptService (das Plugin legt es an) oder direkt per Ampel.start() im Test-Script.

local Ampel = {}

Ampel.config = {
	green = 30, -- Sekunden grün je Richtung
	yellow = 3,
	clear = 2, -- alle rot, bevor die andere Richtung grün bekommt
	pedGreen = 12,
	pedRed = 28,
}

local ON = { Red = { 235, 40, 40 }, Yellow = { 255, 190, 30 }, Green = { 60, 220, 90 } }
local DIM = { Red = { 90, 20, 20 }, Yellow = { 100, 74, 12 }, Green = { 20, 80, 36 } }

-- Zustand einer Kreuzung zur Zeit t (Sekunden) -> Farbe für NS und EW
function Ampel.junction(c, t)
	local phases = {
		{ c.green, "Green", "Red" }, { c.yellow, "Yellow", "Red" }, { c.clear, "Red", "Red" },
		{ c.green, "Red", "Green" }, { c.yellow, "Red", "Yellow" }, { c.clear, "Red", "Red" },
	}
	local cycle = 0
	for _, p in ipairs(phases) do cycle = cycle + p[1] end
	t = t % cycle
	for _, p in ipairs(phases) do
		if t < p[1] then return p[2], p[3] end
		t = t - p[1]
	end
	return "Red", "Red"
end

-- Feuerwache: state = { mode = "Green" | "Yellow" | "Red", since = t }. Gibt die Farbe zurück (ändert state).
function Ampel.wache(c, state, alarm, t)
	if alarm and state.mode == "Green" then state.mode, state.since = "Yellow", t end
	if state.mode == "Yellow" and t - state.since >= c.yellow then state.mode, state.since = "Red", t end
	if not alarm and state.mode ~= "Green" and t - state.since >= 1 then state.mode, state.since = "Green", t end
	return state.mode
end

function Ampel.ped(c, t)
	return (t % (c.pedGreen + c.pedRed)) < c.pedGreen and "Green" or "Red"
end

local function setLamp(part, on, name)
	if part:GetAttribute("Lit") == on then return end
	part:SetAttribute("Lit", on)
	part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local col = (on and ON or DIM)[name]
	part.Color = Color3.fromRGB(col[1], col[2], col[3])
end

function Ampel.start()
	local CollectionService = game:GetService("CollectionService")
	local Workspace = game:GetService("Workspace")
	local groups = {} -- name -> { lamps = { NS = { Red = {parts} ...}, EW = ... }, wache = state | nil, offset }
	local n = 0
	local function collect(tag)
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			local name, axis, lamp = part:GetAttribute("Group"), part:GetAttribute("Axis"), part:GetAttribute("Lamp")
			if name and axis and lamp then
				local g = groups[name]
				if not g then
					n = n + 1
					g = { lamps = { NS = {}, EW = {} }, ped = tag == "PedLight", wache = string.sub(name, 1, 6) == "Wache_" and { mode = "Green", since = 0 } or nil, offset = n * 7 }
					groups[name] = g
				end
				local list = g.lamps[axis][lamp] or {}
				g.lamps[axis][lamp] = list
				list[#list + 1] = part
			end
		end
	end
	collect("TrafficLight")
	collect("PedLight")
	local function show(g, axis, color)
		for name, list in pairs(g.lamps[axis]) do
			for _, part in ipairs(list) do setLamp(part, name == color, name) end
		end
	end
	task.spawn(function()
		while true do
			local t = os.clock()
			local alarm = Workspace:GetAttribute("WacheAlarm") == true
			for _, g in pairs(groups) do
				if g.ped then
					local c = Ampel.ped(Ampel.config, t)
					show(g, "EW", c)
				elseif g.wache then
					local c = Ampel.wache(Ampel.config, g.wache, alarm, t)
					show(g, "NS", c)
					show(g, "EW", "Red")
				else
					local ns, ew = Ampel.junction(Ampel.config, t + g.offset)
					show(g, "NS", ns)
					show(g, "EW", ew)
				end
			end
			task.wait(0.25)
		end
	end)
end

return Ampel
