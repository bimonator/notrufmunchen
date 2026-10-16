-- Blocks.lua
-- Häuserblöcke (Kartenkoordinaten in Studs, Ursprung = Siegestor, x = Ost, z = Süd).
-- Außenkante = Straßenrand (Raster-Straßen 57 breit: V1 x=-460, V2 x=-235, H1 z=-285, H2 z=30; Ring 48 breit; Achse 110 breit).
-- reserved = Flächen der Sonderbauten (Specials.lua): dort entfallen Blockrand-Häuser.

local Config = require(script and script.Parent.Config or "Config")
local T = Config.tankstelle

return {
	{ name = "A_NordWest", xmin = -637, zmin = -448, xmax = -488.5, zmax = -313.5 },
	{ name = "B_NordMitte", xmin = -431.5, zmin = -448, xmax = -263.5, zmax = -313.5, noInner = true }, -- Innenhof ist der Hinterhofpark
	{ name = "C_LeopoldWestNord", xmin = -206.5, zmin = -448, xmax = -55, zmax = -313.5, reserved = { { -127, -385, -55, -315 } }, shopSide = "E" },
	{ name = "D_West", xmin = -637, zmin = -256.5, xmax = -488.5, zmax = 1.5, reserved = { { -599, -163, -527, -91 } } }, -- Hochhaus-West
	{ name = "E_Mitte", xmin = -431.5, zmin = -256.5, xmax = -263.5, zmax = 1.5, reserved = { { -429.5, -200, -265.5, -100 } } },
	{ name = "F_LeopoldWestSued", xmin = -206.5, zmin = -256.5, xmax = -55, zmax = 1.5, reserved = { { -205, -250, -109, -140 }, { -125, -90, -55, 2 } }, shopSide = "E" }, -- zweite Fläche: Kreisverkehr um das Siegestor
	{ name = "M_MarienplatzSued", xmin = -632, zmin = 326, xmax = -215, zmax = 386, noInner = true }, -- Häuserzeile am Südrand des Marienplatzes (vorn zum Platz, hinten zum Ring)
	{ name = "G_LeopoldOst", xmin = 55, zmin = -448, xmax = 276, zmax = 4, reserved = { { T.lot[1], T.lot[2], 86, T.lot[4] }, { 55, -90, 125, 6 }, { 70, -448, 130, -388 }, { 138, -448, 190, -394 }, { 229, -448, 276, -400 }, { 128, -48, 192, 6 } }, shopSide = "W", lot = T.lot, avoidInner = { { 190, -400, 234, -108 } } }, -- Lücke in der Häuserzeile: Tankstelle liegt frei an der Straße, lot = ihr Grundstück
}
