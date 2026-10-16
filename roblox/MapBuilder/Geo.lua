-- Geo.lua
-- Kleine 2D-Geometrie in der Draufsicht (x = Ost, z = Süd). Reine Mathematik, keine Roblox-Funktionen.

local Geo = {}

function Geo.round3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

-- Einheitsvektor und Länge von a nach b
function Geo.dir(ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local l = math.sqrt(dx * dx + dz * dz)
	return dx / l, dz / l, l
end

-- Drehwinkel (Grad) um die Y-Achse, bei dem die lokale x-Achse eines Teils in Richtung (ux, uz) zeigt
function Geo.yawOf(ux, uz)
	return math.deg(math.atan2(-uz, ux)) % 360
end

-- Drehkörper (Kuppel, Turmhelm) als Folge dünner, stehender Scheiben von h = 0 bis H; diam(h) = Durchmesser in der Höhe h.
-- Der Schritt ist so fein, dass sich der Durchmesser zwischen zwei Scheiben um höchstens dd ändert (keine sichtbaren Stufen), in der Höhe um höchstens dhMax.
-- Liefert { { y = Mitte, dick = Dicke (0,3 Überlappung), d = Durchmesser, h0 = Unterkante, h1 = Oberkante }, ... }
function Geo.lathe(H, diam, dd, dhMax)
	local out, h = {}, 0
	while h < H - 1e-6 do
		local step = math.min(dhMax, H - h)
		while step > 0.02 and math.abs(diam(h + step) - diam(h)) > dd do step = step * 0.8 end
		out[#out + 1] = { y = h + step / 2, dick = step + 0.3, d = diam(h + step / 2), h0 = h, h1 = h + step }
		h = h + step
	end
	return out
end

-- Rechteck um eine Strecke a-b mit Halbbreite hw; extA/extB verlängern an den Enden
function Geo.rect(ax, az, bx, bz, hw, extA, extB)
	local ux, uz, l = Geo.dir(ax, az, bx, bz)
	return { ax = ax, az = az, ux = ux, uz = uz, nx = -uz, nz = ux, s0 = -extA, s1 = l + extB, w = hw }
end

-- Abschnitt [t0, t1] der Linie P + u*t (t = 0..L), der im Rechteck r liegt (margin verkleinert das Rechteck). nil, wenn keiner.
function Geo.within(px, pz, ux, uz, L, r, margin)
	margin = margin or 0
	local lo, hi = 0, L
	local function clip(c0, c1, a, b) -- c0 + c1*t muss in [a, b] liegen
		if math.abs(c1) < 1e-9 then return c0 >= a and c0 <= b end
		local t0, t1 = (a - c0) / c1, (b - c0) / c1
		if t0 > t1 then t0, t1 = t1, t0 end
		if t0 > lo then lo = t0 end
		if t1 < hi then hi = t1 end
		return lo < hi
	end
	local dx, dz = px - r.ax, pz - r.az
	if not clip(dx * r.ux + dz * r.uz, ux * r.ux + uz * r.uz, r.s0 + margin, r.s1 - margin) then return nil end
	if not clip(dx * r.nx + dz * r.nz, ux * r.nx + uz * r.nz, -r.w + margin, r.w - margin) then return nil end
	if hi - lo < 1e-6 then return nil end
	return lo, hi
end

-- Abstand des Punkts (x, z) zu einem Linienzug pts = { {x, z}, ... }
function Geo.polyDist(x, z, pts)
	local best = 1e9
	for i = 1, #pts - 1 do
		local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
		local dx, dz = bx - ax, bz - az
		local t = math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
		local px, pz = ax + t * dx - x, az + t * dz - z
		best = math.min(best, math.sqrt(px * px + pz * pz))
	end
	return best
end

-- Überlappen sich zwei Rechtecke (Format von Geo.rect) in der Draufsicht um mehr als 0,5 Studs? (Trennachsen-Test)
function Geo.rectsOverlap(a, b)
	local function corners(r)
		local out = {}
		for _, s in ipairs({ r.s0, r.s1 }) do
			for _, w in ipairs({ -r.w, r.w }) do
				out[#out + 1] = { r.ax + r.ux * s + r.nx * w, r.az + r.uz * s + r.nz * w }
			end
		end
		return out
	end
	local ca, cb = corners(a), corners(b)
	for _, r in ipairs({ a, b }) do
		for _, axis in ipairs({ { r.ux, r.uz }, { r.nx, r.nz } }) do
			local amin, amax, bmin, bmax = 1e18, -1e18, 1e18, -1e18
			for _, c in ipairs(ca) do local d = c[1] * axis[1] + c[2] * axis[2] amin, amax = math.min(amin, d), math.max(amax, d) end
			for _, c in ipairs(cb) do local d = c[1] * axis[1] + c[2] * axis[2] bmin, bmax = math.min(bmin, d), math.max(bmax, d) end
			if amax < bmin + 0.5 or bmax < amin + 0.5 then return false end
		end
	end
	return true
end

-- Aus den Abschnitten spans (Liste {a, b}) die Abschnitte cuts herausschneiden
function Geo.subtract(spans, cuts)
	local out = {}
	for _, s in ipairs(spans) do
		local pieces = { { s[1], s[2] } }
		for _, c in ipairs(cuts) do
			local nxt = {}
			for _, p in ipairs(pieces) do
				if c[2] <= p[1] or c[1] >= p[2] then
					nxt[#nxt + 1] = p
				else
					if c[1] > p[1] then nxt[#nxt + 1] = { p[1], c[1] } end
					if c[2] < p[2] then nxt[#nxt + 1] = { c[2], p[2] } end
				end
			end
			pieces = nxt
		end
		for _, p in ipairs(pieces) do out[#out + 1] = p end
	end
	return out
end

-- Liegt der Punkt (px, pz) in der Draufsicht innerhalb des Teils? (margin verkleinert)
function Geo.inPart(px, pz, p, margin)
	margin = margin or 0
	local r = math.rad(p.yaw)
	local c, s = math.cos(r), math.sin(r)
	local dx, dz = px - p.pos[1], pz - p.pos[3]
	local lx, lz = dx * c - dz * s, dx * s + dz * c -- Umkehrung der Drehung
	return math.abs(lx) <= p.size[1] / 2 - margin and math.abs(lz) <= p.size[3] / 2 - margin
end

return Geo
