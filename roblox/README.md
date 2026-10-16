# MapBuilder (Roblox, Luau)

Baut die Karte aus `docs/MAP_PLAN.md` und `docs/phase1_bauplan.html` per Code: Terrain mit Isar und Bach, Straßen mit Gehwegen, Parkbuchten, gewölbten Isar-Brücken und der Siegestor-Unterführung, Reihenhäuser im Schwabing-Raster und entlang der Leopoldstraße, Platzhalter für die Sonderbauten (Bank, Wachen, Krankenhaus ...) und die Mapgrenze. Geometrie und Roblox-Aufrufe sind getrennt, damit die Geometrie ohne Roblox getestet werden kann.

## So fügst du alles zusammen (empfohlen: Plugin, dauerhaft)

1. Studio öffnen, neues Projekt mit der Vorlage **Baseplate**. Die Baseplate **löschen** (der Builder legt das Terrain selbst an).
2. In `Workspace` ein **Script** anlegen und den ganzen Inhalt von **`MapBuilder_Plugin.lua`** einfügen.
3. Rechtsklick auf das Script > **Als lokales Plugin speichern**. Danach das Script löschen.
4. Im Reiter **Plugins** erscheint der Knopf **Karte bauen**. Draufklicken, der Build dauert ca. 1–3 Minuten (Output-Fenster zeigt den Fortschritt).
5. Im Output steht je Schritt eine Zeile. Erwartet:

```
[terrain] 1171 Terrain-Operationen
[boden] Terrain-Oberkante gemessen: -2.0, alle weiteren Teile werden daran ausgerichtet
[wasser] ok (... Wasser-Zellen am Messpunkt)
[roads] 1475 Teile, 157 Parkbuchten
[lights] 270 Laternen, 13 Ampelmasten, 2 Fußgängerampeln, 1529 Teile
[landmarks] 279 Teile (Siegestor, Friedensengel, Frauenkirche, Chinesischer Turm)
[gardens] 1050 Teile, 143 Bäume, 103 Uferweg-Platten, 50 Findlinge
[houses] 154 Häuser, 12928 Teile
[ampel] Script AmpelSteuerung in ServerScriptService angelegt
[wall] 128 Gebäude, 8743 Teile
Fertig
```

Wichtig sind die Zeilen `[boden]` und `[wasser]`. **Boden:** Roblox füllt Terrain in 4-Studs-Zellen, die tatsächliche Oberkante kann daher von der geplanten abweichen. Der Builder misst sie nach dem Terrain und setzt Straßen, Häuser und Mauer genau darauf (sonst versinken die flachen Straßen). **Wasser:** Findet er kein Terrain-Wasser, setzt er blaue Ersatz-Platten (Ordner `WasserErsatz`, nicht schwimmbar) und schreibt das in den Output. Bitte beide Zeilen mitschicken, wenn etwas nicht stimmt.

Strg+Z nimmt den ganzen Lauf zurück. Erneutes Bauen ersetzt die Ordner `Strassen`, `Gebaeude.<Block>` und `Mapgrenze` (das Terrain wird zuerst geleert).

### Schnelltest ohne Plugin

`MapBuilder_Script.lua` in ein Script in `ServerScriptService` einfügen, oben auf **Run** klicken (nicht Play). Oben in der Datei kann man `STEPS` auf einzelne Schritte beschränken, z. B. `{ "roads" }`. Die Karte ist nach dem Stoppen wieder weg. Geeignet, um einen Schritt auszuprobieren.

### Schritt für Schritt (wenn etwas nicht klappt)

Die Schritte laufen in dieser Reihenfolge und sind unabhängig voneinander ausführbar: `terrain` → `roads` → `lights` → `landmarks` → `gardens` → `houses` → `wall`. Im Script oben `STEPS = { "terrain" }`, dann `{ "roads" }` usw. Fehler eines Schritts stoppen die anderen nicht, sie stehen im Output als `FEHLER: ...`.

## Dateien

| Datei | Inhalt | Geprüft |
|---|---|---|
| `MapBuilder/Geo.lua` | 2D-Mathematik (Strecken, Schnitte) | ja |
| `MapBuilder/Config.lua` | Alle Maße aus dem Plan als Daten (Straßen, Wasser, Tunnel, Brücken, Parks, Wand) | ja (wird getestet) |
| `MapBuilder/Planner.lua`, `Blocks.lua`, `Specials.lua` | Reihenhäuser (7 Blöcke), Sonderbauten als Platzhalter, Mapgrenzen-Gebäude | ja |
| `MapBuilder/RoadsPlanner.lua` | Straßen, Gehwege, Markierungen, Parkbuchten, Brücken (3 gewölbt), Unterführung | ja |
| `MapBuilder/TerrainPlanner.lua` | Terrain-Operationen (Boden, Parks, Hügel, Terrasse, Isar, Bach, Tunnelgraben) | ja (nur die Liste) |
| `MapBuilder/WallPlanner.lua` | Mapgrenze mit Toren, Querriegel, Feldherrnhalle | ja |
| `MapBuilder/Builder.lua`, `BuildAll.lua` | Erzeugt daraus Roblox-Objekte | **nur gegen eine Attrappe** |
| `MapBuilder_Script.lua`, `MapBuilder_Plugin.lua` | Alles in einer Datei, erzeugt mit `python3 make_bundles.py` | wie Builder |
| `tests/` | `planner_test.lua`, `map_test.lua`, `bundle_smoke_test.py`, `run_with_lupa.py` | – |

Nach jeder Änderung an `MapBuilder/*.lua` die Einzeldateien neu erzeugen: `python3 make_bundles.py`.

## Feinjustierung (ohne Programmieren)

| Was | Wo | Beispiel |
|---|---|---|
| Hügel und Terrasse niedriger oder höher | `MapBuilder/Config.lua`: `C.hills` (Schichten `{ Radius, von, bis }`) und `C.terrace.height` | Terrasse 4 → 0 entfernt sie fast |
| Maximilianbrücke (Spannweite, Bogenhöhe) | `C.isarBridges` Eintrag B6: `span` (Hälfte der Gesamtbogenlänge je Bogen), `rise` (Pfeilhöhe der Bögen, flach = 4,5) | `rise = 7` für stärker gewölbte Bögen (Ansatz sinkt ins Wasser, dann `rise` ≤ 5,5 lassen) |
| Länge der Isar-Brücken, Pfeilerabstand | `C.isarBridges`: `len` (muss größer als 2 × Böschungsbreite sein), `pier`, `walk` (Gehwegbreite) | `pier = 30` für engere Pfeiler |
| Isar-Böschung (Breite der Stufen, Material) | `C.water.isar.layers` (Tiefe, Halbbreite) und `fills` (Sand-Kiesbank, Gras-Uferweg) | Halbbreite 90 → 70 für ein schmaleres Ufer |
| Mittelstreifen-Höhe | `MapBuilder/RoadsPlanner.lua`: `TOP.median` | 0.8 (Gehweg 1.0, Straße 0.5) |
| Abwechslung der Häuser | `MapBuilder/Planner.lua`: `DEFAULTS.floorWeights`, `palette`, `targetWidth` | mehr Hochhäuser: `{ 6, 0.3 }` |
| Anderer Zufall | `seed` in `MapBuilder_Script.lua` bzw. `BuildAll.run({ seed = 7 })` | gleiche Zahl = gleiche Häuser |

Nach jeder Änderung `python3 make_bundles.py` ausführen und das Plugin bzw. Script neu einfügen.

## Was getestet wurde (Cloud-Session, kein Roblox)

- `python3 tests/run_with_lupa.py` (Lua 5.1): Häuser (Maße, Überlappung, Eckhäuser, Abwechslung bei Farben, Geschossen, Dachformen, Breiten, Sonderflächen frei), Sonderbauten (Grundfläche stimmt, keine Überlappung), Straßen (157 Parkbuchten wie im Plan, kein Gehweg in einer Kreuzung, jede Straße asphaltiert, Tunnel frei, Rampenneigung 7,1° und lichte Höhe ≥ 13,5, Brücken: Scheitelhöhe, Enden auf Straßenniveau, zwei Pfeiler im Fluss, keine flache Straße darunter), Terrain (Kacheln decken die Karte genau ab, Wasser nur zwischen Bett und Wasserlinie), Wand (innen bleibt der Ring frei, Tore frei, Höhen 74–110).
- `python3 tests/bundle_smoke_test.py`: `Builder` und `BuildAll` laufen gegen eine selbst gebaute Roblox-Attrappe: 257 Models, 18 211 Teile, 1171 Terrain-Aufrufe, zweiter Lauf ersetzt statt zu verdoppeln.
- Eine Draufsicht der berechneten Teile (aus den Plänen gezeichnet) stimmt mit der Karte im Bauplan überein.
- Die Tests wurden gezielt mit eingebauten Fehlern geprüft (Gehweg-Schnitt aus, Brücken-Schnitt aus, Tunnel nicht ausgenommen, falscher Drehwinkel): sie schlagen dann an.

## Was NICHT geprüft werden konnte (bitte im Studio ansehen)

- Ob die echte Roblox-API sich wie die Attrappe verhält (`Terrain:FillBlock` mit gedrehtem CFrame, `FillCylinder`, `Terrain:Clear`, `CollectionService`).
- Ob die Isar im Terrain sauber aussieht. Sie ist aus gestapelten Blöcken gebaut (Stufen von 4 Studs). Falls sie treppig wirkt, im Terrain-Editor mit **Smooth** glätten.
- Das Aussehen: Höhenlage von Gehweg, Straße und Brücken (Z-Fighting möglich), Wirkung der Mapgrenze, Rampe und Tunnel.
- Die Leistung: ca. 18 000 Teile (Häuser 8 100, Mapgrenze 8 700, Straßen 1 300). Wenn es ruckelt, zuerst die Mapgrenze vereinfachen.

## Bewusst (noch) nicht enthalten

Ampeln, Schilder und Straßennamen, Straßenlampen und Bäume, Innenräume und Details der Sonderbauten (Bank, Wachen, Krankenhaus, Parkhaus, Tankstellen-Shop sind nur Platzhalter-Gebäude, die Tankstelle hat Schirm und Zapfsäulen), Supermarkt, Werkstatt, Kirche und Plätze mit Brunnen, Siegestor, Friedensengel, Monopteros-Tempel, Schrägdächer (nur flache und Mansarddächer). Das Wasser der Eisbachwelle ist ein normaler Bach. Die Fußgängerbrücke B5 ist flach (keine Rampen). Die Isar-Brücken haben Pfeiler, aber keine echten Bögen und Lampen.

## Übergabe an eine neue Claude-Session

Ordner `roblox/` zeigen und sagen: „Baue die Karte im Studio mit `MapBuilder_Plugin.lua` (Anleitung in `roblox/README.md`), prüfe das Ergebnis und korrigiere `Builder.lua`. Die Geometrie nur ändern, wenn `tests/run_with_lupa.py` danach weiter besteht, und danach `python3 make_bundles.py` ausführen."

## Ampelsteuerung

Das Plugin legt beim Bauen ein Script `AmpelSteuerung` in ServerScriptService an (beim zweiten Bauen wird es ersetzt). Es schaltet beim Play/Run:

- **Kreuzungen** (Achse × Ring Nord, H1, Odeonsplatz): Achse 30 s grün, 3 s gelb, 2 s alle rot, dann Querstraße 30 s grün usw. Jede Kreuzung startet versetzt. Zeiten oben in `Ampel.lua` (`Ampel.config`), im Script `AmpelSteuerung` ganz oben im Block `Ampel.config`.
- **Feuerwache** (Gruppen `Wache_V1`, `Wache_V2`): grün für den Verkehr. `workspace:SetAttribute("WacheAlarm", true)` schaltet gelb, dann rot; `false` schaltet wieder grün. Test: im Run-Modus in der Command Bar `workspace:SetAttribute("WacheAlarm", true)`.
- **Fußgängerampeln** am Siegestor: 12 s grün, 28 s rot.

Das Test-Script `MapBuilder_Script.lua` startet die Steuerung direkt nach dem Bauen.

## Offen / Backlog

- **Siegestor und Friedensengel:** mehr Detail (Reliefs, Kapitell, Engel mit Gewand, Quadriga, Wasserspiele), bewusst später.
- **Tore der Feuerwache** (`FireGate`) und **Schranken der Polizei** (`Schranke`, Attribut `Offen`) sind Modelle ohne Skript; das Öffnen und Schließen kommt mit den Einsatz-Skripten. Fahrzeug-Spawnflächen tragen den Tag `VehicleSpawn` (Attribut `Team`).
- **Eisbachwelle** ist nur das Bild einer stehenden Welle (Tags `Eisbachwelle`, `SurfZone`); das Surfen (Strömung, Brett) kommt als Skript.
- Café (wartet auf Foto), Straßenschilder, Straßennamen, Frauenkirche mit mehr Detail (Fensterspitzbögen, Dachgauben, Uhrzeiger).
