# Notruf München – Systemplan v0.1

Spielsystem nach dem Vorbild von Notruf-Hamburg-artigen Roblox-Spielen: Teams, Notrufe, Überfälle, Festnahmen.
Alle Zahlen sind **Startwerte** zum Nachjustieren, nicht getestet.
Die Karte steht in `docs/MAP_PLAN.md` und `docs/phase1_bauplan.html`.

## 0. Entscheidungen und Annahmen

| Thema | Stand |
|---|---|
| Teams | Zivilist, Polizei, Rettungsdienst, Kriminelle. Feuerwehr später. |
| Server-Typen | Chill (kein Crime) und Action (alle Teams). **Noch offen: getrennt oder alles auf einem Server?** Empfehlung getrennt. |
| Drogen | **Nicht als Drogen darstellen** (Roblox-Richtlinien, bitte aktuell prüfen). Stattdessen neutrale „Schmuggelware" (Kisten, Pakete). Spielmechanik bleibt gleich: kaufen, transportieren, am Schwarzmarkt verkaufen. |
| Fahrzeugmaße | Unbekannt. Siehe Abschnitt 8: erst messen, dann Zielmaße festlegen. |

## 1. Teams

| Team | Aufgabe | Einnahmen | Cap pro Server (Start) |
|---|---|---|---|
| Zivilist | Jobs (Taxi, Lieferung), Chillen | kleine Löhne | Rest |
| Polizei | Streife, Notrufe, Festnahme, Verfolgung | Gehalt je Einsatz | ≤ 30 % |
| Rettungsdienst | Notrufe, Erstversorgung, Transport ins Krankenhaus | Gehalt je Einsatz | ≤ 20 % |
| Kriminelle | Überfälle, Schmuggelware | Beute, Verkauf | ≤ 35 % |

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

**Polizei-Anfahrt:** Wache ca. 900–1100 Studs vom Tresor entfernt, dann kommt die Polizei nach ca. 20–25 s an (Durchschnittstempo ca. 40 Studs/s mit Ampeln und Kurven, Annahme). Das ist knapp vor dem Aufgehen des Tresors: Tension statt „sofort vorbei".

**Kiosk:** 1–2 Spieler, 20 s ohne Sprengung (Kasse aufbrechen), Cooldown 5 min.

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

## 8. Fahrzeugmaße messen und festlegen

Fahrzeug im Explorer anklicken, dann in der Command Bar (View → Command Bar):

```lua
local m = game:GetService("Selection"):Get()[1]
print(m.Name, m:GetExtentsSize()) -- X/Y/Z = Breite, Höhe, Länge (je nach Ausrichtung des Fahrzeugs)
```

**Zielmaße, wenn du eigene oder angepasste Fahrzeuge baust (Annahmen):**

| Klasse | Breite × Länge × Höhe | Passt durch |
|---|---|---|
| Pkw / Streifenwagen | 7 × 14,5 × 5,5 | Spur 14, Parkbucht 9 × 16, Poller-Lücke 20 |
| Transporter / Geldtransporter | 8 × 18 × 8 | Spur 14, Tunnel |
| Rettungswagen | 8 × 20 × 9 | Spur 14, Tunnel |
| Feuerwehr, später | 9 × 26 × 11 (Drehleiter bis 12,5) | Spur 14 (2,5 Luft je Seite), Tunnel 14 |

Wenn deine Fahrzeuge größer sind, sag mir die Zahlen und ich passe Spur, Tunnel und Parkbuchten an.

## 9. Reihenfolge (MVP zuerst)

| Stufe | Inhalt |
|---|---|
| v1 | Team-Wahl, Fahrzeuge, Notruf-System, Rettungseinsatz, Polizeifestnahme mit Zelle, Kiosk-Überfall |
| v2 | Banküberfall mit Sprengladung, Fluchtwagenwechsel im Parkhaus, Waschen der Beute |
| v3 | Schwarzmarkt mit Schmuggelware, Ränge, Fahrzeug-Freischaltungen |
| v4 | Events (Christkindlmarkt), Surf-Minispiel, Nachtleben, Feuerwehr |

## 10. Offene Punkte

1. Chill und Action getrennt oder zusammen?
2. Schmuggelware statt Drogen ok?
3. Welche Fahrzeuge (eigene bauen, Toolbox oder gekauft)? Danach Maße prüfen.
4. Standort Polizeiwache, Rettungswache, Krankenhaus.
