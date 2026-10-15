-- Specials.lua
-- Sonderbauten als Platzhalter-Gebäude (richtige Grundfläche, Farbe nach Art). Details und Innenräume kommen später.
-- facing = Seite zur Straße. Koordinaten wie in docs/phase1_bauplan.html.

return {
	{ name = "Isarbank", x0 = -127, z0 = -385, x1 = -55, z1 = -315, facing = "E", floors = 4, color = { 176, 120, 100 } },
	{ name = "Parkhaus", x0 = -205, z0 = -250, x1 = -109, z1 = -140, facing = "N", floors = 4, color = { 170, 170, 176 } },
	{ name = "Tankstellen-Shop", x0 = 112, z0 = -280, x1 = 164, z1 = -210, facing = "W", floors = 1, color = { 245, 245, 245 }, canopy = { 68, -292, 102, -196 } },
	{ name = "Feuer-und-Rettungswache", x0 = -425, z0 = -200, x1 = -275, z1 = -100, facing = "W", floors = 3, color = { 200, 70, 55 } },
	{ name = "Polizeiwache", x0 = 215, z0 = 310, x1 = 295, z1 = 380, facing = "S", floors = 3, color = { 70, 110, 200 } },
	{ name = "Krankenhaus", x0 = 340, z0 = -430, x1 = 500, z1 = -310, facing = "W", floors = 5, color = { 90, 170, 150 } },
	{ name = "Kiosk", x0 = -350, z0 = 66, x1 = -300, z1 = 106, facing = "N", floors = 1, color = { 200, 70, 55 } },
	{ name = "Cafe-Terrasse", x0 = -130, z0 = 64, x1 = -66, z1 = 116, facing = "E", floors = 2, color = { 226, 190, 120 } },
	{ name = "Uni-Fassade", x0 = -160, z0 = 130, x1 = -60, z1 = 220, facing = "E", floors = 4, color = { 214, 204, 176 } },
	{ name = "Casino-Odeon", x0 = -200, z0 = 316, x1 = -144, z1 = 360, facing = "E", floors = 2, color = { 70, 56, 84 } },
	{ name = "Kaffeehaus", x0 = 144, z0 = 300, x1 = 194, z1 = 340, facing = "W", floors = 2, color = { 100, 150, 100 } },
	{ name = "Prinz-Eins", x0 = 560, z0 = 330, x1 = 616, z1 = 370, facing = "S", floors = 2, color = { 52, 44, 76 } },
}
