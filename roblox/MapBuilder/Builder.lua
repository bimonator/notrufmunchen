-- Builder.lua
-- Wandelt die Pläne (Teilelisten, Terrain-Operationen) in Roblox-Instanzen um. Läuft im Studio.
-- Die Roblox-Aufrufe hier sind in der Cloud-Session nur gegen eine Attrappe getestet, nicht gegen echtes Roblox.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic, Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick,
	Glass = Enum.Material.Glass, Wood = Enum.Material.Wood, Metal = Enum.Material.Metal, Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Pavement, Grass = Enum.Material.Grass, Water = Enum.Material.Water, Neon = Enum.Material.Neon, Air = Enum.Material.Air,
}

local function buildPart(spec, origin)
	local p = Instance.new("Part")
	p.Name = spec.name
	p.Anchored = true
	p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	p.CFrame = CFrame.new(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]))
		* CFrame.Angles(0, math.rad(spec.yaw), 0) * CFrame.Angles(math.rad(spec.pitch or 0), 0, 0)
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
	if spec.attrs then
		for k, v in pairs(spec.attrs) do p:SetAttribute(k, v) end -- z. B. Lampenfarbe für das Ampel-Skript
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

-- Häuser: je Haus ein Model (PrimaryPart = Body)
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
		model.Parent = parent -- erst am Ende, spart Replikation
		breathe(8)
	end
end

function Builder.applyTerrain(ops, origin)
	local terrain = Workspace.Terrain
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
