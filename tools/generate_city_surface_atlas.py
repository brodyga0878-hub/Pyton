#!/usr/bin/env python3
"""Create original four-role PBR city surfaces with a wrapped atlas gutter.

Requires NumPy/Pillow. --check regenerates bytes and validates material data,
periodic padding, four-times vector coverage and safe atlas coordinates.
No borrowed artwork, font, directional illumination or geometry is included.
"""
from __future__ import annotations
import argparse, hashlib, io, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]/"assets/city_surfaces"
RESOLUTION=2048
TILE=1024
GUTTER=16
SIZE=TILE-2*GUTTER
SS=4
ROLES=("facade","road","pad","roof")
CHANNELS=("albedo","normal","orm")
Y,X=np.mgrid[:SIZE,:SIZE].astype(np.float64)/SIZE

# Authored small technical stencil; no font file or system rasterizer.
STENCIL={
 "0":["01110","10001","10011","10101","11001","10001","01110"],
 "1":["00100","01100","00100","00100","00100","00100","01110"],
 "2":["01110","10001","00001","00010","00100","01000","11111"],
 "3":["11110","00001","00001","01110","00001","00001","11110"],
 "4":["00010","00110","01010","10010","11111","00010","00010"],
 "5":["11111","10000","10000","11110","00001","00001","11110"],
 "6":["01110","10000","10000","11110","10001","10001","01110"],
 "7":["11111","00001","00010","00100","01000","01000","01000"],
 "8":["01110","10001","10001","01110","10001","10001","01110"],
 "9":["01110","10001","10001","01111","00001","00001","01110"],
 "Т":["11111","00100","00100","00100","00100","00100","00100"],
 "Е":["11111","10000","10000","11110","10000","10000","11111"],
 "Х":["10001","10001","01010","00100","01010","10001","10001"],
 "С":["01111","10000","10000","10000","10000","10000","01111"],
 "К":["10001","10010","10100","11000","10100","10010","10001"],
 "О":["01110","10001","10001","10001","10001","10001","01110"],
 "Р":["11110","10001","10001","11110","10000","10000","10000"],
 "А":["01110","10001","10001","11111","10001","10001","10001"],
 "П":["11111","10001","10001","10001","10001","10001","10001"],
 "Д":["00110","01010","01010","01010","01010","11111","10001"],
 "В":["11110","10001","10001","11110","10001","10001","11110"],
 "У":["10001","10001","10001","01111","00001","00001","01110"],
 "Л":["00111","01001","01001","01001","01001","01001","10001"],
 "Н":["10001","10001","10001","11111","10001","10001","10001"],
 "И":["10001","10001","10011","10101","11001","10001","10001"],
 "М":["10001","11011","10101","10101","10001","10001","10001"],
 "Ь":["10000","10000","10000","11110","10001","10001","11110"],
 " ":["00000"]*7,"-":["00000","00000","00000","11111","00000","00000","00000"]}

def noise(rng,cells_x,cells_y=None):
 cells_y=cells_y or cells_x
 lattice=rng.uniform(-1,1,(cells_y,cells_x))
 px,py=X*cells_x,Y*cells_y
 ix,iy=np.floor(px).astype(int),np.floor(py).astype(int)
 fx,fy=px-ix,py-iy
 fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
 return ((1-fx)*lattice[iy%cells_y,ix%cells_x]+fx*lattice[iy%cells_y,(ix+1)%cells_x])*(1-fy)+((1-fx)*lattice[(iy+1)%cells_y,ix%cells_x]+fx*lattice[(iy+1)%cells_y,(ix+1)%cells_x])*fy

def mask(points,draw_fn,padding=3):
 """Local high-resolution geometric coverage, downsampled to original pixels."""
 coords=[(x*SIZE,y*SIZE) for x,y in points]
 left=max(0,int(np.floor(min(p[0] for p in coords)-padding)))
 top=max(0,int(np.floor(min(p[1] for p in coords)-padding)))
 right=min(SIZE,int(np.ceil(max(p[0] for p in coords)+padding))+1)
 bottom=min(SIZE,int(np.ceil(max(p[1] for p in coords)+padding))+1)
 result=Image.new("L",(SIZE,SIZE))
 if right<=left or bottom<=top:return np.asarray(result,dtype=np.float64)/255
 high=Image.new("L",((right-left)*SS,(bottom-top)*SS))
 local=[((x-left)*SS,(y-top)*SS) for x,y in coords]
 draw_fn(ImageDraw.Draw(high),local)
 result.paste(high.resize((right-left,bottom-top),Image.Resampling.LANCZOS),(left,top))
 return np.asarray(result,dtype=np.float64)/255

def polygon(points):
 return mask(points,lambda d,p:d.polygon(p,fill=255))

def line(points,width=1.5,closed=False):
 def paint(d,p):d.line(p+[p[0]] if closed else p,fill=255,width=max(1,round(width*SS)),joint="curve")
 return mask(points,paint,padding=width+3)

def rectangle(x0,y0,x1,y1,radius=0):
 def paint(d,p):
  box=[p[0],p[1]]
  if radius:d.rounded_rectangle(box,radius=radius*SS,fill=255)
  else:d.rectangle(box,fill=255)
 return mask([(x0,y0),(x1,y1)],paint,padding=3)

def circle(cx,cy,r):
 return mask([(cx-r,cy-r),(cx+r,cy+r)],lambda d,p:d.ellipse([p[0],p[1]],fill=255))

def stencil(text,cx,cy,scale=2):
 width=(len(text)*6-1)*scale;height=7*scale
 high=Image.new("L",(width*SS,height*SS));d=ImageDraw.Draw(high)
 for index,char in enumerate(text):
  for y,row in enumerate(STENCIL[char]):
   for x,b in enumerate(row):
    if b=="1":d.rectangle(((index*6+x)*scale*SS,y*scale*SS,((index*6+x+1)*scale)*SS-1,(y+1)*scale*SS-1),fill=255)
 image=high.resize((width,height),Image.Resampling.LANCZOS)
 result=Image.new("L",(SIZE,SIZE));result.paste(image,(round(cx*SIZE-width/2),round(cy*SIZE-height/2)))
 return np.asarray(result,dtype=np.float64)/255

def quantize(values):return np.clip(np.rint(values*255),0,255).astype(np.uint8)

def normal_map(height):
 dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*3.0
 dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*3.0
 normal=np.stack((-dx,dy,np.ones_like(height)),axis=-1)
 normal/=np.linalg.norm(normal,axis=-1)[...,None]
 return quantize(normal*.5+.5)

class Surface:
 def __init__(self,rng,base,roughness,metalness=0):
  coarse=noise(rng,9)*.5+noise(rng,31)*.3+noise(rng,103)*.2
  grain=noise(rng,251)
  self.albedo=np.repeat((base+coarse*.018+grain*.006)[...,None],3,axis=2)
  self.height=.5+coarse*.004+grain*.002
  self.rough=np.clip(roughness+coarse*.025+grain*.012,.06,.95)
  self.metal=np.full_like(X,metalness);self.ao=np.full_like(X,.99)
 def apply(self,mask,colour=None,height=None,rough=None,metal=None,ao=None):
  if colour is not None:self.albedo=self.albedo*(1-mask[...,None])+np.asarray(colour)*mask[...,None]
  for key,value in [("height",height),("rough",rough),("metal",metal),("ao",ao)]:
   if value is not None:setattr(self,key,getattr(self,key)*(1-mask)+value*mask)
 def fastener(self,x,y,r=.0045):
  self.apply(circle(x,y,r),(.43,.45,.46),.46,.38,.72,.92)
  self.apply(line([(x-r*.6,y),(x+r*.6,y)],.8),(.29,.31,.32),.43,.63,.1,.84)
 def panel(self,points,colour,rough=.55,metal=.12):
  self.apply(polygon(points),colour,.525,rough,metal)
  self.apply(line(points,2,True),(.48,.50,.51),.40,.68,.04,.87)
  c=np.mean(points,axis=0);inner=[tuple(c+(np.asarray(p)-c)*.976) for p in points]
  self.apply(line(inner,.8,True),(.88,.89,.87),.54,.33,.56,.98)
 def grille(self,x0,y0,x1,y1):
  self.apply(rectangle(x0,y0,x1,y1,3),(.43,.46,.47),.40,.59,.35,.91)
  count=max(3,round((y1-y0)*SIZE/9))
  for y in np.linspace(y0+.008,y1-.008,count):self.apply(line([(x0+.006,y),(x1-.006,y)],2),(.27,.30,.31),.35,.69,.30,.84)
 def maps(self):
  return {"albedo":quantize(self.albedo),"normal":normal_map(self.height),"orm":quantize(np.stack((self.ao,self.rough,self.metal),axis=-1))}

def facade(rng):
 s=Surface(rng,.78,.76)
 # Four floors by four structural bays, with recessed glazing and inter-floor belts.
 for row in range(4):
  for col in range(4):
   x0=col*.25+.012;y0=row*.25+.018;x1=(col+1)*.25-.012;y1=(row+1)*.25-.018
   tone=.72+(.025*((row*3+col*5)%6))
   s.panel([(x0,y0),(x1,y0),(x1,y1),(x0,y1)],(tone,tone*1.006,tone*1.012),.68,.015)
   wx0=x0+.025;wx1=x1-.025;wy0=y0+.025;wy1=y1-.053
   s.apply(rectangle(wx0-.005,wy0-.005,wx1+.005,wy1+.005),(.52,.55,.56),.57,.39,.65,.95)
   shade=.29+((row*7+col*3)%5)*.025
   s.apply(rectangle(wx0,wy0,wx1,wy1),(shade*.95,shade,shade*1.04),.36,.18+col*.025,.58,.88)
   s.apply(line([((wx0+wx1)*.5,wy0),((wx0+wx1)*.5,wy1)],2),(.61,.64,.65),.60,.32,.70)
   # Vertical sill weathering is material wear, not directional illumination.
   s.apply(rectangle(wx0,y1-.032,wx1,y1-.017),(.61,.64,.64),.49,.85,.02)
   for x in [x0+.009,x1-.009]:
    for y in [y0+.009,y1-.009]:s.fastener(x,y,.0035)
 phase=np.mod(Y*4.0,1.0);distance=np.minimum(phase,1.0-phase)
 belt=np.clip((.014-distance)*SIZE/4.0,0,1)
 s.apply(belt,(.48,.51,.52),.42,.75,.03,.92)
 s.grille(.033,.945,.215,.982)
 s.apply(stencil("СЕКТОР 04",.625,.978,2),(.90,.90,.84),.51,.63,.02)
 return s.maps()

def road(rng):
 s=Surface(rng,.54,.88)
 aggregate=noise(rng,317)*.012+noise(rng,487)*.006
 s.albedo+=aggregate[...,None];s.height+=aggregate*.12
 # Utility patches and joints, not centre lines or invented traffic lanes.
 for points in [[(.02,.28),(.23,.29),(.36,.32),(.63,.31),(.98,.27)],[(.04,.76),(.34,.75),(.57,.79),(.98,.77)]]:
  s.apply(line(points,2.2),(.41,.43,.43),.44,.93,0,.94)
 for x0,y0,w,h in [(.08,.08,.24,.14),(.60,.50,.27,.18)]:
  s.apply(rectangle(x0,y0,x0+w,y0+h,8),(.50,.52,.52),.498,.91,0,.985)
  s.apply(line([(x0,y0),(x0+w,y0),(x0+w,y0+h),(x0,y0+h)],1.0,True),(.43,.45,.45),.45,.94,0,.97)
 # One diagonal utility cover, with local short service bars only.
 pts=[(.72,.08),(.88,.08),(.91,.11),(.91,.25),(.72,.25)]
 s.panel(pts,(.56,.58,.58),.51,.63)
 for y in np.linspace(.105,.225,12):s.apply(line([(.745,y),(.885,y)],2),(.35,.38,.39),.42,.74,.5,.87)
 for x in [.73,.90]:
  for y in [.09,.24]:s.fastener(x,y,.004)
 for i in range(4):s.apply(polygon([(.71+i*.045,.286),(.734+i*.045,.286),(.72+i*.045,.323),(.696+i*.045,.323)]),(.83,.79,.61),.502,.85,.02)
 s.apply(stencil("ТЕХ-02",.80,.36,2),(.78,.78,.71),.502,.89,0)
 return s.maps()

def pad(rng):
 s=Surface(rng,.76,.84)
 # Large expansion slabs, restrained seams and inset anchor clusters.
 for row in range(3):
  for col in range(3):
   x0=col/3+.007;y0=row/3+.007;x1=(col+1)/3-.007;y1=(row+1)/3-.007
   value=[.72,.78,.75,.81][(row*3+col)%4]
   s.apply(rectangle(x0,y0,x1,y1), (value,value*1.004,value*.995),.51,.79+((row+col)%3)*.035,0)
   s.apply(line([(x0,y0),(x1,y0),(x1,y1),(x0,y1)],1.5,True),(.58,.60,.59),.43,.92,0,.93)
 for cx,cy in [(.12,.13),(.86,.14),(.13,.86),(.85,.84)]:
  s.apply(circle(cx,cy,.025),(.58,.61,.61),.46,.43,.62,.94)
  s.apply(circle(cx,cy,.016),(.42,.45,.45),.40,.61,.72,.87)
  for x,y in [(cx-.018,cy),(cx+.018,cy),(cx,cy-.018),(cx,cy+.018)]:s.fastener(x,y,.0035)
 # Service hatch and a short local hazard patch; no H, arrow or new target mark.
 s.panel([(.39,.38),(.60,.38),(.63,.41),(.63,.57),(.39,.57)],(.70,.73,.73),.52,.49)
 s.apply(stencil("ДОСТУП",.51,.475,2),(.89,.89,.83),.53,.67,.02)
 for i in range(6):
  x=.40+i*.036
  s.apply(polygon([(x,.60),(x+.020,.60),(x+.003,.64),(x-.017,.64)]),(.88,.82,.59),.512,.82,.02)
 s.apply(stencil("ПАНЕЛЬ 03",.50,.685,2),(.60,.62,.60),.51,.86,0)
 return s.maps()

def roof(rng):
 s=Surface(rng,.73,.46,.67)
 # Staggered folded-metal modules, access plates and small recessed cooling grids.
 for row in range(4):
  for col in range(4):
   x0=col*.25+.009;y0=row*.25+.009;x1=(col+1)*.25-.009;y1=(row+1)*.25-.009
   cut=.018+.006*((row+col)%2)
   poly=[(x0+cut,y0),(x1,y0),(x1,y1-cut),(x1-cut,y1),(x0,y1),(x0,y0+cut)]
   tone=[.69,.80,.74,.77][(row+2*col)%4]
   s.panel(poly,(tone*.99,tone,tone*1.013),.35+((row+col)%4)*.065,.72)
   for x in np.linspace(x0+.025,x1-.025,5):s.apply(line([(x,y0+.017),(x,y1-.017)],.8),(.80,.82,.82),.54,.30,.80)
 for x0,y0 in [(.055,.055),(.555,.555)]:
  s.grille(x0,y0,x0+.14,y0+.13)
  for x in [x0+.007,x0+.133]:
   for y in [y0+.006,y0+.124]:s.fastener(x,y,.0035)
 s.apply(stencil("СЕРВИС 04",.37,.455,2),(.92,.91,.84),.53,.62,.1)
 return s.maps()

GENERATORS={"facade":facade,"road":road,"pad":pad,"roof":roof}

def encoded(array):
 output=io.BytesIO();Image.fromarray(array).save(output,format="PNG",compress_level=9,optimize=False);return output.getvalue()

def linear_mean(rgb):
 c=rgb.astype(np.float64)/255;c=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
 return float(np.mean(c@np.array([.2126,.7152,.0722])))

def import_settings(channel):
 relative="assets/city_surfaces/"+channel+".png"
 digest=hashlib.md5(("res://"+relative).encode()).hexdigest()
 return f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://.godot/imported/{channel}.png-{digest}.ctex"
metadata={{
"vram_texture": false
}}

[deps]
source_file="res://{relative}"
dest_files=["res://.godot/imported/{channel}.png-{digest}.ctex"]

[params]
compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={1 if channel=="normal" else 0}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
'''

def validate_content(role,maps):
 assert set(maps)==set(CHANNELS)
 for channel,array in maps.items():assert array.shape==(SIZE,SIZE,3) and array.dtype==np.uint8,(role,channel,"shape")
 normal=maps["normal"].astype(np.float64)/255*2-1
 assert np.max(np.abs(np.linalg.norm(normal,axis=-1)-1))<.011,(role,"unit normals")
 assert normal[...,2].min()>.48,(role,"normal slope limit")
 orm=maps["orm"]
 assert orm[...,0].min()>=200 and orm[...,1].min()>=30 and orm[...,1].max()<=250,(role,"ORM range")
 assert maps["albedo"].std()>(3 if role=="road" else 6),(role,"missing authored structure")

def validate_atlas_mips(atlas):
 # Independent whole-atlas box filtering proves role padding remains periodic
 # at every supported integer LOD. No half-pixel UV adjustment is necessary.
 for channel,image in atlas.items():
  level=image.astype(np.float64)
  for lod in range(5):
   tile=TILE>>lod;gutter=GUTTER>>lod
   for index,role in enumerate(ROLES):
    x=(index%2)*tile;y=(index//2)*tile
    padded=level[y:y+tile,x:x+tile]
    inner=padded[gutter:-gutter,gutter:-gutter]
    expected=np.pad(inner,((gutter,gutter),(gutter,gutter),(0,0)),mode="wrap")
    assert np.array_equal(padded,expected),(role,channel,"periodic mip gutter",lod)
   if lod<4:
    height,width,_=level.shape
    level=level.reshape(height//2,2,width//2,2,3).mean(axis=(1,3))

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--check",action="store_true");args=parser.parse_args()
 diagonal=line([(.10,.11),(.82,.79)],.8)
 assert np.count_nonzero((diagonal>0)&(diagonal<1))>100,"Missing original4x coverage"
 flat=normal_map(np.zeros_like(X));assert np.all(flat==np.array([128,128,255])),"flat normal contract"
 assert normal_map(np.sin(X*2*np.pi))[0,0,0]<128 and normal_map(np.sin(Y*2*np.pi))[0,0,1]>128,"OpenGL normal handedness"
 atlas={channel:np.zeros((RESOLUTION,RESOLUTION,3),dtype=np.uint8) for channel in CHANNELS}
 manifest={"version":1,"resolution":RESOLUTION,"tile_size":TILE,"content_size":SIZE,"gutter":GUTTER,"max_safe_lod":4,"license":"CC0-1.0","authoring":"Original deterministic geometric city surfaces; original bitmap stencil, no borrowed imagery, external font or baked directional illumination.","normal_convention":"OpenGL +Y; image rows grow down; no green inversion on import","orm_channels":{"r":"ambient_occlusion","g":"roughness","b":"metallic"},"uv_formula":"(tile_origin_px+16+fract(local_uv)*992)/2048; use derivatives before fract; clamp texture LOD <=4","roles":{},"files":{}}
 for index,role in enumerate(ROLES):
  seed=731405+index*7919;maps=GENERATORS[role](np.random.default_rng(seed));validate_content(role,maps)
  x=(index%2)*TILE;y=(index//2)*TILE
  entry={"index":index,"seed":seed,"origin_px":[x,y],"mean_linear_luminance":round(linear_mean(maps["albedo"]),8),"mean_roughness":round(float(maps["orm"][...,1].mean()/255),8),"mean_metallic":round(float(maps["orm"][...,2].mean()/255),8)}
  manifest["roles"][role]=entry
  for channel,content in maps.items():
   padded=np.pad(content,((GUTTER,GUTTER),(GUTTER,GUTTER),(0,0)),mode="wrap")
   assert np.array_equal(padded[:GUTTER,GUTTER:-GUTTER],content[-GUTTER:]),(role,channel,"top gutter")
   assert np.array_equal(padded[-GUTTER:,GUTTER:-GUTTER],content[:GUTTER]),(role,channel,"bottom gutter")
   assert np.array_equal(padded[GUTTER:-GUTTER,:GUTTER],content[:,-GUTTER:]),(role,channel,"left gutter")
   assert np.array_equal(padded[GUTTER:-GUTTER,-GUTTER:],content[:,:GUTTER]),(role,channel,"right gutter")
   atlas[channel][y:y+TILE,x:x+TILE]=padded
  print(f"authored {role}: luminance={entry['mean_linear_luminance']:.4f}",flush=True)
 assert len({hashlib.sha256(atlas['albedo'][y*TILE:(y+1)*TILE,x*TILE:(x+1)*TILE].tobytes()).digest() for y in range(2) for x in range(2)})==4,"Roles must be visually distinct"
 validate_atlas_mips(atlas)
 if not args.check:ROOT.mkdir(parents=True,exist_ok=True)
 total=0
 for channel,array in atlas.items():
  raw=encoded(array);total+=len(raw);path=ROOT/(channel+".png")
  if args.check:assert path.read_bytes()==raw,(channel,"deterministic bytes mismatch")
  else:
   path.write_bytes(raw)
   if not Path(str(path)+".import").exists():Path(str(path)+".import").write_text(import_settings(channel))
  manifest["files"][channel]={"sha256":hashlib.sha256(raw).hexdigest(),"bytes":len(raw)}
 assert total<10*1024*1024,("Source atlas budget exceeded",total)
 text=json.dumps(manifest,ensure_ascii=False,indent=2)+"\n"
 if args.check:assert (ROOT/"manifest.json").read_text()==text,"Manifest mismatch"
 else:
  (ROOT/"manifest.json").write_text(text)
  (ROOT/"LICENSE.txt").write_text("Original city surface artwork and bitmap stencils: CC0-1.0. This does not alter the provenance or license of other game resources.\n")
 print(f"CITY SURFACE ATLAS PASS:4 roles,3 maps2048x2048,wrapped16pxgutters,4xvectorcoverage,{total/1024/1024:.2f}MiB; byte reproduction and physical checks passed")

if __name__=="__main__":main()
