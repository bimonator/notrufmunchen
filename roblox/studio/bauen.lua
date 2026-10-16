-- bauen.lua: baut die Karte aus dem in ServerStorage geladenen MapBuilder (zuerst lade_in_studio.lua ausführen). Edit-Modus, dauert 1-3 Minuten.
-- Ergebnis steht im Output (je Schritt eine Zeile, Fehler als "FEHLER: ..."). Strg+Z nimmt den ganzen Lauf zurück.
local MB = require(game:GetService("ServerStorage"):WaitForChild("MapBuilder"))

-- Alles bauen (Terrain wird zuerst geleert):
MB.run({ controllerSource = MB.AMPEL_SOURCE })

-- Nur einzelne Schritte neu bauen (ohne das Terrain anzufassen); Namen: terrain roads lights landmarks marienplatz stachus gardens houses skyline bus wall
-- MB.run({ steps = { "stachus", "skyline" }, clearTerrain = false })
