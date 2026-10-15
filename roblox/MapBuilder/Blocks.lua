-- Blocks.lua
-- Häuserblöcke im Schwabing-Raster (Kartenkoordinaten in Studs, Ursprung = Siegestor, x = Ost, z = Süd).
-- Außenkante = Straßenrand (Straße 57 breit, Mittellinien V1 x=-460, V2 x=-235, H1 z=-285, H2 z=30; Ring 48 breit).
-- Bank, Parkhaus, Feuerwache und die Leopoldstraße-Ladenzeile sind hier absichtlich NICHT enthalten.

return {
	{ name = "A_NordWest", xmin = -637, zmin = -448, xmax = -488.5, zmax = -313.5 }, -- Supermarkt kommt später in den Innenhof
	{ name = "B_NordMitte", xmin = -431.5, zmin = -448, xmax = -263.5, zmax = -313.5 }, -- Innenhof wird der Hinterhofpark
	{ name = "D_West", xmin = -637, zmin = -256.5, xmax = -488.5, zmax = 1.5 }, -- Wohnhäuser
}
