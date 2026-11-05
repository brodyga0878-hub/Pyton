#!/usr/bin/env python3
"""Original object-projected ship surface atlases (no geometry, borrowed artwork or lighting).

Requires NumPy and Pillow. --check reproduces every PNG byte and metadata without
editing assets. The tiny Cyrillic technical stencil is authored below; no system
font or external font rasterizer is involved in reproducibility.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / 'assets/surface_details/ships'
SIZE = 1024
SUPERSAMPLE = 4
SPAN = 42.0
PROFILES = {'cobra': (1.0, 1.0, '03'), 'eagle': (.90, 1.20, '02'), 'shuttle': (.82, .96, '01')}
CHANNELS = ('albedo', 'normal', 'orm')
# Original five-column technical stencil. Shapes are bitmaps, not a font copy.
STENCIL = {
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
 'Б':['11111','10000','10000','11110','10001','10001','11110'],
 'В':['11110','10001','10001','11110','10001','10001','11110'],
 'Г':['11111','10000','10000','10000','10000','10000','10000'],
 'Д':['00110','01010','01010','01010','01010','11111','10001'],
 'Е':['11111','10000','10000','11110','10000','10000','11111'],
 'Ж':['10101','10101','01110','00100','01110','10101','10101'],
 'З':['11110','00001','00001','01110','00001','00001','11110'],
 'И':['10001','10001','10011','10101','11001','10001','10001'],
 'К':['10001','10010','10100','11000','10100','10010','10001'],
 'Л':['00111','01001','01001','01001','01001','01001','10001'],
 'М':['10001','11011','10101','10101','10001','10001','10001'],
 'Н':['10001','10001','10001','11111','10001','10001','10001'],
 'О':['01110','10001','10001','10001','10001','10001','01110'],
 'П':['11111','10001','10001','10001','10001','10001','10001'],
 'Р':['11110','10001','10001','11110','10000','10000','10000'],
 'С':['01111','10000','10000','10000','10000','10000','01111'],
 'Т':['11111','00100','00100','00100','00100','00100','00100'],
 'У':['10001','10001','10001','01111','00001','00001','01110'],
 'Ф':['00100','01110','10101','10101','01110','00100','00100'],
 'Х':['10001','10001','01010','00100','01010','10001','10001'],
 'Ц':['10010','10010','10010','10010','10010','11111','00001'],
 'Ч':['10001','10001','10001','01111','00001','00001','00001'],
 'Ш':['10101','10101','10101','10101','10101','10101','11111'],
 'Ы':['10001','10001','10001','11101','10011','10011','11101'],
 'Ь':['10000','10000','10000','11110','10001','10001','11110'],
 'Я':['01111','10001','10001','01111','00101','01001','10001'],
 '/':['00001','00001','00010','00100','01000','10000','10000'],
 '-':['00000','00000','00000','11111','00000','00000','00000'],
 ' ':['00000']*7,
}
# Existing authored armour footprints, copied as texture authoring coordinates;
# they are not applied to source/collision meshes by this generator.
PLATES = [
 [( .5,-16.2),(4.8,-13.3),(8.6,-8.8),(1.8,-9.8)],
 [(4.4,-8.1),(9.6,-8.2),(15.7,-1),(5.1,-1.4)],
 [(6.0,-.6),(16.5,-.2),(19.8,4.3),(8.5,3.0)],
 [(10.1,3.9),(20.1,5.1),(19.7,7.4),(14.8,10.7),(10.2,9.8)],
 [(4.9,0.0),(8.3,3.8),(8.0,10.7),(4.2,10.9)],
 [(1.0,3.1),(3.5,2.8),(3.5,10.7),(1,11.1)],
]


def pixel(point):
    return tuple(int(round((value/SPAN+.5)*(SIZE-1))) for value in point)


def _vector_mask(points, paint, padding=3):
    """Rasterise real vector coordinates at4x only in their occupied crop.

    Bounds include the complete filter kernel. This is coverage sampling, not
    enlarging an existing1024px image. Subpixel positions remain unrounded.
    """
    coords=[tuple((value/SPAN+.5)*(SIZE-1) for value in point) for point in points]
    left=max(0,int(np.floor(min(p[0] for p in coords)-padding)))
    top=max(0,int(np.floor(min(p[1] for p in coords)-padding)))
    right=min(SIZE,int(np.ceil(max(p[0] for p in coords)+padding))+1)
    bottom=min(SIZE,int(np.ceil(max(p[1] for p in coords)+padding))+1)
    result=Image.new('L',(SIZE,SIZE))
    if right<=left or bottom<=top:return np.asarray(result,dtype=np.float64)/255.
    image=Image.new('L',((right-left)*SUPERSAMPLE,(bottom-top)*SUPERSAMPLE))
    local=[((px-left)*SUPERSAMPLE,(py-top)*SUPERSAMPLE) for px,py in coords]
    paint(ImageDraw.Draw(image),local,SUPERSAMPLE)
    image=image.resize((right-left,bottom-top),Image.Resampling.LANCZOS)
    result.paste(image,(left,top))
    return np.asarray(result,dtype=np.float64)/255.


def mask_polygon(points, blur=.0):
    return _vector_mask(points,lambda draw,coords,ss:draw.polygon(coords,fill=255))


def path_mask(points, width=1, closed=False):
    def paint(draw,coords,ss):
        if closed:coords=coords+[coords[0]]
        draw.line(coords,fill=255,width=max(1,int(round(width*ss))),joint='curve')
    return _vector_mask(points,paint,padding=max(3,width+2))


def stencil_mask(text, at, scale=2, rotation=0):
    width=max(1,len(text)*6-1)*scale;height=7*scale
    image=Image.new('L',(width*SUPERSAMPLE,height*SUPERSAMPLE));draw=ImageDraw.Draw(image)
    for index,char in enumerate(text):
        assert char in STENCIL,('Missing authored stencil glyph',char)
        for y,row in enumerate(STENCIL[char]):
            for x,bit in enumerate(row):
                if bit=='1':draw.rectangle(((index*6+x)*scale*SUPERSAMPLE,y*scale*SUPERSAMPLE,(index*6+x+1)*scale*SUPERSAMPLE-1,(y+1)*scale*SUPERSAMPLE-1),fill=255)
    if rotation:image=image.rotate(rotation,expand=True,resample=Image.Resampling.BICUBIC)
    image=image.resize((round(image.width/SUPERSAMPLE),round(image.height/SUPERSAMPLE)),Image.Resampling.LANCZOS)
    result=Image.new('L',(SIZE,SIZE));x,y=pixel(at);result.paste(image,(x-image.width//2,y-image.height//2))
    return np.asarray(result,dtype=np.float64)/255.


def encode(array):
    target=io.BytesIO();Image.fromarray(array).save(target,format='PNG',optimize=False,compress_level=9);return target.getvalue()


def quantize(array):return np.clip(np.rint(array*255),0,255).astype(np.uint8)


def normal_map(height):
    # Atlas image Y grows down; OpenGL tangent +Y grows upward, thus +dH/dY.
    dy,dx=np.gradient(height)
    normals=np.stack((-dx*4.0,dy*4.0,np.ones_like(height)),axis=-1)
    normals/=np.linalg.norm(normals,axis=-1)[...,None]
    return quantize(normals*.5+.5)


def authored(profile):
    index=list(PROFILES).index(profile);seed=913357+index*1709
    rng=np.random.default_rng(seed)
    yy,xx=np.mgrid[:SIZE,:SIZE].astype(np.float64)
    x=(xx/(SIZE-1)-.5)*SPAN;z=(yy/(SIZE-1)-.5)*SPAN
    # Neutral diffuse paint: fine variation is material grain, never a light gradient.
    grain=rng.normal(0,.0035,(SIZE,SIZE));slow=np.sin(x*2.1)*np.sin(z*1.17)*.003
    # Aperiodic powder-coat/brush finish is a physical field, not simulated light.
    coarse=Image.fromarray(rng.integers(0,256,(64,64),dtype=np.uint8)).resize((SIZE,SIZE),Image.Resampling.BICUBIC)
    finish_noise=(np.asarray(coarse,dtype=np.float64)/255.-.5)
    albedo=np.repeat((.827+grain+slow)[...,None],3,axis=2)
    height=np.full((SIZE,SIZE),.5);rough=np.full_like(height,.43);metal=np.full_like(height,.045);ao=np.ones_like(height)
    def apply(mask,colour=None,relief=None,finish=None,metalness=None,occlusion=None):
        nonlocal albedo,height,rough,metal,ao
        if colour is not None:
            value=np.asarray(colour);albedo=albedo*(1-mask[...,None])+value*mask[...,None]
        for name,value in [('height',relief),('rough',finish),('metal',metalness),('ao',occlusion)]:
            if value is None:continue
            if name=='height':height=height*(1-mask)+value*mask
            elif name=='rough':rough=rough*(1-mask)+value*mask
            elif name=='metal':metal=metal*(1-mask)+value*mask
            else:ao=ao*(1-mask)+value*mask
    def line(points,width=2,colour=(.51,.53,.54),relief=.41,finish=.58,occlusion=.96):
        apply(path_mask(points,width),colour,relief,finish,None,occlusion)
    def ink(text,at,scale=2,colour=(.96,.96,.93),rotation=0):
        apply(stencil_mask(text,at,scale,rotation),colour,.505,.57,.02)
    def fastener(at,size=.09):
        bounds=[(at[0]-size,at[1]-size),(at[0]+size,at[1]+size)]
        mask=_vector_mask(bounds,lambda draw,p,ss:draw.ellipse((p[0][0],p[0][1],p[1][0],p[1][1]),fill=255))
        apply(mask,(.62,.64,.65),.43,.35,.65,.96)
        slot=path_mask([(at[0]-size*.65,at[1]),(at[0]+size*.65,at[1])],.7)
        apply(slot,(.48,.50,.51),.39,.65,.08,.94)
    def hatch(cx,cz,width,depth,number):
        bevel=.28
        poly=[(cx-width/2+bevel,cz-depth/2),(cx+width/2-bevel,cz-depth/2),(cx+width/2,cz-depth/2+bevel),(cx+width/2,cz+depth/2-bevel),(cx+width/2-bevel,cz+depth/2),(cx-width/2+bevel,cz+depth/2),(cx-width/2,cz+depth/2-bevel),(cx-width/2,cz-depth/2+bevel)]
        apply(mask_polygon(poly),(.65,.67,.68),.48,.49,.06)
        apply(path_mask(poly,1.2,True),(.49,.52,.54),.39,.59,.05,.96)
        for sx in [-1,1]:
            for sz in [-1,1]:fastener((cx+sx*(width/2-.22),cz+sz*(depth/2-.22)),.07)
        ink('ДОСТУП',(cx,cz-.35),1)
        ink(number,(cx,cz+.35),2)
        line([(cx-.25,cz+.83),(cx+.25,cz+.83)],2,(.48,.50,.51),.41)
    # Large non-periodic angular panel divisions follow the actual wedge plates.
    for side in [-1,1]:
        for number,raw in enumerate(PLATES):
            points=np.asarray([(px*side,pz) for px,pz in raw],dtype=np.float64)
            centre=points.mean(axis=0)
            inset=centre+(points-centre)*(.92 if profile!='shuttle' else .89)
            value=[.77,.88,.71,.84,.80,.75][(number+index*2)%6]
            mask=mask_polygon(inset)
            apply(mask,(.99*value,value,value*1.006),.515,[.34,.52,.43,.31,.57,.47][(number+index)%6],.045)
            # Small neutral coat variation and non-directional roughness inside
            # each plate; this is not a diffuse-light or highlight gradient.
            albedo+=mask[...,None]*finish_noise[...,None]*.023
            rough+=mask*finish_noise*.045
            apply(path_mask(inset,1.0,True),(.54,.57,.59),.40,.57,.03,.96)
            # A thin exposed wear rim follows the seam; no directional lighting baked.
            rim=centre+(inset-centre)*.985
            apply(path_mask(rim,.65,True),(.86,.88,.87),.52,.31,.42)
            for point in centre+(inset-centre)*.91:fastener(tuple(point),.06)
            # Deliberate diagonal subdivisions are sparse and different per profile.
            if number in ([1,3] if profile=='cobra' else [0,2,3] if profile=='eagle' else [1,2,4]):
                first=(inset[0]+inset[1])*.5;last=(inset[-1]+inset[-2])*.5
                line([tuple(first),tuple(last)],.7,(.58,.61,.63),.44,.55,.98)
            ink('%02d'%(number+1),(float(centre[0]),float(centre[1])+.12),2,colour=(.65,.69,.71))
        # Separate recessed service hatches and serial plaques, not repeated tiles.
        hatch(side*11.6,-4.0,2.65,2.25,'%02d'%(10+index))
        hatch(side*14.8,7.4,2.55,2.15,'%02d'%(20+index))
        # The thermal grille belongs behind the cockpit beside existing exchanger.
        panel=[(side*4.65,2.5),(side*8.1,2.8),(side*8.1,9.4),(side*4.45,9.7)]
        apply(mask_polygon(panel),(.43,.46,.47),.35,.47,.25,.93)
        for row in range(17):
            depth=2.85+row*.36
            line([(side*5.25,depth),(side*7.65,depth+.05)],2,(.16,.18,.19),.24,.59,.87)
        ink('ГОРЯЧО',(side*6.5,10.1),1,colour=(.96,.88,.66))
        # Sparse caution chevrons avoid a generic repeated yellow/black texture.
        for row in range(7):
            start=-7.2+row*.46
            poly=[(side*8.95,start),(side*9.26,start+.08),(side*9.60,start+.54),(side*9.28,start+.47)]
            apply(mask_polygon(poly),(.95,.86,.58),.503,.53,.02)
        ink('НЕ ВСТАВАТЬ',(side*13.6,1.3),1,colour=(.92,.92,.86))
        ink('СФ / '+PROFILES[profile][2],(side*13.9,8.9),2)
        # Only a few controlled flow-aligned stain/scratch marks, not random noise.
        for wear in range(28):
            wx=side*rng.uniform(4.8,17.5);wz=rng.uniform(-6.8,9.7)
            length=rng.uniform(.06,.36)
            line([(wx,wz),(wx+.025*side,wz+length)],1,(.80,.81,.79),.501,.52,.99)
        if profile=='eagle':
            for band in [0,.36]:
                line([(side*2.1,-13.0+band),(side*5.5,-9.8+band),(side*7.4,-9.1+band)],3,(.96,.97,.95),.503,.45,.99)
            ink('ПАТРУЛЬ',(side*14.5,6.25),1)
        elif profile=='shuttle':
            ink('ГРУЗ',(side*16.6,6.5),3)
            for stripe in range(3):
                line([(side*(11.9+stripe*.3),-6.3),(side*(15.2+stripe*.3),-2.1)],3,(.94,.90,.75),.503,.48,.99)
        else:
            ink('СЕРВИС',(side*10.5,-5.55),1)
            line([(side*17.5,5.3),(side*17.4,6.5),(side*16.4,7.2)],3,(.94,.91,.76),.503,.48,.99)
    # Longitudinal foredeck gives the nose a designed structure, not a tiled floor.
    for side in [-1,1]:
        line([(side*.25,-16.4),(side*.85,-12.3),(side*1.65,-10.3)],1.2,(.54,.57,.59),.41,.54,.97)
    ink('ОПАСНО',(.0,-11.1),1,colour=(.92,.88,.75))
    # Smooth only relief to keep each normal finite while retaining crisp decals.
    height=np.asarray(Image.fromarray(quantize(height)).filter(ImageFilter.GaussianBlur(.5)),dtype=np.float64)/255.
    height+=finish_noise*.0018
    # Very fine neutral variation after shapes: no diffuse shading, arbitrary highlights or shadows.
    albedo=np.clip(albedo+grain[...,None]*.48,0,1)
    return {'albedo':quantize(albedo),'normal':normal_map(height),'orm':quantize(np.stack((ao,rough,metal),axis=-1))}


def import_settings(source):
    path='res://'+source.relative_to(ROOT.parents[2]).as_posix()
    digest=hashlib.md5(path.encode()).hexdigest();packed=f'res://.godot/imported/{source.name}-{digest}.ctex'
    return f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="{packed}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{path}"
dest_files=["{packed}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={1 if source.stem=='normal' else 0}
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


def linear_mean(rgb):
    srgb=rgb.astype(np.float64)/255.;linear=np.where(srgb<=.04045,srgb/12.92,((srgb+.055)/1.055)**2.4)
    return float(np.mean(linear@np.array([.2126,.7152,.0722])))


def validate(profile,maps):
    for channel,array in maps.items():assert array.shape==(SIZE,SIZE,3) and array.dtype==np.uint8,(profile,channel,'dimensions')
    normal=maps['normal'].astype(np.float64)/255.*2-1
    assert np.max(np.abs(np.linalg.norm(normal,axis=-1)-1))<.011,(profile,'invalid unit normal')
    assert normal[...,2].min()>.65,(profile,'excessive relief')
    orm=maps['orm'];assert orm[...,0].min()>=210 and orm[...,1].min()>50 and orm[...,1].max()<220
    assert float(maps['albedo'].std())>10,(profile,'empty authored layout')
    assert float(np.std(maps['albedo'][100:880,100:900]))>12
    # Intentionally non-periodic atlas: unlike the base surfaces, no UV wrapping.
    assert np.all(maps['normal'][0,:,2]>250) and np.all(maps['normal'][-1,:,2]>250)
    assert STENCIL['Ф'][2]=='10101' and STENCIL['Д'][-1]=='10001','Cyrillic technical stencil contract'


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    # Oblique edges must contain fractional coverage, rather than merely
    # enlarge an already aliased target-resolution image.
    edge=path_mask([(-1.7,-1.4),(2.2,.9)],1.0)
    assert np.count_nonzero((edge>.0)&(edge<1.0))>100,'Missing antialiased subpixel vector coverage'
    manifest={'version':1,'resolution':SIZE,'license':'CC0-1.0','authoring':'Original deterministic object-projected ship finish layouts; no downloaded artwork, system font or baked illumination. Authored Cyrillic bitmap stencils.',
              'projection':{'canonical_bounds_m':[-21.,21.],'u':'canonical_x/42+0.5','v':'canonical_z/42+0.5','wrap':False,'shape_normalization':'canonical = object_point / ((span/42) * shape)'},
              'normal_convention':'OpenGL +Y; image Y grows down; no import inversion',
              'orm_channels':{'r':'ambient_occlusion','g':'roughness','b':'metallic'},'profiles':{}}
    total=0;hashes=[]
    for profile,(shape_x,shape_z,registry) in PROFILES.items():
        maps=authored(profile);validate(profile,maps)
        entry={'seed':913357+list(PROFILES).index(profile)*1709,'shape_x':shape_x,'shape_z':shape_z,'registry':registry,
               'mean_linear_luminance':round(linear_mean(maps['albedo']),8),'mean_roughness':round(float(maps['orm'][...,1].mean()/255.),8),'files':{}}
        directory=ROOT/profile
        if not args.check:directory.mkdir(parents=True,exist_ok=True)
        for channel in CHANNELS:
            content=encode(maps[channel]);path=directory/(channel+'.png');digest=hashlib.sha256(content).hexdigest();total+=len(content)
            if args.check:assert path.read_bytes()==content,(path,'non-deterministic bytes')
            else:
                path.write_bytes(content);settings=Path(str(path)+'.import')
                if not settings.exists():settings.write_text(import_settings(path))
            entry['files'][channel]={'sha256':digest,'bytes':len(content)}
        hashes.append(entry['files']['albedo']['sha256']);manifest['profiles'][profile]=entry
    assert len(set(hashes))==3,'Each adapted ship has an individual finish layout'
    assert total<8*1024*1024,('Ship atlas source budget exceeded',total)
    text=json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'
    if args.check:assert (ROOT/'manifest.json').read_text()==text,'Atlas metadata differs'
    else:
        (ROOT/'manifest.json').write_text(text)
        (ROOT/'LICENSE.txt').write_text('Original ship surface atlas artwork and authored bitmap stencil: CC0 1.0 Universal.\nNo third-party artwork or fonts are embedded in these assets.\nhttps://creativecommons.org/publicdomain/zero/1.0/\n')
    print(f'SHIP SURFACE ATLASES PASS: 3 individual layouts, 9 PBR maps, 1024x1024, {total/1024/1024:.2f} MiB; byte reproduction, unit normals, linear ORM and original Cyrillic stencil verified')


if __name__=='__main__':main()
