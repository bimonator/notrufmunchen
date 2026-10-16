"""Fallback ohne HTTP: zerlegt MapBuilder_Modul/Teil1/Teil2 in Luau-Häppchen (Standard 30 000 Zeichen), die einzeln im Edit-Modus von Studio
ausgeführt werden (z. B. per MCP-Werkzeug zum Ausführen von Luau). Reihenfolge = Dateinamen in studio_chunks/. Die letzte Datei prüft die Längen.
Aufruf: python3 studio_chunks.py [Chunkgröße]"""
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "studio_chunks")
size = int(sys.argv[1]) if len(sys.argv) > 1 else 30000
os.makedirs(out, exist_ok=True)
for f in os.listdir(out):
    os.remove(os.path.join(out, f))

SOURCES = [("MapBuilder", "MapBuilder_Modul.lua"), ("Teil1", "MapBuilder_Teil1.lua"), ("Teil2", "MapBuilder_Teil2.lua")]
PATH = {"MapBuilder": 'game.ServerStorage.MapBuilder', "Teil1": 'game.ServerStorage.MapBuilder.Teil1', "Teil2": 'game.ServerStorage.MapBuilder.Teil2'}

setup = '''local SS = game:GetService("ServerStorage")
local old = SS:FindFirstChild("MapBuilder")
if old then old:Destroy() end
local main = Instance.new("ModuleScript")
main.Name = "MapBuilder"
main.Source = ""
for _, n in ipairs({ "Teil1", "Teil2" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Source = ""
	m.Parent = main
end
main.Parent = SS
print("MapBuilder-Gerüst angelegt")
'''
with open(os.path.join(out, "000_gerüst.lua"), "w", encoding="utf-8") as fh:
    fh.write(setup)

manifest, nfile = {}, 0
for name, fn in SOURCES:
    with open(os.path.join(here, fn), encoding="utf-8") as fh:
        text = fh.read()
    manifest[name] = len(text.encode("utf-8"))
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    op, cl = "[" + "=" * level + "[", "]" + "=" * level + "]"
    pieces, i = [], 0
    while i < len(text):
        j = min(len(text), i + size)
        if j < len(text):  # an Zeilenende trennen
            k = text.rfind("\n", i, j)
            if k > i:
                j = k + 1
        pieces.append(text[i:j])
        i = j
    for pi, piece in enumerate(pieces, 1):
        nfile += 1
        with open(os.path.join(out, "%03d_%s_%02d.lua" % (nfile, name, pi)), "w", encoding="utf-8") as fh:
            fh.write("local m = %s\nm.Source = m.Source .. %s\n%s%s\n" % (PATH[name], op, "\n" + piece if piece.startswith("\n") else piece, cl))
check = "local mb = game.ServerStorage.MapBuilder\nlocal erwartet = { MapBuilder = %d, Teil1 = %d, Teil2 = %d }\nlocal ist = { MapBuilder = #mb.Source, Teil1 = #mb.Teil1.Source, Teil2 = #mb.Teil2.Source }\nfor k, v in pairs(erwartet) do assert(ist[k] == v, k .. \": \" .. ist[k] .. \" statt \" .. v .. \" Zeichen\") end\nprint(\"MapBuilder vollständig geladen\")\n" % (manifest["MapBuilder"], manifest["Teil1"], manifest["Teil2"])
with open(os.path.join(out, "%03d_prüfen.lua" % (nfile + 1)), "w", encoding="utf-8") as fh:
    fh.write(check)
with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as fh:
    json.dump(manifest, fh)
print("%d Dateien in %s (Chunkgröße %d), Längen %s" % (nfile + 2, out, size, manifest))
