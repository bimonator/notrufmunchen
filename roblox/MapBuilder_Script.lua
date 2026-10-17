-- MapBuilder_Script.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
--
-- NOTRUF MÜNCHEN: KOMPLETTE KARTE IN EINEM SCRIPT
-- So geht's: 1) In Studio ein leeres Baseplate-Projekt öffnen (Baseplate gern löschen).
--            2) In ServerScriptService ein Script "MapBuilder" anlegen, diesen ganzen Text einfügen.
--            3) Unter diesem Script zwei ModuleScripts anlegen (Rechtsklick auf das Script > Insert Object > ModuleScript),
--               umbenennen in "Teil1" und "Teil2" und die Texte aus MapBuilder_Teil1.lua bzw. MapBuilder_Teil2.lua einfügen.
--               (Roblox erlaubt pro Script nur ca. 200 000 Zeichen, darum drei Teile.)
--            4) Oben auf RUN klicken (nicht Play). Das Bauen dauert 1-3 Minuten, Fortschritt steht im Output.
--            5) Mit der Kamera (F im Viewport, WASD + Rechtsklick) zum Siegestor fliegen: Ursprung = (0, 0, 0).
--            Die Karte ist nach dem Stoppen weg. Dauerhaft bauen: MapBuilder_Plugin.lua als lokales Plugin.
--
-- WAS GEBAUT WIRD (Schritte, in dieser Reihenfolge; Output zeigt je Schritt eine Zeile):
--   terrain    Boden, Parks, Hügel (Monopteros), Terrasse (Friedensengel), Isar mit 3-stufiger Böschung, Bach
--   roads      Ring, Leopoldstraße/Ludwigstraße (Achse, rund um das Siegestor ein Kreisverkehr), Schwabinger Raster, Diagonale, Isarspange,
--              Maximilianstraße, Isar-Allee (Ostufer: Straße mit Parkstreifen, Laternen, roter Radweg, Baumreihe, Ufergehweg), Friedensengel-Oval, Kreisverkehr, gerundete Gehwegecken, 12 Zebrastreifen, Parkbuchten, 4 Brücken über die Isar (flach, auf Säulen),
--              Maximilianbrücke (zwei Bögen, Statuen)
--   lights     270 Laternen (runder Mast, Bogenarm, Leuchtkopf), 13 Ampelmasten (Rundmast, Ausleger, Linsenköpfe mit Blenden)
--   marienplatz Neues Rathaus, Mariensäule, U-Bahn-Abgang, Pflaster, Kugelleuchten, Platanen, Cafés (Frauenkirche verkleinert im Nordwesten)
--   autohaus   Autohaus an der V3 mit Showroom (Glas um die Ecke), Parkdeck, Werkstatt, Pylon (ohne Fahrzeuge)
--   einfahrten Einfahrten (Kerben im Gehweg) an Autohaus, Klinik, Polizei, Feuerwache, Parkhaus, Café, Prinz-Eins (nur diese Teile)
--   kreiselwege Gehwege am Siegestor-Kreisel nahtlos an die Zufahrten angeschlossen (nur diese Gehwege)
--   tankshop   Schiebetür und Glastür am Allguth-Shop (nur die Türteile)
--   kaffeehaus Café mit Terrasse zur Leopoldstraße, Parkplatz im Süden (Modell neu)
--   stachus    Stachus: Halbkreis-Geschäftshäuser, Karlstor, Brunnen mit Strahlen, Taxistand (statt Casino/Kaffeehaus-Gelände am Odeonsplatz)
--   landmarks  Siegestor auf Mittelinsel, Friedensengel (Engel mit Flügeln, Ölzweig, Nike; rundes Becken), Frauenkirche (runde Zwiebelhauben),
--              Chinesischer Turm
--   gardens    Hofgarten, Englischer Garten, Monopteros-Tempel, Biergarten, Eisbachwelle, Isar-Uferwege, Prinz-Eins-Vorplatz
--   houses     7 Häuserblöcke mit Rück- und Hinterhäusern, Isar-Allee-Zeile mit Backsteinkirche, Westufer-Zeile, gebogene Eckhäuser am Siegestor, Kino Casino Odeon und Kaffeehaus Odeon am Odeonsplatz, 13 Sonderbauten (Feuerwache, Polizeiwache mit Hof, Klinikum,
--              Tankstelle mit Schirm, Shop und Parkplätzen (3 Ladeplätze, 1 Behindertenparkplatz), Bank, Parkhaus, ...)
--   skyline    5 Hochhäuser (Glas mit abgerundeten Ecken; Vierzylinder-Turm "BMO" mit Logo und blauem Band; Schüssel-Gebäude "BMO Welt" mit Brücke)
--   bus        18 Bushaltestellen (Wartehäuschen, Bank, Schild "H") auf Gehwegen in der Innenstadt
--   wall       Häuserband um die Karte (Mapgrenze) mit Toren und Flusstoren
--
-- WAS FUNKTIONIERT WIE:
--   Ampeln      Starten automatisch nach dem Bauen. Kreuzungen: 30 s grün je Richtung (Einstellung Ampel.config.green weiter unten).
--               Feuerwache: im Run-Modus in der Command Bar  workspace:SetAttribute("WacheAlarm", true)  -> V1/V2 gelb, dann rot;
--               mit false wieder grün. Tag der Lampen: TrafficLight (Gruppen Wache_V1, Wache_V2, Achse_*).
--   Tore/Schranken  Feuerwache-Tore (Tag FireGate) und Polizei-Schranken (Tag Schranke) sind Modelle, noch ohne Skript.
--   Spawns      Polizeihof: 4 Flächen mit Tag VehicleSpawn (Attribut Team = Polizei).
--   Fenster     Tag HouseWindow, Attribut Lit = leuchtet nachts (Tag-Nacht-Skript folgt). Laternen: Tag StreetLamp.
--   Eisbachwelle  an der Maximilianbrücke (Welle flussabwärts, Deck am Westufer). Tags Eisbachwelle, SurfZone (Surf-Skript folgt).
--   Isar-Allee  Ostufer der Isar zwischen Ring Nord und Isarspange (Karte nach Osten um 100 Studs erweitert), 11 Häuser + Backsteinkirche.
--   Alle Maße   in Config (weiter unten im Text, Block "local Config = (function()"): Straßen, Isar, Brücken, Tankstelle, Gärten.
--
-- OUTPUT-ZEILEN, auf die du achten kannst: [boden] (Bodenhöhe), [wasser] ok, [roads], [lights], [landmarks], [gardens], [houses], [wall].
-- Steht irgendwo "FEHLER:", schick mir die Zeile.
--
local STEPS = { "terrain", "roads", "lights", "landmarks", "marienplatz", "stachus", "gardens", "houses", "skyline", "bus", "wall" } -- Teilmenge möglich, z. B. { "roads" }
local ONLY = nil -- nur bestimmte Häuserblöcke, z. B. { "B_NordMitte" }; nil = alle
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

local M = {}
for _, n in ipairs({ "Teil1", "Teil2" }) do
	local mod = script:FindFirstChild(n)
	assert(mod, "ModuleScript '" .. n .. "' fehlt als Kind dieses Scripts (siehe Anleitung oben)")
	require(mod)(M)
end
local Geo = M.Geo
local Config = M.Config
local Planner = M.Planner
local Blocks = M.Blocks
local Specials = M.Specials
local Werkstatt = M.Werkstatt
local Anlagen = M.Anlagen
local RoadsPlanner = M.RoadsPlanner
local LightsPlanner = M.LightsPlanner
local Landmarks = M.Landmarks
local Rathaus = M.Rathaus
local Marienplatz = M.Marienplatz
local Stachus = M.Stachus
local Autohaus = M.Autohaus
local Hochhaus = M.Hochhaus
local Bushaltestellen = M.Bushaltestellen
local TerrainPlanner = M.TerrainPlanner
local Garden = M.Garden
local WallPlanner = M.WallPlanner

local Ampel = (function()
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

end)()
local Builder = (function()
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
local p = Instance.new("Part")
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
p.CanTouch = false
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
local count = 0
local function breathe(every)
count = count + 1
if count % every == 0 then task.wait() end
end
function Builder.buildParts(parts, parent, origin)
for _, spec in ipairs(parts) do
buildPart(spec, origin).Parent = parent
breathe(500)
end
end
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
function Builder.installController(source)
local sss = game:GetService("ServerScriptService")
local old = sss:FindFirstChild("AmpelSteuerung")
if old then old:Destroy() end
local script = Instance.new("Script")
script.Name = "AmpelSteuerung"
script.Source = source
script.Parent = sss
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

end)()
local BuildAll = (function()
local Config = Config
local Blocks = Blocks
local Planner = Planner
local Specials = Specials
local RoadsPlanner = RoadsPlanner
local LightsPlanner = LightsPlanner
local Landmarks = Landmarks
local Rathaus = Rathaus
local Marienplatz = Marienplatz
local Hochhaus = Hochhaus
local Bushaltestellen = Bushaltestellen
local Stachus = Stachus
local Autohaus = Autohaus
local Werkstatt = Werkstatt
local Anlagen = Anlagen
local Garden = Garden
local TerrainPlanner = TerrainPlanner
local WallPlanner = WallPlanner
local Builder = Builder
local Geo = Geo
local BuildAll = {}
local function nearGrass(x, z, r)
for _, p in ipairs(Config.parks) do
if x + r > p.x0 - 8 and x - r < p.x1 + 8 and z + r > p.z0 - 8 and z - r < p.z1 + 8 then return true end
end
local t = Config.terrace
if x + r > t.x0 - 8 and x - r < t.x1 + 8 and z + r > t.z0 - 8 and z - r < t.z1 + 8 then return true end
for _, h in ipairs(Config.hills) do
if math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2) < h.layers[1][1] + r + 8 then return true end
end
return Geo.polyDist(x, z, Config.water.isar.pts) < Config.water.isar.layers[1][3] + 10 + r
end
local STEPS = {
terrain = function(opts, origin)
if opts.clearTerrain ~= false then Builder.clearTerrain() end
local ops = TerrainPlanner.plan(Config)
Builder.applyTerrain(ops, origin)
return string.format("%d Terrain-Operationen", #ops)
end,
kanal = function(opts, origin) -- nur der Eisbach-Kanal (Terrain), wenn das übrige Terrain schon steht; bei "terrain" ist er schon dabei
local ops = TerrainPlanner.planKanal(Config)
Builder.applyTerrain(ops, origin)
return string.format("%d Terrain-Operationen (Eisbach-Kanal)", #ops)
end,
eisbach = function(opts, origin) -- Eisbach-Szene in der fertigen Karte gezielt erneuern (Kanal-Terrain, Brückenbögen, Welle, Mauern), übrige Ordner bleiben unberührt
local map = game:GetService("Workspace"):FindFirstChild("Map")
local roads, gardens = map.Strassen, map.Gruenanlagen
Builder.applyTerrain(TerrainPlanner.planKanal(Config), origin)
local OLD = {} -- Namen der früheren und der neuen Eisbach-Teile im Umkreis der Welle
for _, n in ipairs({ "Eisbachwelle", "Schussrinne", "Kanalwasser", "Kanalboden", "Wellenschaum", "Wellental", "Gischt", "Wellenkamm", "Wellenzug", "SurfZone", "Ufermauer", "Kanalmauer", "Mauerkappe", "Kanalstufe", "Plateau", "Plateaubalken",
"Plateauquerbalken", "Plateaupfosten", "Holzstufe", "RettungsringPfosten", "Rettungsring", "EisStamm", "EisKrone", "Zuschauerdeck", "DeckGelaender", "Schild", "SchildPfosten", "Schrift",
"BankSitz", "BankLehne", "BankBein", "Uferweg", "Wellenhang", "Wellenruecken", "Wellenflanke", "Wellenkrone", "Nachlauf", "Sitzbohle", "Stegstufe", "StegWest", "StegWestBalken", "StegWestQuerbalken",
"StegWestPfosten", "Stegpoller", "RettungsringSegment", "RettungsringTafel", "Kanalboden", "Kanalwasser" }) do OLD[n] = true end
local removed = 0
for _, c in ipairs(gardens:GetChildren()) do
if c:IsA("BasePart") and OLD[c.Name] and c.Position.X > 600 and c.Position.X < 700 and c.Position.Z > 315 and c.Position.Z < 400 then c:Destroy() removed = removed + 1 end
end
for _, c in ipairs(roads:GetChildren()) do
if c.Name:sub(1, 7) == "Eisbach" then c:Destroy() removed = removed + 1 end
end
local bridge = {}
for _, p in ipairs(RoadsPlanner.plan(Config).parts) do
if p.name:sub(1, 7) == "Eisbach" then bridge[#bridge + 1] = p end
end
Builder.buildParts(bridge, roads, origin)
local scene = Garden.planEisbach(Config)
Builder.buildParts(scene, gardens, origin)
return string.format("%d alte Teile entfernt, %d Brückenteile und %d Teile der Szene neu", removed, #bridge, #scene)
end,
fugen = function(opts, origin) -- Plattenfugen und Bänder (Stachus, Marienplatz) in der fertigen Karte erneuern, übrige Teile bleiben
local map = game:GetService("Workspace"):FindFirstChild("Map")
local n = 0
local function redo(folder, parts)
for _, c in ipairs(folder:GetChildren()) do
if c.Name == "Fuge" or c.Name == "Band" then c:Destroy() end
end
local list = {}
for _, p in ipairs(parts) do
if p.name == "Fuge" or p.name == "Band" then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
n = n + #list
end
redo(map.Stachus, Stachus.plan(Config).parts)
redo(map.Marienplatz, Marienplatz.plan(Config).parts)
return string.format("%d Fugen und Bänder erneuert", n)
end,
zylinder = function(opts, origin) -- flache Scheiben (Pflasterringe, Baumscheiben) und Brunnen-Düsen in der fertigen Karte erneuern, übrige Teile bleiben
local map = game:GetService("Workspace"):FindFirstChild("Map")
local n = 0
local function redo(folder, parts, names)
for _, c in ipairs(folder:GetChildren()) do
if names[c.Name] then c:Destroy() end
end
local list = {}
for _, p in ipairs(parts) do
if names[p.name] then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
n = n + #list
end
redo(map.Stachus, Stachus.plan(Config).parts, { Wasserstrahl = true, Duese = true, Pflasterring = true, Baumscheibe = true })
redo(map.Marienplatz, Marienplatz.plan(Config).parts, { SaeulenKreis = true, Baumscheibe = true })
return string.format("%d Teile erneuert", n)
end,
stachuslaternen = function(opts, origin) -- nur die Kugelleuchten am Stachus in der fertigen Karte neu setzen
local folder = game:GetService("Workspace"):FindFirstChild("Map").Stachus
for _, c in ipairs(folder:GetChildren()) do
if c.Name == "KugelleuchteMast" or c.Name == "Kugelleuchte" then c:Destroy() end
end
local list = {}
for _, p in ipairs(Stachus.plan(Config).parts) do
if p.name == "KugelleuchteMast" or p.name == "Kugelleuchte" then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
return string.format("%d Teile der Kugelleuchten erneuert", #list)
end,
pave = function(opts, origin) -- Terrain unter Wegen und Straßen von Gras zu Pflaster, damit dort keine Gras-Büschel wachsen
local roadPlan = RoadsPlanner.plan(Config)
local specs = {}
for _, list in ipairs({ roadPlan.parts, Garden.plan(Config, roadPlan, Specials).parts }) do
for _, p in ipairs(list) do specs[#specs + 1] = p end
end
local n = Builder.paveUnder(specs, origin, function(p) return nearGrass(p.pos[1], p.pos[3], math.max(p.size[1], p.size[3]) / 2) end)
return string.format("%d Zellenreihen unter Wegen und Straßen von Gras zu Pflaster", n)
end,
roads = function(opts, origin)
local plan = RoadsPlanner.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Strassen"), origin)
return string.format("%d Teile, %d Parkbuchten", #plan.parts, plan.stats.bays)
end,
lights = function(opts, origin)
local plan = LightsPlanner.plan(Config, RoadsPlanner.plan(Config))
Builder.buildParts(plan.parts, Builder.container("Strassenmobiliar"), origin)
return string.format("%d Laternen, %d Ampelmasten, %d Fußgängerampeln, %d Teile", plan.stats.lamps, plan.stats.signals, plan.stats.ped, #plan.parts)
end,
landmarks = function(opts, origin)
local plan = Landmarks.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Wahrzeichen"), origin)
return string.format("%d Teile (Siegestor, Friedensengel, Frauenkirche, Chinesischer Turm)", #plan.parts)
end,
marienplatz = function(opts, origin)
local folder = Builder.container("Marienplatz")
local rh, mp = Rathaus.plan(Config), Marienplatz.plan(Config)
Builder.buildParts(rh, folder, origin)
Builder.buildParts(mp.parts, folder, origin)
return string.format("%d Teile (Rathaus %d, Platz %d), %d Kugelleuchten, %d Platanen, U-Bahn-Abgang mit %d Stufen", #rh + #mp.parts, #rh, #mp.parts, mp.stats.lamps, mp.stats.trees, mp.stats.steps)
end,
skyline = function(opts, origin)
local plan = Hochhaus.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Hochhaeuser"), origin)
return string.format("%d Teile, %d Hochhäuser (höchstes %d Studs)", #plan.parts, plan.stats.towers, plan.stats.tallest)
end,
bus = function(opts, origin)
local plan = Bushaltestellen.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Bushaltestellen"), origin)
return string.format("%d Haltestellen, %d Teile", plan.stats.stops, #plan.parts)
end,
einfahrten = function(opts, origin) -- Einfahrten (Kerben im Gehweg) in der fertigen Karte erneuern, übrige Straßenteile bleiben
local folder = game:GetService("Workspace"):FindFirstChild("Map").Strassen
local removed = 0
for _, c in ipairs(folder:GetChildren()) do
if c.Name == "Einfahrt" or c.Name == "EinfahrtRampe" then c:Destroy() removed = removed + 1 end
end
local list = {}
for _, p in ipairs(RoadsPlanner.plan(Config).parts) do
if p.name == "Einfahrt" or p.name == "EinfahrtRampe" then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
return string.format("%d alte Teile entfernt, %d neu", removed, #list)
end,
kreiselwege = function(opts, origin) -- alle Gehwege, Eckrundungen und der Siegestor-Kreisel neu; Fahrbahnen und übrige Straßenteile bleiben
local folder = game:GetService("Workspace"):FindFirstChild("Map").Strassen
local CORNER = { GehwegEcke = true, GehwegEckeRund = true, EckAsphalt = true }
local function mine(name, x, z)
return name:match("^%w+_%d+_walk$") or name:match("^SiegestorKreisel_") or name == "GehwegKurve" or name == "KreiselEckAsphalt" or CORNER[name]
end
local removed = 0
for _, c in ipairs(folder:GetChildren()) do
if c:IsA("BasePart") and mine(c.Name, c.Position.X - origin.X, c.Position.Z - origin.Z) then c:Destroy() removed = removed + 1 end
end
local list = {}
for _, p in ipairs(RoadsPlanner.plan(Config).parts) do
if mine(p.name, p.pos[1], p.pos[3]) then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
return string.format("%d alte Gehwegteile entfernt, %d neu", removed, #list)
end,
tankshop = function(opts, origin) -- nur die Eingangstür des Allguth-Shops (Schiebetür, Glastür, Matte) erneuern
local model = game:GetService("Workspace"):FindFirstChild("Map").Gebaeude.Sonderbauten["Sonder_Tankstellen-Shop"]
local NAMES = { ShopTuer = true, ShopTuerrahmen = true, Schiebetuer = true, Schiebetuerrahmen = true, Schiebetuerantrieb = true, Tuersensor = true,
Glastuer = true, GlastuerRahmen = true, GlastuerGriff = true, Tuermatte = true }
local removed = 0
for _, c in ipairs(model:GetChildren()) do
if NAMES[c.Name] then c:Destroy() removed = removed + 1 end
end
local spec
for _, sp in ipairs(Specials) do if sp.name == "Tankstellen-Shop" then spec = sp end end
local list = {}
for _, p in ipairs(Planner.planSpecial(spec, { seed = opts.seed or 1 }).houses[1].parts) do
if NAMES[p.name] then list[#list + 1] = p end
end
Builder.buildParts(list, model, origin)
return string.format("%d alte Türteile entfernt, %d neu", removed, #list)
end,
kaffeehaus = function(opts, origin) -- Café neu (Terrasse zur Leopoldstraße, Parkplatz im Süden)
local folder = game:GetService("Workspace"):FindFirstChild("Map").Gebaeude.Sonderbauten
local old = folder:FindFirstChild("Sonder_Kaffeehaus")
if old then old:Destroy() end
for _, sp in ipairs(Specials) do
if sp.name == "Kaffeehaus" then Builder.build(Planner.planSpecial(sp, { seed = opts.seed or 1 }), folder, origin) end
end
return "Kaffeehaus neu gebaut"
end,
autohaus = function(opts, origin)
local plan = Autohaus.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Autohaus"), origin)
return string.format("%d Teile (%d Boxenlinien, %d Leuchten, %d Bäume), keine Fahrzeuge", #plan.parts, plan.stats.bays, plan.stats.lamps, plan.stats.trees)
end,
anlagen = function(opts, origin) -- Allee, Klinikpark, Ufer-Parks: Rasen (Terrain), Wege, Bäume usw.; ersetzt nur den Ordner Anlagen
local ops = Anlagen.terrain(Config)
Builder.applyTerrain(ops, origin)
local plan = Anlagen.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Anlagen"), origin)
Builder.paveUnder(plan.parts, origin, function() return true end) -- keine Gras-Büschel durch die Kieswege
local st = plan.stats
return string.format("%d Anlagen, %d Teile, %d Rasen-Blöcke, %d Bäume, %d Bänke, %d Leuchten, %d Büsche, %d Findlinge", st.areas, #plan.parts, #ops, st.trees, st.benches, st.lamps, st.bushes, st.rocks)
end,
werkstatt = function(opts, origin)
local plan = Werkstatt.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Werkstatt"), origin)
return string.format("%d Teile (%d Tore, %d Schriften, %d Leuchten)", #plan.parts, plan.stats.gates, plan.stats.texts, plan.stats.lamps)
end,
stachus = function(opts, origin)
local plan = Stachus.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Stachus"), origin)
local st = plan.stats
return string.format("%d Teile (%d Abschnitte, %d Läden, %d Wasserstrahlen, %d Zinnen, %d Taxis)", #plan.parts, st.segs, st.shops, st.jets, st.merlons, st.taxis)
end,
gardens = function(opts, origin)
local plan = Garden.plan(Config, RoadsPlanner.plan(Config), Specials)
Builder.buildParts(plan.parts, Builder.container("Gruenanlagen"), origin)
local st = plan.stats
return string.format("%d Teile, %d Bäume, %d Uferweg-Platten, %d Findlinge", #plan.parts, st.hofTrees + st.egTrees, st.bank.slabs, st.bank.rocks)
end,
houses = function(opts, origin)
local only, houses, parts = {}, 0, 0
for _, n in ipairs(opts.only or {}) do only[n] = true end
for _, block in ipairs(Blocks) do
if next(only) == nil or only[block.name] then
local plan = Planner.planBlock(block, { seed = opts.seed or 1, raise = Config.eckhaeuser })
Builder.build(plan, Builder.container("Gebaeude", block.name), origin)
local st = Planner.stats(plan)
houses, parts = houses + st.houses, parts + st.parts
end
end
if next(only) == nil or only.IsarAllee then
local plan = Planner.planAllee(Config, { seed = opts.seed or 1 })
Builder.build(plan, Builder.container("Gebaeude", "IsarAllee"), origin)
local st = Planner.stats(plan)
houses, parts = houses + st.houses, parts + st.parts
end
if next(only) == nil or only.IsarWestufer then
local plan = Planner.planWestbank(Config, { seed = opts.seed or 1 })
local folder = Builder.container("Gebaeude", "IsarWestufer")
Builder.build(plan, folder, origin)
Builder.buildParts(plan.parts, folder, origin)
local st = Planner.stats(plan)
houses, parts = houses + st.houses, parts + st.parts + #plan.parts
end
if next(only) == nil or only.SiegestorEcken then
local plan = Planner.planCorners(Config, { seed = opts.seed or 1 })
Builder.build(plan, Builder.container("Gebaeude", "SiegestorEcken"), origin)
local st = Planner.stats(plan)
houses, parts = houses + st.houses, parts + st.parts
end
if next(only) == nil then
local folder = Builder.container("Gebaeude", "Sonderbauten")
for _, spec in ipairs(Specials) do
local plan = Planner.planSpecial(spec, { seed = opts.seed or 1 })
Builder.build(plan, folder, origin)
local st = Planner.stats(plan)
houses, parts = houses + st.houses, parts + st.parts
end
end
return string.format("%d Häuser, %d Teile", houses, parts)
end,
wall = function(opts, origin)
local plan = WallPlanner.plan(Config, { seed = opts.seed or 1 })
local folder = Builder.container("Mapgrenze")
Builder.build(plan, folder, origin)
Builder.buildParts(plan.parts, folder, origin)
local st = Planner.stats(plan)
return string.format("%d Gebäude, %d Teile", st.houses, st.parts + #plan.parts)
end,
}
BuildAll.order = { "terrain", "roads", "lights", "landmarks", "marienplatz", "stachus", "autohaus", "werkstatt", "anlagen", "gardens", "pave", "houses", "skyline", "bus", "wall" }
local function afterTerrain(base)
local ground = Builder.measureGround(base)
print(string.format("[boden] Terrain-Oberkante gemessen: %.1f, alle weiteren Teile werden daran ausgerichtet", ground))
local pts = Config.water.isar.pts
local mid = pts[math.ceil(#pts / 2)]
local water = Builder.countWater(base + Vector3.new(mid[1], Config.water.isar.waterTop - 2, mid[2]))
if water == nil then
print("[wasser] Auslesen nicht möglich, bitte im Studio nachsehen")
elseif water == 0 then
print("[wasser] KEIN Terrain-Wasser gefunden, setze blaue Ersatz-Platten (nicht schwimmbar)")
Builder.waterFallback(pts, 38, Config.water.isar.waterTop + 0.2, base + Vector3.new(0, ground, 0))
else
print(string.format("[wasser] ok (%d Wasser-Zellen am Messpunkt)", water))
end
return ground
end
function BuildAll.run(opts)
opts = opts or {}
local base = opts.origin or Vector3.new(0, 0, 0)
local steps = opts.steps or BuildAll.order
local ground = 0
local hasTerrain = false
for _, n in ipairs(steps) do hasTerrain = hasTerrain or n == "terrain" end
if not hasTerrain then ground = Builder.measureGround(base) end -- vorhandenes Terrain, z. B. beim zweiten Lauf
for _, name in ipairs(steps) do
local origin = base + Vector3.new(0, ground, 0)
local ok, result = pcall(STEPS[name], opts, origin) -- ein fehlerhafter Schritt stoppt die anderen nicht
print(string.format("[%s] %s", name, ok and result or ("FEHLER: " .. tostring(result))))
if name == "terrain" and ok then
local ok2, g = pcall(afterTerrain, base)
if ok2 then ground = g else print("[boden] FEHLER: " .. tostring(g)) end
end
end
if opts.controllerSource then -- Plugin: Ampel-Skript dauerhaft anlegen
local ok, err = pcall(Builder.installController, opts.controllerSource)
print(ok and "[ampel] Script AmpelSteuerung in ServerScriptService angelegt" or ("[ampel] FEHLER: " .. tostring(err)))
end
if opts.afterBuild then opts.afterBuild() print("[ampel] läuft (nur bis zum Stoppen)") end -- Test-Script
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapBuilder") end) -- Strg+Z
print("Fertig")
end
return BuildAll

end)()
BuildAll.run({ steps = STEPS, only = ONLY, origin = ORIGIN, afterBuild = Ampel.start })
