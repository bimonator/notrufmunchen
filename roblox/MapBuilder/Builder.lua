-- Builder.lua
-- Wandelt die Pläne (Teilelisten, Terrain-Operationen) in Roblox-Instanzen um. Läuft im Studio.
-- Die Roblox-Aufrufe hier sind in der Cloud-Session nur gegen eine Attrappe getestet, nicht gegen echtes Roblox.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic, Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick,
	Glass = Enum.Material.Glass, Wood = Enum.Material.Wood, Metal = Enum.Material.Metal, Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Pavement, Grass = Enum.Material.Grass, Water = Enum.Material.Water, Neon = Enum.Material.Neon, Sand = Enum.Material.Sand, Rock = Enum.Material.Rock,
	Marble = Enum.Material.Marble, Fabric = Enum.Material.Fabric, Ground = Enum.Material.Ground, Air = Enum.Material.Air,
	Snow = Enum.Material.Snow, Granite = Enum.Material.Granite, Slate = Enum.Material.Slate, Cobblestone = Enum.Material.Cobblestone,
}

local function buildPart(spec, origin)
	local p = Instance.new(spec.seat and "Seat" or "Part") -- seat = true: Sitzplatz (Bänke), man setzt sich durch Hineinlaufen
	p.Name = spec.name
	p.Anchored = true
	p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	if spec.wedge then -- Dreieck aus Keilen (Geo.wedges): y-Achse = erster Schenkel, z-Achse = zweiter Schenkel (rechter Winkel bei -y/+z), x-Achse = Normale
		local ey, ez = Vector3.new(spec.wedge[1][1], spec.wedge[1][2], spec.wedge[1][3]), Vector3.new(spec.wedge[2][1], spec.wedge[2][2], spec.wedge[2][3])
		p.CFrame = CFrame.fromMatrix(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]), ey:Cross(ez), ey, ez)
		p.Shape = Enum.PartType.Wedge
	else
		p.CFrame = CFrame.new(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]))
			* CFrame.Angles(0, math.rad(spec.yaw), 0) * CFrame.Angles(math.rad(spec.pitch or 0), 0, math.rad(spec.roll or 0))
	end
	if spec.shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder elseif spec.shape == "Ball" then p.Shape = Enum.PartType.Ball end -- Achse läuft entlang x, mit roll = 90 steht sie senkrecht
	if spec.transparency then p.Transparency = spec.transparency end
	p.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
	p.Material = MATERIALS[spec.material] or Enum.Material.SmoothPlastic
	p.CanCollide = spec.collide
	p.CanTouch = spec.seat == true -- Sitze brauchen Berührung zum Hinsetzen
	if spec.kind == "glass" then
		p.Transparency = 0.3
		p.CastShadow = false
	end
	if spec.tag then
		CollectionService:AddTag(p, spec.tag) -- Tag-Skript schaltet nachts Lit-Fenster auf Neon
		p:SetAttribute("Lit", spec.lit == true)
	end
	if spec.text then -- Schrift: Platte unsichtbar, Text als SurfaceGui auf der Vorderseite
		p.Transparency = 1
		p.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = spec.text.s
		label.TextColor3 = Color3.fromRGB(spec.text.color[1], spec.text.color[2], spec.text.color[3])
		label.Parent = gui
		gui.Parent = p
	end
	if spec.attrs then
		for k, v in pairs(spec.attrs) do p:SetAttribute(k, v) end -- z. B. Lampenfarbe für das Ampel-Skript
	end
	if spec.emitter then -- Düse: unsichtbares, geneigtes Teil mit Partikelstrahl nach oben (Top = Sprührichtung), z. B. Springbrunnen-Sprenkler
		local e = spec.emitter
		p.Transparency = 1
		p.CastShadow = false
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Rate = e.rate
		pe.Lifetime = NumberRange.new(e.life, e.life * 1.3)
		pe.Speed = NumberRange.new(e.speed * 0.9, e.speed * 1.1)
		pe.SpreadAngle = Vector2.new(e.spread, e.spread)
		pe.Acceleration = Vector3.new(0, -e.gravity, 0)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Size = NumberSequence.new(e.size, e.size * 1.6)
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		pe.Color = ColorSequence.new(Color3.fromRGB(e.color[1], e.color[2], e.color[3]))
		pe.LightEmission = 0.4
		pe.Parent = p
	end
	return p
end

-- Gibt dem Studio zwischendurch Luft, sonst friert es bei vielen tausend Teilen ein.
local count = 0
local function breathe(every)
	count = count + 1
	if count % every == 0 then task.wait() end
end

-- Liste von Teilen unter parent anlegen
function Builder.buildParts(parts, parent, origin)
	for _, spec in ipairs(parts) do
		buildPart(spec, origin).Parent = parent
		breathe(500)
	end
end

-- Häuser: je Haus ein Model (PrimaryPart = Body); plan.houses und die Hinterhäuser plan.inner
function Builder.build(plan, parent, origin)
	for _, list in ipairs({ plan.houses, plan.inner or {} }) do
		for _, h in ipairs(list) do
			local model = Instance.new("Model")
			model.Name = h.name
			model:SetAttribute("Floors", h.floors)
			model:SetAttribute("Side", h.side)
			for _, spec in ipairs(h.parts) do
				local part = buildPart(spec, origin)
				part.Parent = model
				if spec.name == "Body" then model.PrimaryPart = part end
			end
			model.Parent = parent -- erst am Ende, spart Replikation
			breathe(8)
		end
	end
end

function Builder.applyTerrain(ops, origin)
	local terrain = Workspace.Terrain
	-- Wasser deckend genug, dass man es von oben als Wasser sieht (Gras-Büschel bleiben an; unter Wegen und Straßen sorgt paveUnder dafür, dass keine wachsen)
	pcall(function()
		terrain.WaterTransparency = 0.45
		terrain.WaterColor = Color3.fromRGB(38, 104, 128)
		terrain.WaterReflectance = 0.35
	end)
	for _, op in ipairs(ops) do
		local cf = CFrame.new(origin + Vector3.new(op.pos[1], op.pos[2], op.pos[3])) * CFrame.Angles(0, math.rad(op.yaw or 0), 0)
		if op.op == "cylinder" then
			terrain:FillCylinder(cf, op.height, op.radius, MATERIALS[op.material])
		else
			terrain:FillBlock(cf, Vector3.new(op.size[1], op.size[2], op.size[3]), MATERIALS[op.material])
		end
		breathe(10)
	end
end

-- Gras-Büschel (Terrain.Decoration) wachsen nur auf Gras-Terrain und ragen sonst durch flache Wege und Straßen. Deshalb wird das Terrain unter flachen Teilen der
-- Arten road/walk/plaza/path/corner/bike von Gras zu Pflaster umgefärbt: ganze 4-Studs-Zellen, deren Mitte höchstens 1 Stud neben dem Teil liegt.
-- nearGrass(spec) wählt vorab die Teile in Grasnähe. Liefert die Zahl der Zellenreihen.
local PAVED = { road = true, walk = true, plaza = true, path = true, corner = true, bike = true }
function Builder.paveUnder(specs, origin, nearGrass)
	local terrain = Workspace.Terrain
	local rows = {}
	for _, s in ipairs(specs) do
		if PAVED[s.kind] and s.size[2] <= 3 and s.pos[2] > -6 and nearGrass(s) then
			local r = math.rad(s.yaw or 0)
			local ux, uz = math.cos(r), -math.sin(r) -- lokale x-Achse in der Draufsicht (lokale z-Achse: (sin, cos))
			local hx, hz = s.size[1] / 2 + 1, s.size[3] / 2 + 1
			if s.wedge then -- Dreieck: Rechteck aus den beiden Schenkeln
				ux, uz = s.wedge[1][1], s.wedge[1][3]
				hx, hz = s.size[2] / 2 + 1, s.size[3] / 2 + 1
			end
			local cx, cz = origin.X + s.pos[1], origin.Z + s.pos[3]
			local rad = hx + hz
			local y0 = math.floor((origin.Y + s.pos[2] - 6) / 4) * 4
			for gx = math.floor((cx - rad) / 4), math.floor((cx + rad) / 4) do
				for gz = math.floor((cz - rad) / 4), math.floor((cz + rad) / 4) do
					local dx, dz = gx * 4 + 2 - cx, gz * 4 + 2 - cz
					if math.abs(dx * ux + dz * uz) <= hx and math.abs(-dx * uz + dz * ux) <= hz then
						local key = y0 .. ":" .. gz
						rows[key] = rows[key] or { y0 = y0, gz = gz, cells = {} }
						rows[key].cells[gx] = true
					end
				end
			end
		end
	end
	local n = 0
	for _, row in pairs(rows) do
		local xs = {}
		for gx in pairs(row.cells) do xs[#xs + 1] = gx end
		table.sort(xs)
		local i = 1
		while i <= #xs do -- zusammenhängende Zellen einer Reihe in einem Aufruf
			local j = i
			while xs[j + 1] == xs[j] + 1 do j = j + 1 end
			local region = Region3.new(Vector3.new(xs[i] * 4, row.y0, row.gz * 4), Vector3.new((xs[j] + 1) * 4, row.y0 + 12, (row.gz + 1) * 4))
			terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Pavement)
			n = n + 1
			breathe(80)
			i = j + 1
		end
	end
	return n
end

-- Wie paveUnder, aber für eine Kreisfläche (Mitte cx, cz in Welt-Koordinaten, Radius r, y = Höhe der Oberfläche darüber), z. B. unter dem Rondell des Friedensengels. Liefert die Zahl der Zellenreihen.
function Builder.paveDisk(cx, cz, r, y)
	local terrain = Workspace.Terrain
	local y0 = math.floor((y - 8) / 4) * 4
	local n = 0
	for gz = math.floor((cz - r) / 4), math.floor((cz + r) / 4) do
		local xs = {}
		for gx = math.floor((cx - r) / 4), math.floor((cx + r) / 4) do
			local dx, dz = gx * 4 + 2 - cx, gz * 4 + 2 - cz
			if dx * dx + dz * dz <= r * r then xs[#xs + 1] = gx end
		end
		local i = 1
		while i <= #xs do
			local j = i
			while xs[j + 1] == xs[j] + 1 do j = j + 1 end
			terrain:ReplaceMaterial(Region3.new(Vector3.new(xs[i] * 4, y0, gz * 4), Vector3.new((xs[j] + 1) * 4, y0 + 16, (gz + 1) * 4)), 4, Enum.Material.Grass, Enum.Material.Pavement)
			n = n + 1
			breathe(80)
			i = j + 1
		end
	end
	return n
end

-- Tatsächliche Höhe der Terrain-Oberkante: Strahl von oben auf mehrere ebene Stellen, Median. 0, wenn nichts getroffen wird.
function Builder.measureGround(origin)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local ys = {}
	for _, p in ipairs({ { -560, -200 }, { 0, -100 }, { 200, -350 }, { -300, 150 }, { 300, 200 } }) do
		local hit = Workspace:Raycast(origin + Vector3.new(p[1], 200, p[2]), Vector3.new(0, -400, 0), params)
		if hit then ys[#ys + 1] = hit.Position.Y - origin.Y end
	end
	if #ys == 0 then return 0 end
	table.sort(ys)
	return math.floor(ys[math.ceil(#ys / 2)] * 2 + 0.5) / 2 -- auf 0,5 gerundet
end

-- Anzahl Wasser-Zellen in einem kleinen Würfel um center (nil, wenn das Auslesen nicht klappt)
function Builder.countWater(center)
	local ok, n = pcall(function()
		local region = Region3.new(center - Vector3.new(16, 20, 16), center + Vector3.new(16, 8, 16)):ExpandToGrid(4)
		local mats = Workspace.Terrain:ReadVoxels(region, 4)
		local c = 0
		for x = 1, #mats do
			for y = 1, #mats[x] do
				for z = 1, #mats[x][y] do
					if mats[x][y][z] == Enum.Material.Water then c = c + 1 end
				end
			end
		end
		return c
	end)
	return ok and n or nil
end

-- Notlösung, falls das Terrain-Wasser fehlt: halbdurchsichtige blaue Platten entlang der Mittellinie (nicht schwimmbar)
function Builder.waterFallback(pts, halfWidth, y, origin)
	local folder = Builder.container("WasserErsatz")
	for i = 1, #pts - 1 do
		local dx, dz = pts[i + 1][1] - pts[i][1], pts[i + 1][2] - pts[i][2]
		local len = math.sqrt(dx * dx + dz * dz)
		local p = Instance.new("Part")
		p.Name = "Wasser"
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(len + 2, 0.4, halfWidth * 2)
		p.CFrame = CFrame.new(origin + Vector3.new((pts[i][1] + pts[i + 1][1]) / 2, y, (pts[i][2] + pts[i + 1][2]) / 2)) * CFrame.Angles(0, math.atan2(-dz, dx), 0)
		p.Color = Color3.fromRGB(63, 155, 220)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.35
		p.Parent = folder
	end
end

function Builder.clearTerrain()
	Workspace.Terrain:Clear()
end

-- Ordner Workspace.Map.<path...>; ein vorhandener letzter Ordner wird ersetzt (Neu-Bauen möglich).
-- Legt das Ampel-Skript in ServerScriptService an (Plugin darf Source setzen), ersetzt ein vorhandenes
function Builder.installScript(name, source)
	local sss = game:GetService("ServerScriptService")
	local old = sss:FindFirstChild(name)
	if old then old:Destroy() end
	local script = Instance.new("Script")
	script.Name = name
	script.Source = source
	script.Parent = sss
end

function Builder.installController(source)
	Builder.installScript("AmpelSteuerung", source)
end

function Builder.container(...)
	local function folder(parent, name, replace)
		local f = parent:FindFirstChild(name)
		if f and replace then
			f:Destroy()
			f = nil
		end
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end
	local path = { ... }
	local f = folder(Workspace, "Map")
	for i, name in ipairs(path) do
		f = folder(f, name, i == #path)
	end
	return f
end

return Builder
