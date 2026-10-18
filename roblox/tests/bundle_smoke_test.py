"""Lässt MapBuilder_Script.lua gegen eine kleine Roblox-Attrappe (Instance, Vector3, CFrame, Terrain ...) laufen.
Fängt Tippfehler und nil-Zugriffe in Builder/BuildAll ab. Prüft NICHT, ob die echte Roblox-API sich genauso verhält."""
import os
from lupa import lua51

here = os.path.dirname(os.path.abspath(__file__))
STUB = r'''
local function newInstance(class)
	local children = {}
	local inst = { ClassName = class, _children = children, _attrs = {} }
	function inst:FindFirstChild(n)
		for _, c in ipairs(children) do if c.Name == n then return c end end
	end
	function inst:Destroy()
		local p = rawget(self, "_parent")
		if p then for i, c in ipairs(p._children) do if c == self then table.remove(p._children, i) break end end end
	end
	function inst:SetAttribute(k, v) self._attrs[k] = v end
	setmetatable(inst, { __newindex = function(t, k, v)
		if k == "Parent" then rawset(t, "_parent", v); table.insert(v._children, t) else rawset(t, k, v) end
	end })
	return inst
end
Instance = { new = function(c) return newInstance(c) end }
local V = {}
V.__index = V
V.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V) end
V.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
local C = {}
C.__index = C
C.__mul = function(a, b) return setmetatable({ v = a.v or b.v, ang = b.ang or a.ang }, C) end
CFrame = { new = function(v) return setmetatable({ v = v }, C) end, Angles = function(x, y, z) assert(x and y and z); return setmetatable({ ang = { x, y, z } }, C) end }
Color3 = { fromRGB = function(r, g, b) assert(r and g and b); return { r, g, b } end }
local mats = {}
Enum = { Material = setmetatable({}, { __index = function(t, k) mats[k] = true; return k end }) }
task = { wait = function() end, spawn = function() end }
terrainCalls, tagged = 0, 0
local terrain = { Clear = function() end }
terrain.ReadVoxels = function(self, region, res) return { { { Enum.Material.Water } } } end
Region3 = { new = function(a, b) return { ExpandToGrid = function(self, r) return self end } end }
RaycastParams = { new = function() return {} end }
Enum.RaycastFilterType = { Include = "Include" }
Enum.PartType = { Cylinder = "Cylinder", Ball = "Ball" }
Enum.NormalId = { Front = "Front" }
Enum.SurfaceGuiSizingMode = { PixelsPerStud = "PixelsPerStud" }
Enum.Font = { GothamBold = "GothamBold" }
UDim2 = { fromScale = function(a, b) return { a, b } end }
terrain.FillBlock = function(self, cf, size, mat) assert(cf and size and mat, "FillBlock: Argument fehlt"); terrainCalls = terrainCalls + 1 end
terrain.FillCylinder = function(self, cf, h, r, mat) assert(cf and h and r and mat, "FillCylinder: Argument fehlt"); terrainCalls = terrainCalls + 1 end
local services = { Workspace = newInstance("Workspace") }
services.Workspace.Terrain = terrain
services.Workspace.Raycast = function(self, origin, dir, params) return { Position = { Y = -2 } } end
services.ServerScriptService = newInstance('ServerScriptService')
services.CollectionService = { GetTagged = function() return {} end, AddTag = function(self, p, t) assert(p and t); tagged = tagged + 1 end }
services.ChangeHistoryService = { SetWaypoint = function() end }
game = { GetService = function(self, n) return services[n] end }
function count(i, class)
	local n = (i.ClassName == class) and 1 or 0
	for _, c in ipairs(i._children) do n = n + count(c, class) end
	return n
end
workspace_ = services.Workspace
'''

# Script und Plugin laden die ModuleScripts "Teil1"/"Teil2" als Kinder von script: Attrappe liest sie aus MapBuilder_TeilN.lua
PARTS = {}
for n in ("Teil1", "Teil2"):
    with open(os.path.join(here, "..", "MapBuilder_%s.lua" % n), encoding="utf-8") as f:
        PARTS[n] = f.read()
CHILDREN = r'''
script = { FindFirstChild = function(self, n) if PART_SOURCE[n] then return { Name = n } end end }
require = function(mod) return assert(loadstring(PART_SOURCE[mod.Name], mod.Name))() end
'''


def new_runtime():
    rt = lua51.LuaRuntime()
    rt.execute(STUB)
    rt.globals().PART_SOURCE = rt.table_from(PARTS)
    rt.execute(CHILDREN)
    return rt


lua = new_runtime()
with open(os.path.join(here, "..", "MapBuilder_Script.lua"), encoding="utf-8") as f:
    code = f.read()
lua.execute(code)
parts, models, terrain = lua.eval("count(workspace_, 'Part')"), lua.eval("count(workspace_, 'Model')"), lua.eval("terrainCalls")
print("Attrappe: %d Models, %d Parts, %d Terrain-Aufrufe, %d Fenster-Tags" % (models, parts, terrain, lua.eval("tagged")))
assert models > 220, "Models: %d" % models
assert terrain > 800, "Terrain-Aufrufe: %d" % terrain
assert parts > 16000, "Parts: %d" % parts
lua.execute(code)  # zweiter Lauf ersetzt die Ordner statt sie zu verdoppeln
assert lua.eval("count(workspace_, 'Model')") == models and lua.eval("count(workspace_, 'Part')") == parts, "zweiter Lauf hat verdoppelt"
print("Smoke-Test bestanden (auch der zweite Lauf)")

# Plugin-Bundle: Knopf bauen und prüfen, dass das Ampel-Skript angelegt wird
lua = new_runtime()
lua.execute("""
clicked = nil
plugin = { CreateToolbar = function() return { CreateButton = function() return { Click = { Connect = function(_, f) clicked = f end } } end } end }
""")
with open(os.path.join(here, "..", "MapBuilder_Plugin.lua"), encoding="utf-8") as f:
    lua.execute(f.read())
lua.execute("clicked()")
assert lua.eval("game:GetService('ServerScriptService'):FindFirstChild('AmpelSteuerung') ~= nil"), "Plugin legt kein Ampel-Skript an"
assert "Ampel.start()" in lua.eval("game:GetService('ServerScriptService'):FindFirstChild('AmpelSteuerung').Source")
lua.execute("clicked()")
assert lua.eval("count(game:GetService('ServerScriptService'), 'Script')") == 1, "Ampel-Skript doppelt"
assert lua.eval("game:GetService('ServerScriptService'):FindFirstChild('TramSteuerung') == nil"), "Standardbau legt TramSteuerung an (Tram ist nicht im Standardbau)"
print("Plugin-Test bestanden (Knopf, Ampel-Skript einmalig, keine Tram)")

# Modul-Bundle (für MCP/Skripte): require liefert run(), nur ein Schritt lässt sich bauen
lua = new_runtime()
with open(os.path.join(here, "..", "MapBuilder_Modul.lua"), encoding="utf-8") as f:
    lua.execute("MB = (function(...)\n" + f.read() + "\nend)()")
assert lua.eval("type(MB.run) == 'function' and type(MB.AMPEL_SOURCE) == 'string' and #MB.order >= 10"), "Modul liefert run/AMPEL_SOURCE nicht"
lua.execute("MB.run({ steps = { 'bus' }, controllerSource = MB.AMPEL_SOURCE })")
assert lua.eval("count(workspace_, 'Part')") > 150, "Modul: Schritt bus hat nichts gebaut"
lua.execute("MB.run({ steps = { 'tram' } })")
assert lua.eval("game:GetService('ServerScriptService'):FindFirstChild('TramSteuerung') ~= nil"), "Modul: Schritt tram legt TramSteuerung nicht an"
assert "Heartbeat" in lua.eval("game:GetService('ServerScriptService'):FindFirstChild('TramSteuerung').Source"), "Modul: TramSteuerung ohne Fahrschleife"
print("Modul-Test bestanden (require, einzelner Schritt, Tram-Skript)")
