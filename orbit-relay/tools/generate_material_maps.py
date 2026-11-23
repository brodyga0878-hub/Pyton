#!/usr/bin/env python3
"""Bake tileable 1024² linear RGB material maps using NumPy and Pillow."""

import argparse
from math import ceil, cos, floor, sin, tau
from pathlib import Path

import numpy as np
from PIL import Image


SIZE = 1024
AXIS = np.arange(SIZE, dtype=np.float32) / SIZE
U, V = np.meshgrid(AXIS, AXIS)
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "materials"


def smooth(value):
    value = np.clip(value, 0.0, 1.0)
    return value * value * (3.0 - 2.0 * value)


def noise(rng, u, v, columns, rows=None):
    """Value noise on a periodic lattice, with smooth first derivatives."""
    rows = columns if rows is None else rows
    lattice = rng.uniform(-1.0, 1.0, size=(rows, columns)).astype(np.float32)
    x, y = u * columns, v * rows
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    fx, fy = smooth(x - ix), smooth(y - iy)
    x0, y0 = ix % columns, iy % rows
    x1, y1 = (ix + 1) % columns, (iy + 1) % rows
    top = lattice[y0, x0] + (lattice[y0, x1] - lattice[y0, x0]) * fx
    bottom = lattice[y1, x0] + (lattice[y1, x1] - lattice[y1, x0]) * fx
    return (top + (bottom - top) * fy).astype(np.float32)


def layered(rng, u, v, octaves):
    result = np.zeros_like(u)
    for cells, weight in octaves:
        result += weight * noise(rng, u, v, cells)
    return result


def cells(rng, u, v, columns, rows):
    """Return the nearest mineral cell tone and distance to its boundaries."""
    pattern = rng.uniform(0.15, 0.85, size=(rows, columns, 3)).astype(np.float32)
    x, y = u * columns, v * rows
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    closest = np.full_like(x, np.inf)
    runner_up = closest.copy()
    tone = np.zeros_like(x)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            sx, sy = ix + dx, iy + dy
            feature = pattern[sy % rows, sx % columns]
            distance = ((x - sx - feature[:, :, 0]) ** 2 + (y - sy - feature[:, :, 1]) ** 2).astype(np.float32)
            nearer = distance < closest
            runner_up = np.where(nearer, closest, np.minimum(runner_up, distance))
            closest = np.minimum(closest, distance)
            tone = np.where(nearer, feature[:, :, 2], tone)
    return tone - 0.5, np.sqrt(runner_up) - np.sqrt(closest)


def centered(signal, scale=1.0):
    return 0.5 + (signal - signal.mean()) * scale


def stamp_coordinates(center_x, center_y, angle, radius_x, radius_y):
    """Create a rotated local patch with indices wrapped onto the atlas."""
    cos_angle, sin_angle = cos(angle), sin(angle)
    extent_x = abs(cos_angle) * radius_x + abs(sin_angle) * radius_y
    extent_y = abs(sin_angle) * radius_x + abs(cos_angle) * radius_y
    columns = np.arange(floor((center_x - extent_x) * SIZE), ceil((center_x + extent_x) * SIZE) + 1)
    rows = np.arange(floor((center_y - extent_y) * SIZE), ceil((center_y + extent_y) * SIZE) + 1)
    x = columns[None, :] / SIZE - center_x
    y = rows[:, None] / SIZE - center_y
    return np.ix_(rows % SIZE, columns % SIZE), x * cos_angle + y * sin_angle, -x * sin_angle + y * cos_angle


def surface_marks(rng, count, radii, ratios, angularity):
    """Stamp irregular pits with a shallow rim and independent depth."""
    cores = np.zeros_like(U)
    rims = np.zeros_like(U)
    for center_x, center_y, turn, length, aspect, phase, depth in rng.uniform(size=(count, 7)):
        radius_x = radii[0] + length * (radii[1] - radii[0])
        radius_y = radius_x * (ratios[0] + aspect * (ratios[1] - ratios[0]))
        region, along, across = stamp_coordinates(center_x, center_y, tau * turn, radius_x * 1.65, radius_y * 1.65)
        along /= radius_x
        across /= radius_y
        direction = np.arctan2(across, along)
        outline = 1.0 + angularity * (
            0.68 * np.cos(3.0 * direction + tau * phase) + 0.32 * np.cos(5.0 * direction - tau * turn)
        )
        radius = np.hypot(along, across) / outline
        weight = 0.38 + depth * 0.62
        core = 1.0 - smooth((radius - 0.55) / 0.45)
        rim = 1.0 - smooth(np.abs(radius - 0.95) / 0.26)
        cores[region] = np.maximum(cores[region], (core * weight).astype(np.float32))
        rims[region] = np.maximum(rims[region], (rim * weight).astype(np.float32))
    return cores, rims


def basalt(rng):
    u = U + 0.052 * noise(rng, U, V, 5) + 0.011 * noise(rng, U, V, 18)
    v = V + 0.047 * noise(rng, U, V, 6) + 0.010 * noise(rng, U, V, 23)
    plate, boundary = cells(rng, u, v, 9, 11)
    shard, smaller_boundary = cells(rng, u + v, v, 29, 24)
    bedding = layered(rng, u, v, [(4, 0.45), (14, 0.25), (36, 0.17), (77, 0.13)])
    laminae = noise(rng, u, v + u, 8, 51)
    grit = layered(rng, U, V, [(65, 0.45), (159, 0.32), (367, 0.23)])
    width = 0.049 + 0.041 * smooth((bedding + 0.35) / 0.65)
    fracture_density = 0.25 + 0.75 * smooth((0.30 + bedding + 0.23 * laminae) / 0.65)
    fissure = np.exp(-((boundary / width) ** 2)) * fracture_density
    shoulder = np.exp(-(((boundary - 1.40 * width) / (0.64 * width)) ** 2)) * fracture_density
    hairline = np.exp(-((smaller_boundary / 0.044) ** 2)) * smooth((bedding + 0.32 + 0.18 * laminae) / 0.58)
    plate *= 0.59 + 0.41 * fracture_density
    mineral = smooth((0.7 * grit + 0.62 * shard - 0.17) / 0.28)
    pits, pit_rims = surface_marks(rng, 840, (0.0014, 0.0076), (0.46, 0.94), 0.32)
    porosity = smooth((bedding + 0.21) / 0.50)
    pits *= porosity
    pit_rims *= porosity
    height = centered(
        0.27 * plate + 0.41 * bedding + 0.085 * laminae + 0.13 * grit - 0.29 * fissure
        + 0.065 * shoulder - 0.11 * hairline + 0.051 * mineral - 0.15 * pits
    )
    tone = centered(
        0.22 * plate + 0.31 * bedding + 0.092 * laminae + 0.16 * grit - 0.25 * fissure
        + 0.05 * shoulder - 0.068 * hairline + 0.10 * mineral - 0.12 * pits + 0.05 * pit_rims
    )
    roughness = 0.78 + 0.14 * grit + 0.10 * fissure + 0.067 * hairline - 0.11 * mineral + 0.13 * pits
    return tone, height, roughness


def fractured_ice(rng):
    u = U + 0.064 * noise(rng, U, V, 5) + 0.011 * noise(rng, U, V, 26)
    v = V + 0.051 * noise(rng, U, V, 6) + 0.016 * noise(rng, U, V, 25)
    plate, boundary = cells(rng, u + v, v, 6, 9)
    _, branch = cells(rng, u - v, v, 23, 21)
    frost = layered(rng, u, v, [(5, 0.47), (16, 0.27), (43, 0.16), (108, 0.10)])
    powder = layered(rng, U, V, [(109, 0.52), (229, 0.28), (419, 0.20)])
    vein_width = 0.038 + 0.033 * smooth((frost + 0.32) / 0.68)
    stress = 0.29 + 0.71 * smooth((0.29 + frost + 0.25 * noise(rng, u + v, v, 13, 18)) / 0.53)
    veins = np.exp(-((boundary / vein_width) ** 2)) * stress
    halo = np.exp(-((boundary / (vein_width * 2.7)) ** 2)) * stress - veins
    microveins = np.exp(-((branch / 0.043) ** 2)) * smooth((frost + 0.18) / 0.39)
    frozen_layers = noise(rng, u + v, v, 8, 107)
    air, air_rims = surface_marks(rng, 720, (0.0016, 0.0105), (0.49, 0.93), 0.24)
    pocket_density = smooth((frost + 0.28) / 0.51)
    specks = smooth((powder - 0.31) / 0.36) * pocket_density
    air *= pocket_density
    air_rims *= pocket_density
    tone = centered(
        0.16 * plate + 0.34 * frost + 0.26 * veins + 0.081 * halo
        + 0.091 * microveins + 0.05 * frozen_layers + 0.13 * air_rims - 0.064 * air + 0.08 * specks
    )
    height = centered(
        0.17 * plate + 0.26 * frost - 0.24 * veins - 0.04 * halo
        - 0.078 * microveins + 0.062 * powder - 0.07 * air
    )
    roughness = 0.38 + 0.27 * frost + 0.16 * microveins + 0.055 * halo + 0.11 * veins         + 0.12 * air_rims + 0.065 * powder + 0.10 * specks
    return tone, height, roughness


def scratches(rng, count, angle, lengths=(0.018, 0.128), widths=(0.0006, 0.0026), spread=0.27):
    """Stamp tapered, intermittently shallow scratches without seams."""
    result = np.zeros_like(U)
    for center_x, center_y, tilt, length, width, variation, depth in rng.uniform(size=(count, 7)):
        direction = angle + (tilt - 0.5) * spread
        extent = lengths[0] + length * (lengths[1] - lengths[0])
        radius = widths[0] + width * (widths[1] - widths[0])
        region, parallel, across = stamp_coordinates(center_x, center_y, direction, extent, 3.0 * radius)
        taper = 1.0 - smooth((np.abs(parallel) / extent - 0.63) / 0.37)
        line = np.exp(-((across / radius) ** 2)) * (1.0 - smooth((np.abs(across) / radius - 2.4) / 0.6))
        interrupted = 0.79 + 0.21 * np.cos(tau * (parallel / extent * (1.2 + variation) + tilt))
        score = line * taper * interrupted * (0.34 + depth * 0.66)
        result[region] = np.maximum(result[region], score.astype(np.float32))
    return result


def brushed_metal(rng):
    flow = V + 0.006 * noise(rng, U, V, 5, 6) + 0.0017 * noise(rng, U, V, 11, 14)
    long_tracks = noise(rng, U + 0.055 * noise(rng, U, V, 5), flow, 9, 169)
    fine_tracks = noise(rng, U, flow, 29, 307)
    bristles = noise(rng, U, flow, 71, 441)
    broad = layered(rng, U, V, [(4, 0.68), (17, 0.32)])
    fine = 0.53 * long_tracks + 0.31 * fine_tracks + 0.16 * bristles
    scuff = scratches(rng, 118, 0.04)
    fine_scuff = scratches(rng, 185, -0.053, (0.010, 0.051), (0.00043, 0.00103), 0.38)
    lips = np.maximum(0.0, np.roll(scuff, 1, axis=0) - scuff)
    dust = noise(rng, U, V, 332)
    # The brushed tracks vary with overlapping tool passes and oxide patches.
    passes = noise(rng, U, flow, 6, 37)
    satin = smooth((0.27 + 0.44 * passes + 0.32 * broad) / 0.56)
    oxide = smooth((broad + 0.28 * noise(rng, U, V, 39) - 0.17) / 0.48)
    grind = scratches(rng, 44, 0.022, (0.049, 0.176), (0.0016, 0.0038), 0.094)
    tracks = fine * (0.70 + 0.36 * satin)
    tone = centered(
        0.33 * tracks + 0.14 * broad + 0.059 * satin - 0.13 * oxide - 0.16 * scuff
        - 0.06 * fine_scuff - 0.12 * grind + 0.10 * lips + 0.032 * dust
    )
    height = centered(
        0.28 * tracks + 0.075 * broad - 0.17 * scuff - 0.077 * fine_scuff
        - 0.13 * grind + 0.039 * lips + 0.026 * dust
    )
    roughness = (
        0.38 + 0.072 * broad + 0.095 * tracks + 0.19 * scuff + 0.12 * fine_scuff
        + 0.14 * grind + 0.16 * oxide - 0.10 * satin - 0.065 * lips
    )
    return tone, height, roughness


def painted_metal(rng):
    u = U + 0.019 * noise(rng, U, V, 7) + 0.004 * noise(rng, U, V, 23)
    v = V + 0.018 * noise(rng, U, V, 6) + 0.004 * noise(rng, U, V, 25)
    orange_peel = layered(rng, u, v, [(81, 0.46), (163, 0.32), (321, 0.22)])
    patch = layered(rng, u, v, [(6, 0.55), (17, 0.30), (38, 0.15)])
    pigment = noise(rng, u + v, v, 124, 151)
    wear = noise(rng, u, v, 18, 25) + 0.47 * noise(rng, u + v, v, 66, 59) + 0.32 * patch
    large_chips = smooth((wear - 0.79) / 0.25)
    broken_edge = np.exp(-(((wear - 0.8) / 0.075) ** 2))
    small_chips, rims = surface_marks(rng, 570, (0.0020, 0.0155), (0.26, 0.78), 0.38)
    wear_density = smooth((0.31 + patch + 0.16 * pigment) / 0.62)
    chip = np.maximum(large_chips, small_chips * wear_density)
    rim = np.maximum(broken_edge * 0.53, rims * wear_density) * (1.0 - 0.55 * chip)
    scrape = scratches(rng, 82, -0.25)
    scars = scratches(rng, 117, 0.20, (0.012, 0.070), (0.00051, 0.00138), 0.65)
    skim = noise(rng, u, v, 23, 263)
    impacts, impact_rims = surface_marks(rng, 47, (0.0048, 0.022), (0.75, 0.97), 0.24)
    faded_paint = smooth((0.31 + patch + 0.18 * noise(rng, u, v, 31)) / 0.68)
    tone = centered(
        0.17 * orange_peel + 0.15 * patch + 0.025 * pigment - 0.26 * chip
        + 0.13 * rim - 0.13 * scrape - 0.061 * scars + 0.073 * skim * chip
        + 0.092 * faded_paint - 0.22 * impacts + 0.094 * impact_rims
    )
    height = centered(
        0.15 * orange_peel + 0.085 * patch - 0.235 * chip + 0.075 * rim
        - 0.13 * scrape - 0.067 * scars - 0.28 * impacts + 0.050 * impact_rims
    )
    roughness = (
        0.49 + 0.13 * faded_paint + 0.095 * orange_peel - 0.23 * chip + 0.13 * rim
        + 0.22 * scrape + 0.10 * scars + 0.19 * impact_rims - 0.12 * impacts
    )
    return tone, height, roughness


def cloud_bands(rng):
    u, v = U.copy(), V.copy()
    eyes = np.zeros_like(U)
    for x, y, radius, strength, ellipticity in [
        (0.27, 0.37, 0.15, 4.4, 1.46), (0.72, 0.62, 0.16, -4.1, 1.31),
        (0.90, 0.14, 0.11, 3.4, 1.59), (0.48, 0.83, 0.092, -3.5, 1.44),
    ]:
        dx = ((u - x + 0.5) % 1.0 - 0.5) / ellipticity
        dy = (v - y + 0.5) % 1.0 - 0.5
        distance = np.hypot(dx, dy)
        asymmetry = 0.86 + 0.42 * np.clip(dx / radius, -0.30, 0.30)
        angle = strength * smooth(1.0 - distance / radius) * asymmetry
        u += ellipticity * (dx * (np.cos(angle) - 1.0) - dy * np.sin(angle))
        v += dx * np.sin(angle) + dy * (np.cos(angle) - 1.0)
        ring = np.exp(-(((distance / radius - 0.31 - 0.40 * dx) / 0.14) ** 2))
        eyes = np.maximum(eyes, ring * smooth((1.0 - distance / radius) / 0.43) * asymmetry)
    jet = noise(rng, u, v, 7, 11)
    shear = v + 0.036 * jet + 0.011 * noise(rng, u, v, 22, 29)
    belt_velocity = u + 0.035 * np.sin(tau * 7.0 * shear + jet * 0.8)
    belts = np.sin(tau * (9.0 * shear + 0.12 * jet))         + 0.42 * np.sin(tau * (16.0 * shear + 0.2 * noise(rng, u, v, 9, 7)))
    veils = layered(rng, u, v, [(7, 0.34), (17, 0.28), (39, 0.22), (91, 0.16)])
    filament = 0.50 * noise(rng, belt_velocity, shear, 13, 67) + 0.29 * noise(rng, belt_velocity, shear, 31, 145)         + 0.14 * noise(rng, belt_velocity, shear, 81, 233) + 0.07 * noise(rng, belt_velocity, shear, 127, 389)
    wave = noise(rng, belt_velocity, shear, 8, 32)
    overshoot = smooth((filament + 0.58 * veils + 0.25 * wave + 0.16) / 0.63)
    billow = smooth((0.67 * veils + 0.28 * filament + 0.15 * wave + 0.20) / 0.52)
    bright_shear = smooth((filament - 0.14) / 0.36)
    tone = centered(0.082 * belts + 0.25 * filament + 0.18 * veils + 0.091 * eyes + 0.068 * billow)
    flow = centered(0.163 * belts + 0.20 * filament + 0.12 * veils + 0.10 * overshoot)
    secondary = centered(0.065 * belts + 0.16 * veils + 0.11 * bright_shear - 0.17 * filament + 0.14 * eyes)
    return tone, flow, secondary


def bake(output):
    output.mkdir(parents=True, exist_ok=True)
    materials = (
        ("rock_basalt", basalt, 72491),
        ("rock_ice", fractured_ice, 81233),
        ("metal_brushed", brushed_metal, 66349),
        ("metal_paint", painted_metal, 94909),
        ("cloud_bands", cloud_bands, 79117),
    )
    for filename, function, seed in materials:
        fields = function(np.random.Generator(np.random.PCG64(seed)))
        packed = np.rint(255.0 * np.clip(np.stack(fields, axis=-1), 0.0, 1.0)).astype(np.uint8)
        # No ICC profile, gamma tag or sRGB chunk: these channels are shader data.
        Image.fromarray(packed).save(output / f"{filename}.png", compress_level=9)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT)
    bake(parser.parse_args().out)


if __name__ == "__main__":
    main()
