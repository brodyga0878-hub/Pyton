#!/usr/bin/env python3
"""Author original periodic PBR surfaces. No downloaded artwork or baked lighting.
Requires Python 3, NumPy and Pillow. Run --check for deterministic regeneration
and physical/periodicity checks without changing the checked-in assets.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import numpy as np
from PIL import Image

SIZE = 512
VERSION = 1
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'materials'
KINDS = ('painted_alloy', 'brushed_metal', 'concrete', 'asphalt', 'rock', 'ice', 'rubber', 'glass')
Y, X = np.mgrid[:SIZE, :SIZE].astype(np.float64) / SIZE


def noise(rng, cells_x, cells_y=None):
    """Smooth lattice noise defined on a torus, sampled without duplicated edges."""
    cells_y = cells_y or cells_x
    lattice = rng.uniform(-1, 1, (cells_y, cells_x))
    px, py = X * cells_x, Y * cells_y
    ix, iy = np.floor(px).astype(int), np.floor(py).astype(int)
    fx, fy = px - ix, py - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = lattice[iy % cells_y, ix % cells_x]
    b = lattice[iy % cells_y, (ix + 1) % cells_x]
    c = lattice[(iy + 1) % cells_y, ix % cells_x]
    d = lattice[(iy + 1) % cells_y, (ix + 1) % cells_x]
    return (a * (1-fx) + b * fx) * (1-fy) + (c * (1-fx) + d * fx) * fy


def fbm(rng):
    return sum(noise(rng, cells) * amplitude for cells, amplitude in ((4,.48),(11,.25),(31,.15),(79,.08),(151,.04)))


def line(coord, count, width):
    distance = np.minimum((coord * count) % 1, 1 - (coord * count) % 1)
    return np.exp(-np.square(distance / width))


def pixels(values):
    if values.ndim == 2:
        values = np.repeat(values[..., None], 3, axis=2)
    return np.clip(np.rint(values * 255), 0, 255).astype(np.uint8)


def normal_from_height(height, strength):
    # Image Y grows downward; OpenGL tangent +Y grows upward. Green is +dH/dImageY.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * .5 * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * .5 * strength
    normal = np.stack((-dx, dy, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    return pixels(normal * .5 + .5)


def authored(kind, seed):
    rng = np.random.default_rng(seed)
    coarse = fbm(rng)
    grain = noise(rng, 213)
    fine = noise(rng, 127)
    roughness = np.full_like(X, .7)
    metallic = np.zeros_like(X)
    ao = np.full_like(X, .99)
    tint = np.array([1.,1.,1.])
    strength = 3.
    if kind == 'painted_alloy':
        # Two metre-scale armour plates, recessed seams, four inset fasteners per plate.
        seams = np.maximum(line(X,2,.012), line(Y,2,.012))
        edge = np.maximum(line(X,2,.026), line(Y,2,.026)) - seams
        bolts = np.zeros_like(X)
        bolt_rims = np.zeros_like(X)
        for cx in (.025,.475,.525,.975):
            for cy in (.025,.475,.525,.975):
                dx = np.minimum(abs(X-cx), 1-abs(X-cx))
                dy = np.minimum(abs(Y-cy), 1-abs(Y-cy))
                radius = np.sqrt(dx*dx + dy*dy)
                bolts += np.exp(-np.square(radius/.005))
                bolt_rims += np.exp(-np.square((radius-.0065)/.0018))
        # Sparse directional scuffs are material wear, not illumination.
        scuff = np.maximum(noise(rng,7,103)-.58,0) * np.maximum(fine+.25,0)
        albedo = .825 + .045*coarse + .012*grain - .19*seams - .07*bolts + .045*edge + .10*scuff
        height = .045*grain + .03*coarse - .45*seams - .2*bolts + .08*bolt_rims
        ao = .99 - .27*seams - .15*bolts
        roughness = .46 + .08*coarse + .035*grain + .12*scuff
        metallic = np.clip(.12 + .65*edge + 1.9*scuff + .32*bolt_rims,0,.9)
        strength = 3.2
    elif kind == 'brushed_metal':
        brushing = noise(rng,6,245)
        bands = np.sin(Y * 2*np.pi*173 + noise(rng,5)*.35)
        albedo = .815 + .043*coarse + .035*brushing + .006*bands
        height = .018*brushing + .007*bands + .004*grain
        roughness = .34 + .10*brushing + .06*coarse
        metallic = np.full_like(X,.94)
        strength = 5.
    elif kind == 'concrete':
        pores = np.minimum(np.maximum(.40 - noise(rng,177),0)**2,.75)
        joints = np.maximum(line(X,2,.006), line(Y,2,.006))
        albedo = .81 + .11*coarse + .025*grain - .18*pores - .065*joints
        height = .15*coarse + .035*grain - .28*pores - .13*joints
        ao = .99 - .18*pores - .1*joints
        roughness = .86 + .06*coarse + .025*grain
        strength = 4.5
    elif kind == 'asphalt':
        aggregate = noise(rng,171)
        chips = np.maximum(aggregate-.15,0)
        fissures = np.exp(-np.square((noise(rng,8)+.18*noise(rng,29))/.025))
        albedo = .765 + .065*coarse + .085*aggregate + .025*chips - .04*fissures
        height = .075*aggregate + .04*chips - .035*fissures
        ao = .985 - .075*fissures - .035*np.maximum(-aggregate,0)
        roughness = .93 + .025*aggregate
        strength = 4.5
    elif kind == 'rock':
        strata = np.sin((X*7 + Y*3)*2*np.pi + noise(rng,8)*1.7)
        ridges = np.abs(noise(rng,17)+.27*noise(rng,43))
        fractures = np.exp(-np.square((noise(rng,9)+.16*noise(rng,37))/.038))
        albedo = .79 + .16*coarse + .025*strata + .025*grain - .065*fractures
        height = .22*coarse + .15*ridges + .026*grain - .10*fractures
        ao = .99 - .17*fractures
        roughness = .86 + .07*coarse + .025*grain
        strength = 5.
    elif kind == 'ice':
        crystal = noise(rng,34)
        cracks = np.exp(-np.square((noise(rng,9)+.12*crystal)/.020))
        frost = np.clip(noise(rng,17)+.2,0,1)
        albedo = .86 + .05*coarse + .055*frost - .055*cracks + .01*grain
        tint = np.array([.98,.995,1.])
        height = .035*crystal + .012*grain - .075*cracks
        ao = .995 - .035*cracks
        roughness = .25 + .30*frost + .07*coarse
        strength = 3.
    elif kind == 'rubber':
        # Moulded micro-diamond tread; rough diffuse rubber remains the caller's colour.
        tread = np.minimum(line(X+Y,38,.12), line(X-Y,38,.12))
        ribs = np.maximum(line(X+Y,38,.035),line(X-Y,38,.035))
        albedo = .80 + .028*coarse + .014*grain - .025*ribs + .012*tread
        height = .022*grain - .035*ribs
        ao = .99 - .045*ribs
        roughness = .84 + .045*coarse + .03*grain
        strength = 3.
    elif kind == 'glass':
        smudges = noise(rng,8)
        scratches = np.maximum(noise(rng,3,203)-.72,0)
        albedo = .945 + .012*smudges - .025*scratches
        height = .0015*grain - .009*scratches
        ao = np.ones_like(X)
        roughness = .12 + .045*smudges + .25*scratches
        strength = 2.
    else:
        raise ValueError(kind)
    maps = {
        'albedo': pixels(albedo[...,None]*tint),
        'normal': normal_from_height(height,strength),
        'orm': pixels(np.stack((ao,np.clip(roughness,.04,.98),metallic),axis=-1)),
    }
    return maps


def encoded(array):
    stream = io.BytesIO()
    Image.fromarray(array).save(stream, format='PNG', optimize=True)
    return stream.getvalue()


def linear_mean(array):
    srgb = array.astype(np.float64)/255.
    linear = np.where(srgb<=.04045,srgb/12.92,((srgb+.055)/1.055)**2.4)
    return float(np.mean(linear @ np.array([.2126,.7152,.0722])))


def seam_score(array):
    # Adjacent edge pixels need not match: compare wrapped gradient with all interior gradients.
    data = array.astype(float)/255.
    interior = np.concatenate((np.diff(data,axis=0).reshape(-1),np.diff(data,axis=1).reshape(-1)))
    edges = np.concatenate(((data[0]-data[-1]).reshape(-1),(data[:,0]-data[:,-1]).reshape(-1)))
    return float(np.mean(np.abs(edges))/(np.mean(np.abs(interior))+1e-9))


def verify(kind,maps):
    for channel,array in maps.items():
        assert array.shape == (SIZE,SIZE,3), (kind,channel,array.shape)
        assert np.isfinite(array).all()
        assert seam_score(array) < 24, (kind,channel,'unbounded seam gradient',seam_score(array))
    decoded = maps['normal'].astype(float)/255.*2-1
    lengths = np.linalg.norm(decoded,axis=-1)
    assert np.max(abs(lengths-1)) < .009, (kind,'unnormalized normal')
    assert decoded[...,2].min() > .5, (kind,'over-strong relief')
    assert maps['orm'][...,0].min() >= 150, (kind,'baked lighting in AO')
    assert maps['orm'][...,1].min() >= 10, (kind,'invalid roughness')
    if kind not in ('painted_alloy','brushed_metal'):
        assert maps['orm'][...,2].max() == 0, (kind,'non-metallic material')
    assert maps['albedo'].std() > .35, (kind,'empty material')


def import_settings(source):
    target = f'res://assets/materials/{source.parent.name}/{source.name}'
    digest = hashlib.md5(target.encode()).hexdigest()
    imported = f'res://.godot/imported/{source.name}-{digest}.ctex'
    normal = source.stem == 'normal'
    # Lossless mipmapped RGB works on the GL Compatibility renderer and does not
    # quantise data maps into sRGB. Platform export can subsequently compress VRAM.
    return f'''[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath="{imported}"\nmetadata={{\n"vram_texture": false\n}}\n\n[deps]\n\nsource_file="{target}"\ndest_files=["{imported}"]\n\n[params]\n\ncompress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\ncompress/uastc_level=0\ncompress/rdo_quality_loss=0.0\ncompress/hdr_compression=1\ncompress/normal_map={1 if normal else 0}\ncompress/channel_pack=0\nmipmaps/generate=true\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=""\nprocess/fix_alpha_border=false\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=0\n'''


def verify_periodicity(kind, seed, maps):
    global X, Y
    saved_x, saved_y = X, Y
    try:
        X, Y = X + 1.0, Y - 1.0
        repeated = authored(kind, seed)
    finally:
        X, Y = saved_x, saved_y
    for channel in maps:
        delta = abs(maps[channel].astype(int)-repeated[channel].astype(int))
        assert delta.max() <= 1, (kind,channel,'surface does not repeat at integer UV offsets',delta.max())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    flat = normal_from_height(np.zeros_like(X), 1)
    assert np.all(flat == np.array([128,128,255],dtype=np.uint8)), 'flat OpenGL normal contract'
    u_ramp = normal_from_height(np.sin(X*2*np.pi),1)
    v_ramp = normal_from_height(np.sin(Y*2*np.pi),1)
    assert u_ramp[0,0,0] < 128 and v_ramp[0,0,1] > 128, 'OpenGL tangent normal handedness'
    manifest = {'version':VERSION,'resolution':SIZE,'license':'CC0-1.0','authoring':'Original deterministic authored periodic PBR surfaces; no downloaded artwork or baked illumination.', 'normal_convention':'OpenGL +Y; image Y grows down; no Y inversion on import', 'orm_channels':{'r':'ambient_occlusion','g':'roughness','b':'metallic'}, 'materials':{}}
    total=0
    previews=[]
    for index,kind in enumerate(KINDS):
        seed=534021+index*7919
        maps=authored(kind,seed)
        verify(kind,maps)
        verify_periodicity(kind,seed,maps)
        entry={'seed':seed,'mean_linear_luminance':round(linear_mean(maps['albedo']),8),'normal_strength':1.0,'mean_roughness':round(float(maps['orm'][...,1].mean()/255),8),'mean_metallic':round(float(maps['orm'][...,2].mean()/255),8),'files':{}}
        directory=ROOT/kind
        if not args.check:
            directory.mkdir(parents=True,exist_ok=True)
        for channel,array in maps.items():
            content=encoded(array)
            path=directory/f'{channel}.png'
            total+=len(content)
            if args.check:
                assert path.read_bytes()==content, f'{path}: differs from deterministic generator'
            else:
                path.write_bytes(content)
                settings=Path(str(path)+'.import')
                # Existing import UIDs generated by Godot remain stable on regeneration.
                if not settings.exists():
                    settings.write_text(import_settings(path))
            entry['files'][channel]={'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content),'seam_gradient_ratio':round(seam_score(array),3)}
        manifest['materials'][kind]=entry
        previews.append((kind,maps))
    assert total<15*1024*1024, ('texture source budget exceeded',total)
    content=json.dumps(manifest,indent=2,ensure_ascii=False)+'\n'
    if args.check:
        assert (ROOT/'manifest.json').read_text()==content, 'metadata differs from generator'
    else:
        (ROOT/'manifest.json').write_text(content)
        # Review contact sheet: raw base colour, normal and ORM, not an in-game render.
        from PIL import ImageDraw
        sheet=Image.new('RGB',(3*256,8*280),(22,26,32))
        draw=ImageDraw.Draw(sheet)
        for row,(kind,maps) in enumerate(previews):
            draw.text((8,row*280+4),kind,fill=(220,225,235))
            for col,channel in enumerate(('albedo','normal','orm')):
                sheet.paste(Image.fromarray(maps[channel]).resize((256,256)),(col*256,row*280+24))
        sheet.save(ROOT/'texture_contact_sheet.jpg',quality=90)
    print(f'MATERIAL ASSETS: {len(KINDS)} families, {len(KINDS)*3} periodic PBR maps, {SIZE}x{SIZE}, {total/1024/1024:.2f} MiB; deterministic and physical checks passed')

if __name__=='__main__':
    main()
