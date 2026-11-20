#!/usr/bin/env python3
"""Bake tileable linear RGB material maps using NumPy and Pillow."""

import argparse
from math import tau
from pathlib import Path

import numpy as np
from PIL import Image


SIZE = 512
AXIS = np.arange(SIZE, dtype=np.float64) / SIZE
U, V = np.meshgrid(AXIS, AXIS)
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "materials"


def smooth(value):
    value = np.clip(value, 0.0, 1.0)
    return value * value * (3.0 - 2.0 * value)


def noise(rng, u, v, columns, rows=None):
    """Value noise on a periodic lattice, with smooth first derivatives."""
    rows = columns if rows is None else rows
    lattice = rng.uniform(-1.0, 1.0, size=(rows, columns))
    x, y = u * columns, v * rows
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    fx, fy = smooth(x - ix), smooth(y - iy)
    x0, y0 = ix % columns, iy % rows
    x1, y1 = (ix + 1) % columns, (iy + 1) % rows
    top = (1.0 - fx) * lattice[y0, x0] + fx * lattice[y0, x1]
    bottom = (1.0 - fx) * lattice[y1, x0] + fx * lattice[y1, x1]
    return (1.0 - fy) * top + fy * bottom


def layered(rng, u, v, octaves):
    result = np.zeros_like(u)
    for cells, weight in octaves:
        result += weight * noise(rng, u, v, cells)
    return result


def cells(rng, u, v, columns, rows):
    """Return the nearest mineral cell tone and distance to its boundaries."""
    pattern = rng.uniform(0.15, 0.85, size=(rows, columns, 3))
    x, y = u * columns, v * rows
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    closest = np.full_like(x, np.inf)
    runner_up = closest.copy()
    tone = np.zeros_like(x)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            sx, sy = ix + dx, iy + dy
            feature = pattern[sy % rows, sx % columns]
            distance = (x - sx - feature[:, :, 0]) ** 2 + (y - sy - feature[:, :, 1]) ** 2
            nearer = distance < closest
            runner_up = np.where(nearer, closest, np.minimum(runner_up, distance))
            closest = np.minimum(closest, distance)
            tone = np.where(nearer, feature[:, :, 2], tone)
    return tone - 0.5, np.sqrt(runner_up) - np.sqrt(closest)


def centered(signal, scale=1.0):
    return 0.5 + (signal - signal.mean()) * scale


def basalt(rng):
    u = U + 0.045 * noise(rng, U, V, 5) + 0.012 * noise(rng, U, V, 17)
    v = V + 0.041 * noise(rng, U, V, 6) + 0.010 * noise(rng, U, V, 21)
    plate, boundary = cells(rng, u, v, 9, 11)
    _, smaller_boundary = cells(rng, u + v, v, 23, 19)
    bedding = layered(rng, u, v, [(4, 0.45), (14, 0.25), (33, 0.15), (91, 0.12)])
    grit = layered(rng, U, V, [(43, 0.44), (101, 0.31), (207, 0.25)])
    fissure = np.exp(-((boundary / (0.052 + 0.030 * (grit + 1.0))) ** 2))
    hairline = np.exp(-((smaller_boundary / 0.052) ** 2)) * smooth((bedding + 0.28) / 0.42)
    grains = smooth((grit - 0.22) / 0.30)
    height = centered(0.29 * plate + 0.39 * bedding + 0.12 * grit - 0.21 * fissure - 0.10 * hairline + 0.07 * grains)
    tone = centered(0.22 * plate + 0.26 * bedding + 0.18 * grit - 0.18 * fissure - 0.07 * hairline + 0.09 * grains)
    roughness = 0.78 + 0.14 * grit + 0.13 * fissure + 0.08 * hairline - 0.11 * grains
    return tone, height, roughness


def fractured_ice(rng):
    u = U + 0.052 * noise(rng, U, V, 5) + 0.012 * noise(rng, U, V, 25)
    v = V + 0.045 * noise(rng, U, V, 6) + 0.016 * noise(rng, U, V, 22)
    plate, boundary = cells(rng, u + v, v, 6, 9)
    _, branch = cells(rng, u - v, v, 19, 18)
    frost = layered(rng, u, v, [(5, 0.47), (15, 0.27), (41, 0.17), (96, 0.09)])
    powder = noise(rng, U, V, 156)
    veins = np.exp(-((boundary / 0.060) ** 2))
    microveins = np.exp(-((branch / 0.048) ** 2)) * smooth((frost + 0.12) / 0.36)
    frozen_layers = noise(rng, u + v, v, 7, 83)
    bubbles = smooth((powder - 0.52) / 0.31) * smooth((frost + 0.18) / 0.48)
    tone = centered(0.17 * plate + 0.31 * frost + 0.20 * veins + 0.09 * microveins + 0.05 * frozen_layers + 0.09 * bubbles)
    height = centered(0.21 * plate + 0.23 * frost - 0.18 * veins - 0.071 * microveins + 0.05 * powder)
    roughness = 0.39 + 0.28 * frost + 0.21 * microveins + 0.16 * bubbles + 0.11 * veins + 0.05 * powder
    return tone, height, roughness


def scratches(rng, count, angle):
    """Thin, tapered tracks stamped with toroidal distances at tile edges."""
    result = np.zeros_like(U)
    for center_x, center_y, tilt, length, width in rng.uniform(size=(count, 5)):
        direction = angle + (tilt - 0.5) * 0.26
        x = (U - center_x + 0.5) % 1.0 - 0.5
        y = (V - center_y + 0.5) % 1.0 - 0.5
        parallel = x * np.cos(direction) + y * np.sin(direction)
        across = -x * np.sin(direction) + y * np.cos(direction)
        taper = smooth((1.0 - np.abs(parallel) / (0.023 + length * 0.12)) / 0.32)
        line = np.exp(-((across / (0.0007 + width * 0.0022)) ** 2))
        result = np.maximum(result, line * taper)
    return result


def brushed_metal(rng):
    long_tracks = noise(rng, U + 0.1 * noise(rng, U, V, 3), V, 7, 185)
    fine_tracks = noise(rng, U, V, 24, 218)
    broad = layered(rng, U, V, [(4, 0.65), (18, 0.35)])
    fine = 0.62 * long_tracks + 0.38 * fine_tracks
    scuff = scratches(rng, 64, 0.03)
    dust = noise(rng, U, V, 204)
    tone = centered(0.24 * fine + 0.16 * broad - 0.19 * scuff + 0.033 * dust)
    height = centered(0.27 * fine + 0.09 * broad - 0.19 * scuff + 0.025 * dust)
    roughness = 0.34 + 0.11 * broad + 0.10 * fine + 0.23 * scuff
    return tone, height, roughness


def painted_metal(rng):
    u = U + 0.018 * noise(rng, U, V, 7)
    v = V + 0.017 * noise(rng, U, V, 6)
    orange_peel = layered(rng, u, v, [(69, 0.51), (126, 0.29), (223, 0.20)])
    patch = layered(rng, u, v, [(6, 0.54), (16, 0.31), (37, 0.15)])
    wear = noise(rng, u, v, 17, 23) + 0.54 * noise(rng, u + v, v, 62, 54) + 0.29 * patch
    chip = smooth((wear - 0.73) / 0.19)
    rim = np.exp(-((wear - 0.73) / 0.13) ** 2)
    scrape = scratches(rng, 45, -0.23)
    skim = noise(rng, u, v, 16, 192)
    tone = centered(0.17 * orange_peel + 0.18 * patch - 0.26 * chip + 0.14 * rim - 0.13 * scrape + 0.05 * skim * chip)
    height = centered(0.14 * orange_peel + 0.092 * patch - 0.21 * chip + 0.09 * rim - 0.12 * scrape)
    roughness = 0.53 + 0.13 * patch + 0.09 * orange_peel - 0.25 * chip + 0.12 * rim + 0.22 * scrape
    return tone, height, roughness


def cloud_bands(rng):
    u, v = U.copy(), V.copy()
    # Locally rotate the flow around storm cores; fade each rotation to zero.
    for x, y, radius, strength in [(0.27, 0.37, 0.17, 3.3), (0.72, 0.62, 0.19, -3.5), (0.90, 0.14, 0.13, 2.7)]:
        dx = (u - x + 0.5) % 1.0 - 0.5
        dy = (v - y + 0.5) % 1.0 - 0.5
        distance = np.sqrt(dx * dx + dy * dy)
        angle = strength * smooth(1.0 - distance / radius)
        u += dx * (np.cos(angle) - 1.0) - dy * np.sin(angle)
        v += dx * np.sin(angle) + dy * (np.cos(angle) - 1.0)
    shear = v + 0.037 * noise(rng, u, v, 7, 10) + 0.012 * noise(rng, u, v, 16, 29)
    belts = np.sin(tau * 9.0 * shear) + 0.45 * np.sin(tau * (15.0 * shear + 0.2 * noise(rng, u, v, 8, 7)))
    wisps = 0.60 * noise(rng, u, shear, 12, 57) + 0.26 * noise(rng, u, shear, 31, 111) + 0.14 * noise(rng, u, shear, 73, 187)
    billows = layered(rng, u, v, [(8, 0.42), (19, 0.28), (45, 0.19), (88, 0.11)])
    tone = centered(0.09 * belts + 0.26 * wisps + 0.18 * billows)
    flow = centered(0.17 * belts + 0.24 * wisps + 0.12 * billows)
    secondary = centered(0.08 * belts + 0.17 * billows - 0.23 * wisps)
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
