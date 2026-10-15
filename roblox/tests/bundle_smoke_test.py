"""Lässt das QuickTest-Bundle gegen eine kleine Roblox-Attrappe (Instance, Vector3, CFrame ...) laufen.
Fängt Tippfehler und nil-Zugriffe in Builder/Run ab. Prüft NICHT, ob die echte Roblox-API sich genauso verhält."""
import os
from lupa import lua51

here = os.path.dirname(os.path.abspath(__file__))
STUB = r'''
local function newInstance(class)
	local children = {}
	local inst = { ClassName = class, _children = children, _attrs = {}, _tags = {} }
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
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
local C = {}
C.__index = C
C.__mul = function(a, b) return setmetatable({ v = a.v, ang = b.ang }, C) end
CFrame = { new = function(v) return setmetatable({ v = v }, C) end, Angles = function(x, y, z) return setmetatable({ ang = { x, y, z } }, C) end }
Color3 = { fromRGB = function(r, g, b) assert(r and g and b); return { r, g, b } end }
local mats = {}
Enum = { Material = setmetatable({}, { __index = function(t, k) mats[k] = true; return k end }) }
local root = newInstance("DataModel")
local services = { Workspace = newInstance("Workspace") }
tagged = 0
services.CollectionService = { AddTag = function(self, p, t) assert(p and t); tagged = tagged + 1 end }
services.ChangeHistoryService = { SetWaypoint = function() end }
game = { GetService = function(self, n) return services[n] end }
function countParts(i)
	local n = (i.ClassName == "Part") and 1 or 0
	for _, c in ipairs(i._children) do n = n + countParts(c) end
	return n
end
function countModels(i)
	local n = (i.ClassName == "Model") and 1 or 0
	for _, c in ipairs(i._children) do n = n + countModels(c) end
	return n
end
workspace_ = services.Workspace
'''

lua = lua51.LuaRuntime()
lua.execute(STUB)
with open(os.path.join(here, "..", "HouseGenerator_QuickTest.lua"), encoding="utf-8") as f:
    code = f.read()
lua.execute(code)
ws = lua.eval("workspace_")
parts, models, tagged = lua.eval("countParts(workspace_)"), lua.eval("countModels(workspace_)"), lua.eval("tagged")
print("Attrappe: %d Models, %d Parts, %d Fenster-Tags" % (models, parts, tagged))
assert models == 18 and parts > 800 and tagged > 100, "unerwartete Mengen"
# Neu bauen ersetzt den Ordner statt zu verdoppeln
lua.execute("Run_again = true")
lua.execute(code)
assert lua.eval("countModels(workspace_)") == 18, "zweiter Lauf hat Häuser verdoppelt"
print("Smoke-Test bestanden (zweiter Lauf ersetzt den Block)")
