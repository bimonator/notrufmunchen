# MapBuilder (Roblox, Luau)

Baut die Karte aus `docs/MAP_PLAN.md` und `docs/phase1_bauplan.html` per Code: Terrain mit Isar und Bach, Straßen mit Gehwegen, Parkbuchten, gewölbten Isar-Brücken und der Siegestor-Unterführung, Reihenhäuser im Schwabing-Raster und entlang der Leopoldstraße, Platzhalter für die Sonderbauten (Bank, Wachen, Krankenhaus ...) und die Mapgrenze. Geometrie und Roblox-Aufrufe sind getrennt, damit die Geometrie ohne Roblox getestet werden kann.

## So fügst du alles zusammen (empfohlen: Plugin, dauerhaft)

1. Studio öffnen, neues Projekt mit der Vorlage **Baseplate**. Die Baseplate **löschen** (der Builder legt das Terrain selbst an).
2. In `Workspace` ein **Script** anlegen und den ganzen Inhalt von **`MapBuilder_Plugin.lua`** einfügen.
3. Unter diesem Script zwei **ModuleScripts** anlegen (Rechtsklick auf das Script > Insert Object > ModuleScript), umbenennen in **`Teil1`** und **`Teil2`** und die Inhalte von **`MapBuilder_Teil1.lua`** bzw. **`MapBuilder_Teil2.lua`** einfügen. Roblox erlaubt pro Script nur ca. 200 000 Zeichen, darum ist der Code auf drei Teile verteilt.
4. Rechtsklick auf das Script > **Als lokales Plugin speichern** (die beiden ModuleScripts werden mitgespeichert). Danach das Script löschen.
5. Im Reiter **Plugins** erscheint der Knopf **Karte bauen**. Draufklicken, der Build dauert ca. 1–3 Minuten (Output-Fenster zeigt den Fortschritt).
6. Im Output steht je Schritt eine Zeile. Erwartet:

```
[terrain] 1171 Terrain-Operationen
[boden] Terrain-Oberkante gemessen: -2.0, alle weiteren Teile werden daran ausgerichtet
[wasser] ok (... Wasser-Zellen am Messpunkt)
[roads] 1475 Teile, 157 Parkbuchten
[lights] 273 Laternen, 13 Ampelmasten, 3016 Teile
[landmarks] ~1100 Teile (Siegestor, Friedensengel, Frauenkirche, Chinesischer Turm)
[marienplatz] 990 Teile (Rathaus 532, Platz 458), 15 Kugelleuchten, 8 Platanen, U-Bahn-Abgang mit 14 Stufen
[gardens] 1050 Teile, 143 Bäume, 103 Uferweg-Platten, 50 Findlinge
[houses] 154 Häuser, 12928 Teile
[ampel] Script AmpelSteuerung in ServerScriptService angelegt
[wall] 128 Gebäude, 8743 Teile
Fertig
```

Wichtig sind die Zeilen `[boden]` und `[wasser]`. **Boden:** Roblox füllt Terrain in 4-Studs-Zellen, die tatsächliche Oberkante kann daher von der geplanten abweichen. Der Builder misst sie nach dem Terrain und setzt Straßen, Häuser und Mauer genau darauf (sonst versinken die flachen Straßen). **Wasser:** Findet er kein Terrain-Wasser, setzt er blaue Ersatz-Platten (Ordner `WasserErsatz`, nicht schwimmbar) und schreibt das in den Output. Bitte beide Zeilen mitschicken, wenn etwas nicht stimmt.

Strg+Z nimmt den ganzen Lauf zurück. Erneutes Bauen ersetzt die Ordner `Strassen`, `Gebaeude.<Block>` und `Mapgrenze` (das Terrain wird zuerst geleert).

### Schnelltest ohne Plugin

`MapBuilder_Script.lua` in ein Script in `ServerScriptService` einfügen, darunter die ModuleScripts `Teil1` und `Teil2` wie oben anlegen, oben auf **Run** klicken (nicht Play). Oben in der Datei kann man `STEPS` auf einzelne Schritte beschränken, z. B. `{ "roads" }`. Die Karte ist nach dem Stoppen wieder weg. Geeignet, um einen Schritt auszuprobieren.

### Schritt für Schritt (wenn etwas nicht klappt)

Die Schritte laufen in dieser Reihenfolge und sind unabhängig voneinander ausführbar: `terrain` → `roads` → `lights` → `landmarks` → `gardens` → `houses` → `wall`. Im Script oben `STEPS = { "terrain" }`, dann `{ "roads" }` usw. Fehler eines Schritts stoppen die anderen nicht, sie stehen im Output als `FEHLER: ...`.

## Dateien

| Datei | Inhalt | Geprüft |
|---|---|---|
| `MapBuilder/Geo.lua` | 2D-Mathematik (Strecken, Schnitte) | ja |
| `MapBuilder/Config.lua` | Alle Maße aus dem Plan als Daten (Straßen, Kreisverkehr am Siegestor, Wasser, Brücken, Parks, Wand) | ja (wird getestet) |
| `MapBuilder/Planner.lua`, `Blocks.lua`, `Specials.lua` | Reihenhäuser (7 Blöcke), Sonderbauten als Platzhalter, Mapgrenzen-Gebäude | ja |
| `MapBuilder/RoadsPlanner.lua` | Straßen, Gehwege, Markierungen, Parkbuchten, Brücken (3 gewölbt), Unterführung | ja |
| `MapBuilder/TerrainPlanner.lua` | Terrain-Operationen (Boden, Parks, Hügel, Terrasse, Isar, Bach) | ja (nur die Liste) |
| `MapBuilder/WallPlanner.lua` | Mapgrenze mit Toren, Querriegel, Feldherrnhalle | ja |
| `MapBuilder/Builder.lua`, `BuildAll.lua` | Erzeugt daraus Roblox-Objekte | **nur gegen eine Attrappe** |
| `MapBuilder_Script.lua`, `MapBuilder_Plugin.lua`, `MapBuilder_Teil1.lua`, `MapBuilder_Teil2.lua` | Script bzw. Plugin plus zwei ModuleScripts (Grenze ca. 200 000 Zeichen je Script), erzeugt mit `python3 make_bundles.py` | wie Builder |
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

- `python3 tests/run_with_lupa.py` (Lua 5.1): Häuser (Maße, Überlappung, Eckhäuser, Abwechslung bei Farben, Geschossen, Dachformen, Breiten, Sonderflächen frei), Sonderbauten (Grundfläche stimmt, keine Überlappung), Straßen (157 Parkbuchten wie im Plan, kein Gehweg in einer Kreuzung, jede Straße asphaltiert, Kreisverkehr (Zu- und Abfahrten münden im Ring, keine Häuser im Ring), Brücken: Scheitelhöhe, Enden auf Straßenniveau, zwei Pfeiler im Fluss, keine flache Straße darunter), Terrain (Kacheln decken die Karte genau ab, Wasser nur zwischen Bett und Wasserlinie), Wand (innen bleibt der Ring frei, Tore frei, Höhen 74–110), Isar-Allee (parallel zur Isar, Gehweg hinter der Böschungskante, Laternen im Laternenstreifen, Baumreihe, Parklinien quer zur Straße, Häuser nie in der Fahrbahn und ohne Überlappung, Kirche mit 18-teiligem Helm und Uhr).
- `python3 tests/bundle_smoke_test.py`: `Builder` und `BuildAll` laufen gegen eine selbst gebaute Roblox-Attrappe: 257 Models, 18 211 Teile, 1171 Terrain-Aufrufe, zweiter Lauf ersetzt statt zu verdoppeln.
- Eine Draufsicht der berechneten Teile (aus den Plänen gezeichnet) stimmt mit der Karte im Bauplan überein.
- Die Tests wurden gezielt mit eingebauten Fehlern geprüft (Gehweg-Schnitt aus, Brücken-Schnitt aus, Kreisverkehr-Schnitt aus, falscher Drehwinkel): sie schlagen dann an.

## Was NICHT geprüft werden konnte (bitte im Studio ansehen)

- Ob die echte Roblox-API sich wie die Attrappe verhält (`Terrain:FillBlock` mit gedrehtem CFrame, `FillCylinder`, `Terrain:Clear`, `CollectionService`).
- Ob die Isar im Terrain sauber aussieht. Sie ist aus gestapelten Blöcken gebaut (Stufen von 4 Studs). Falls sie treppig wirkt, im Terrain-Editor mit **Smooth** glätten.
- Das Aussehen: Höhenlage von Gehweg, Straße und Brücken (Z-Fighting möglich), Wirkung der Mapgrenze und des Kreisverkehrs am Siegestor.
- Die Leistung: ca. 18 000 Teile (Häuser 8 100, Mapgrenze 8 700, Straßen 1 300). Wenn es ruckelt, zuerst die Mapgrenze vereinfachen.

## Bewusst (noch) nicht enthalten

Ampeln, Schilder und Straßennamen, Straßenlampen und Bäume, Innenräume und Details der Sonderbauten (Bank, Wachen, Krankenhaus, Parkhaus, Tankstellen-Shop sind nur Platzhalter-Gebäude, die Tankstelle hat Schirm und Zapfsäulen), Supermarkt, Werkstatt, Kirche und Plätze mit Brunnen, Siegestor, Friedensengel, Monopteros-Tempel, Schrägdächer (nur flache und Mansarddächer). Das Wasser der Eisbachwelle ist ein normaler Bach. Die Fußgängerbrücke B5 ist flach (keine Rampen). Die Isar-Brücken haben Pfeiler, aber keine echten Bögen und Lampen.

## Übergabe an eine neue Claude-Session

Ordner `roblox/` zeigen und sagen: „Baue die Karte im Studio mit `MapBuilder_Plugin.lua` (Anleitung in `roblox/README.md`), prüfe das Ergebnis und korrigiere `Builder.lua`. Die Geometrie nur ändern, wenn `tests/run_with_lupa.py` danach weiter besteht, und danach `python3 make_bundles.py` ausführen."

## Ampelsteuerung

Das Plugin legt beim Bauen ein Script `AmpelSteuerung` in ServerScriptService an (beim zweiten Bauen wird es ersetzt). Es schaltet beim Play/Run:

- **Kreuzungen** (Achse × Ring Nord, H1, Odeonsplatz): Achse 30 s grün, 3 s gelb, 2 s alle rot, dann Querstraße 30 s grün usw. Jede Kreuzung startet versetzt. Zeiten oben in `Ampel.lua` (`Ampel.config`), im Script `AmpelSteuerung` ganz oben im Block `Ampel.config`.
- **Feuerwache** (Gruppen `Wache_V1`, `Wache_V2`): grün für den Verkehr. `workspace:SetAttribute("WacheAlarm", true)` schaltet gelb, dann rot; `false` schaltet wieder grün. Test: im Run-Modus in der Command Bar `workspace:SetAttribute("WacheAlarm", true)`.
- **Fußgängerampeln:** am Siegestor entfallen (Kreisverkehr statt Tunnel); die Steuerung bleibt für spätere Übergänge (`C.pedSignals`).

Das Test-Script `MapBuilder_Script.lua` startet die Steuerung direkt nach dem Bauen.

## Allguth-Tankstelle

Nach Fotos: Schirm mit abgerundeten Nordecken und rotem Band mit Schriftzug, 8 weiße Stützen, zwei Zapfsäulen-Inseln, Rasenstreifen mit Hecke und Büschen zwischen Gehweg und Station (nicht an den Einfahrten), EINFAHRT/AUSFAHRT-Schilder, quadratische Logoschilder und das Preis-Totem mit 5 Sorten.
Die Preiszeilen tragen den Tag `FuelPrice` mit den Attributen `Fuel` und `Price` (nur Anzeige, ein Skript kann sie später ändern). Dahinter stehen drei Bürogebäude (Spezialbauten `Tankstellen-Buero-*`) mit Glasfassade, Geschossbändern und Stahlpfeilern.

## Kreisverkehr am Siegestor

Das Siegestor steht auf einer runden Mittelinsel (Radius 52, Bordstein). Rundherum läuft ein 24 Studs breiter Ring (Mittellinie Radius 68, `SiegestorKreisel`). Die Leopoldstraße (Achse) läuft oberirdisch in den Ring, ebenso H2 und die Diagonale; Häuser am Rand wurden dafür entfernt. Ein Tunnel und Rampen gibt es nicht mehr.

## Isar-Allee (Ostufer)

Gerade Straße `IsarAllee` parallel zur (jetzt geraden) Isar zwischen Ring Nord und Isarspange; die Karte ist dafür nach Osten um 100 Studs gewachsen (`Config.map.xmax` 1260, Ring 1176). Querschnitt von der Isar zu den Häusern (Studs): Ufergehweg 8, Baumreihe 12 (alle 24 Studs), roter Radweg 8, Laternenstreifen 4 (Laternen alle 48), Straße 20, Parkstreifen 9, Gehweg 8, dann die Häuserzeile. 11 Häuser (um 7,2° gedreht, wie die Isar) und eine neuromanische Backsteinkirche mit Turm (Uhr, Rosette, Kupferhelm, Höhe ca. 128), Seitenschiffen, Satteldach und Apsis. Die Straßenstreifen `green` und `bike` sind neue Arten in `RoadsPlanner`; Parkbuchten laufen auch an schrägen Straßen (Linien quer zur Fahrtrichtung). Einen Kanal gibt es bewusst nicht.

## Parkplätze an der Allguth-Tankstelle

Im freien Südteil des Grundstücks, gegenüber der schmalen Südseite des Schirms (Fahrzeuge stehen mit der Front zum Schirm): 10 Plätze in einer Reihe (`Config.tankstelle.parking`): 1 Behindertenparkplatz (blau, detailliertes Rollstuhlsymbol aus 16 Teilen: Rad als Ring, Kopf, Rumpf, Arm, Ober- und Unterschenkel, Fußstütze; Schild), 3 Ladeplätze (grün markiert, je eine Ladesäule, Schild „E-LADEN“, **ohne Überdachung**) und 6 normale Plätze mit weißen Linien. Die Säulen tragen den Tag `EVCharger` (Attribute `Station`, `kW`); es ist nur die Optik, ohne Ladelogik.

## Friedensengel-Oval

Die Maximilianstraße endet am Westende eines Straßenovals (`FriedensengelRing`, Superellipse 214 x 124, Mittelpunkt 1013/298) und teilt sich dort in zwei Bögen um die Terrasse; im Osten läuft das Oval wieder zusammen und die `FriedensengelAusfahrt` führt zum Ring. Die Rasen-Insel (Terrasse, 4 hoch) liegt innen, der Friedensengel steht im östlichen Teil (x = 1040), im Westen führen vier Stufen und ein Plattenweg hinauf. Die Isarspange endet an einem verschobenen Ring (Osten +100 gegenüber dem ersten Plan).

## Gehwegecken und Siegestor-Ecken

An allen rechtwinkligen Kreuzungen füllt `RoadsPlanner` das Eck zwischen den beiden unterbrochenen Gehwegen mit einer gerundeten Gehwegecke (Radius 5, `GehwegEcke`, `GehwegEckeRund`, `EckAsphalt`). Um den Kreisverkehr am Siegestor läuft außen ein Gehweg (Radius 80 bis 90). In den beiden Lücken der Häuserreihen (Nordwest, Nordost) stehen gebogene Eckhäuser (`Planner.planCorners`, je vier Fassadenplatten auf dem Kreis, 5 Geschosse, gleiche Farbe) mit Hintergärten (Rasen und Bäume).

## Isar-Allee, Westufer und Hintergärten

Auf der Isarseite gegenüber der Allee steht eine Häuserzeile mit Ufergehweg und Baumreihe (`Planner.planWestbank`) und dahinter ein Park. Die Ost-Häuser der Allee haben Hintergärten (Rasen, bei genug Platz zwei Bäume).

## Marienplatz

Im Südwesten (`Config.marienplatz`, Platz x −632…−215, z 60…326): Granitpflaster mit Fugen und rotbraunen Bändern; **Neues Rathaus** am Nordrand (`Rathaus.lua`, 140 breit: 9 Achsen, Arkaden, Balkone mit rosa Blumen, Spitzbogenfenster, Erker, Ecktürmchen, Schieferdach mit Gauben und Firstzier, Mittelturm mit Tor, Glockenspiel (Tags `Glockenspiel`, `GlockenspielFigur`), Uhr, Umgang, Glockenstube, Helm und Münchner Kindl, ca. 130 hoch); **Mariensäule** (Stufen, Balustrade mit Blumen, vier Putten, roter Marmorschaft, goldene Madonna); **U-Bahn-Abgang** vor dem Rathaus (14 Stufen bis 10,5 unter den Platz, Podest, Portal mit Schild „U S MARIENPLATZ“, beleuchteter Gang mit Fahrplan; Terrain-Aushub in `TerrainPlanner`); 15 **Kugelleuchten** (zwei Glaskugeln, Tag `StreetLamp`), 8 Platanen, Sitzstufen, zwei Café-Terrassen mit blauen Schirmen, Fahrräder, Bänke; Kiosk auf dem Platz; Häuserzeile am Südrand (Block `M_MarienplatzSued`). Die **Frauenkirche** steht im Nordwesten, auf 65 % verkleinert (`scale`), mit Lisenen, Maßwerkfriesen, Spitzbogenfenstern an den Türmen und heller Portal-Vorhalle mit Ziergiebel. Die Straße KirchplatzNord entfällt.

## Klinikum-Parkhaus, Volksbank, größere Bauten am Odeonsplatz

- **Klinikum-Parkhaus** (`style = "parkhaus"`, x 500…660, z −430…−310): grenzt an der Ostseite des Klinikums an und ist genau so groß (160 x 120). Drei offene Decks (Erdgeschoss, 1. und 2. Stock, je 11 hoch) mit 35 Stützen je Deck, Brüstungen, Lamellenfassade, 56 Stellplatzlinien je Deck, Geschossschildern, Einfahrt/Ausfahrt mit Kassenhäuschen und Schranken (Tag `Schranke`), zwei Treppenhäusern und einer Auffahrt ins 1. Obergeschoss an der Ostseite. Eine Rampe ins 2. Obergeschoss fehlt noch.
- **Volksbank** (erster grober Entwurf, x 330…404, z −280…−210, Front zur V3): Lücke südlich des Klinikums. Heller dreigeschossiger Bau mit blau-orangem Band, Glasfront, Drehtür, Vordach, zwei Geldautomaten, großem Schriftzug „Volksbank“ (nur Wortmarke, kein Logo), Fahnenmasten. Die bisherige „Isarbank“ an der Leopoldstraße bleibt als zweite Bank.
- **Casino Odeon** (Kino) und **Kaffeehaus Odeon** sind 50 % größer (105 x 90 bzw. 90 x 60, höher mit mehr Fensterreihen, Kino mit 8 Plakaten, Café mit 8 Tischen), schauen nach Norden und haben daneben je einen **Parkplatz** (`lots` in `Specials.lua`, zwei Stellplatzreihen). **Prinz Eins** ist auf 84 x 40 und 3 Geschosse gewachsen, mit Parkplatz westlich davon.

## Fußgängerüberwege

`Config.crossings`: 12 Zebrastreifen (Streifen 2 breit, 2 Lücke, 10 lang, parallel zur Fahrtrichtung): 6 am Friedensengel-Oval (radial über die Fahrbahn von Gehweg zu Gehweg, bei 22°, 90°, 158°, 202°, 270°, 338°) und 6 am Siegestor (Achse Nord und Süd je beide Fahrbahnen, H2, Diagonale).

## Odeonsplatz

Odeonsplatz, Kirchplatz und Fußgängerzone bleiben ohne Pflaster (`Config.plazas` ist leer); die Leopoldstraße ist durchgehend Asphalt. Am Odeonsplatz stehen nach `docs/MAP_PLAN.md` zwei Bauten mit Vorplatz in Gehwegoptik: das Kino **Casino Odeon** (West, x −205…−135: dunkle Fassade, Marquise mit goldenem Neonrand und Schriftzug, Glashalle mit Doppeltür und Kasse, vier Filmplakate, Dachschild „KINO“ mit Filmrolle, roter Teppich) und das **Kaffeehaus Odeon** (Ost, x 140…200: grün-weiße Fassade, grüne Markise, rundes Schild mit Kaffeebohne, Terrasse mit Zaun, 6 Tischen, 3 Sonnenschirmen). Der Plan nennt für die Kaffeekette bewusst einen eigenen Namen ohne Logo (Markenrisiko).

## Hinweise zu Terrain-Einstellungen

Der Terrain-Schritt setzt `Terrain.Decoration = false` (keine Gras-Büschel, die sonst durch Wege und Straßen ragen), `WaterTransparency = 0.45` und eine Wasserfarbe, damit die Isar von oben als Wasser erscheint. Das Flussbett besteht aus Sand statt Asphalt-grau.

## Offen / Backlog

- **Siegestor:** mehr Detail (Reliefs, Quadriga). Der Friedensengel hat jetzt Gewand, Flügel, Ölzweig, Nike, Kanneluren und Reliefs; weitere Verfeinerung nach Foto möglich.
- **Tore der Feuerwache** (`FireGate`) und **Schranken der Polizei** (`Schranke`, Attribut `Offen`) sind Modelle ohne Skript; das Öffnen und Schließen kommt mit den Einsatz-Skripten. Fahrzeug-Spawnflächen tragen den Tag `VehicleSpawn` (Attribut `Team`).
- **Eisbachwelle** liegt direkt flussabwärts (südlich) der Maximilianbrücke wie in München: die Welle liegt unter dem südlichen Brückengehweg (Aussichtsplatz), auf dem Westufer ein Deck mit Bänken. Figuren und Bretter sind (vorerst) entfernt. Die Welle ist nur das Bild einer stehenden Welle (Tags `Eisbachwelle`, `SurfZone`); das Surfen (Strömung, Brett) kommt als Skript. Das westliche Widerlager der Brücke hat einen Durchlass (`culvert`), sonst wäre der Bach darunter zugemauert.
- Café (wartet auf Foto), Straßenschilder, Straßennamen, Frauenkirche mit mehr Detail (Fensterspitzbögen, Dachgauben, Uhrzeiger).

## Skyline, Eckhäuser, Bushaltestellen

- **Hochhäuser** (`Hochhaus.lua`, Standorte in `Config.hochhaeuser`, Flächen in `Blocks.lua` als `reserved`): Glasturm *Hochhaus-Klinikum* (hinter Volksbank/Krankenhaus, 64 × 64, 24 Etagen), *Hochhaus-West* (Block D_West, 30 Etagen, ~284 Studs), drei Türme an der Allguth-Tankstelle: **BMO-Turm** (vier Zylinder, blaues Band, eigenes Logo mit Ring/Raute und Schrift „BMO“, 24 Etagen), **BMO Welt** (Schüssel-Gebäude, Brücke zum Turm), *Hochhaus-Allguth-Sued* und *-Nordost*. Glastürme haben abgerundete Ecken; Fenster mit Tag `HouseWindow` (ca. 30 % nachts an).
- **Eckhäuser höher** (`Config.eckhaeuser`, Faktor auf die Geschosse, 3 = +200 %): `Haus_F_LeopoldWestSued_N1`, `Haus_C_LeopoldWestNord_S2`. Anderes Haus gemeint? Namen in der Liste tauschen.
- **Bushaltestellen** (`Bushaltestellen.lua`, `Config.busstops`): 18 Wartehäuschen mit Bank, Fahrplan und Schild „H“ auf den Gehwegen (Attribut `Haltestelle`).
- Neue Schritte `skyline` und `bus` in `BuildAll`.

- **Schaufenster an der Leopoldstraße** (`storefront` in `Planner.lua`, Blöcke mit `shopSide` in `Blocks.lua`: C/F Ostseite, G Westseite): vor der Fassade Vitrine mit Glas, Rahmen und Namensschild, nicht begehbar. Vier Arten: Mode (Schaufensterpuppen, Kleiderstange, SALE), Bar (Tresen, Flaschenregal, Neonröhren, Hocker), Café (Tische, Stühle, Kuchentheke, Pendelleuchten, gestreifte Markise, Kreidetafel), Schuhe (Regale mit Kartons). Aktuell 9 Läden an 5 Häusern; die Tür daneben bleibt Wohnungseingang.
