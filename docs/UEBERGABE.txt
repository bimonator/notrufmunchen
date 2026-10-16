# Übergabe an eine neue Claude-Code-Session: Notruf München (Roblox-Karte per Code)

> Zweck: Diese Datei in die neue Session einfügen (oder `docs/UEBERGABE.md` lesen lassen). Danach weiß Claude, was gebaut ist, wie gearbeitet wird,
> welche Probleme es gab, was offen ist und wie die Karte automatisch in Roblox Studio kommt (MCP). Rückfragen sind trotzdem erlaubt, wenn etwas unklar ist.
> Stand: Branch `claude/tender-lovelace-cq74xc` im Repo `bimonator/notrufmunchen`, letzter Commit „Stachus: eckiger Hof …“ bzw. neuer.

## 0. Erste Schritte der neuen Session (Checkliste)

1. Repo ansehen: `docs/MAP_PLAN.md`, `docs/SYSTEMPLAN.md`, `docs/phase1_bauplan.html`, `roblox/README.md`, diese Datei.
2. Tests laufen lassen (ohne Roblox, dauert wenige Sekunden): `cd roblox && pip install lupa pillow numpy && python3 tests/run_with_lupa.py && python3 make_bundles.py && python3 tests/bundle_smoke_test.py`. Erwartet: „Alle Karten-Tests bestanden“, „Alle Tests bestanden“, „Smoke-Test bestanden …“, „Plugin-Test bestanden …“, „Modul-Test bestanden …“.
3. Prüfen, welche **Roblox-Studio-MCP-Werkzeuge** verfügbar sind (Abschnitt 4). Ziel: Karte selbst in Studio laden und bauen, der User soll nichts mehr per Hand einfügen müssen.
4. Mit dem User klären, was als Nächstes gebaut wird (Backlog Abschnitt 9). Vorher kurz zusammenfassen, was verstanden wurde.

## 1. Zusammenarbeit mit dem User (wichtig)

| Thema | Regel |
|---|---|
| Sprache | **Deutsch**, kompakt. Tabellen, Stichpunkte, kurze Beispiele. Keine langen Monologe (Token sparen). |
| Stil | „Warum“ nur dort erklären, wo es für eine Entscheidung zählt. Wenn möglich quantifizieren (Prozent, Wahrscheinlichkeiten, Zahlen). Sicheres und Unsicheres klar trennen. Bei Code: erst Code/Änderung, dann nur die entscheidenden Stellen erklären. |
| Lerntyp | Visuell. Deshalb **Bilder** liefern: Draufsichten/Pläne (`roblox/tools/overview.py`, `lmview.py`) und Vorschauen, bevor/wenn etwas Größeres gebaut wird. |
| Rückfragen | „Wenn etwas unklar ist, frag mich davor.“ Bei echter Mehrdeutigkeit lieber kurz fragen (AskUserQuestion), bei Kleinigkeiten sinnvolle Standardwerte wählen und im Ergebnis nennen. |
| Lieferung | Nach jedem Schritt: Tests, `python3 make_bundles.py`, commit + push auf den Feature-Branch, die Lua-Dateien (`MapBuilder_Alles/Script/Plugin/Teil1/Teil2.lua`) bereitstellen. User sagte: „mach von allem einen großen Packen“ = alles in einer Datei bzw. gesammelt liefern. |
| Screenshots | Der User schickt Studio-Screenshots mit **roten Markierungen/Pfeilen**. Diese genau lesen (Pfeil = Richtung/Ausdehnung, Kasten = Position, „50 %“ = Faktor). Bei Unsicherheit die gewählte Deutung im Ergebnis nennen. |
| Marken | Keine echten Markennamen/Logos (Rechtsrisiko). Anspielungen mit erfundenen Namen: „Kaffeehaus Odeon“, „OSRUM“, „McDonnell's“, „BMO / BMO Welt“ (Logo eigener Entwurf), „Casino Odeon“ (entfällt inzwischen). Vom User ausdrücklich gewünscht und abgesegnet. |
| Ehrlichkeit | Das Aussehen in echtem Roblox Studio wurde **nie** von Claude gesehen (nur Plan-Renderings und eine Roblox-Attrappe). Das so benennen. |

## 2. Projekt in zwei Sätzen

„Notruf München“ ist ein Roblox-Einsatzspiel (Polizei / Rettungsdienst / Feuerwehr / Kriminelle / Zivilisten, Vorbild Notruf Hamburg) in einer stilisierten
Münchner Innenstadt. Aktuell geht es **nur um die Karte**, die komplett per Lua-Code erzeugt wird; Spielsysteme (Notrufe, Überfälle, Jobs) stehen als Plan in `docs/SYSTEMPLAN.md` und sind noch nicht gebaut.

| Dokument | Inhalt |
|---|---|
| `docs/MAP_PLAN.md` | Kartenplan v0.2 (Orte, Koordinaten, Beschlüsse) |
| `docs/SYSTEMPLAN.md` | Spielsystem v0.1 (Teams, Chill-/Loot-Spots, Banküberfall, Rettung, Fahrzeuge) |
| `docs/phase1_bauplan.html` | Maße der Straßen, Wachen, Krankenhaus, Tankstelle |
| `roblox/README.md` | Bedienung und Dateien des MapBuilders |
| `roblox/tests/` | Tests (Lua 5.1 über `lupa`) |

Hinweis: Im Systemplan stehen „Casino Odeon“ und „Café-Terrasse“ als Chill-Spots; beide sind inzwischen **durch den Stachus ersetzt** (Chill-Spot-Liste bei Gelegenheit aktualisieren: Stachus statt Casino Odeon/Café-Terrasse).

## 3. Repo und Arbeitsablauf

```
roblox/
  MapBuilder/*.lua         Quelle (reine Geometrie-Planer + Builder). Nur hier ändern!
  make_bundles.py          erzeugt aus MapBuilder/ die Dateien zum Einfügen ins Studio
  MapBuilder_Alles.lua     alles in EINEM Script (~265k Zeichen, über dem Roblox-Limit ~200k je Script!)
  MapBuilder_Script.lua    Script (Run-Modus) + Teil1/Teil2 als ModuleScripts
  MapBuilder_Plugin.lua    Plugin-Variante (Knopf „Karte bauen“, dauerhaft im Projekt)
  MapBuilder_Modul.lua     ModuleScript „MapBuilder“ (für MCP/Skripte): require(...).run({ steps = {...} })
  MapBuilder_Teil1.lua / _Teil2.lua   ModuleScripts mit den Modulen (je ≤ 190k Zeichen, wird geprüft)
  studio/lade_in_studio.lua, studio/bauen.lua   Studio-Loader per HTTP + Bau-Skript (Abschnitt 4)
  studio_chunks.py         Fallback ohne HTTP: zerlegt die Dateien in Luau-Häppchen
  tools/overview.py, lmview.py   Plan-/Ansichtsbilder (PIL + numpy + lupa)
  tests/                   run_with_lupa.py (map_test.lua + planner_test.lua), bundle_smoke_test.py
```

Ablauf bei jeder Änderung:
1. `roblox/MapBuilder/*.lua` ändern (Maße meist in `Config.lua`, Blöcke in `Blocks.lua`, Sonderbauten in `Specials.lua`).
2. `cd roblox && python3 tests/run_with_lupa.py` (Geometrie-Tests; sie sind streng: Überlappungen, Straßen, Grenzen, Durchgänge).
3. `python3 make_bundles.py` (erzeugt alle Bundles, prüft die Größe) und `python3 tests/bundle_smoke_test.py` (läuft das Bundle gegen eine Roblox-Attrappe).
4. Visuell prüfen (Bild aus `tools/overview.py` / `lmview.py` oder eigene Skripte, siehe Abschnitt 8).
5. Commit + Push auf `claude/tender-lovelace-cq74xc`. **Keine PRs, außer der User will es.** Commit-Trailer und PR-Texte nach den Vorgaben der jeweiligen Session.
6. In Studio neu laden und bauen (Abschnitt 4) oder die Dateien dem User geben.

## 4. Roblox Studio per MCP ansteuern (Ziel: der User muss nichts mehr einfügen)

Der User will, dass Claude Code die Lua-Dateien selbst in Studio bringt und die Karte baut („dass ich dort selber nichts mehr machen muss“). Vorbereitung im Repo ist fertig, **ungetestet gegen echtes Studio/MCP** (hier gab es nur eine Cloud-Session ohne Studio).

**Schritt A: Werkzeuge klären.** Die MCP-Werkzeuge des Roblox-Studio-Servers auflisten (typisch: Luau-Code im Edit-Modus ausführen, z. B. `run_code`; Konsolen-Output lesen `get_console_output`; Play starten/stoppen; Modelle einfügen). Genaue Namen/Parameter prüfen, nicht raten. Fehlt „Luau ausführen“, den User fragen.

**Schritt B (bevorzugt): Quelltexte per lokalem HTTP-Server laden** (wenige KB statt 270k Zeichen durch den MCP-Aufruf):
1. Im Repo: `python3 -m http.server 8765 --directory roblox` (Hintergrundprozess).
2. In Studio muss HTTP erlaubt sein (Game Settings > Security > „Allow HTTP Requests“; `HttpService.HttpEnabled`). Wenn per Code nicht setzbar, den User bitten.
3. Per MCP den Inhalt von `roblox/studio/lade_in_studio.lua` ausführen: legt `ServerStorage.MapBuilder` (ModuleScript, Quelle `MapBuilder_Modul.lua`) mit den Kindern `Teil1`, `Teil2` an und gibt Längen aus.
4. Per MCP `roblox/studio/bauen.lua` ausführen (Edit-Modus, 1–3 Minuten; kann ein MCP-Timeout reißen: dann Schritte einzeln bauen, z. B. `MB.run({ steps = { "terrain" } })`, dann `roads` usw.; Reihenfolge `MB.order`). Output (je Schritt eine Zeile, Fehler als `FEHLER: …`) per Konsole lesen.
5. Nach Code-Änderungen: `python3 make_bundles.py`, Schritt 3 erneut, dann nur die geänderten Schritte neu bauen (`MB.run({ steps = { "stachus" }, clearTerrain = false })`; die Builder ersetzen ihre Ordner statt sie zu verdoppeln).

**Schritt B2 (Fallback ohne HTTP):** `cd roblox && python3 studio_chunks.py` erzeugt `roblox/studio_chunks/*.lua` (Gerüst, ~11 Häppchen à 30k Zeichen, Prüfskript). In Reihenfolge per MCP ausführen. Kostet ca. 80k Token Ausgabe. Das letzte Skript prüft die Längen.

**Schritt C: Ergebnis prüfen.** Nach dem Bau (a) Output-Zeilen: `[boden]` (gemessene Terrain-Oberkante, bisher −2,0 in der Attrappe, in Studio erwartet ähnlich) und `[wasser]` (echtes Terrain-Wasser oder Ersatzplatten) sind wichtig; (b) Kamera/Screenshot-Werkzeug des MCP nutzen, falls vorhanden, und die Bereiche aus Abschnitt 7 ansehen; (c) Zahlen mit Abschnitt 7 vergleichen (Parts je Schritt).

**Bekannte Studio-Eigenheiten:** Skripte haben ein Limit von ca. 200 000 Zeichen (deshalb Teil1/Teil2); `MapBuilder_Alles.lua` (265k) passt vermutlich nicht in ein Script (ungeprüft: der User meinte „passt wohl, muss man ausprobieren“). `Source` setzen geht nur im Plugin-/MCP-Kontext. Terrain wird in 4-Studs-Zellen gefüllt, deshalb misst der Builder die tatsächliche Oberkante und richtet alles daran aus. Ampel-Steuerung (`AmpelSteuerung`) legt der Builder nur an, wenn `controllerSource` übergeben wird.

## 5. Architektur (Module in `roblox/MapBuilder/`)

| Modul | Aufgabe |
|---|---|
| `Geo.lua` | 2D-Mathe, Rundung (`round3`), Abstand zu Polylinien |
| `Config.lua` | **Alle Maße als Daten**: Karte, Straßen+Profile, Wasser, Parks, Brücken, Landmarks, Marienplatz, Stachus, Hochhäuser, Bushaltestellen, Zebrastreifen, Parkbuchten, Tankstelle, Eckhaus-Faktoren |
| `RoadsPlanner.lua` | Straßensegmente → Streifen (road/walk/plaza/median/green/bike), Kreuzungen, Gehwegecken (R=5), Zebrastreifen, Parkbuchten, Brücken |
| `LightsPlanner.lua` | Laternen (runder Mast, Bogenarm), Ampelmasten, Fußgängerampeln |
| `TerrainPlanner.lua` | Terrain-Operationen (Boden, Parks, Hügel, Terrasse, Isar, Bach, U-Bahn-Gruben als „Air“-Blöcke mit Tag `ubahn`) |
| `Planner.lua` | Häuser: `planHouse`, `planSides`, `planBlock` (Blockrand + Hinterhäuser), `planAllee`, `planWestbank`, `planCorners` (Siegestor-Ecken), Sonderbauten-Stile (`feuerwache`, `polizei`, `klinik`, `buero`, `kaffee`, `parkhaus`, `bank`, `tankstelle`), Schaufenster (`storefront`) |
| `Blocks.lua` / `Specials.lua` | Häuserblöcke (A…G, M) mit `reserved`-Flächen / Sonderbauten-Liste |
| `Landmarks.lua` | Siegestor (detailliert), Mittelinsel, Friedensengel, Frauenkirche (Maßstab 0,65), Chinesischer Turm |
| `Rathaus.lua`, `Marienplatz.lua` | Neues Rathaus, Mariensäule, U-Bahn-Abgang, Pflaster, Kugelleuchten, Platanen |
| `Stachus.lua` | Stachus (Abschnitt 7) |
| `Hochhaus.lua` | Glas-Hochhäuser, BMO-Vierzylinder-Turm, BMO Welt (Schüssel) |
| `Bushaltestellen.lua` | Wartehäuschen mit Schild |
| `Garden.lua` | Hofgarten, Englischer Garten, Allee-Bäume, Westufer-Park, Eisbachwelle, Uferwege |
| `WallPlanner.lua` | Mapgrenze (Häuserband mit Toren) |
| `Builder.lua` | **Einziges Modul mit Roblox-Aufrufen**: Parts/Terrain erzeugen, Ordner, Bodenmessung, Wasser-Ersatz, Ampel-Script anlegen |
| `BuildAll.lua` | Schritte in fester Reihenfolge: `terrain, roads, lights, landmarks, marienplatz, stachus, gardens, houses, skyline, bus, wall` |
| `Ampel.lua` | Ampelsteuerung (Tags `TrafficLight`, `PedLight`), Feuerwache-Alarm per `workspace:SetAttribute("WacheAlarm", true)` |

Alle Planer sind **reine Geometrie** (keine Roblox-Aufrufe) und laufen in Lua 5.1 und Luau; deshalb sind sie testbar.

## 6. Konventionen (Fehlerquellen!)

* **Koordinaten:** Studs; x = Ost, z = Süd (Roblox „vorwärts“ = −z = Norden), y = oben. Ursprung = Siegestor (0,0). Karte x −745…1260, z −556…494. Terrain-Oberkante im Plan y = 0, Straße 0,5, Gehweg/Pflaster 1,0 (`floorY` = 1).
* **Teilespezifikation** (Liste `parts`): `name, kind, size{x,y,z}, pos{x,y,z}, yaw, pitch, roll, color{r,g,b}, material, collide, shape ("Cylinder"|"Ball"), text{s,color}, tag, lit, attrs{}, transparency`. Builder dreht `CFrame.Angles(yaw) * CFrame.Angles(pitch,0,roll)`. `kind="glass"` bekommt Transparenz 0,3.
* **Zylinder:** Achse = lokale x-Achse, `size = (Länge, Durchmesser, Durchmesser)`. Stehender Zylinder: `roll = 90`. Falsche Reihenfolge (`size = (Dm, Höhe, Dm)`) erzeugt riesige Scheiben (Fehler wurde mehrfach gemacht!).
* **Text:** Ein Teil mit `text` wird unsichtbar, die Schrift steht als SurfaceGui auf der **Vorderseite = −z lokal**. Flach auf dem Boden: `pitch = 90` (lesbar für Fahrer Richtung Süden); Schilder an Fassaden: Teil bei yaw 0 zeigt nach Norden, `yaw=180` nach Süden.
* **Spitzbogen:** Rechteck + um 45° gedrehtes Quadrat (`roll=45` für z-Flächen, `pitch=45` für x-Flächen). Runde Bögen: senkrechte Scheibchen, deren Unterkante dem Halbkreis folgt.
* **Hausrahmen** (`Planner.add`, `Stachus.frame`): lx entlang der Fassade, lz in das Gebäude (Front lz < 0); Weltposition `x + lx·cos(yaw) + lz·sin(yaw)`, `z − lx·sin(yaw) + lz·cos(yaw)`. Blickrichtung der Front = (−sin yaw, −cos yaw): yaw 0 → Norden, 90 → Westen, 180 → Süden, 270 → Osten.
* **Tags:** `HouseWindow` (+Attribut `Lit` für Nachtbeleuchtung; Tag-Nacht-Skript fehlt noch), `StreetLamp`, `TrafficLight`, `PedLight`, `FireGate`, `Schranke`, `VehicleSpawn`, `Eisbachwelle`, `SurfZone`, `Glockenspiel`, `GlockenspielFigur`, `ubahn` (Terrain-Aushub).
* **Doppelte Teilenamen** sind erlaubt, aber nicht bei Landmarks mit Test auf Eindeutigkeit (einmal `LaternenMast` → `LaternenMastOben`).
* **Rundung:** Positionen auf 0,001 runden (`Geo.round3`), damit Tests exakt vergleichen.
* **Bundle:** `make_bundles.py` entfernt Kommentarzeilen und Einrückung und ersetzt `require(script and script.Parent.X or "X")` durch lokale Variablen. Neue Module müssen in `PARTS` (Teil1/Teil2) eingetragen werden; Teil1 ~110k, Teil2 ~135k Zeichen (Grenze 190k je Teil; bei Überschreitung Teil3 anlegen oder Module verschieben).
* **Tests:** Neue Geometrie braucht Tests in `tests/planner_test.lua` bzw. `map_test.lua` (Grenzen, Überlappung mit Straßen/Sonderbauten/Häusern, Durchgänge frei, Teilezahl). Beim Test von Zylindern mit `roll=90` Höhe/Durchmesser vertauschen.

## 7. Was gebaut ist (Stand jetzt)

Letzter Smoke-Lauf (Attrappe): 299 Models, ~38 900 Parts, 9 740 Fenster-Tags. Teile je Schritt: terrain 1697 Ops, roads 1820 (159 Parkbuchten), lights 3256, landmarks 1604, marienplatz 990, **stachus 2869**, gardens 1058, houses 17 766 (169 Häuser), skyline 560, bus 216, wall 8752.

| Bereich | Stand |
|---|---|
| Terrain/Wasser | Boden aus Pavement, Parks als Gras, Monopteros-Hügel (+8), Friedensengel-Terrasse (Superellipse-Insel, +4), **Isar** (schwimmbar, 3-stufige Böschung, Wasser), Schwabinger Bach. Karte nach Osten um 100 erweitert. |
| Straßen | Ring, Leopoldstraße/Ludwigstraße (Achse 110 breit mit Mittelstreifen), Schwabinger Raster (V1, V2, H1, H2, 57 breit), Diagonale, Isarspange, V3, Maximilianstraße, **Isar-Allee** (Ostufer, Parkstreifen, roter Radweg), Friedensengel-Oval mit Zebrastreifen, Kreisverkehr um das Siegestor, gerundete Gehwegecken, 12 Zebrastreifen, Parkbuchten (159), 4 Brücken, **Maximilianbrücke mit Eisbachwelle** (Welle, Deck; Figuren wieder entfernt). Siegestor-Unterführung aus dem alten Plan entfiel zugunsten des Kreisverkehrs. |
| Licht/Verkehr | 297 Laternen (runder Mast, Bogenarm), 13 Ampelmasten; Fußgängerampeln aktuell **0** (prüfen, ob gewollt). Ampelsteuerung `Ampel.lua`. |
| Siegestor | Detailliert nach Foto: korinthische Säulen, Gebälk-Kröpfungen, Fries, Zahnschnitt, Archivolten, Rustika, Attika mit Inschrift („DEM SIEGE GEWEIHT · VOM KRIEG ZERSTÖRT · ZUM FRIEDEN MAHNEND“), Eckfiguren, Reliefs, **Quadriga** (Bavaria + vier Löwen). Gebogene Eckhäuser (`planCorners`) rund um den Kreisverkehr. |
| Friedensengel | Becken, Säule, goldener Engel; Oval mit Zebrastreifen. |
| Marienplatz | Granitpflaster, **Neues Rathaus** (140 breit, Glockenspiel-Tags), Mariensäule, **U-Bahn-Abgang** (14 Stufen, Portal, Gang), Kugelleuchten, Platanen, Cafés; **Frauenkirche** (Maßstab 0,65, Zwiebelhauben, Details). Südliche Häuserzeile Block `M_MarienplatzSued`. |
| **Stachus** (neu) | Ersetzt Casino-Odeon, Café-Terrasse, Uni-Fassade am Odeonsplatz. Platz x −215…−55, z 60…386. **Eckiger Hof** aus 5-geschossigen Geschäftshäusern: Nordzeile (Front nach Süden, bündig mit dem Neuen Rathaus an dessen Ostgiebel), Südzeile (spiegelbildlich, schließt an die Marienplatz-Häuserzeile an), Westzeile (Front nach Osten) mit **Karlstor** (so hoch wie die Zeilen, Bogendurchgang, zwei Zinnentürme, Uhr, Wappen) und flankierenden Türmen; Endtürme im Osten und am Tor mit flachem rotbraunem Walmdach. 39 tief, Mansarddach, Gauben, Erdgeschoss-Läden (52 Läden, „McDonnell's“ im Nordflügel), Dachschrift **„OSRUM“** auf Nord- und Südzeile. Mitte: Brunnen (Granitrand, 54 Wasserstrahlen, Mittelstrahl, Poller, Sitzsteine), Pflasterringe, zwei **U-Bahn-Abgänge** (spiegelbildlich, Betonrahmen, Treppe zwischen zwei Rolltreppen, Glasgeländer, Pylon, Portal „U S KARLSPLATZ“, Gang, Terrain-Aushub), Kugelleuchten, 8 Platanen, **Taxistand** (8 Parkbuchten an der Leopoldstraße mit aufgemaltem „TAXI“, 2 Schilder, keine Autos). Parameter in `Config.stachus`. |
| Hofgarten/Gärten | Hofgarten (am Odeonsplatz-Ost), Englischer Garten mit Monopteros, Biergarten, Bach mit Brücke, Isar-Uferwege, Westufer-Park, Eckgärten. |
| Häuserblöcke | A…G, M mit Hinterhäusern; Stilvarianten plain/palazzo/erker/jugend/modern; **Schaufenster** an der Leopoldstraße (Blöcke C, F: Ostseite; G: Westseite): Mode, Bar, Café, Schuhe, nur zum Gucken (9 Läden an 5 Häusern). **Höhere Eckhäuser:** `Config.eckhaeuser` (Faktor 1,5 = +50 %): `Haus_F_LeopoldWestSued_N1`, `Haus_C_LeopoldWestNord_S2` – **vom User per Screenshot gemeint, aber nur nach Farbe/Lage geraten** (bei Bedarf Namen tauschen). |
| Sonderbauten | Isarbank (alt), Parkhaus (alt), Allguth-Tankstelle (Schirm, Shop, Ladeplätze/EV, Behindertenplatz, Parkplatz), 3 Büro-Gebäude, Feuer-und-Rettungswache, Polizeiwache mit Hof und Seitenflügel, Krankenhaus (Klinik), **Klinikum-Parkhaus** (3 Etagen, angrenzend), **Volksbank** (grober erster Entwurf), Kiosk (auf dem Marienplatz), **Kaffeehaus Odeon** (grün-weiß, 50 % größer, Parkplatz), **Prinz Eins** (50 % größer, Parkplatz). |
| **Skyline** | `Config.hochhaeuser`: Glasturm hinter Volksbank/Krankenhaus (12 Etagen), Glasturm im Block D_West (15), **BMO-Turm** (Vierzylinder, blaues Band, eigenes Logo, 12 Etagen) + **BMO Welt** (Schüssel, Brücke) + 2 weitere Glastürme bei Allguth (10 und 9 Etagen). Höchster ~149 Studs. Auf Wunsch zuletzt **halbiert**. |
| Bushaltestellen | 18 Wartehäuschen (Bank, Fahrplan, Schild „H“) auf Gehwegen (`Config.busstops`, Attribut `Haltestelle`). |
| Mapgrenze | Häuserband mit Toren und Flusstoren. |

## 8. Probleme, Lösungen, Lehren

| Problem | Lösung / Lehre |
|---|---|
| Script-Limit ~200k Zeichen (Bundle war 210k) | Aufteilung in `Teil1`/`Teil2` (ModuleScripts), Kommentare/Einrückung im Bundle gestrichen, `LIMIT=190000` geprüft. `Alles.lua` überschreitet es (ungeprüft in Studio). |
| Terrain-Zellen 4 Studs, Oberkante ≠ Plan | Builder misst die Oberkante (`measureGround`) und richtet alles daran aus. Wasser-Fallback mit Ersatzplatten, wenn kein Terrain-Wasser. |
| Zylinder falsch skaliert (Siegestor-Säulen wurden riesige Scheiben, Uhr in der Wand) | Achse = lokal x, `size = (Länge, Dm, Dm)` mit `roll = 90`; Tests rechnen Höhe/Durchmesser entsprechend. |
| Bach von Widerlager blockiert | `culvert`-Option an Brücke B6 + Test. |
| Gehwege an Ellipsen/gebogenen Straßen wurden geschnitten | Regel: benachbarte Segmente derselben Straße mit kleinem Knick (dot > 0,95) schneiden nicht; Test angepasst. |
| Marienplatz: Block M zu flach (Überlappung) | `zmin` 326, Platz-z1 326; Hinterhof (`noInner`) aus. |
| Teile ragen über den Blockrand | Test erlaubt höchstens 2 Studs über den Blockrand (Markisen kürzen). |
| Tests schlagen bei neuer Geometrie an (Schwellen) | Schwellen anpassen, aber **erst prüfen, ob die Geometrie wirklich stimmt**. |
| Mehrfach falsche Interpretation von Screenshots | Annotationen genau lesen, Deutung nennen; beim Stachus erst Plan-Bild, dann Bau. |
| Python-Edits an Lua scheiterten an Tabs/Einrückung | Exakte Strings prüfen, nach `str.replace` immer `assert old in s`. |
| Renderer-Vorschau zeigt Glas undurchsichtig und Text schwarz | Nur ein Hilfsrenderer (`tools/lmview.py`), kein Studio. Glas/Text dort ignorieren. |

Gut funktioniert hat: planen mit Bild → bauen → Tests → Vorschau → liefern; Geometrie mit Konfigurationsdaten steuern; strikte Tests als Sicherheitsnetz; Auto-Bundle-Skript; kleine, klar benannte Commits.

## 9. Offen / Backlog

**Direkt zum Stachus/Karte (aus dem Verlauf):**
* [ ] Echte Studio-Prüfung aller neuen Bereiche (Stachus, Skyline, Siegestor, Schaufenster, Bushaltestellen) und Feintuning nach User-Screenshots.
* [ ] Stachus: Nordzeile↔Rathaus und Südzeile↔Marienplatz-Häuserzeile Wand an Wand – bitte im Studio prüfen (Dach-/Traufhöhen der Nachbarn, Rathaus ~130 hoch, Südzeile 5 Geschosse).
* [ ] Systemplan-Liste der Chill-Spots aktualisieren (Stachus statt Casino Odeon/Café-Terrasse).
* [ ] Zwei Eckhäuser (+50 %) sind geraten: mit dem User bestätigen.
* [ ] Fußgängerampeln: aktuell 0 – klären.
* [ ] Isarbank (altes, zweites Bankgebäude) bleibt neben der Volksbank bestehen; Parkhaus (alt) ohne Rampe in den 2. Stock; Volksbank und Klinikum-Parkhaus sind grobe erste Entwürfe.
* [ ] Kino/Café-Vorplatz am Hofgarten-Rand überlappt leicht (nur noch Kaffeehaus Odeon relevant).
* [ ] Mehr Schaufenster: nur 9 Läden an 5 Häusern; Eckhäuser am Siegestor und Südseite (Ludwigstraße) wären Kandidaten.
* [ ] Stachus-Südflügel an den Marienplatz-Block angeschlossen, aber der Block M (Höhe/Tiefe) ist nicht angepasst; ggf. Dächer vereinheitlichen.

**Aus den Plänen (noch nichts gebaut):**
* [ ] U-Bahn-Halle/Bahnsteig unter Marienplatz und Stachus (Abgänge gibt es, Halle fehlt).
* [ ] Surf-Skript an der Eisbachwelle (Tags `Eisbachwelle`, `SurfZone`).
* [ ] Glockenspiel-Animation am Rathaus (Tags `Glockenspiel`, `GlockenspielFigur`).
* [ ] Tag-Nacht-Zyklus (60 % Tag / 40 % Nacht; Fenster-Tag `HouseWindow` + Attribut `Lit`, Laternen `StreetLamp`).
* [ ] Schranken/Tore-Skripte (`FireGate`, `Schranke`), Spawns (`VehicleSpawn`).
* [ ] Spielsysteme laut `docs/SYSTEMPLAN.md`: Teams, Notruf-Telefon, Banküberfall mit Sprengladung (Isarbank/Volksbank), Kiosk, Rettungs-Minispiel, Polizei-Festnahme, Fahrzeuge (Toolbox, vereinheitlicht), Chill-/Loot-Spots.
* [ ] Innenräume der Wachen/Krankenhaus (Rollenspiel), Allianz Arena als Kulisse hinter der Nordgrenze.

## 10. Risiken und Unbekanntes (ehrlich)

| Punkt | Einschätzung |
|---|---|
| Aussehen in echtem Studio | Nie gesehen. Erwartete Probleme: Z-Fighting bei dicht gestapelten Flächen, Terrain-Zellen vs. Straßenhöhe, Lichtstimmung. |
| Teilezahl | ca. 39 000 Parts. Für Studio ok, Spieler-Performance (Streaming, CastShadow) ungetestet. |
| `MapBuilder_Alles.lua` im Studio | Über 200k Zeichen; Studio nimmt es vielleicht nicht an. Nutze Teil1/Teil2/Modul. |
| MCP-Anbindung | Nur vorbereitet, nicht getestet (HTTP-Loader, Chunk-Fallback, `Modul`-Bundle sind lokal gegen eine Attrappe geprüft). |
| Plugin speichert ModuleScript-Kinder? | Ungeprüft (Plugin-Variante). Für MCP irrelevant. |
| Roblox-Aufrufe in `Builder.lua` | Nur gegen Attrappe getestet. |

## 11. Wo ändere ich was (Schnellreferenz)

| Wunsch | Datei / Schlüssel |
|---|---|
| Straße/Breite/Profil | `Config.lua`: `C.roads`, `C.profiles` |
| Parkbuchten, Taxistand | `C.bays`, `C.stachus.taxi` |
| Hochhaus verschieben/Etagen | `C.hochhaeuser` + passende `reserved`-Fläche in `Blocks.lua` |
| Eckhäuser höher/niedriger | `C.eckhaeuser` (Hausname → Faktor, gerundet) |
| Bushaltestellen | `C.busstops` (`zurStrasse` = Seite der Fahrbahn; Test prüft Gehweg) |
| Stachus | `C.stachus` (Platz, Tiefe, Zeilen, Tor, Brunnen, U-Bahn-Gruben); Code `Stachus.lua` |
| Läden Leopoldstraße | `Blocks.lua` `shopSide`; Code `Planner.lua` (`storefront`, `SHOPNAMES`) |
| Sonderbau hinzufügen/entfernen | `Specials.lua` (Stil in `Planner.lua` `STYLES`) |
| Haus-Defaults (Tiefe, Geschosshöhe) | `Planner.DEFAULTS` (Tiefe 28, groundH 14, upperH 12) |
| Neues Modul | Datei in `MapBuilder/`, in `BuildAll.lua` Schritt + Reihenfolge, in `make_bundles.py` `PARTS`, Tests, README |

## 12. Verlauf der Nutzerwünsche (Kurzfassung, chronologisch)

1. Karte nach Skizze (Siegestor-Mitte, Leopoldstraße, Schwabinger Raster, Isar/Bach, Hofgarten/Englischer Garten); Straßen, Parkbuchten, Brücken, Ampeln, Wachen, Krankenhaus, Tankstelle.
2. Siegestor-Kreisverkehr mit gebogenen Eckhäusern (zwei mit Löchern), gerundete Gehwegecken, Fußgängerüberwege, detaillierteres Rollstuhlsymbol, Allguth: Ladeplätze (3 EV, normale Plätze, 1 Behindertenparkplatz), keine Dächer über den Ladeplätzen.
3. Isar-Allee mit Backsteinkirche, Westufer-Zeile, Hintergärten; Eisbachwelle an der Maximilianbrücke (Figuren wieder raus); Friedensengel nach hinten geschoben mit Oval-Straße und Zebrastreifen; gepflasterte Flächen zwischen Frauenkirche und Polizeistation entfernt.
4. Marienplatz mit Neuem Rathaus, Mariensäule, U-Bahn-Abgang, Frauenkirche (65 %, mehr Details).
5. Kino „Casino Odeon“, „Kaffeehaus Odeon“, Prinz Eins 50 % größer mit Parkplätzen; Klinikum-Parkhaus; Volksbank (grober Entwurf).
6. Skyline: Glas-Hochhäuser, BMO-Vierzylinder-Turm + BMO Welt (kein BMW-Logo), Eckhäuser +200 % (dann +50 %), Bushaltestellen; später alle Hochhäuser **50 % niedriger**.
7. Schaufenster an der Leopoldstraße (Mode, Bar, Café, Schuhe; nicht betretbar).
8. Siegestor mit mehr Detail (Referenzfotos).
9. **Stachus:** Odeon-Bebauung entfällt; erst Plan-Bild (Halbkreis, Brunnen, Karlstor, Taxistand, „OSRUM“, Burger-Lokal), dann Bau; Rückmeldungen mit Screenshots (Tor auf Flügelhöhe, Reihe 50 % tiefer, Walmdach statt Kuppel, U-Bahn-Schacht, Rathaus-Anschluss, Taxi als Bodenschrift); zuletzt **Rundung weg: eckiger Hof, Zeilen schließen Wand an Wand an Rathaus und Marienplatz-Häuserzeile an, beidseitig**.
10. Diese Übergabe, damit in einer neuen Session (mit Studio-MCP) reibungslos weitergearbeitet werden kann.
