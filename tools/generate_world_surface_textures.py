#!/usr/bin/env python3
"""Author original seamless natural PBR surfaces, independent of game geography.

Requires NumPy/Pillow. --check reproduces PNG/manifest bytes without modifying
assets, and verifies toroidal periodicity, transfer functions, normal handedness,
unit normals, material ranges and analytic sub-pixel coverage.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
KINDS = ("earth", "rock", "desert", "ice")
CHANNELS = ("albedo", "normal", "orm")
ROOT = Path(__file__).resolve().parents[1] / "assets/world_surfaces"
Y, X = np.mgrid[:SIZE, :SIZE].astype(np.float64) / SIZE


def smoothstep(low, high, value):
    t = np.clip((value-low)/(high-low), 0, 1)
    return t*t*(3-2*t)


def noise(rng, cells_x, cells_y=None):
    """Periodic smooth lattice noise sampled without duplicated boundary pixels."""
    cells_y = cells_y or cells_x
    lattice = rng.uniform(-1, 1, (cells_y, cells_x))
    px, py = X*cells_x, Y*cells_y
    ix, iy = np.floor(px).astype(int), np.floor(py).astype(int)
    fx, fy = px-ix, py-iy
    fx = fx*fx*(3-2*fx)
    fy = fy*fy*(3-2*fy)
    return ((1-fx)*lattice[iy % cells_y, ix % cells_x] + fx*lattice[iy % cells_y, (ix+1) % cells_x])*(1-fy) + ((1-fx)*lattice[(iy+1) % cells_y, ix % cells_x] + fx*lattice[(iy+1) % cells_y, (ix+1) % cells_x])*fy


def cellular(rng, cells, warp_x=0.0, warp_y=0.0):
    """Nearest two toroidal sites, nearest vector and site identity.

    A 5x5 search also covers corner cases where two nearest sites lie beyond
    adjacent cells. Restricting this to3x3 can create false fissures at cell edges.
    Domains may be warped by any periodic field; each integer UV shift is exact.
    """
    sites = rng.uniform(0.08, 0.92, (cells, cells, 2))
    px, py = (X+warp_x)*cells, (Y+warp_y)*cells
    ix, iy = np.floor(px).astype(int), np.floor(py).astype(int)
    fx, fy = px-ix, py-iy
    first = np.full_like(X, np.inf)
    second = np.full_like(X, np.inf)
    dx = np.zeros_like(X)
    dy = np.zeros_like(X)
    identity = np.zeros_like(ix)
    for oy in (-2, -1, 0, 1, 2):
        for ox in (-2, -1, 0, 1, 2):
            jx, jy = (ix+ox) % cells, (iy+oy) % cells
            cx = sites[jy, jx, 0]+ox-fx
            cy = sites[jy, jx, 1]+oy-fy
            distance = cx*cx+cy*cy
            closer = distance < first
            second = np.where(closer, first, np.minimum(second, distance))
            first = np.minimum(first, distance)
            dx = np.where(closer, cx, dx)
            dy = np.where(closer, cy, dy)
            identity = np.where(closer, jy*cells+jx, identity)
    return np.sqrt(first), np.sqrt(second), dx, dy, identity


def pebble_field(rng, cells, broad):
    """Varied, analytic antialiased elliptical mineral inclusions, not highlights."""
    first, second, dx, dy, identity = cellular(rng, cells, broad*0.006, broad*0.004)
    per_site = rng.uniform(0, 1, (cells*cells, 4))[identity]
    angle = per_site[..., 0]*np.pi
    c, s = np.cos(angle), np.sin(angle)
    ax = 0.10+per_site[..., 1]*0.20
    ay = ax*(0.45+per_site[..., 2]*0.45)
    local_x, local_y = (dx*c+dy*s)/ax, (dy*c-dx*s)/ay
    radius = np.sqrt(local_x**2+local_y**2)
    angle = np.arctan2(local_y, local_x)
    radius *= 1+0.13*np.sin(angle*5+per_site[..., 3]*11)+noise(rng, 137)*0.09
    aa = cells/(SIZE*np.maximum(ay, 0.01))*0.75
    mask = 1-smoothstep(1-aa, 1+aa, radius)
    dome = np.sqrt(np.maximum(0, 1-np.minimum(radius, 1)**2))*mask
    return mask, dome, per_site[..., 3], first, second


def pixels(value):
    if value.ndim == 2:
        value = np.repeat(value[..., None], 3, axis=-1)
    return np.clip(np.rint(value*255), 0, 255).astype(np.uint8)


def normals_from_height(height, strength):
    # Image Y points down. OpenGL tangent +Y points up: green = +dH/dImageY.
    dx = (np.roll(height, -1, axis=1)-np.roll(height, 1, axis=1))*0.5*strength
    dy = (np.roll(height, -1, axis=0)-np.roll(height, 1, axis=0))*0.5*strength
    normals = np.stack((-dx, dy, np.ones_like(height)), axis=-1)
    normals /= np.linalg.norm(normals, axis=-1)[..., None]
    return pixels(normals*0.5+0.5)


def authored(kind, seed):
    rng = np.random.default_rng(seed)
    broad = noise(rng, 5)*0.50+noise(rng, 13)*0.30+noise(rng, 37)*0.20
    middle = noise(rng, 89)
    fine = noise(rng, 263)*0.72+noise(rng, 449)*0.28
    ao = np.full_like(X, 0.99)
    strength = 5.5
    if kind == "earth":
        # Soil, fine root-like fibres, low organic cover and irregular pebbles.
        cover = smoothstep(-0.13, 0.18, noise(rng, 17)+broad*0.6)
        fibres = smoothstep(0.12, 0.6, noise(rng, 73, 197))*cover
        pores = smoothstep(0.18, 0.70, -noise(rng, 187))
        pebbles, dome, tone, _, _ = pebble_field(rng, 29, broad)
        matrix = 0.63+broad*0.10+middle*0.023+fine*0.013-pores*0.035
        organic = 0.56+broad*0.08+middle*0.033+fibres*0.031+fine*0.012
        shade = matrix*(1-cover)+organic*cover
        albedo = np.stack((shade*(1.015-cover*0.035), shade*(0.995+cover*0.025), shade*0.965), axis=-1)
        stone = (0.60+tone*0.14+fine*0.05+middle*0.012)[..., None]*np.array([1.01, 1.0, 0.98])
        albedo = albedo*(1-pebbles[..., None])+stone*pebbles[..., None]
        height = broad*0.13+middle*0.027+fine*0.015+fibres*0.020-pores*0.025+dome*0.19
        rough = 0.91+broad*0.035+fine*0.016-cover*0.03-pebbles*0.08
        ao -= pores*0.065+pebbles*(1-dome)*0.065
    elif kind == "rock":
        warp = noise(rng, 43)
        first, second, _, _, identity = cellular(rng, 11, broad*0.022+warp*0.008, broad*0.014-warp*0.006)
        per_site = rng.uniform(-1, 1, 11*11)[identity]
        aa = 11/SIZE
        fracture = 1-smoothstep(0.017-aa, 0.017+aa, second-first)
        vein = 1-smoothstep(0.041-aa, 0.041+aa, second-first)
        strata = np.sin((X*9+Y*5)*2*np.pi+noise(rng, 7)*2.1)
        mineral = smoothstep(0.30, 0.72, noise(rng, 127))*0.022
        shade = 0.68+broad*0.11+per_site*0.036+strata*0.025+middle*0.018+fine*0.014-fracture*0.13+vein*0.016+mineral
        albedo = shade[..., None]*np.array([1.005, 1.0, 0.99])
        height = broad*0.18+per_site*0.035+strata*0.035+middle*0.035+fine*0.014-fracture*0.12
        rough = 0.84+broad*0.046+middle*0.018+fine*0.018+fracture*0.06-mineral*0.8
        ao -= fracture*0.17+vein*0.025
        strength = 6.8
    elif kind == "desert":
        # Periodic, domain-warped wind ripples; dry clay patches have separate cracks.
        warp = noise(rng, 7)*0.9+noise(rng, 19)*0.30
        phase = (X*3+Y*31)*2*np.pi+warp
        ripples = np.maximum(0, np.sin(phase))**1.7
        clay = smoothstep(0.08, 0.38, noise(rng, 9)+broad*0.7)
        first, second, _, _, identity = cellular(rng, 13, broad*0.018, broad*0.01)
        aa = 13/SIZE
        cracks = (1-smoothstep(0.018-aa, 0.018+aa, second-first))*clay
        grain = smoothstep(0.18, 0.7, noise(rng, 401))
        shade = 0.73+broad*0.07+middle*0.018+fine*0.014+grain*0.018+clay*0.015-cracks*0.12
        albedo = shade[..., None]*np.array([1.02, 1.0, 0.965])
        height = broad*0.08+ripples*0.11*(1-clay*0.75)+middle*0.014+fine*0.016+grain*0.013-cracks*0.080
        rough = 0.94+broad*0.020+fine*0.016-clay*0.045
        ao -= cracks*0.14
        strength = 6.3
    elif kind == "ice":
        # Frozen cloudy layers, fine frost crystals and a connected fissure network.
        first, second, _, _, identity = cellular(rng, 7, broad*0.027, broad*0.021)
        aa = 7/SIZE
        crack = 1-smoothstep(0.009-aa*0.65, 0.009+aa*0.65, second-first)
        frosted_rim = 1-smoothstep(0.032-aa, 0.032+aa, second-first)
        frost = smoothstep(-0.12, 0.36, noise(rng, 27)+broad*0.4)
        crystals = smoothstep(0.19, 0.66, noise(rng, 233))*frost
        trapped = smoothstep(0.31, 0.77, noise(rng, 83))
        layers = np.sin((X*2+Y*7)*2*np.pi+noise(rng, 9)*2)*0.012
        shade = 0.77+broad*0.046+layers+frost*0.07+crystals*0.020+trapped*0.016+fine*0.006-crack*0.115+frosted_rim*0.016
        albedo = shade[..., None]*np.array([0.985, 0.998, 1.01])
        height = broad*0.025+frost*0.019+crystals*0.013+fine*0.007-crack*0.080+frosted_rim*0.009
        rough = 0.24+frost*0.36+crystals*0.07+middle*0.022-crack*0.08
        ao -= crack*0.055
        strength = 5.2
    else:
        raise ValueError(kind)
    return {"albedo": pixels(albedo), "normal": normals_from_height(height, strength), "orm": pixels(np.stack((np.clip(ao, 0.80, 1), np.clip(rough, 0.08, 0.98), np.zeros_like(X)), axis=-1))}


def encode(array):
    output = io.BytesIO()
    Image.fromarray(array).save(output, format="PNG", compress_level=9, optimize=False)
    return output.getvalue()


def linear_luminance(array):
    values = array.astype(np.float64)/255
    linear = np.where(values <= 0.04045, values/12.92, ((values+0.055)/1.055)**2.4)
    return float(np.mean(linear@np.array([0.2126, 0.7152, 0.0722])))


def seam_score(array):
    values = array.astype(np.float64)/255
    interior = np.concatenate((np.diff(values, axis=0).reshape(-1), np.diff(values, axis=1).reshape(-1)))
    wrapped = np.concatenate(((values[0]-values[-1]).reshape(-1), (values[:, 0]-values[:, -1]).reshape(-1)))
    return float(np.mean(np.abs(wrapped))/(np.mean(np.abs(interior))+1e-9))


def check_maps(kind, maps):
    for channel, array in maps.items():
        assert array.shape == (SIZE, SIZE, 3) and array.dtype == np.uint8, (kind, channel, "RGB1024 shape")
        assert seam_score(array) < 3.5, (kind, channel, "seam gradient", seam_score(array))
    vectors = maps["normal"].astype(np.float64)/255*2-1
    assert np.max(np.abs(np.linalg.norm(vectors, axis=-1)-1)) < 0.009, (kind, "normal length")
    assert vectors[..., 2].min() > 0.68, (kind, "excessive microrelief")
    assert maps["orm"][..., 0].min() >= 204 and maps["orm"][..., 1].min() >= 20, (kind, "material range")
    assert maps["orm"][..., 2].max() == 0, (kind, "natural dielectric must not be metallic")
    assert maps["albedo"].std() > 4, (kind, "empty colour texture")


def check_periodicity(kind, seed, maps):
    global X, Y
    saved_x, saved_y = X, Y
    try:
        X, Y = X+1, Y-1
        repeated = authored(kind, seed)
    finally:
        X, Y = saved_x, saved_y
    for channel in CHANNELS:
        delta = np.abs(maps[channel].astype(np.int16)-repeated[channel].astype(np.int16))
        assert delta.max() <= 1, (kind, channel, "integer torus shift", delta.max())


def import_settings(kind, channel):
    target = f"res://assets/world_surfaces/{kind}/{channel}.png"
    digest = hashlib.md5(target.encode()).hexdigest()
    imported = f"res://.godot/imported/{channel}.png-{digest}.ctex"
    return f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="{imported}"
metadata={{
"vram_texture": false
}}

[deps]
source_file="{target}"
dest_files=["{imported}"]

[params]
compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={1 if channel == "normal" else 0}
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    assert np.all(normals_from_height(np.zeros_like(X), 1) == np.array([128, 128, 255], dtype=np.uint8))
    assert normals_from_height(np.sin(X*2*np.pi), 2)[0, 0, 0] < 128
    assert normals_from_height(np.sin(Y*2*np.pi), 2)[0, 0, 1] > 128
    # Analytic edge coverage really contains partial pixels, without binary aliasing.
    analytic_edge = 1-smoothstep(0.99, 1.01, np.linspace(0.97, 1.03, 100))
    assert np.count_nonzero((analytic_edge > 0) & (analytic_edge < 1)) >= 30
    manifest = {"version": 1, "resolution": SIZE, "license": "CC0-1.0", "authoring": "Original deterministic toroidal natural PBR art: soil/organic cover/mineral pebbles, fractured strata, sand ripples/dry clay and fissured frozen layers. No borrowed imagery, baked directional illumination, macro geography or geometry.", "normal_convention": "OpenGL +Y; image rows grow down; no green inversion on import", "orm_channels": {"r": "ambient_occlusion", "g": "roughness", "b": "metallic"}, "edge_antialiasing": "Analytic subpixel coverage on pebble and fissure distance fields, mipmapped lossless imports", "materials": {}}
    total = 0
    for index, kind in enumerate(KINDS):
        seed = 1186207+index*7927
        maps = authored(kind, seed)
        check_maps(kind, maps)
        check_periodicity(kind, seed, maps)
        entry = {"seed": seed, "mean_linear_luminance": round(linear_luminance(maps["albedo"]), 8), "mean_roughness": round(float(maps["orm"][..., 1].mean()/255), 8), "mean_metallic": 0.0, "files": {}}
        if not args.check:
            (ROOT/kind).mkdir(parents=True, exist_ok=True)
        for channel, array in maps.items():
            content = encode(array)
            path = ROOT/kind/(channel+".png")
            total += len(content)
            if args.check:
                assert path.read_bytes() == content, (kind, channel, "PNG byte reproduction")
            else:
                path.write_bytes(content)
                settings = Path(str(path)+".import")
                if not settings.exists():
                    settings.write_text(import_settings(kind, channel))
            entry["files"][channel] = {"sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content), "seam_gradient_ratio": round(seam_score(array), 5)}
        manifest["materials"][kind] = entry
        print(f"WORLD SURFACE {kind}: linear mean {entry['mean_linear_luminance']}, roughness {entry['mean_roughness']}", flush=True)
    assert total < 12*1024*1024, ("Source PNG budget12MiB", total)
    content = json.dumps(manifest, indent=2, ensure_ascii=False)+"\n"
    if args.check:
        assert (ROOT/"manifest.json").read_text() == content, "manifest reproduction"
    else:
        (ROOT/"manifest.json").write_text(content)
        (ROOT/"LICENSE.txt").write_text("Original natural surface artwork: CC0-1.0. This does not change the provenance or license of other game resources.\n")
    print(f"WORLD SURFACE ART PASS:4 kinds,12 maps1024x1024,{total} bytes ({total/1024/1024:.2f}MiB); physical, periodic, antialias and byte reproduction checks passed")


if __name__ == "__main__":
    main()
