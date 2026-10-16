import os, math, sys
from lupa import lua51
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(HERE, ".."))  # Repo-Ordner roblox/ (hier liegt MapBuilder/)
S = os.path.join(HERE, "out") + os.sep
os.makedirs(S, exist_ok=True)
L = lua51.LuaRuntime(); L.execute('package.path = "MapBuilder/?.lua;" .. package.path')
data = L.execute('''
local C, R, Sp, B = require("Config"), require("RoadsPlanner"), require("Specials"), require("Blocks")
local road = R.plan(C)
local out = {roads={}, specials={}, blocks={}}
for _, p in ipairs(road.parts) do if p.kind=="road" or p.kind=="plaza" or p.kind=="walk" then out.roads[#out.roads+1] = {p.pos[1], p.pos[3], p.size[1], p.size[3], p.yaw, p.kind} end end
for _, s in ipairs(Sp) do out.specials[#out.specials+1] = {s.x0, s.z0, s.x1, s.z1, s.name} end
for _, b in ipairs(B) do out.blocks[#out.blocks+1] = {b.xmin, b.zmin, b.xmax, b.zmax} end
return out
''')
def tl(t): return list(t.values())
roads=[tl(r) for r in data.roads.values()]; specials=[tl(r) for r in data.specials.values()]; blocks=[tl(r) for r in data.blocks.values()]
def render(x0,z0,x1,z1,Sc,name,extra=None):
    im=Image.new("RGB",(int((x1-x0)*Sc),int((z1-z0)*Sc)),(150,176,140)); d=ImageDraw.Draw(im)
    def poly(pts,hw,col):
        for i in range(len(pts)-1):
            ax,az=pts[i];bx,bz=pts[i+1]
            dx,dz=bx-ax,bz-az;l=math.hypot(dx,dz);nx,nz=-dz/l*hw,dx/l*hw
            d.polygon([((ax+nx-x0)*Sc,(az+nz-z0)*Sc),((ax-nx-x0)*Sc,(az-nz-z0)*Sc),((bx-nx-x0)*Sc,(bz-nz-z0)*Sc),((bx+nx-x0)*Sc,(bz+nz-z0)*Sc)],fill=col)
    isar=[(945,-556),(945,-472),(930,-330),(915,-200),(895,-90),(885,0),(850,100),(800,200),(750,300),(705,390),(695,410),(670,494)]
    bach=[(640,-257),(642,-226),(665,-31),(672,194),(650,330),(620,410),(612,494)]
    poly(isar,90,(124,156,104));poly(isar,60,(214,200,152));poly(isar,36,(70,120,190))
    poly(bach,13,(214,200,152));poly(bach,7,(70,120,190))
    # parks
    for nm,(a,b,c,e) in {"Hofgarten":(60,100,400,290),"Englischer Garten":(430,-45,700,345)}.items():
        d.rectangle([(a-x0)*Sc,(b-z0)*Sc,(c-x0)*Sc,(e-z0)*Sc],outline=(60,120,60),width=2)
    for r in roads:
        x,z,sx,sz,yaw,k=r
        a=math.radians(yaw);c,s=math.cos(a),math.sin(a)
        pts=[((x+lx*c+lz*s-x0)*Sc,(z-lx*s+lz*c-z0)*Sc) for lx,lz in [(-sx/2,-sz/2),(sx/2,-sz/2),(sx/2,sz/2),(-sx/2,sz/2)]]
        d.polygon(pts,fill=(84,86,94) if k=="road" else ((196,186,164) if k=="plaza" else (176,176,178)))
    for b in blocks: d.rectangle([(b[0]-x0)*Sc,(b[1]-z0)*Sc,(b[2]-x0)*Sc,(b[3]-z0)*Sc],fill=(176,150,132))
    for s in specials: d.rectangle([(s[0]-x0)*Sc,(s[1]-z0)*Sc,(s[2]-x0)*Sc,(s[3]-z0)*Sc],fill=(150,110,100),outline=(90,60,50))
    d.rectangle([(890-x0)*Sc,(250-z0)*Sc,(1040-x0)*Sc,(346-z0)*Sc],outline=(230,200,60),width=2)
    if extra: extra(d,x0,z0,Sc)
    im.save(S+name); return im
if __name__=="__main__":
    render(-745,-556,1160,494,0.55,"overview.png")
