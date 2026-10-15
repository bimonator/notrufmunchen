# Häuser-Generator (Roblox, Luau)

Baut Reihenhaus-Blockränder im Schwabing-Raster per Code. Geometrie und Roblox-Aufrufe sind getrennt, damit die Geometrie ohne Roblox getestet werden kann.

| Datei | Inhalt | Geprüft |
|---|---|---|
| `HouseGenerator/Planner.lua` | Berechnet alle Häuser und Teile (reine Geometrie) | ja, Tests in Lua 5.1 |
| `HouseGenerator/Blocks.lua` | Block-Koordinaten (A, B, D) aus dem Kartenplan | ja (wird getestet) |
| `HouseGenerator/Builder.lua` | Erzeugt daraus Roblox-`Part`s | **nein**, nur im Studio testbar |
| `HouseGenerator/Run.lua` | Einstieg für die Command Bar | **nein**, nur im Studio testbar |
| `tests/planner_test.lua` | 6 Prüfgruppen (Maße, Überlappung, Eckhäuser, Determinismus) | – |
| `tests/bundle_smoke_test.py` | Lässt Builder/Run gegen eine Roblox-Attrappe laufen (fängt Tippfehler und nil-Zugriffe) | ja, aber nur gegen die Attrappe |

## Schnelltest im Studio (2 Minuten)

1. Studio öffnen, Vorlage **Baseplate** wählen (Oberkante Y = 0, passt zu den Häusern).
2. In `ServerScriptService` ein **Script** anlegen, den gesamten Inhalt von `HouseGenerator_QuickTest.lua` einfügen.
3. Oben auf **Run** klicken (nicht Play). Im Output erscheint `B_NordMitte: 18 Häuser, 867 Teile`.
4. Im Explorer `Workspace > Map > Gebaeude > B_NordMitte` anklicken und **F** drücken, dann mit der Kamera umsehen (Block B liegt bei x −430…−264, z −448…−314).
5. Stoppen: die Häuser verschwinden wieder, das ist beim Schnelltest gewollt. Für dauerhaftes Bauen siehe „Einrichten im Studio".

Im Script oben steht `ONLY = { "B_NordMitte" }`. Mit `nil` statt der Liste werden alle drei Blöcke gebaut (64 Häuser). Die Datei wird mit `python3 make_quicktest.py` aus den Modulen neu erzeugt.

## Was gebaut wird

- Je Block ein **Blockrand** aus Reihenhäusern (Tiefe 28, Breite ca. 26, 4–5 Geschosse, Höhe 50–62) rund um einen **Innenhof**.
- Block A: 18 Häuser, Block B: 18 Häuser, Block D: 28 Häuser. Zusammen **64 Häuser, ca. 2900 Teile** (ca. 45 je Haus).
- Je Haus: Hauptkörper, Sockel, Gesimse, Fenster mit Rahmen, Scheibe und Bank, Tür mit Vordach, Schaufenster, Flachdach mit Attika, Schornsteine, teils Balkone, teils Staffelgeschoss.
- Eckhäuser haben auch Seitenfenster zur Querstraße.
- Fenster tragen den Tag `HouseWindow` und das Attribut `Lit`. Das spätere Tag/Nacht-Skript kann nachts alle `Lit`-Fenster auf `Neon` schalten.
- Jedes Haus ist ein `Model` (`PrimaryPart` = Hauptkörper), abgelegt in `Workspace.Map.Gebaeude.<Block>`.

## Einrichten im Studio

1. In `ServerStorage` einen Ordner `HouseGenerator` anlegen.
2. Darin vier **ModuleScripts** `Planner`, `Blocks`, `Builder`, `Run` anlegen und den Inhalt der gleichnamigen Dateien einfügen.
3. Das Siegestor muss auf `(0, 0, 0)` liegen (Kartenursprung), sonst `origin` mitgeben. Die Terrain-Oberkante muss auf Y = 0 liegen, der Boden der Häuser liegt auf Y = 1 (Gehweg).
4. In der **Command Bar** (Edit-Modus, nicht im Play-Modus):

```lua
require(game.ServerStorage.HouseGenerator.Run).run()
-- nur ein Block, anderer Seed, anderer Ursprung:
require(game.ServerStorage.HouseGenerator.Run).run({ only = { "B_NordMitte" }, seed = 7, origin = Vector3.new(0, 0, 0) })
```

Erneutes Ausführen ersetzt den jeweiligen Block-Ordner. Mit Strg+Z lässt sich ein Lauf zurücknehmen.

## Tests (ohne Roblox)

```
cd roblox/tests
lua planner_test.lua            # wenn Lua installiert ist
python3 run_with_lupa.py        # sonst: pip install lupa
```

Ergebnis in der Cloud-Session: **Alle Tests bestanden** (Lua 5.1). Zusätzlich gezielt geprüft, dass ein falscher Drehwinkel der Westseite vom Test erkannt wird.

## Bekannte Grenzen

- **Nicht in Roblox ausprobiert.** `Builder.lua` und `Run.lua` können Tippfehler oder API-Abweichungen enthalten. Erster Lauf mit Block B (`only`), dann im Studio ansehen.
- Dächer sind **flach** (mit Attika). Schrägdächer fehlen absichtlich, weil die Ausrichtung von `WedgePart` ohne Studio nicht prüfbar ist.
- Fenster sind aufgesetzt, keine Aussparungen in der Wand. Es gibt **keine Innenräume** und keine Türen, die sich öffnen.
- Keine Läden, Schilder oder Hausnummern. Details kommen später.
- Nicht enthalten: Blöcke E (Feuerwache), C und F (Bank, Parkhaus, Ladenzeile).

## Übergabe an eine neue Claude-Session

Ordner `roblox/` zeigen und sagen: „Baue die Module ins Studio ein (Anleitung in `roblox/README.md`), lass `Run.run({ only = { 'B_NordMitte' } })` laufen, prüfe das Ergebnis im Studio und korrigiere `Builder.lua`. Die Geometrie in `Planner.lua` nur ändern, wenn `tests/planner_test.lua` danach weiter besteht."
