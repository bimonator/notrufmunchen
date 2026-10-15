# MapBuilder (Roblox, Luau)

Baut die Karte aus `docs/MAP_PLAN.md` und `docs/phase1_bauplan.html` per Code: Terrain mit Isar und Bach, Straßen mit Gehwegen, Parkbuchten, Brücken und der Siegestor-Unterführung, die Reihenhäuser im Schwabing-Raster und die Mapgrenze. Geometrie und Roblox-Aufrufe sind getrennt, damit die Geometrie ohne Roblox getestet werden kann.

## So fügst du alles zusammen (empfohlen: Plugin, dauerhaft)

1. Studio öffnen, neues Projekt mit der Vorlage **Baseplate**. Die Baseplate **löschen** (der Builder legt das Terrain selbst an).
2. In `Workspace` ein **Script** anlegen und den ganzen Inhalt von **`MapBuilder_Plugin.lua`** einfügen.
3. Rechtsklick auf das Script > **Als lokales Plugin speichern**. Danach das Script löschen.
4. Im Reiter **Plugins** erscheint der Knopf **Karte bauen**. Draufklicken, der Build dauert ca. 1–3 Minuten (Output-Fenster zeigt den Fortschritt).
5. Im Output steht je Schritt eine Zeile. Erwartet:

```
[terrain] 105 Terrain-Operationen
[roads] 1124 Teile, 157 Parkbuchten
[houses] 64 Häuser, 2903 Teile
[wall] 131 Gebäude, 9483 Teile
Fertig
```

Strg+Z nimmt den ganzen Lauf zurück. Erneutes Bauen ersetzt die Ordner `Strassen`, `Gebaeude.<Block>` und `Mapgrenze` (das Terrain wird zuerst geleert).

### Schnelltest ohne Plugin

`MapBuilder_Script.lua` in ein Script in `ServerScriptService` einfügen, oben auf **Run** klicken (nicht Play). Oben in der Datei kann man `STEPS` auf einzelne Schritte beschränken, z. B. `{ "roads" }`. Die Karte ist nach dem Stoppen wieder weg. Geeignet, um einen Schritt auszuprobieren.

### Schritt für Schritt (wenn etwas nicht klappt)

Die Schritte laufen in dieser Reihenfolge und sind unabhängig voneinander ausführbar: `terrain` → `roads` → `houses` → `wall`. Im Script oben `STEPS = { "terrain" }`, dann `{ "roads" }` usw. Fehler eines Schritts stoppen die anderen nicht, sie stehen im Output als `FEHLER: ...`.

## Dateien

| Datei | Inhalt | Geprüft |
|---|---|---|
| `MapBuilder/Geo.lua` | 2D-Mathematik (Strecken, Schnitte) | ja |
| `MapBuilder/Config.lua` | Alle Maße aus dem Plan als Daten (Straßen, Wasser, Tunnel, Brücken, Parks, Wand) | ja (wird getestet) |
| `MapBuilder/Planner.lua`, `Blocks.lua` | Reihenhäuser und Mapgrenzen-Gebäude | ja |
| `MapBuilder/RoadsPlanner.lua` | Straßen, Gehwege, Markierungen, Parkbuchten, Brücken, Unterführung | ja |
| `MapBuilder/TerrainPlanner.lua` | Terrain-Operationen (Boden, Parks, Hügel, Terrasse, Isar, Bach, Tunnelgraben) | ja (nur die Liste) |
| `MapBuilder/WallPlanner.lua` | Mapgrenze mit Toren, Querriegel, Feldherrnhalle | ja |
| `MapBuilder/Builder.lua`, `BuildAll.lua` | Erzeugt daraus Roblox-Objekte | **nur gegen eine Attrappe** |
| `MapBuilder_Script.lua`, `MapBuilder_Plugin.lua` | Alles in einer Datei, erzeugt mit `python3 make_bundles.py` | wie Builder |
| `tests/` | `planner_test.lua`, `map_test.lua`, `bundle_smoke_test.py`, `run_with_lupa.py` | – |

Nach jeder Änderung an `MapBuilder/*.lua` die Einzeldateien neu erzeugen: `python3 make_bundles.py`.

## Was getestet wurde (Cloud-Session, kein Roblox)

- `python3 tests/run_with_lupa.py` (Lua 5.1): Häuser (Maße, Überlappung, Eckhäuser), Straßen (157 Parkbuchten wie im Plan, kein Gehweg in einer Kreuzung, jede Straße asphaltiert, Tunnel frei, Rampenneigung 7,1° und lichte Höhe ≥ 13,5), Terrain (Kacheln decken die Karte genau ab, Wasser nur zwischen Bett und Wasserlinie), Wand (innen bleibt der Ring frei, Tore frei, Höhen 74–110).
- `python3 tests/bundle_smoke_test.py`: `Builder` und `BuildAll` laufen gegen eine selbst gebaute Roblox-Attrappe: 195 Models, 13 510 Teile, 105 Terrain-Aufrufe, zweiter Lauf ersetzt statt zu verdoppeln.
- Eine Draufsicht der berechneten Teile (aus den Plänen gezeichnet) stimmt mit der Karte im Bauplan überein.
- Die Tests wurden gezielt mit eingebauten Fehlern geprüft (Gehweg-Schnitt aus, Tunnel nicht ausgenommen, falscher Drehwinkel): sie schlagen dann an.

## Was NICHT geprüft werden konnte (bitte im Studio ansehen)

- Ob die echte Roblox-API sich wie die Attrappe verhält (`Terrain:FillBlock` mit gedrehtem CFrame, `FillCylinder`, `Terrain:Clear`, `CollectionService`).
- Ob die Isar im Terrain sauber aussieht. Sie ist aus gestapelten Blöcken gebaut (Stufen von 4 Studs). Falls sie treppig wirkt, im Terrain-Editor mit **Smooth** glätten.
- Das Aussehen: Höhenlage von Gehweg, Straße und Brücken (Z-Fighting möglich), Wirkung der Mapgrenze, Rampe und Tunnel.
- Die Leistung: ca. 13 500 Teile. Die Mapgrenze allein ca. 9 500 (Fenster der Wandgebäude).

## Bewusst (noch) nicht enthalten

Ampeln, Schilder und Straßennamen, Straßenlampen und Bäume, Tankstelle, Polizeiwache, Feuerwache, Krankenhaus, Bank, Parkhaus, Supermarkt, Kirche und Plätze mit Brunnen, Siegestor, Friedensengel, Monopteros-Tempel, Schrägdächer. Das Wasser der Eisbachwelle ist ein normaler Bach. Die Fußgängerbrücke B5 ist flach (keine Rampen). Brücke B2 liegt über einem Knick der Isarspange und ist nur grob ausgerichtet.

## Übergabe an eine neue Claude-Session

Ordner `roblox/` zeigen und sagen: „Baue die Karte im Studio mit `MapBuilder_Plugin.lua` (Anleitung in `roblox/README.md`), prüfe das Ergebnis und korrigiere `Builder.lua`. Die Geometrie nur ändern, wenn `tests/run_with_lupa.py` danach weiter besteht, und danach `python3 make_bundles.py` ausführen."
