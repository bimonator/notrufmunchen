"""Erzeugt aus den Modulen in MapBuilder/ zwei Einzeldateien zum Einfügen ins Studio:
  MapBuilder_Script.lua  - Script für ServerScriptService, baut beim Klick auf Run (Test, nicht dauerhaft)
  MapBuilder_Plugin.lua  - als lokales Plugin speichern, baut per Knopf im Edit-Modus (dauerhaft)
Aufruf: python3 make_bundles.py"""
import os
import re

here = os.path.dirname(os.path.abspath(__file__))
ORDER = ["Geo", "Config", "Planner", "Blocks", "Specials", "RoadsPlanner", "LightsPlanner", "Landmarks", "Ampel", "TerrainPlanner", "Garden", "WallPlanner", "Builder", "BuildAll"]


def read(name):
    with open(os.path.join(here, "MapBuilder", name + ".lua"), encoding="utf-8") as f:
        text = f.read().rstrip() + "\n"
    # reine Kommentarzeilen entfallen im Bundle (Roblox-Scripts sind auf ca. 200 000 Zeichen begrenzt); die Originale bleiben in MapBuilder/
    text = "".join(l for l in text.splitlines(True) if not l.lstrip().startswith("--"))
    # require(script and script.Parent.X or "X") -> lokale Variable X
    return re.sub(r'require\(script and script\.Parent\.(\w+) or "\w+"\)', r"\1", text)


def modules():
    return "".join("local %s = (function()\n%s\nend)()\n\n" % (n, read(n)) for n in ORDER)


script = """-- MapBuilder_Script.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
--
-- NOTRUF MÜNCHEN: KOMPLETTE KARTE IN EINEM SCRIPT
-- So geht's: 1) In Studio ein leeres Baseplate-Projekt öffnen (Baseplate gern löschen).
--            2) In ServerScriptService ein Script anlegen, diesen ganzen Text einfügen.
--            3) Oben auf RUN klicken (nicht Play). Das Bauen dauert 1-3 Minuten, Fortschritt steht im Output.
--            4) Mit der Kamera (F im Viewport, WASD + Rechtsklick) zum Siegestor fliegen: Ursprung = (0, 0, 0).
--            Die Karte ist nach dem Stoppen weg. Dauerhaft bauen: MapBuilder_Plugin.lua als lokales Plugin.
--
-- WAS GEBAUT WIRD (Schritte, in dieser Reihenfolge; Output zeigt je Schritt eine Zeile):
--   terrain    Boden, Parks, Hügel (Monopteros), Terrasse (Friedensengel), Isar mit 3-stufiger Böschung, Bach
--   roads      Ring, Leopoldstraße/Ludwigstraße (Achse, rund um das Siegestor ein Kreisverkehr), Schwabinger Raster, Diagonale, Isarspange,
--              Maximilianstraße, Isar-Allee (Ostufer: Straße mit Parkstreifen, Laternen, roter Radweg, Baumreihe, Ufergehweg), Friedensengel-Oval, Kreisverkehr, gerundete Gehwegecken, Parkbuchten, 4 Brücken über die Isar (flach, auf Säulen),
--              Maximilianbrücke (zwei Bögen, Statuen)
--   lights     270 Laternen (runder Mast, Bogenarm, Leuchtkopf), 13 Ampelmasten (Rundmast, Ausleger, Linsenköpfe mit Blenden)
--   landmarks  Siegestor auf Mittelinsel, Friedensengel (Engel mit Flügeln, Ölzweig, Nike; rundes Becken), Frauenkirche (runde Zwiebelhauben),
--              Chinesischer Turm
--   gardens    Hofgarten, Englischer Garten, Monopteros-Tempel, Biergarten, Eisbachwelle, Isar-Uferwege, Prinz-Eins-Vorplatz
--   houses     7 Häuserblöcke mit Rück- und Hinterhäusern, Isar-Allee-Zeile mit Backsteinkirche, Westufer-Zeile, gebogene Eckhäuser am Siegestor, 13 Sonderbauten (Feuerwache, Polizeiwache mit Hof, Klinikum,
--              Tankstelle mit Schirm, Shop und Parkplätzen (3 Ladeplätze, 1 Behindertenparkplatz), Bank, Parkhaus, ...)
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
local STEPS = { "terrain", "roads", "lights", "landmarks", "gardens", "houses", "wall" } -- Teilmenge möglich, z. B. { "roads" }
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
