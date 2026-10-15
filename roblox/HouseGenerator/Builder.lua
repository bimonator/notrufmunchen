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
	local map = Workspace:FindFirstChild("Map") or Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace
	local all = map:FindFirstChild("Gebaeude") or Instance.new("Folder")
	all.Name = "Gebaeude"
	all.Parent = map
	local old = all:FindFirstChild(blockName)
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = blockName
	folder.Parent = all
	return folder
end

return Builder
