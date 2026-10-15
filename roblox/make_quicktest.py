"""Erzeugt HouseGenerator_QuickTest.lua: alle Module in einer Datei für einen schnellen Test als einzelnes Script."""
import re
import os

here = os.path.dirname(os.path.abspath(__file__))


def read(name):
    with open(os.path.join(here, "HouseGenerator", name + ".lua"), encoding="utf-8") as f:
        return f.read().rstrip() + "\n"


run = read("Run")
run = re.sub(r"^local (Planner|Builder|Blocks) = require\(script\.Parent\.\w+\)\n", "", run, flags=re.M)

out = ["""-- HouseGenerator_QuickTest.lua  (automatisch erzeugt mit make_quicktest.py, nicht von Hand ändern)
-- Schnelltest: in ServerScriptService ein Script anlegen, diesen Inhalt einfügen, oben im Studio auf RUN (nicht Play) klicken.
-- Die Häuser entstehen nur zur Laufzeit. Nach dem Stoppen sind sie weg, dafür braucht der Test kein Setup.
local ONLY = { "B_NordMitte" } -- nil = alle Blöcke (A, B, D)
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

"""]
for name in ("Planner", "Blocks", "Builder"):
    out.append("local %s = (function()\n%s\nend)()\n\n" % (name, read(name)))
out.append("local Run = (function()\n%s\nend)()\n\n" % run)
out.append("Run.run({ only = ONLY, origin = ORIGIN })\n")

with open(os.path.join(here, "HouseGenerator_QuickTest.lua"), "w", encoding="utf-8") as f:
    f.write("".join(out))
print("geschrieben")
