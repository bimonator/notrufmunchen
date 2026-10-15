# Notruf München – Systemplan v0.1

Spielsystem nach dem Vorbild von Notruf-Hamburg-artigen Roblox-Spielen: Teams, Notrufe, Überfälle, Festnahmen.
Alle Zahlen sind **Startwerte** zum Nachjustieren, nicht getestet.
Die Karte steht in `docs/MAP_PLAN.md` und `docs/phase1_bauplan.html`.

## 0. Entscheidungen und Annahmen

| Thema | Stand |
|---|---|
| Teams | Zivilist, Polizei, Rettungsdienst, Kriminelle. Feuerwehr später. |
| Server | **Ein Server für alles.** Chill-Spots (Schutzzonen) und Loot-Spots (Überfallorte) liegen auf derselben Karte (Abschnitt 1a). |
| Schmuggelware | **Beschlossen:** neutrale Schmuggelware (Kisten, Pakete) statt Drogen, damit es keine Sperrung gibt. Mechanik bleibt: kaufen, transportieren, am Schwarzmarkt verkaufen. |
| Fahrzeuge | **Aus der Toolbox**, auf ein einheitliches Maß, einen einheitlichen Stil und ein eigenes Logo gebracht (Abschnitt 8). |

## 1. Teams

Annahme: ca. 40 Spieler pro Server, das ergibt ca. 10 Polizei, 6 Rettung, 12 Kriminelle, mindestens 12 Zivilisten. Wer nur chillen will, wird nie zu einem Team gezwungen.

| Team | Aufgabe | Einnahmen | Cap pro Server (Start) |
|---|---|---|---|
| Zivilist | Jobs (Taxi, Lieferung), Chillen | kleine Löhne | ≥ 30 % |
| Polizei | Streife, Notrufe, Festnahme, Verfolgung | Gehalt je Einsatz | ≤ 25 % |
| Rettungsdienst | Notrufe, Erstversorgung, Transport ins Krankenhaus | Gehalt je Einsatz | ≤ 15 % |
| Kriminelle | Überfälle, Schmuggelware | Beute, Verkauf | ≤ 30 % |

## 1a. Chill-Spots und Loot-Spots

| Zonentyp | Orte | Regel |
|---|---|---|
| **Chill-Spot** (Schutzzone) | Biergarten und Monopteros im Englischen Garten, Marienplatz, Café-Terrasse, Prinz Eins, Casino Odeon, Eisbachwelle mit Brücke, Friedensengel (8 Spots) | Kein Überfall, keine Waffen oder Sprengladungen, kein Spielerschaden. Schutz endet für **Gesuchte** (Fahndungs-Timer 90 s nach einem Verbrechen), damit man sich nicht dort verstecken kann. Radius ca. 70 Studs. |
| **Loot-Spot** | Isarbank, Kiosk. Vorschlag: Juwelier an der Leopoldstraße, Club-Kasse im Nachtleben, Geldtransporter auf Ring und Achse | Überfall möglich, Alarm, Cooldown pro Spot. |
| Straßen und übrige Fläche | alles andere | Normale Regeln. |

Die 8 Chill-Spots decken ca. 6 % der Kartenfläche ab (8 × π × 70², gerechnet). Chiller haben ihre Orte, die Loot-Spots liegen in Schwabing im Westen, die Chill-Spots verteilt in Osten und Süden. So laufen sich beide Gruppen selten in die Quere.

## 2. Kernschleifen

**Rettungsdienst:** Notruf kommt → Anfahrt → Patient stabilisieren (Minispiel) → Transport zum Krankenhaus → Auszahlung.
Einsatzarten: Verkehrsunfall, Herzstillstand, Sturz an der Eisbachwelle, **Verletzte nach Überfällen**. So hängen die Teams zusammen.

**Polizei:** Streife → Notruf oder Banksalarm → Anfahrt → Festnahme (Handschellen) → Wache mit Zelle → kurze Haft. Dazu Verkehrskontrolle und Strafzettel.

**Kriminelle:** Kiosk (einfach), Bank (schwer), Schmuggelware kaufen und verkaufen. Beute muss „gewaschen" werden (Abgabepunkt), erst dann gibt es Geld.

**Zivilisten:** Notruf-Telefon im Spiel. Ein Anruf erzeugt einen Einsatz. Gegen Missbrauch: 60 s Sperre zwischen Anrufen, Strafe bei Fehlalarm.

## 3. Banküberfall mit Sprengladung (Isarbank)

| Zeit | Ereignis | Wer sieht es |
|---|---|---|
| t = 0 | Hintertür aufbrechen (Minispiel, ca. 8 s) | Räuber |
| t = 15 s | **Alarm** an die Polizei: Marker auf der Karte | Polizei |
| t ≈ 10–20 s | Sprengladung am Tresor anbringen (ca. 10 s) | Räuber |
| +30 s | **Countdown** läuft, sichtbar und hörbar. Entschärfen durch Polizei in 6 s möglich. | alle |
| t ≈ 45 s | Tresor geht auf | alle |
| +20 s | Beute einsammeln, Beute ist schwer (−30 % Lauftempo) | Räuber |
| danach | Flucht, Fahrzeugwechsel im Parkhaus, Beute am Abgabepunkt waschen | beide |
| nach Ende | Bank **10 min** gesperrt | – |

**Polizei-Anfahrt:** Wache (Südosten, Innenhof mit Schranke) ca. 780 Studs vom Tresor entfernt, dann kommt die Polizei nach ca. 19 s an (Durchschnittstempo ca. 40 Studs/s mit Ampeln und Kurven, Annahme). Das ist knapp vor dem Aufgehen des Tresors: Tension statt „sofort vorbei".

**Kiosk:** 1–2 Spieler, 20 s ohne Sprengung (Kasse aufbrechen), Cooldown 5 min.

## 3a. Wachen und Krankenhaus

Standorte, Grundrisse und Maße stehen in `docs/phase1_bauplan.html` (Abschnitt „Wachen und Krankenhaus").

- **Polizeiwache** (klein, modern): Empfang mit Job-Terminal, Umkleide mit Spind, Rollenspiel-Räume, Zellen, Innenhof mit 8 Spawnplätzen und Schranke zum Ring.
- **Feuer- und Rettungswache** im Schwabing-Raster: 8 Tore, vorne 4 Feuerwehr (Straße V1), hinten 4 Rettungsdienst (Straße V2), Job-Terminal, Spinde, Aufenthalt, Einsatzleitung.
- **Krankenhaus** (nur Rollenspiel): Notaufnahme, Schockraum, OP, 4 Krankenzimmer mit Betten.
- **Rettungseinsatz:** Standard ist Wiederbelebung vor Ort (ca. 10–15 s). Der Transport ins Krankenhaus ist freiwillig (Rollenspiel) und gibt einen kleinen Bonus.
- **Job-Ablauf:** Wache betreten, am Job-Terminal bewerben, am Spind Uniform und Ausrüstung holen, Fahrzeug spawnen.

## 3b. Wiederbelebung mit Infusion

Der Sanitäter hält die Infusion in der Hand (Beutel als Werkzeug, Fortschrittsring) und legt sie am Patienten an (Taste gedrückt halten).

| Item | Heilung | Zeit bis der Patient aufsteht | Vorrat im Rettungswagen |
|---|---|---|---|
| Kochsalzlösung | 3 HP/s, bis max. 60 HP | ca. 10 s (aufstehen ab 30 HP) | 6 |
| **Blutinfusion** (stärker) | 8 HP/s, bis 100 HP | ca. 4 s | 2 |

- Startwerte: Patient ist bei 0 HP „down", Verblutungs-Timer 120 s. Blut ist knapp und für Schwerverletzte gedacht.
- Nachfüllen an der Wache oder im Krankenhaus, mit kurzer Sperre (30 s), damit nicht dauernd nachgefüllt wird.
- Die Infusion ersetzt das Minispiel aus Abschnitt 2. Das spart Aufwand und passt zum Rollenspiel.

## 3c. Tankstelle und Tanken

- Tank voll = ca. 15 min Fahrt (Annahme), Anzeige im HUD.
- Tanken: 8–10 s halten an der Zapfsäule, Preis ca. 0,2 E (ca. 3 % des Verdienstes in 15 min Rettungsdienst).
- Leerer Tank: Auto rollt aus, ein Zivilist mit Abschleppdienst-Job kann mit dem Kanister helfen.
- Einsatzfahrzeuge tanken kostenlos an eigener Zapfsäule im Wachen-Hof (kein Umweg im Einsatz).
- Tankstelle: langer Schirm mit 8 Zapfsäulen an der Leopoldstraße. Anspielung auf die bekannte Tankstelle dort, aber **erfundener Name** (nicht den echten Markennamen verwenden). Ihr Shop kann als weiteres Loot-Ziel dienen und nachts als Treffpunkt.

## 4. Schmuggelware und Schwarzmarkt

- Händler-NPC an einem versteckten Ort (später festlegen) verkauft Sprengladungen und Werkzeug.
- Dort verkaufen Spieler auch Schmuggelware.
- Preise: Sprengladung 2 E (siehe Wirtschaft). Waren haben Verfall oder Gewicht, damit nicht ewig gehortet wird.

## 5. Notruf-System (Dispatch)

- Zentrale Einsatzliste auf dem Server: Typ, Ort, Priorität, Team, Alter.
- Einsatz erscheint als Marker bei den passenden Spielern. Der erste, der annimmt, bekommt ihn. Nach 60 s ohne Annahme geht er an alle.
- Banksalarm, Überfall und Zivilisten-Anrufe erzeugen Einsätze.
- **Ampel-Vorrangschaltung** für Einsatzfahrzeuge mit Sirene (siehe Phase-1-Plan).

## 6. Wirtschaft (Startwerte)

Einheit **E** = Auszahlung eines Rettungseinsatzes (ca. 2 min Aufwand).

| Quelle | Dauer | Auszahlung | pro Minute und Spieler |
|---|---|---|---|
| Rettungseinsatz | 2 min | 1 E | 0,5 E |
| Polizeifestnahme | 3 min | 1,5 E | 0,5 E |
| Kiosk (2 Spieler) | 2 min | 3 E gesamt = 1,5 E je Spieler | 0,75 E |
| Bank (4 Spieler) | 6 min | 24 E gesamt = 6 E je Spieler | 1 E, minus Ladung 0,5 E |

Ziel: Erfolgsquote der Bankräuber **60 %**, Verhaftungsquote **40 %**. Dann liegen Kriminelle im Schnitt bei ca. 0,52 E/min, also gleichauf mit Rettung und Polizei (ca. 100–105 %).

- Sprengladung: 2 E pro Stück (wird immer verbraucht).
- **Dynamischer Multiplikator:** Verhältnis Polizisten zu Kriminellen auf dem Server, begrenzt auf 0,5–1,5. Zu wenig Polizei senkt die Beute der Kriminellen. Zu viele Polizisten senken ihr Gehalt.
- Gamepässe nur für Kosmetik und Komfort, keine stärkeren Waffen oder Ladungen (kein Pay-to-win).

## 7. Technik (Skizze)

- Alles Gewinn-relevante läuft auf dem **Server** (Beute, Auszahlungen, Heist-Zustand). Der Client zeigt nur an.
- Heist als Zustandsautomat: Bereit → Eingebrochen → Alarm → Ladung gelegt → Countdown → Tresor offen → Flucht → Cooldown.
- Notruf-Einsätze als Liste auf dem Server, `RemoteEvent` nur für Annehmen und Abschluss.
- Spielstand (Geld, Rang) per `DataStore`.

## 8. Fahrzeuge aus der Toolbox: einheitlich machen

**Warnung zuerst:** Toolbox-Modelle können versteckte Scripts enthalten (Backdoors, die z. B. fremden Code nachladen). Nie ungeprüft ins Spiel übernehmen. Immer alle Scripts löschen und nur ein eigenes Fahr-Script verwenden. Auch Module mit `require(<Asset-ID>)` sind ein Warnzeichen.

**Pipeline pro Fahrzeug**

| Schritt | Was | Wirkung |
|---|---|---|
| 1 | Nur Karosserie auswählen (2–3 Modelle pro Klasse) | einheitliche Auswahl |
| 2 | Alle Scripts löschen | Sicherheit |
| 3 | Auf Zielmaß skalieren | passt auf Spur, Parkbucht, Tunnel |
| 4 | Einheitlicher Stil: feste Lackpalette (z. B. 6 Farben), gleiche Scheinwerfer-/Felgen-Optik, eigene Behörden-Lackierung | wirkt wie eine Fahrzeugfamilie |
| 5 | Marken-Logos ersetzen (dein X-Logo), Typenschilder und Namen entfernen, Fahrzeuge fiktiv benennen | verhindert Sperrungen |
| 6 | **Ein gemeinsames Fahrwerk** (ein Script, Werte als Attribute: Höchsttempo, Beschleunigung, Bremsen, Lenkung) | Leistung pro Fahrzeug zentral einstellbar |

**Skalieren und Scripts löschen** (Command Bar, Fahrzeuge im Explorer anklicken, mit Strg+Z rückgängig zu machen):

```lua
local TARGET_LENGTH = 14.5 -- Studs, siehe Tabelle unten (Pkw)
for _, m in ipairs(game:GetService("Selection"):Get()) do
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("LuaSourceContainer") then d:Destroy() end -- Scripts weg
    end
    local size = m:GetExtentsSize()
    local length = math.max(size.X, size.Z) -- längste waagerechte Achse = Länge
    m:ScaleTo(m:GetScale() * TARGET_LENGTH / length)
    print(m.Name, m:GetExtentsSize()) -- Kontrolle: Breite/Höhe/Länge
end
```

**Zielmaße (Annahmen)**

| Klasse | Breite × Länge × Höhe | Tempo-Startwert |
|---|---|---|
| Pkw | 7 × 14,5 × 5,5 | 70 Studs/s |
| Streifenwagen | 7 × 14,5 × 5,5 | 77 Studs/s (ca. +10 % gegenüber Pkw) |
| Transporter | 8 × 18 × 8 | 60 Studs/s |
| Geldtransporter | 8 × 18 × 8, schwerer | 55 Studs/s |
| Rettungswagen | 8 × 20 × 9 | 75 Studs/s (Sonderrechte) |
| Feuerwehr, später | 9 × 26 × 11 | 55 Studs/s |

Balance-Gedanke: Die Polizei hat ca. 10 % mehr Spitze, Fluchtautos der Kriminellen dafür bessere Beschleunigung und Lenkung (wendiger). So hat keine Seite einen klaren Vorteil, aber die Verfolgung bleibt spannend.

**Logo-Ersatz:** Dein Plan, bei allen Marken ein eigenes Logo (z. B. ein X) einzusetzen, ist richtig und einfach. Wenn das Logo in die Textur des Meshes eingebacken ist, kannst du es nur mit einem Decal überdecken oder die Textur neu zeichnen. Die Fahrzeugform realer Modelle bleibt ein Restrisiko (ca. nicht null). Wähle lieber allgemeine Formen oder ändere Kühlergrill und Scheinwerfer ab.

**Behörden-Optik:** eigenes Emblem statt echtem Polizei- oder Rettungsdienst-Wappen. Das Wort „POLIZEI" ist ok.

## 9. Reihenfolge (MVP zuerst)

| Stufe | Inhalt |
|---|---|
| v1 | Team-Wahl, Fahrzeuge, Notruf-System, Rettungseinsatz, Polizeifestnahme mit Zelle, Kiosk-Überfall |
| v2 | Banküberfall mit Sprengladung, Fluchtwagenwechsel im Parkhaus, Waschen der Beute |
| v3 | Schwarzmarkt mit Schmuggelware, Ränge, Fahrzeug-Freischaltungen |
| v4 | Events (Christkindlmarkt), Surf-Minispiel, Nachtleben, Feuerwehr |

## 10. Offene Punkte

1. Wachen und Krankenhaus sind platziert (siehe 3a). Bitte prüfen, ob die Standorte passen.
2. Welche Toolbox-Fahrzeuge (2–3 pro Klasse)? Schick mir die Namen, dann prüfe ich die Ziele.
3. Dein X-Logo: soll es für alle Fahrzeuge gleich sein oder gibt es Varianten pro Klasse?
4. Loot-Spots erweitern: Juwelier, Club-Kasse, Geldtransporter ja oder nein?

## 11. Was sonst noch wichtig wäre (Vorschläge)

| Priorität | Feature | Warum |
|---|---|---|
| v1 | Minimap, GPS-Marker zu Einsätzen und Orten | Orientierung auf 1900 × 1050 Studs |
| v1 | Fahrzeug-Garage (Fahrzeuge speichern, spawnen) | Basis für Kauf und Tuning |
| v1 | Tutorial für Neulinge (Team wählen, Job-Terminal) | Neue Spieler springen sonst ab |
| v1 | Server-seitig Anti-Cheat, Melden von Spielern | Pflicht bei Geld und Überfällen |
| v2 | Autohaus, Werkstatt, Tuning, Abschleppdienst | Geldsenke und Bindung |
| v2 | Wohnungen und Häuser (kaufen oder mieten) | Fortschritt, eigene Garage |
| v2 | Handy (Notruf, Navigation, Kontakte) | Rollenspiel und Notrufe |
| v2 | Strafzettel und Blitzer (Polizei) | mehr Alltagsaufgaben für die Polizei |
| v3 | U-Bahn als Schnellreise, Taxi, Lieferjobs | Zivilisten-Beschäftigung |
| v3 | Wetter, Radio im Auto, Emotes | Atmosphäre |
| v3 | Events (Christkindlmarkt, Sommer an der Isar) | Wiederkehr |
