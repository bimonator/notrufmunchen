# Notruf München – Map-Plan v0.1

Roblox-Einsatzspiel (Polizei / Feuerwehr / Rettungsdienst) in München, Vorbild-Prinzip: Notruf Hamburg.
Grundlage: `docs/map_sketch.png` (Paint-Skizze). Alle Koordinaten unten sind aus der Skizze abgeleitet.

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
| Hofgarten (grüner Kasten, Pavillon in der Mitte) | oben rechts | (+420, −312) | Park, 8 Wege strahlenförmig |
| Isar (breites Blau) | rechts, NO→SW | X≈+700…+1100 | Fluss, Hauptwasser |
| Schwabinger Bach (dünnes Blau) | links neben der Isar | X≈+650…+700 | Bach im Englischen Garten |
| Englischer Garten (grün gepunktet) | rechts Mitte | (+450…+720, +0…+300) | Park |
| Eisbachwelle + Brücke + P1 | Brücke unten rechts | (+650, +404) | Surfer-Spot, Aussichtsbrücke, Club |
| Allianz Arena | oben links, außerhalb | (−265, −632) | **nur Kulisse** hinter der Mapgrenze |
| Außenring-Straße + Häuserwand | Rahmen | Kartenrand | Mapgrenze |

**Offen (bitte bestätigen):** Die braun-graue Form im Englischen Garten (≈ (+590, +120)) – Hügel/Monopteros, Wiese oder etwas anderes?

## 3. Geografie-Check (Skizze vs. Realität)

| Punkt | Realität | Skizze | Empfehlung |
|---|---|---|---|
| Siegestor → Odeonsplatz | ~1 km, Ludwigstraße mit Uni | ~700 Studs, passt grob | so lassen |
| Marienplatz relativ zu Odeonsplatz | **südlich** davon (~0,6 km) | **nördlich** (Z +254 vs. +460) | Kompromiss: Marienplatz an die SW-Ecke, Odeonsplatz am Südende der Achse; Spielspaß > Genauigkeit (~90 % der Spieler merken es nicht) |
| Hofgarten | direkt **neben dem Odeonsplatz** (Ost) | oben rechts, weit weg | Variante A: wie gezeichnet (mehr Fläche im NO). Variante B: realistisch an den Odeonsplatz (Dichte im Süden steigt) → **Empfehlung B**, weil sonst der NO-Bereich leer wirkt und der Süden zu kahl |
| Eisbachwelle / P1 | SO, an der Prinzregentenstraße, Südende Englischer Garten | unten rechts | passt |
| Allianz Arena | ~8 km nördlich | oben links | Kulisse/Skybox, nicht spielbar |
| Isar | östlich | rechts | passt |

## 4. Straßennetz

- **Achse:** Leopoldstraße/Ludwigstraße, 4 Fahrspuren + Mittelstreifen (Doppellinie in der Skizze), Bäume am Rand.
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
- Einsätze: Verletzte, Vermisste Kinder, Fahrraddiebstahl

### 5.6 Isar / Englischer Garten / Eisbachwelle
- Isar: Flussbett 80–120 Studs breit, Kiesbänke, Brücken NO + S
- Schwabinger Bach: schmal (10–15 Studs), Wiesen, Wege
- **Eisbachwelle:** stehende Welle (animierte Wasserfläche, Surfer-NPCs), **Aussichtsbrücke** darüber mit Zuschauern → Einsatz: Surfer in Not, Wasserrettung
- **P1 (Club):** neben der Brücke, Schlange vor Eingang, Türsteher-NPC, Treffpunkt für Spieler (Social-Hub)

### 5.7 Allianz Arena (Kulisse)
- Als Mesh hinter der Nordgrenze, ~1:3 skaliert, beleuchtete Hülle. Nicht betretbar → spart ~10 % Aufwand.

## 6. Einsatz-Infrastruktur (Vorschlag – nicht in der Skizze)

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
| Starbucks | **hoch** (Marke + Logo; Roblox-Takedown/Marken-Meldung wahrscheinlich, grob **50–70 %** bei 1:1-Nachbau) | Generische Kaffeekette „Kaffeehaus Odeon", grüne Schürzen ok, Logo/Name erfunden |
| P1 | mittel (realer Clubname) | Anspielung: „P-Eins" / „Prinz 1" oder eigener Name, ähnliche Lage + Architektur |
| Filmcasino | niedrig–mittel (realer Name) | z. B. „Kino Casino Odeon" oder ganz erfunden |
| Allianz (Arena) | mittel (Namensrecht Sponsor) | „München Arena" / „Fröttmaninger Arena", Hülle nur als Form |
| Frauenkirche, Siegestor, Feldherrnhalle | niedrig (Gebäude, Außenansicht) | originalgetreu bauen ok |
| Shops/Bars Leopoldstraße | – | nur erfundene Namen (dein Wunsch ✔) |

Zahlen sind Schätzungen, keine Rechtsberatung. Nur dann prüfen lassen, wenn monetarisiert wird (Game-Pässe, Robux).

## 8. Technik (Roblox)

- **StreamingEnabled** an (Pflicht bei 1900 × 1050 Studs mit Detail).
- Performance-Ziel: **< 80k Parts** im Streaming-Radius (grobe Schätzung für stabile 60 FPS auf Mittelklasse-Handys; Messung nötig).
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
| 5 | Wachen, Fahrzeuge, Einsatz-Skripte | 15 % |
| 6 | Beleuchtung/Tageszeit, Audio, Polish, Test | 5 % |

## 10. Offene Fragen

1. Braun-graue Form im Englischen Garten: was ist das?
2. Hofgarten: Variante A (wie gezeichnet) oder B (am Odeonsplatz)?
3. Marienplatz-Position: Skizze lassen oder Odeonsplatz/Marienplatz tauschen?
4. Zeitraum: nur Tag, oder Tag/Nacht-Zyklus (für Cocktail-Café-Vibe nötig)?
5. Spielmodi: Polizei + Feuerwehr + Rettungsdienst, oder nur eine Fraktion zuerst?
6. Namen für Starbucks-/P1-/Filmcasino-Ersatz?
