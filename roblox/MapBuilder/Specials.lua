-- Specials.lua
-- Sonderbauten als Platzhalter-Gebäude (richtige Grundfläche, Farbe nach Art). Details und Innenräume kommen später.
-- facing = Seite zur Straße. Koordinaten wie in docs/phase1_bauplan.html.

return {
	{ name = "Isarbank", x0 = -127, z0 = -385, x1 = -55, z1 = -315, facing = "E", floors = 4, color = { 176, 120, 100 } },
	{ name = "Parkhaus", x0 = -205, z0 = -250, x1 = -109, z1 = -140, facing = "N", floors = 4, color = { 170, 170, 176 } },
	{ name = "Tankstellen-Shop", x0 = 78, z0 = -200, x1 = 146, z1 = -166, facing = "W", floors = 1, color = { 250, 250, 250 }, style = "tankstelle", canopy = { 78, -296, 146, -200 }, lot = { 57, -312, 180, -162 }, curbGaps = { { -312, -280 }, { -232, -200 } } },
	{ name = "Tankstellen-Buero-Nord", x0 = 190, z0 = -400, x1 = 234, z1 = -318, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Tankstellen-Buero-Mitte", x0 = 190, z0 = -302, x1 = 234, z1 = -210, facing = "W", floors = 6, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Tankstellen-Buero-Sued", x0 = 190, z0 = -194, x1 = 234, z1 = -108, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Feuer-und-Rettungswache", x0 = -429.5, z0 = -200, x1 = -265.5, z1 = -100, facing = "W", floors = 4, color = { 200, 70, 55 }, style = "feuerwache" },
	{ name = "Polizeiwache", x0 = 202, z0 = 340, x1 = 342, z1 = 384, facing = "S", floors = 5, color = { 70, 110, 200 }, style = "polizei", compound = "polizei" },
	{ name = "Polizei-Seitenfluegel", x0 = 202, z0 = 298, x1 = 218, z1 = 340, facing = "E", floors = 3, color = { 92, 94, 104 } },
	{ name = "Krankenhaus", x0 = 340, z0 = -430, x1 = 500, z1 = -310, facing = "W", floors = 5, color = { 90, 170, 150 }, style = "klinik" },
	{ name = "Kiosk", x0 = -350, z0 = 66, x1 = -300, z1 = 106, facing = "N", floors = 1, color = { 200, 70, 55 } },
	{ name = "Cafe-Terrasse", x0 = -130, z0 = 64, x1 = -66, z1 = 116, facing = "E", floors = 2, color = { 226, 190, 120 } },
	{ name = "Uni-Fassade", x0 = -160, z0 = 130, x1 = -60, z1 = 220, facing = "E", floors = 4, color = { 214, 204, 176 } },
	{ name = "Casino-Odeon", x0 = -200, z0 = 316, x1 = -144, z1 = 360, facing = "E", floors = 2, color = { 70, 56, 84 } },
	{ name = "Kaffeehaus", x0 = 144, z0 = 300, x1 = 194, z1 = 340, facing = "W", floors = 2, color = { 100, 150, 100 } },
	{ name = "Prinz-Eins", x0 = 546, z0 = 330, x1 = 602, z1 = 370, facing = "S", floors = 2, color = { 52, 44, 76 } },
}
