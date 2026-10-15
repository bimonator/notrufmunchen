"""Erzeugt aus den Modulen in MapBuilder/ zwei Einzeldateien zum Einfügen ins Studio:
  MapBuilder_Script.lua  - Script für ServerScriptService, baut beim Klick auf Run (Test, nicht dauerhaft)
  MapBuilder_Plugin.lua  - als lokales Plugin speichern, baut per Knopf im Edit-Modus (dauerhaft)
Aufruf: python3 make_bundles.py"""
import os
import re

here = os.path.dirname(os.path.abspath(__file__))
ORDER = ["Geo", "Config", "Planner", "Blocks", "Specials", "RoadsPlanner", "LightsPlanner", "Ampel", "TerrainPlanner", "WallPlanner", "Builder", "BuildAll"]


def read(name):
    with open(os.path.join(here, "MapBuilder", name + ".lua"), encoding="utf-8") as f:
        text = f.read().rstrip() + "\n"
    # require(script and script.Parent.X or "X") -> lokale Variable X
    return re.sub(r'require\(script and script\.Parent\.(\w+) or "\w+"\)', r"\1", text)


def modules():
    return "".join("local %s = (function()\n%s\nend)()\n\n" % (n, read(n)) for n in ORDER)


script = """-- MapBuilder_Script.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- Test: in ServerScriptService ein Script anlegen, alles einfügen, oben im Studio auf RUN (nicht Play) klicken.
-- Die Karte entsteht nur zur Laufzeit und ist nach dem Stoppen weg. Für dauerhaftes Bauen: MapBuilder_Plugin.lua.
local STEPS = { "terrain", "roads", "lights", "houses", "wall" } -- Teilmenge möglich, z. B. { "roads" }
local ONLY = nil -- nur bestimmte Häuserblöcke, z. B. { "B_NordMitte" }; nil = alle
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

""" + modules() + "BuildAll.run({ steps = STEPS, only = ONLY, origin = ORIGIN, afterBuild = Ampel.start })\n"

plugin = """-- MapBuilder_Plugin.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- Dauerhaft bauen: in Workspace ein Script anlegen, alles einfügen, Rechtsklick auf das Script >
-- "Als lokales Plugin speichern". Danach das Script löschen. Im Reiter Plugins erscheint der Knopf "Karte bauen".
-- Der Knopf baut im Edit-Modus, die Objekte bleiben im Projekt erhalten (Strg+Z macht es rückgängig).
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

""" + modules() + """local AMPEL_SOURCE = [==[
local Ampel = (function()
""" + read("Ampel") + """
end)()
Ampel.start()
]==]

local toolbar = plugin:CreateToolbar("Notruf München")
local button = toolbar:CreateButton("Karte bauen", "Terrain, Straßen, Ampeln, Laternen, Häuser und Mapgrenze bauen", "")
button.Click:Connect(function()
	BuildAll.run({ origin = ORIGIN, controllerSource = AMPEL_SOURCE })
end)
"""

for name, text in (("MapBuilder_Script.lua", script), ("MapBuilder_Plugin.lua", plugin)):
    with open(os.path.join(here, name), "w", encoding="utf-8") as f:
        f.write(text)
    print(name, len(text.splitlines()), "Zeilen")
