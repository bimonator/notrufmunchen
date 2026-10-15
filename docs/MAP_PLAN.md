# Notruf München – Map-Plan v0.2

Roblox-Einsatzspiel (Polizei / Feuerwehr / Rettungsdienst) in München, Vorbild-Prinzip: Notruf Hamburg.
Grundlage: `docs/map_sketch.png` (Paint-Skizze). Alle Koordinaten unten sind aus der Skizze abgeleitet.

## 0. Beschlossen (Stand v0.2)

| Thema | Entscheidung |
|---|---|
| Fokus | Nur die **Map** planen/bauen. Polizei/Feuerwehr/Rettung (Abschnitt 6) sind **zurückgestellt**. |
| Hofgarten | Wird **am Odeonsplatz** platziert (Ostseite), nicht oben rechts. |
| Marienplatz/Frauenkirche | **Wie in der Skizze** (SW, Kreisel) – Spielbarkeit vor Geografie. |
| Allianz Arena | **Nur Kulisse** hinter der Nordgrenze, nicht betretbar. |
| Starbucks / P1 / Filmcasino | Gleiche Orte, gleicher Vibe, aber **erfundene Namen, keine Logos** (Abschnitt 7). |
| Englischer Garten | Braun-graue Formen = nur **Wege**. Enthält Wiesen, **Monopteros**, Schwabinger Bach mit kleiner **Fußgängerbrücke**. Details später. |
| Tag/Nacht | **Ja**, Verhältnis **60 % Tag / 40 % Nacht** (Abschnitt 8). |
| Friedensengel | Am Ostende der **Luitpoldbrücke** (Prinzregentenstraße), nicht an der Maximilianbrücke (liegt außerhalb der Map). |
| Zielplattform | **PC zuerst**, Mobile zweitrangig. Optimierung später. |
| Isar | **Schwimmbar** (80 breit, 6 tief). |
| Straßenbreiten | **Fahrspur 14 Studs** (Roblox-Auto passt mit Luft), Gesamtbreite Achse 96, alle anderen 48. Details in `docs/phase1_bauplan.html`. |
| Verkehr | **Siegestor-Unterführung:** Achse taucht unter der durchgehenden Querstraße H2/D ab (Rampen 136, Tunnel 72). 3 Ampelkreuzungen, 2 Fußgängerampeln, Ring = Vorfahrtstraße, Schilder nach StVO-Vorbild, braune Wegweiser. Details in `docs/phase1_bauplan.html`. |
| Server | Ein Server für alles, mit Chill-Spots (Schutzzonen) und Loot-Spots. Fahrzeuge aus der Toolbox, vereinheitlicht. Siehe `docs/SYSTEMPLAN.md`. |
| Gebäude | **Polizeiwache** (SO, Innenhof mit Schranke), **Feuer- und Rettungswache** (im Schwabing-Raster, 8 Tore: vorne Feuerwehr, hinten Rettung), **Tankstelle** an der Leopoldstraße, **Krankenhaus** (NO, über neue Straße V3, nur Rollenspiel). Siehe `docs/phase1_bauplan.html`. |
| Häuser | Reihenhaus-Generator (Luau) für die Schwabing-Blöcke A, B, D in `roblox/`, Geometrie getestet, Roblox-Teil noch ungeprüft. |
| Spielsystem | Teams Zivilist, Polizei, Rettungsdienst, Kriminelle. Banküberfall mit Sprengladung, Schmuggelware statt Drogen. Siehe `docs/SYSTEMPLAN.md`. |
| Parken am Straßenrand | Achse **110** breit (Parken beidseitig, ≈ 69 Buchten), Schwabing-Raster **57** (einseitig, ≈ 88). Bucht 9 × 16. |
| Überfallziele | **Isarbank** (Eck Leopoldstraße/H1), **Kiosk** (Schwabing), **Parkhaus** (gegenüber der Bank, Fluchtwagenwechsel). Details in `docs/phase1_bauplan.html`. |
| Fußgängerzone Marienplatz | **Für Einsatzfahrzeuge befahrbar** (40 breit, Poller mit 20 Studs Lücke). |

## 1. Koordinatensystem & Größe

- Ursprung `(0,0)` = **Siegestor**. `+X` = Ost, `+Z` = Süd (Roblox: „vorwärts" = −Z = Norden).
- Skizzenmaßstab: **1 px ≈ 1,5 Studs** (Annahme, anpassbar).
- Spielfläche: ca. **1900 × 1050 Studs** (X −745…+1160, Z −556…+494).
- Fahrzeug bei ~60 Studs/s → Ost-West-Querung ≈ **30 s**, Nord-Süd ≈ **18 s** → Einsätze gut erreichbar, Map fühlt sich nicht leer an.

## 2. Orte (Skizze → Koordinate)

| Ort | Skizze | Studs (X, Z) | Typ |
|---|---|---|---|
| Siegestor (gelber Kasten) | Mitte | (0, 0) | Landmark, Hauptachse |
| Leopoldstraße | senkrechte Doppellinie | X≈0, Z −556…0 | Hauptstraße Nord |
| Ludwigstraße (Fortsetzung Süd) | gleiche Achse | X≈0, Z 0…+460 | Hauptstraße Süd, Uni |
| Frauenkirche + Marienplatz (Kreisel, oranges Dach) | unten links | (−550, +254) | Landmark + Platz im Kreisel |
| Odeonsplatz | unterer Kartenrand an der Achse | (0, +400…+460) | Mapende Süd, Filmcasino-Club, Starbucks-Ersatz |
| Hofgarten (grüner Kasten, Pavillon in der Mitte) | **verschoben** an den Odeonsplatz (Ost) | (+230, +195), ca. 340 × 190 (an Ring und Odeonsplatz angepasst, Details in docs/phase1_bauplan.html) | Park, 8 Wege strahlenförmig |
| Freigewordene Fläche NO (alter Hofgarten-Platz) | oben rechts | (+420, −312) | Wohn-/Gründerzeitblöcke Schwabing, Platz für spätere Wachen |
| Isar (breites Blau) | rechts, NO→SW | X≈+700…+1100 | Fluss, Hauptwasser |
| Schwabinger Bach (dünnes Blau) | links neben der Isar | X≈+650…+700 | Bach im Englischen Garten |
| Englischer Garten (grün gepunktet) | rechts Mitte | (+520…+720, 0…+300) | Park: Wiesen, Wege, Monopteros, Bach mit Fußgängerbrücke |
| Eisbachwelle + Brücke + P1 | Brücke unten rechts | (+650, +404) | Surfer-Spot, Aussichtsbrücke, Club |
| Friedensengel + Luitpoldbrücke (B3) | Ostende der Südbrücke | Engel (+945, +292), Brücke Z +410 | Landmark, 90 Studs hoch, Terrasse +12 mit Kaskaden |
| Allianz Arena | oben links, außerhalb | (−265, −632) | **nur Kulisse** hinter der Mapgrenze |
| Außenring-Straße + Häuserwand | Rahmen | Kartenrand | Mapgrenze |

Braun-graue Form im Englischen Garten (≈ (+590, +120)): nur Wege. Der **Monopteros** (Hügel mit Rundtempel) kommt trotzdem dorthin, Details später.

## 3. Geografie-Check (Skizze vs. Realität)

| Punkt | Realität | Skizze | Empfehlung |
|---|---|---|---|
| Siegestor → Odeonsplatz | ~1 km, Ludwigstraße mit Uni | ~700 Studs, passt grob | so lassen |
| Marienplatz relativ zu Odeonsplatz | **südlich** davon (~0,6 km) | **nördlich** (Z +254 vs. +460) | **Beschlossen:** wie Skizze (Spielspaß > Genauigkeit, ~90 % der Spieler merken es nicht) |
| Hofgarten | direkt **neben dem Odeonsplatz** (Ost) | oben rechts, weit weg | **Beschlossen:** an den Odeonsplatz verschoben |
| Eisbachwelle / P1 | SO, an der Prinzregentenstraße, Südende Englischer Garten | unten rechts | passt |
| Allianz Arena | ~8 km nördlich | oben links | Kulisse/Skybox, nicht spielbar |
| Isar | östlich | rechts | passt |

## 4. Straßennetz

- **Achse:** Leopoldstraße/Ludwigstraße, 4 Fahrspuren à 14 + Mittelstreifen 12 + Parken 2 × 9 + Gehwege 2 × 12, gesamt 110, Bäume am Rand.
- **Unterführung:** Die vier Fahrspuren der Achse tauchen am Siegestor unter der Querstraße H2/D durch (kreuzungsfrei). Sonst ist die Achse bei den Querstraßen ampelgeregelt.
- **NW-Raster (Schwabing):** 2 Längs- + 2 Querstraßen, Blöcke ca. 200 × 150 Studs.
- **Diagonale NO→Siegestor-Bereich:** Verbindung Richtung Hofgarten/Isarbrücke.
- **Südliche Querstraße (unten):** verbindet Marienplatz-Kreisel, Odeonsplatz und Eisbachbrücke.
- **Brücken:** Isar-Brücke NO (Skizze ~ (1190, 470)), Eisbachbrücke unten rechts. Mindestens 2 Querungen → keine Sackgassen für Einsatzfahrzeuge.
- **Mapgrenze:** durchgehende Häuserwand (Höhe ≥ 80 Studs, Dächer geschlossen) mit Lücken nur für Straßen, die in **Tore/Tunnelblenden** oder abgesperrte Baustellen enden – verhindert „Ende der Welt"-Blick.

## 5. Bereiche im Detail

### 5.1 Leopoldstraße (Zentrum)
Ladenzeile beidseitig, Z −400…−40, ~20 Gebäude pro Seite:
- Mode-/Shoppingläden (erfundene Namen), Schuh-/Sneakerladen, Elektronik
- 2–3 Shisha-Bars, 3–4 Cafés mit Außenplätzen, 2 klassische Bars, 1 Eisdiele, Döner/Imbiss
- Optional: Kino-Eingang, Hotel

### 5.2 Univiertel (zwischen Siegestor und Odeonsplatz)
- Unigebäude-Fassade (neoklassisch, ähnlich LMU), Vorplatz mit Brunnen
- **Terrassen-Café** direkt an der Straße: tagsüber Café, **abends Cocktailbar** (Lichtstimmung per Tageszeit-Script, Lichterketten, Heizpilze) – Vibe-Ort + Einsatzort (Schlägerei, Überdosis, Unfall)

### 5.3 Odeonsplatz (Südende)
- Feldherrnhalle-Look (Loggia mit 3 Bögen)
- **Filmcasino** (Club, siehe Namensrisiko unten) + **Kaffeekette** (grün/weiß-ähnlich, **ohne** Logo)
- Schmaler Platz, Fußgängerzone Richtung Marienplatz

### 5.4 Marienplatz / Frauenkirche
- Kreisel um den Platz; Frauenkirche mit 2 Zwiebeltürmen (orange Dächer wie in der Skizze → Zwiebelhauben **kupfergrün/grau** wären realistischer, orange nur falls bewusst gewollt)
- Marienplatz-Fußgängerbereich mit Brunnen/Säule, Weihnachtsmarkt-Event später möglich

### 5.5 Hofgarten
- Quadratischer Park, Mittelpavillon (Diana-Tempel), 8 Wege strahlenförmig, Arkaden an 2 Seiten
- Liegt direkt östlich des Odeonsplatzes, Zugang über die Straße am Platz

### 5.6 Isar / Englischer Garten / Eisbachwelle
- Isar: Flussbett 80–120 Studs breit, Kiesbänke, Brücken NO + S
- Schwabinger Bach: schmal (10–15 Studs), Wiesen, Wege, **kleine Fußgängerbrücke** (begehbar, ~20 Studs lang)
- Monopteros: Rundtempel auf kleinem Hügel (~15 Studs hoch), Wiese außenrum
- **Eisbachwelle:** stehende Welle (animierte Wasserfläche, Surfer-NPCs), **Aussichtsbrücke** darüber mit Zuschauern → Einsatz: Surfer in Not, Wasserrettung
- **P1 (Club):** neben der Brücke, Schlange vor Eingang, Türsteher-NPC, Treffpunkt für Spieler (Social-Hub)

### 5.7 Allianz Arena (Kulisse)
- Als Mesh hinter der Nordgrenze, ~1:3 skaliert, beleuchtete Hülle. Nicht betretbar → spart ~10 % Aufwand.

## 6. Einsatz-Infrastruktur (**zurückgestellt**, nur Ideensammlung)

| Wache | Platz (Studs) | Begründung |
|---|---|---|
| Polizeiinspektion | (−200, −100) | Nähe Leopoldstraße, kurze Wege |
| Feuerwache + Rettungswache | (+200, +150) | zentral, Zugang zur Hauptachse |
| Wasserrettung (Boot) | Isar, (+800, 0) | Eisbachwelle/Isar |
| Krankenhaus | (−450, −300) | NW-Raster |

Einsatztypen pro Ort: Verkehrsunfall (Leopoldstraße), Brandmeldung (Shisha-Bar), Schlägerei (P1/Filmcasino), Wasserrettung (Eisbachwelle), Herzstillstand (Marienplatz), Vermisstensuche (Hofgarten/Englischer Garten).

## 7. Marken & Recht (wichtig)

| Element | Risiko | Plan |
|---|---|---|
| Starbucks | **hoch** (Marke + Logo; Roblox-Takedown/Marken-Meldung wahrscheinlich, grob **50–70 %** bei 1:1-Nachbau) | Platzhalter: **„Kaffeehaus Odeon"**. Kein Logo, keine Sirene, kein typisches Becher-Design. Stattdessen eigenes Logo (z. B. Kaffeebohne). |
| P1 | mittel (realer Clubname) | Platzhalter: **„Prinz Eins"**. Gleiche Lage (an der Eisbachbrücke), eigene Fassade/Schrift. |
| Filmcasino | niedrig–mittel (realer Name) | Platzhalter: **„Casino Odeon"**. Club am Odeonsplatz, eigener Schriftzug. |
| Allianz (Arena) | mittel (Namensrecht Sponsor) | Platzhalter: **„München Arena"**. Hülle als Form, kein Allianz-Schriftzug. |
| Frauenkirche, Siegestor, Feldherrnhalle | niedrig (Gebäude, Außenansicht) | originalgetreu bauen ok |
| Shops/Bars Leopoldstraße | – | nur erfundene Namen (dein Wunsch ✔) |

Zahlen sind Schätzungen, keine Rechtsberatung. Nur dann prüfen lassen, wenn monetarisiert wird (Game-Pässe, Robux).

## 8. Technik (Roblox)

- **PC zuerst**, Mobile zweitrangig. Performance ist **vorerst kein Ziel**; Optimierung folgt nach dem Bau.
- **StreamingEnabled** trotzdem früh an lassen (spart später Umbau bei 1900 × 1050 Studs mit Detail).
- **Tag/Nacht 60/40:** Zyklus z. B. **20 min** = **12 min Tag** (`ClockTime` 6 → 18, 1 Spielstunde/min) + **8 min Nacht** (18 → 6, 1,5 Spielstunden/min). Dämmerung liegt innerhalb dieser Zeiten. Zyklusdauer ist ein Wert in einem Script, später leicht änderbar.
- Nachts an: Straßenlaternen, Lichterketten Terrassen-Café, Club-Neon (Prinz Eins, Casino Odeon), Schaufenster, Fahrzeuglichter, beleuchtete München Arena.
- Landmarks als **MeshParts** (Blender), Rest modulare Häuserteile (Tiling).
- Fassaden-Bausatz: 6–8 Haustypen (Gründerzeit, Neoklassik, Moderne) × 3 Farbvarianten → Straßen wirken verschieden mit ~25 % der Arbeit.
- Collision: Fassaden `CanCollide` nur auf EG-Höhe, Rest `CanQuery=false`.

## 9. Bauphasen (Aufwandsverteilung, Schätzung)

| Phase | Inhalt | Aufwand |
|---|---|---|
| 0 | Plan fixieren (Fragen unten), Maßstab testen mit Fahrzeug | 5 % |
| 1 | Terrain, Isar, Bach, Hauptstraßen, Mapgrenze | 20 % |
| 2 | Landmarks: Siegestor, Frauenkirche, Feldherrnhalle | 20 % |
| 3 | Leopoldstraße-Ladenzeile + Univiertel-Café | 20 % |
| 4 | Parks: Hofgarten, Englischer Garten, Eisbachwelle, P1 | 15 % |
| 5 | (zurückgestellt) Wachen, Fahrzeuge, Einsatz-Skripte | 15 % |
| 6 | Beleuchtung/Tageszeit, Audio, Polish, Test | 5 % |

## 10. Offene Fragen

Alle Fragen aus v0.1 sind beantwortet (siehe Abschnitt 0). Noch offen:

1. Sind die Platzhalter-Namen (Kaffeehaus Odeon, Prinz Eins, Casino Odeon, München Arena) ok oder willst du eigene?
2. Zyklusdauer 20 min (12 Tag / 8 Nacht) ok, oder kürzer/länger?
3. Maßstab (1 px = 1,5 Studs) mit einem Test-Fahrzeug im Studio prüfen, bevor Phase 1 startet.
4. Nächster Schritt: Phase 1 (Terrain, Isar, Hauptstraßen) im Detail planen?
