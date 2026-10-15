-- Builder.lua
-- Wandelt die Pläne (Teilelisten, Terrain-Operationen) in Roblox-Instanzen um. Läuft im Studio.
-- Die Roblox-Aufrufe hier sind in der Cloud-Session nur gegen eine Attrappe getestet, nicht gegen echtes Roblox.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic, Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick,
	Glass = Enum.Material.Glass, Wood = Enum.Material.Wood, Metal = Enum.Material.Metal, Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Pavement, Grass = Enum.Material.Grass, Water = Enum.Material.Water, Air = Enum.Material.Air,
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
		task.wait()
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
