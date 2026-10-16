"""Erzeugt aus den Modulen in MapBuilder/ die Dateien zum Einfügen ins Studio:
  MapBuilder_Script.lua  - Script für ServerScriptService, baut beim Klick auf Run (Test, nicht dauerhaft)
  MapBuilder_Plugin.lua  - als lokales Plugin speichern, baut per Knopf im Edit-Modus (dauerhaft)
  MapBuilder_Teil1.lua, MapBuilder_Teil2.lua - ModuleScripts "Teil1" und "Teil2" als Kinder des Scripts (für beide Varianten gleich)
Roblox begrenzt ein Script auf ca. 200 000 Zeichen, darum sind die Planer auf zwei ModuleScripts verteilt.
Aufruf: python3 make_bundles.py"""
import os
import re

here = os.path.dirname(os.path.abspath(__file__))
PARTS = [ # ModuleScripts (Name, Module); jedes Teil bekommt die Module der vorigen Teile über die Tabelle M
    ("Teil1", ["Geo", "Config", "Planner", "Blocks", "Specials"]),
    ("Teil2", ["RoadsPlanner", "LightsPlanner", "Landmarks", "Rathaus", "Marienplatz", "Hochhaus", "Bushaltestellen", "TerrainPlanner", "Garden", "WallPlanner"]),
]
MAIN = ["Ampel", "Builder", "BuildAll"]
LIMIT = 190000  # Sicherheitsabstand zur Roblox-Grenze von ca. 200 000 Zeichen je Script


def read(name):
    with open(os.path.join(here, "MapBuilder", name + ".lua"), encoding="utf-8") as f:
        text = f.read().rstrip() + "\n"
    # reine Kommentarzeilen entfallen im Bundle (Roblox-Scripts sind auf ca. 200 000 Zeichen begrenzt); die Originale bleiben in MapBuilder/
    text = "".join(l.lstrip() for l in text.splitlines(True) if not l.lstrip().startswith("--"))  # auch die Einrückung entfällt (Lua ignoriert sie)
    # require(script and script.Parent.X or "X") -> lokale Variable X
    return re.sub(r'require\(script and script\.Parent\.(\w+) or "\w+"\)', r"\1", text)


def body(names):
    return "".join("local %s = (function()\n%s\nend)()\n" % (n, read(n)) for n in names)


def part_module(name, names, before):
    head = "-- MapBuilder_%s.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)\n" % name
    head += "-- ModuleScript mit dem Namen \"%s\" als Kind des Scripts MapBuilder (bzw. des Plugin-Scripts) anlegen und diesen Text einfügen.\n" % name
    pre = "".join("local %s = M.%s\n" % (n, n) for n in before)
    post = "".join("M.%s = %s\n" % (n, n) for n in names)
    return head + "return function(M)\n" + pre + body(names) + post + "end\n"


ALL = [n for _, names in PARTS for n in names]
LOADER = ("local M = {}\n"
          "for _, n in ipairs({ %s }) do\n"
          "\tlocal mod = script:FindFirstChild(n)\n"
          "\tassert(mod, \"ModuleScript '\" .. n .. \"' fehlt als Kind dieses Scripts (siehe Anleitung oben)\")\n"
          "\trequire(mod)(M)\n"
          "end\n" % ", ".join('"%s"' % n for n, _ in PARTS)
          + "".join("local %s = M.%s\n" % (n, n) for n in ALL) + "\n")


script = """-- MapBuilder_Script.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
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
local STEPS = { "terrain", "roads", "lights", "landmarks", "marienplatz", "gardens", "houses", "skyline", "bus", "wall" } -- Teilmenge möglich, z. B. { "roads" }
local ONLY = nil -- nur bestimmte Häuserblöcke, z. B. { "B_NordMitte" }; nil = alle
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

""" + LOADER + body(MAIN) + "BuildAll.run({ steps = STEPS, only = ONLY, origin = ORIGIN, afterBuild = Ampel.start })\n"

plugin = """-- MapBuilder_Plugin.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- Dauerhaft bauen: in Workspace ein Script anlegen, alles einfügen. Darunter zwei ModuleScripts "Teil1" und "Teil2" mit den Texten aus
-- MapBuilder_Teil1.lua und MapBuilder_Teil2.lua anlegen. Dann Rechtsklick auf das Script > "Als lokales Plugin speichern" (die
-- ModuleScripts werden mitgespeichert). Danach das Script löschen. Im Reiter Plugins erscheint der Knopf "Karte bauen".
-- Der Knopf baut im Edit-Modus, die Objekte bleiben im Projekt erhalten (Strg+Z macht es rückgängig).
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

""" + LOADER + body(MAIN) + """local AMPEL_SOURCE = [==[
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

files = [("MapBuilder_Script.lua", script), ("MapBuilder_Plugin.lua", plugin)]
before = []
for name, names in PARTS:
    files.append(("MapBuilder_%s.lua" % name, part_module(name, names, before)))
    before = before + names
# Alles in einer Datei (ohne ModuleScripts): kann über der Roblox-Grenze von ca. 200 000 Zeichen liegen, darum ohne Prüfung
single = script.split(LOADER)[0] + body(ALL + MAIN) + "BuildAll.run({ steps = STEPS, only = ONLY, origin = ORIGIN, afterBuild = Ampel.start })\n"
single = single.replace("zwei ModuleScripts anlegen", "zwei ModuleScripts anlegen (bei dieser Datei NICHT nötig)")
files.append(("MapBuilder_Alles.lua", single))
for name, text in files:
    if name != "MapBuilder_Alles.lua":
        assert len(text) <= LIMIT, "%s ist %d Zeichen lang (Grenze %d): Module neu auf die Teile verteilen" % (name, len(text), LIMIT)
    with open(os.path.join(here, name), "w", encoding="utf-8") as f:
        f.write(text)
    print(name, len(text.splitlines()), "Zeilen,", len(text), "Zeichen")
