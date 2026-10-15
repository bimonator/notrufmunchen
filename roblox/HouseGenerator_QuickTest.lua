-- HouseGenerator_QuickTest.lua  (automatisch erzeugt mit make_quicktest.py, nicht von Hand ändern)
-- Schnelltest: in ServerScriptService ein Script anlegen, diesen Inhalt einfügen, oben im Studio auf RUN (nicht Play) klicken.
-- Die Häuser entstehen nur zur Laufzeit. Nach dem Stoppen sind sie weg, dafür braucht der Test kein Setup.
local ONLY = { "B_NordMitte" } -- nil = alle Blöcke (A, B, D)
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

local Planner = (function()
-- Planner.lua
-- Reine Geometrie für Reihenhaus-Blockränder. Keine Roblox-Funktionen, läuft in Luau und in Lua 5.1 (Tests).
-- Koordinaten wie im Kartenplan: x = Ost, z = Süd, y = oben. Einheiten: Studs.
-- Lokales Haus-System: x läuft entlang der Fassade, z zeigt von der Fassade in den Block hinein, y nach oben.
-- Alles, was vor der Wand liegt (Fenster, Gesimse, Balkone), hat lokal z < 0.

local Planner = {}

Planner.DEFAULTS = {
	depth = 28, -- Gebäudetiefe
	setback = 2, -- Abstand der Fassade zur Blockkante (der Gehweg liegt schon in der Straße)
	targetWidth = 26, -- Wunschbreite eines Reihenhauses
	floorY = 1, -- Gehweg-Oberkante = Boden des Erdgeschosses
	groundH = 14, -- Höhe Erdgeschoss
	upperH = 12, -- Höhe jedes Obergeschosses
	minFloors = 4,
	maxFloors = 5,
	seed = 1,
	litChance = 0.35, -- Anteil Fenster, die nachts leuchten
	palette = { -- Putzfarben (RGB 0-255)
		{ 236, 226, 200 }, { 232, 208, 150 }, { 214, 200, 178 }, { 228, 186, 150 },
		{ 196, 204, 200 }, { 214, 168, 150 }, { 188, 200, 216 },
	},
}

local function round3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

local function hash(s)
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

-- Park-Miller: Zwischenwerte bleiben unter 2^53, daher in Luau und Lua 5.1 identisch.
local function newRng(seed)
	local state = (seed % 2147483646) + 1
	local self = {}
	function self.next()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	function self.int(a, b) -- beide Grenzen eingeschlossen
		return a + math.floor(self.next() * (b - a + 1))
	end
	function self.pick(t)
		return t[self.int(1, #t)]
	end
	return self
end

local function tint(c, f) -- Richtung weiß mischen
	return {
		math.floor(c[1] + (255 - c[1]) * f), math.floor(c[2] + (255 - c[2]) * f), math.floor(c[3] + (255 - c[3]) * f),
	}
end

local function mergeOpts(opts)
	local o = {}
	for k, v in pairs(Planner.DEFAULTS) do o[k] = v end
	if opts then
		for k, v in pairs(opts) do o[k] = v end
	end
	return o
end

-- Teil im lokalen Haus-System anlegen; Position wird in Weltkoordinaten umgerechnet.
local function add(h, name, kind, lx, ly, lz, sx, sy, sz, color, material, extra)
	extra = extra or {}
	local r = math.rad(h.yaw)
	local c, s = math.cos(r), math.sin(r)
	local part = {
		name = name, kind = kind,
		size = { sx, sy, sz },
		pos = { round3(h.ox + lx * c + lz * s), round3(ly), round3(h.oz - lx * s + lz * c) },
		yaw = (h.yaw + (extra.yaw or 0)) % 360,
		color = color, material = material,
		collide = extra.collide == true,
		lit = extra.lit, tag = extra.tag,
		lpos = { lx, ly, lz },
	}
	h.parts[#h.parts + 1] = part
	return part
end

-- Fläche (face) "front", "+x" oder "-x"; u = Position entlang der Fläche, d = Abstand vor der Wand
local function onFace(h, face, u, d)
	if face == "front" then return u, -d, 0 end
	if face == "+x" then return h.width / 2 + d, u, -90 end
	return -h.width / 2 - d, u, 90
end

local FRAME = { 70, 62, 56 }
local GLASS = { 70, 92, 112 }
local GLASS_LIT = { 255, 214, 140 }

-- Fenster: Rahmen und Scheibe sitzen vor der Wand (kein Ausschnitt), Fensterbank darunter.
local function addWindow(h, label, face, u, yc, w, hgt, lit)
	local lx, lz, ey = onFace(h, face, u, 0.2)
	add(h, "Frame" .. label, "frame", lx, yc, lz, w + 1.6, hgt + 1.6, 0.4, FRAME, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4)
	add(h, "Glass" .. label, "glass", lx, yc, lz, w, hgt, 0.2, lit and GLASS_LIT or GLASS, "Glass",
		{ yaw = ey, lit = lit, tag = "HouseWindow" })
	lx, lz = onFace(h, face, u, 0.5)
	add(h, "Sill" .. label, "trim", lx, yc - hgt / 2 - 1.1, lz, w + 3, 0.6, 1.0, { 200, 196, 188 }, "Concrete", { yaw = ey })
end

local function planHouse(h, o, rng, cornerA, cornerB)
	local W, D = h.width, h.depth
	local floors = rng.int(o.minFloors, o.maxFloors)
	local H = o.groundH + o.upperH * (floors - 1)
	local y0 = o.floorY
	local facade = rng.pick(o.palette)
	local doorSign = (rng.next() < 0.5) and -1 or 1
	local balcony = rng.next() < 0.5
	local staffel = floors == o.minFloors and rng.next() < 0.35
	local chimneys = rng.int(0, 2)
	h.floors, h.height, h.facade = floors, H, facade

	-- Hauptkörper, Sockel, Gesimse, Dachabschluss
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, facade, "SmoothPlastic", { collide = true })
	add(h, "Plinth", "trim", 0, y0 + 1.2, -0.25, W, 2.4, 0.5, { 140, 140, 140 }, "Concrete")
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		add(h, "Ledge" .. k, "trim", 0, yb, -0.4, W, 0.7, 0.8, tint(facade, 0.35), "Concrete")
	end
	add(h, "Cornice", "trim", 0, y0 + H - 0.8, -0.8, W, 1.6, 1.6, tint(facade, 0.45), "Concrete")
	add(h, "Roof", "roof", 0, y0 + H + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	add(h, "ParapetF", "trim", 0, y0 + H + 1.6, 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
	add(h, "ParapetB", "trim", 0, y0 + H + 1.6, D - 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
	local roofTop = y0 + H + 0.6
	if staffel then
		add(h, "Staffel", "body", 0, roofTop + 5, D / 2, W - 4, 10, D - 12, tint(facade, 0.15), "SmoothPlastic", { collide = true })
		add(h, "StaffelGlass", "glass", 0, roofTop + 5, 5.8, W - 8, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add(h, "StaffelRoof", "roof", 0, roofTop + 10.3, D / 2, W - 3, 0.6, D - 11, { 96, 96, 100 }, "Concrete")
		roofTop = roofTop + 10.6
	end
	for i = 1, chimneys do
		local lim = math.floor(W / 2 - 3)
		add(h, "Chimney" .. i, "chimney", rng.int(-lim, lim), roofTop + 3, D - 6, 2.5, 6, 2.5, { 170, 100, 80 }, "Brick")
	end

	-- Obergeschoss-Fenster (vorne) und optionale Balkone
	local nw = math.max(2, math.floor((W - 4) / 9))
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		for i = 1, nw do
			addWindow(h, "F" .. k .. "_" .. i, "front", -W / 2 + (i - 0.5) * W / nw, yb + 6, 4.4, 6.4, rng.next() < o.litChance)
		end
		if balcony and k >= 2 then
			local bw = math.min(14, W - 10)
			add(h, "Balcony" .. k, "balcony", 0, yb + 0.3, -1.25, bw, 0.6, 2.5, { 150, 150, 150 }, "Concrete")
			add(h, "Rail" .. k, "balcony", 0, yb + 2.1, -2.35, bw, 3, 0.3, { 60, 60, 66 }, "Metal")
		end
	end

	-- Erdgeschoss: Tür auf einer Seite, Schaufenster auf der anderen
	local a = W / 2 - 6
	local dx = doorSign * a
	add(h, "DoorFrame", "frame", dx, y0 + 5, -0.25, 6.4, 10, 0.5, { 70, 52, 42 }, "Wood")
	add(h, "Door", "door", dx, y0 + 4.5, -0.55, 5, 9, 0.3, { 110, 70, 45 }, "Wood")
	add(h, "DoorCanopy", "trim", dx, y0 + 10.6, -1, 7, 0.5, 2, { 120, 120, 124 }, "Concrete")
	local nwg = math.max(1, math.floor((W - 21) / 9) + 1)
	for i = 1, nwg do
		addWindow(h, "G_" .. i, "front", -dx + doorSign * 9 * (i - 1), y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
	end

	-- Eckhaus: Fenster auch an der Seitenfläche zur Querstraße
	for _, face in ipairs({ cornerA and "-x" or false, cornerB and "+x" or false }) do
		if face then
			for _, u in ipairs({ 7, D - 7 }) do
				for k = 1, floors - 1 do
					addWindow(h, "SideF" .. k .. "_" .. face .. u, face, u, y0 + o.groundH + o.upperH * (k - 1) + 6, 4.4, 6.4, rng.next() < o.litChance)
				end
				addWindow(h, "SideG_" .. face .. u, face, u, y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
			end
		end
	end
end

-- block = { name, xmin, zmin, xmax, zmax } (Außenkante = Straßenrand). Gibt den Bauplan zurück.
function Planner.planBlock(block, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(block.name))
	local s, D = o.setback, o.depth
	local xmin, zmin, xmax, zmax = block.xmin, block.zmin, block.xmax, block.zmax
	local sides = {
		{ name = "N", yaw = 0, sx = xmin + s, sz = zmin + s, ux = 1, uz = 0, len = (xmax - xmin) - 2 * s, corners = true },
		{ name = "S", yaw = 180, sx = xmax - s, sz = zmax - s, ux = -1, uz = 0, len = (xmax - xmin) - 2 * s, corners = true },
		{ name = "W", yaw = 90, sx = xmin + s, sz = zmax - s - D, ux = 0, uz = -1, len = (zmax - zmin) - 2 * s - 2 * D, corners = false },
		{ name = "E", yaw = 270, sx = xmax - s, sz = zmin + s + D, ux = 0, uz = 1, len = (zmax - zmin) - 2 * s - 2 * D, corners = false },
	}
	local plan = {
		block = block, houses = {},
		courtyard = { xmin + s + D, zmin + s + D, xmax - s - D, zmax - s - D },
	}
	for _, side in ipairs(sides) do
		local n = math.floor(side.len / o.targetWidth + 0.5)
		if side.len >= 12 and n < 1 then n = 1 end
		if side.len >= 12 then
			local width = side.len / n
			for i = 0, n - 1 do
				local t = (i + 0.5) * width
				local h = {
					side = side.name, index = i + 1,
					ox = side.sx + side.ux * t, oz = side.sz + side.uz * t,
					yaw = side.yaw, width = width, depth = D, parts = {},
					name = string.format("Haus_%s_%s%d", block.name, side.name, i + 1),
				}
				planHouse(h, o, rng, side.corners and i == 0, side.corners and i == n - 1)
				plan.houses[#plan.houses + 1] = h
			end
		end
	end
	return plan
end

-- Achsparallele Außenmaße eines Teils (Drehung nur in 90-Grad-Schritten).
function Planner.aabb(p)
	local sx, sy, sz = p.size[1], p.size[2], p.size[3]
	if p.yaw % 180 == 90 then sx, sz = sz, sx end
	return p.pos[1] - sx / 2, p.pos[2] - sy / 2, p.pos[3] - sz / 2, p.pos[1] + sx / 2, p.pos[2] + sy / 2, p.pos[3] + sz / 2
end

function Planner.stats(plan)
	local parts, area = 0, 0
	for _, h in ipairs(plan.houses) do
		parts = parts + #h.parts
		area = area + h.width * h.depth
	end
	return { houses = #plan.houses, parts = parts, footprint = area }
end

return Planner

end)()

local Blocks = (function()
-- Blocks.lua
-- Häuserblöcke im Schwabing-Raster (Kartenkoordinaten in Studs, Ursprung = Siegestor, x = Ost, z = Süd).
-- Außenkante = Straßenrand (Straße 57 breit, Mittellinien V1 x=-460, V2 x=-235, H1 z=-285, H2 z=30; Ring 48 breit).
-- Bank, Parkhaus, Feuerwache und die Leopoldstraße-Ladenzeile sind hier absichtlich NICHT enthalten.

return {
	{ name = "A_NordWest", xmin = -637, zmin = -448, xmax = -488.5, zmax = -313.5 }, -- Supermarkt kommt später in den Innenhof
	{ name = "B_NordMitte", xmin = -431.5, zmin = -448, xmax = -263.5, zmax = -313.5 }, -- Innenhof wird der Hinterhofpark
	{ name = "D_West", xmin = -637, zmin = -256.5, xmax = -488.5, zmax = 1.5 }, -- Wohnhäuser
}

end)()

local Builder = (function()
-- Builder.lua
-- Wandelt den Bauplan aus Planner.lua in Roblox-Instanzen um. NUR im Studio testen (Command Bar).
-- Nicht in der Cloud-Session geprüft: die Roblox-Aufrufe unten sind ungetestet.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Concrete = Enum.Material.Concrete,
	Brick = Enum.Material.Brick,
	Glass = Enum.Material.Glass,
	Wood = Enum.Material.Wood,
	Metal = Enum.Material.Metal,
}

local function buildPart(spec, origin)
	local p = Instance.new("Part")
	p.Name = spec.name
	p.Anchored = true
	p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	p.CFrame = CFrame.new(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3])) * CFrame.Angles(0, math.rad(spec.yaw), 0)
	p.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
	p.Material = MATERIALS[spec.material] or Enum.Material.SmoothPlastic
	p.CanCollide = spec.collide
	p.CanTouch = false
	if spec.kind == "glass" then
		p.Transparency = 0.3
		p.CastShadow = false
	end
	if spec.tag then
		CollectionService:AddTag(p, spec.tag) -- Tag-Skript schaltet nachts Lit-Fenster auf Neon
		p:SetAttribute("Lit", spec.lit == true)
	end
	return p
end

-- Baut alle Häuser eines Plans unter `parent`. origin = Weltposition des Siegestors.
function Builder.build(plan, parent, origin)
	for _, h in ipairs(plan.houses) do
		local model = Instance.new("Model")
		model.Name = h.name
		model:SetAttribute("Floors", h.floors)
		model:SetAttribute("Side", h.side)
		for _, spec in ipairs(h.parts) do
			local part = buildPart(spec, origin)
			part.Parent = model
			if spec.name == "Body" then model.PrimaryPart = part end
		end
		model.Parent = parent -- erst ganz am Ende, spart Replikation
	end
end

-- Eigener Ordner Workspace.Map.Gebaeude.<Blockname>; ein vorhandener Ordner wird ersetzt (neu bauen möglich).
function Builder.container(blockName)
	local function folder(parent, name)
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end
	local all = folder(folder(Workspace, "Map"), "Gebaeude")
	local old = all:FindFirstChild(blockName)
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = blockName
	folder.Parent = all
	return folder
end

return Builder

end)()

local Run = (function()
-- Run.lua
-- Aufruf in der Command Bar (Studio, Edit-Modus):
--   require(game.ServerStorage.HouseGenerator.Run).run()
-- Optionen: origin (Vector3, Position des Siegestors), seed (Zahl), only ({ "B_NordMitte" })


local Run = {}

function Run.run(opts)
	opts = opts or {}
	local origin = opts.origin or Vector3.new(0, 0, 0)
	local only = {}
	for _, n in ipairs(opts.only or {}) do only[n] = true end
	local houses, parts = 0, 0
	for _, block in ipairs(Blocks) do
		if next(only) == nil or only[block.name] then
			local plan = Planner.planBlock(block, { seed = opts.seed or 1 })
			Builder.build(plan, Builder.container(block.name), origin)
			local st = Planner.stats(plan)
			houses, parts = houses + st.houses, parts + st.parts
			print(string.format("%s: %d Häuser, %d Teile", block.name, st.houses, st.parts))
		end
	end
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("HouseGenerator") end) -- Strg+Z
	print(string.format("Fertig: %d Häuser, %d Teile", houses, parts))
end

return Run

end)()

Run.run({ only = ONLY, origin = ORIGIN })
