-- Specials.lua
-- Sonderbauten als Platzhalter-Gebäude (richtige Grundfläche, Farbe nach Art). Details und Innenräume kommen später.
-- facing = Seite zur Straße. Koordinaten wie in docs/phase1_bauplan.html.

local Config = require(script and script.Parent.Config or "Config")
local T = Config.tankstelle

return {
	{ name = "Isarbank", x0 = -127, z0 = -385, x1 = -55, z1 = -315, facing = "E", floors = 4, color = { 176, 120, 100 } },
	{ name = "Parkhaus", x0 = -205, z0 = -250, x1 = -109, z1 = -140, facing = "N", floors = 4, color = { 170, 170, 176 } },
	-- Shop liegt am Nordende des Schirms (gegenüber der Einfahrt), Glasfront zur Straße
	{ name = "Tankstellen-Shop", x0 = 78, z0 = -332, x1 = 146, z1 = -298, facing = "W", floors = 1, color = { 250, 250, 250 }, style = "tankstelle", canopy = { 78, -298, 146, -202 }, lot = T.lot, curbGaps = T.gaps, parking = T.parking },
	{ name = "Tankstellen-Buero-Nord", x0 = 190, z0 = -400, x1 = 234, z1 = -318, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Tankstellen-Buero-Mitte", x0 = 190, z0 = -302, x1 = 234, z1 = -210, facing = "W", floors = 6, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Tankstellen-Buero-Sued", x0 = 190, z0 = -194, x1 = 234, z1 = -108, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Feuer-und-Rettungswache", x0 = -429.5, z0 = -200, x1 = -265.5, z1 = -100, facing = "W", floors = 4, color = { 200, 70, 55 }, style = "feuerwache" },
	{ name = "Polizeiwache", x0 = 202, z0 = 340, x1 = 342, z1 = 384, facing = "S", floors = 5, color = { 70, 110, 200 }, style = "polizei", compound = "polizei" },
	{ name = "Polizei-Seitenfluegel", x0 = 202, z0 = 298, x1 = 218, z1 = 340, facing = "E", floors = 3, color = { 92, 94, 104 } },
	{ name = "Krankenhaus", x0 = 340, z0 = -430, x1 = 500, z1 = -310, facing = "W", floors = 5, color = { 90, 170, 150 }, style = "klinik" },
	{ name = "Kiosk", x0 = -420, z0 = 280, x1 = -370, z1 = 320, facing = "N", floors = 1, color = { 200, 70, 55 } }, -- auf dem Marienplatz
	{ name = "Kaffeehaus", x0 = 112, z0 = 300, x1 = 202, z1 = 360, facing = "N", floors = 3, color = { 244, 242, 232 }, style = "kaffee", lots = { { 60, 296, 110, 384 } } },
	{ name = "Prinz-Eins", x0 = 526, z0 = 326, x1 = 610, z1 = 366, facing = "S", floors = 3, color = { 52, 44, 76 }, lots = { { 436, 350, 522, 384 } } },
	{ name = "Klinikum-Parkhaus", x0 = 500, z0 = -430, x1 = 660, z1 = -310, facing = "N", floors = 3, color = { 176, 176, 172 }, style = "parkhaus" }, -- grenzt an das Klinikum (x = 500)
	{ name = "Volksbank", x0 = 330, z0 = -280, x1 = 404, z1 = -210, facing = "W", floors = 3, color = { 236, 238, 240 }, style = "bank" }, -- Lücke an der V3, südlich des Klinikums (erster grober Entwurf)
}
