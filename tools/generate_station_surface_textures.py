#!/usr/bin/env python3
"""Original periodic station panels: albedo, OpenGL +Y normal and ORM.

Requires NumPy/Pillow. --check regenerates without modifying source files.
No source photograph, commercial artwork, baked light or downloaded font.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'assets/surface_details/station'
SIZE = 1024
SEED = 713550
Y, X = np.mgrid[:SIZE, :SIZE].astype(float) / SIZE
GLYPHS = {
 '0':['01110','10001','10011','10101','11001','10001','01110'],
 '1':['00100','01100','00100','00100','00100','00100','01110'],
 '2':['01110','10001','00001','00010','00100','01000','11111'],
 '3':['11110','00001','00001','01110','00001','00001','11110'],
 '4':['00010','00110','01010','10010','11111','00010','00010'],
 '5':['11111','10000','10000','11110','00001','00001','11110'],
 '6':['01110','10000','10000','11110','10001','10001','01110'],
 '7':['11111','00001','00010','00100','01000','01000','01000'],
 '8':['01110','10001','10001','01110','10001','10001','01110'],
 '9':['01110','10001','10001','01111','00001','00001','01110'],
 'А':['01110','10001','10001','11111','10001','10001','10001'],
 'В':['11110','10001','10001','11110','10001','10001','11110'],
 'Е':['11111','10000','10000','11110','10000','10000','11111'],
 'И':['10001','10011','10101','10101','11001','10001','10001'],
 'К':['10001','10010','10100','11000','10100','10010','10001'],
 'Л':['00111','01001','01001','01001','01001','10001','10001'],
 'Н':['10001','10001','10001','11111','10001','10001','10001'],
 'О':['01110','10001','10001','10001','10001','10001','01110'],
 'П':['11111','10001','10001','10001','10001','10001','10001'],
 'Р':['11110','10001','10001','11110','10000','10000','10000'],
 'С':['01111','10000','10000','10000','10000','10000','01111'],
 'Т':['11111','00100','00100','00100','00100','00100','00100'],
 'У':['10001','10001','01010','00100','00100','01000','10000'],
 'Х':['10001','10001','01010','00100','01010','10001','10001'],
 'Ь':['10000','10000','10000','11110','10001','10001','11110'],
 'Я':['01111','10001','10001','01111','00101','01001','10001'],
 '-':['00000','00000','00000','11111','00000','00000','00000'],
 ' ':['00000']*7,
}

def noise(rng, cells):
    lattice = rng.uniform(-1, 1, (cells, cells))
    x, y = X*cells, Y*cells
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x-ix, y-iy
    fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
    return ((lattice[iy%cells,ix%cells]*(1-fx)+lattice[iy%cells,(ix+1)%cells]*fx)*(1-fy)
           +(lattice[(iy+1)%cells,ix%cells]*(1-fx)+lattice[(iy+1)%cells,(ix+1)%cells]*fx)*fy)

def mask():return Image.new('L',(SIZE,SIZE),0)
def array(image):return np.asarray(image,dtype=float)/255
def polygon(image,points,value,width=0):
    for dy in (-SIZE,0,SIZE):
        for dx in (-SIZE,0,SIZE):
            shifted=[(x+dx,y+dy) for x,y in points]
            draw=ImageDraw.Draw(image)
            if width:draw.line(shifted+[shifted[0]],fill=value,width=width,joint='curve')
            else:draw.polygon(shifted,fill=value)
def text(image,position,value,label,scale=2):
    draw=ImageDraw.Draw(image);x,y=position
    for ch in label:
        for row,line in enumerate(GLYPHS[ch]):
            for col,bit in enumerate(line):
                if bit=='1':draw.rectangle((x+col*scale,y+row*scale,x+(col+1)*scale-1,y+(row+1)*scale-1),fill=value)
        x+=6*scale

def authored():
    rng=np.random.default_rng(SEED)
    coarse=noise(rng,7)*.65+noise(rng,23)*.25+noise(rng,59)*.1
    grain=noise(rng,193)
    face=mask();seams=mask();edges=mask();hatches=mask();bolts=mask();vents=mask();marks=mask();wear=mask()
    panels=[
      ([(-36,-30),(324,-30),(372,18),(372,358),(324,406),(-36,406)],190),
      ([(392,-30),(765,-30),(810,15),(810,196),(760,246),(392,246)],224),
      ([(832,-30),(1048,-30),(1048,556),(987,615),(832,615)],206),
      ([(392,268),(755,268),(803,316),(803,591),(742,652),(436,652),(392,608)],201),
      ([(-36,428),(288,428),(350,490),(350,806),(300,856),(-36,856)],226),
      ([(371,677),(746,677),(803,734),(803,1045),(371,1045)],214),
      ([(832,638),(980,638),(1048,706),(1048,1045),(832,1045)],194),
      ([(-36,878),(282,878),(350,946),(350,1045),(-36,1045)],211),
    ]
    for points,value in panels:
        polygon(face,points,value);polygon(seams,points,255,7);polygon(edges,points,255,2)
    # Service doors are physical inset outlines, not light/shadow painted into colour.
    for points in [
      [(45,66),(270,66),(301,97),(301,255),(270,286),(45,286)],
      [(445,337),(697,337),(741,381),(741,535),(697,579),(445,579)],
      [(434,747),(706,747),(735,776),(735,945),(434,945)],
      [(57,500),(230,500),(274,544),(274,718),(230,762),(57,762)],
    ]:
        polygon(hatches,points,255,5)
        for px,py in points:
            ImageDraw.Draw(bolts).ellipse((px-4,py-4,px+4,py+4),fill=255)
            ImageDraw.Draw(bolts).line((px-2,py,px+2,py),fill=145,width=1)
    # Recessed louvres; their texture does not add opaque or collision geometry.
    dv=ImageDraw.Draw(vents)
    for x,y,w,h in [(468,65,270,98),(78,540,146,101),(870,735,104,170)]:
        dv.rectangle((x-7,y-7,x+w+7,y+h+7),fill=70)
        for row in range(y,y+h,11):dv.rounded_rectangle((x,row,x+w,row+5),2,fill=255)
    dm=ImageDraw.Draw(marks)
    for x,y in [(66,318),(448,608),(436,973)]:
        for j in range(0,84,18):dm.polygon([(x+j,y),(x+j+8,y),(x+j+18,y+15),(x+j+10,y+15)],fill=210)
    for position,label in [((72,294),'ТЕХ-01'),((452,303),'СЕРВИС 12'),((450,700),'ПАНЕЛЬ 07'),((855,676),'СЕК 03')]:
        text(marks,position,255,label)
    # Sparse short scuffs align with manufactured surfaces, not a per-pixel noise wash.
    dw=ImageDraw.Draw(wear)
    for i in range(145):
        x=int(rng.integers(0,SIZE));y=int(rng.integers(0,SIZE))
        dw.line((x,y,x+int(rng.integers(3,19)),y+int(rng.integers(-2,3))),fill=int(rng.integers(45,150)),width=1)
    f,s,e,h,b,v,m,w=[array(x) for x in (face,seams,edges,hatches,bolts,vents,marks,wear)]
    panel=(f-.79)*.18
    albedo=.80+panel+.025*coarse+.008*grain-.27*s-.23*h-.19*b-.33*v+.095*e+.12*w
    rgb=np.repeat(albedo[...,None],3,axis=2)
    # Maintenance paint is neutral off-white; separate narrow hazard patches amber.
    rgb=rgb*(1-m[...,None])+(np.array([.91,.90,.84])*m[...,None])
    height=.018*grain+.009*coarse-.40*s-.32*h-.29*b-.20*v+.04*e+.015*w
    dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.5*2.8
    dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.5*2.8
    n=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);n/=np.linalg.norm(n,axis=-1)[...,None]
    ao=np.clip(.99-.22*s-.16*h-.13*b-.12*v,.6,1)
    rough=np.clip(.52+.045*coarse+.025*grain+.16*m+.08*w+.08*v,.12,.9)
    metal=np.clip(.72+.20*w+.10*e-.58*m,.04,.98)
    def pixels(value):return np.rint(np.clip(value,0,1)*255).astype('uint8')
    return {'albedo':pixels(rgb),'normal':pixels(n*.5+.5),'orm':pixels(np.stack((ao,rough,metal),axis=-1))}

def encoded(image):
    f=io.BytesIO();Image.fromarray(image).save(f,format='PNG',compress_level=9);return f.getvalue()
def settings(channel):
    source=f'res://assets/surface_details/station/{channel}.png'
    imported='res://.godot/imported/'+channel+'.png-'+hashlib.md5(source.encode()).hexdigest()+'.ctex'
    return f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="{imported}"
metadata={{"vram_texture": false}}

[deps]

source_file="{source}"
dest_files=["{imported}"]

[params]

compress/mode=0
compress/normal_map={1 if channel=='normal' else 0}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=false
process/normal_map_invert_y=false
detect_3d/compress_to=0
'''
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    maps=authored();linear=maps['albedo'].astype(float)/255
    linear=np.where(linear<=.04045,linear/12.92,((linear+.055)/1.055)**2.4)
    manifest={'version':1,'resolution':SIZE,'seed':SEED,'license':'CC0-1.0','authoring':'Original authored periodic industrial station panels; no downloaded imagery or baked light. Original5x7 Cyrillic pixel glyphs.','normal_convention':'OpenGL +Y; image Y increases down; no Y inversion','orm_channels':{'r':'ambient_occlusion','g':'roughness','b':'metallic'},'mean_linear_luminance':round(float(np.mean(linear@np.array([.2126,.7152,.0722]))),8),'mean_roughness':round(float(maps['orm'][...,1].mean()/255),8),'tile_size_m':16,'files':{}}
    if not args.check:ROOT.mkdir(parents=True,exist_ok=True)
    total=0
    for channel,value in maps.items():
        assert value.shape==(SIZE,SIZE,3)
        content=encoded(value);total+=len(content)
        path=ROOT/(channel+'.png')
        if args.check:assert path.read_bytes()==content,'Byte reproduction failed: '+str(path)
        else:
            path.write_bytes(content)
            sidecar=Path(str(path)+'.import')
            if not sidecar.exists():sidecar.write_text(settings(channel))
        manifest['files'][channel]={'bytes':len(content),'sha256':hashlib.sha256(content).hexdigest()}
    normal=maps['normal'].astype(float)/255*2-1
    assert np.max(abs(np.linalg.norm(normal,axis=-1)-1))<.009
    assert normal[...,2].min()>.6
    assert maps['orm'][...,0].min()>=153
    assert total<4*1024*1024
    data=json.dumps(manifest,indent=2,ensure_ascii=False)+'\n'
    if args.check:assert (ROOT/'manifest.json').read_text()==data
    else:
        (ROOT/'manifest.json').write_text(data)
        (ROOT/'LICENSE.txt').write_text('CC0 1.0 Universal\nOriginal station surface maps and original pixel glyphs authored for this project. No third-party photographs or game textures.\n')
    print(f'STATION SURFACES: 3 maps, {SIZE}x{SIZE}, {total/1024/1024:.2f} MiB; deterministic PBR checks passed')
if __name__=='__main__':main()
