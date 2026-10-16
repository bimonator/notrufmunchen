# Orthografische Ansicht von Landmarks-Teilen (Rotation Roblox: yaw(Y) * Rx(pitch) * Rz(roll)); Zylinder-Achse = lokal x
import sys, math, os
import numpy as np
from lupa import lua51
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(HERE, ".."))  # Repo-Ordner roblox/ (hier liegt MapBuilder/)
S = os.path.join(HERE, "out") + os.sep  # Ausgabeordner für Bilder
os.makedirs(S, exist_ok=True)
def rot(yaw, pitch, roll):
    y, p, r = map(math.radians, (yaw, pitch, roll))
    Ry = np.array([[math.cos(y),0,math.sin(y)],[0,1,0],[-math.sin(y),0,math.cos(y)]])
    Rx = np.array([[1,0,0],[0,math.cos(p),-math.sin(p)],[0,math.sin(p),math.cos(p)]])
    Rz = np.array([[math.cos(r),-math.sin(r),0],[math.sin(r),math.cos(r),0],[0,0,1]])
    return Ry @ Rx @ Rz
def hull(pts):
    pts = sorted(set(map(tuple, pts)))
    if len(pts) <= 2: return pts
    def cross(o,a,b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lo=[]; 
    for p in pts:
        while len(lo)>=2 and cross(lo[-2],lo[-1],p)<=0: lo.pop()
        lo.append(p)
    up=[]
    for p in reversed(pts):
        while len(up)>=2 and cross(up[-2],up[-1],p)<=0: up.pop()
        up.append(p)
    return lo[:-1]+up[:-1]
def verts(p):
    sx, sy, sz = p["size"]; R = rot(p["yaw"], p["pitch"], p["roll"]); c = np.array(p["pos"])
    out = []
    if p["shape"] == "Ball":
        d = max(sx, sy, sz)/2
        for a in np.linspace(0, 2*math.pi, 16, endpoint=False):
            for b in np.linspace(0, math.pi, 7):
                out.append(c + d*np.array([math.cos(b), math.sin(b)*math.cos(a), math.sin(b)*math.sin(a)]))
    elif p["shape"] == "Cylinder":
        for e in (-sx/2, sx/2):
            for a in np.linspace(0, 2*math.pi, 16, endpoint=False):
                out.append(c + R @ np.array([e, sy/2*math.cos(a), sz/2*math.sin(a)]))
    else:
        for ix in (-1,1):
            for iy in (-1,1):
                for iz in (-1,1):
                    out.append(c + R @ np.array([ix*sx/2, iy*sy/2, iz*sz/2]))
    return out
def render(parts, view, path, scale, box, size=None):
    # view: "S" (von Süden, x horizontal), "W" (von Westen, z horizontal), "T" (Draufsicht)
    x0, y0, x1, y1 = box
    W, H = int((x1-x0)*scale), int((y1-y0)*scale)
    im = Image.new("RGB", (W, H), (178, 206, 236)); d = ImageDraw.Draw(im)
    def proj(v):
        if view == "S": u, w, dep = v[0], v[1], -v[2]
        elif view == "W": u, w, dep = v[2], v[1], v[0]
        elif view == "E": u, w, dep = -v[2], v[1], -v[0]
        else: u, w, dep = v[0], v[2], v[1]
        return u, w, dep
    items = []
    for p in parts:
        vs = [proj(v) for v in verts(p)]
        dep = sum(v[2] for v in vs)/len(vs)
        items.append((dep, p, [(v[0], v[1]) for v in vs]))
    items.sort(key=lambda t: t[0], reverse=True) if view != "T" else items.sort(key=lambda t: t[1]["pos"][1])
    for dep, p, pts in items:
        h = hull(pts)
        if len(h) < 3: continue
        poly = [((u-x0)*scale, (y1-w)*scale if view != "T" else (w-y0)*scale) for u, w in h]
        col = tuple(int(c) for c in p["color"])
        if p.get("transparency") and p["transparency"] > 0.3: col = tuple((c+200)//2 for c in col)
        d.polygon(poly, fill=col, outline=(0,0,0))
    im.save(S + path)
def load(fn):
    L = lua51.LuaRuntime(); L.execute('package.path = "MapBuilder/?.lua;" .. package.path')
    t = L.execute('local C=require("Config"); local M=require("Landmarks"); return M.%s(C)' % fn)
    parts = []
    for p in t.values():
        parts.append({"name": p["name"], "size": [p["size"][i] for i in (1,2,3)], "pos": [p["pos"][i] for i in (1,2,3)], "yaw": p["yaw"] or 0, "pitch": p["pitch"] or 0,
                      "roll": p["roll"] or 0, "color": [p["color"][i] for i in (1,2,3)], "shape": p["shape"], "transparency": p["transparency"]})
    return parts
if __name__ == "__main__":
    fn = sys.argv[1]; view = sys.argv[2]; out = sys.argv[3]
    box = tuple(float(v) for v in sys.argv[4:8]); scale = float(sys.argv[8])
    parts = load(fn)
    if len(sys.argv) > 9:
        key = sys.argv[9]; parts = [p for p in parts if key in p["name"]] if not key.startswith("!") else [p for p in parts if key[1:] not in p["name"]]
    render(parts, view, out, scale, box)
