"""Generate the d20 — the most important object in the game.

A regular icosahedron is the dual of a regular dodecahedron, so the 20 face
normals are exactly the 20 dodecahedron vertex directions. A point is inside
the solid iff its projection onto every one of those directions is within the
inradius. That gives clean, correct faceting for free.

Colouring each voxel by its nearest face plane doubles as a self-test: if the
render shows 20 distinct facets, the geometry is right.

    python3 gen_dice.py [--radius 14] [--tile 8]
"""

from __future__ import annotations

import argparse
import colorsys
from pathlib import Path

import numpy as np

from voxlib import render_iso, stats, write_vox

PHI = (1.0 + 5.0**0.5) / 2.0

OUT_VOX = Path(__file__).resolve().parents[1] / "vox" / "dice"
OUT_PNG = Path(__file__).resolve().parents[1] / "renders"


def face_normals() -> np.ndarray:
    """The 20 face directions of an icosahedron = dodecahedron vertices."""
    verts: list[tuple[float, float, float]] = []
    for sx in (1, -1):
        for sy in (1, -1):
            for sz in (1, -1):
                verts.append((sx * 1.0, sy * 1.0, sz * 1.0))
    inv = 1.0 / PHI
    for sy in (1, -1):
        for sz in (1, -1):
            verts.append((0.0, sy * inv, sz * PHI))
            verts.append((sy * inv, sz * PHI, 0.0))
            verts.append((sy * PHI, 0.0, sz * inv))

    n = np.array(verts, dtype=np.float64)
    assert n.shape == (20, 3), f"expected 20 normals, got {n.shape[0]}"
    return n / np.linalg.norm(n, axis=1, keepdims=True)


def build(radius: int) -> tuple[np.ndarray, list[tuple[int, int, int]]]:
    normals = face_normals()
    size = radius * 2 + 3
    c = size // 2

    ax = np.arange(size, dtype=np.float64) - c
    X, Y, Z = np.meshgrid(ax, ax, ax, indexing="ij")
    pts = np.stack([X, Y, Z], axis=-1)

    # proj[..., k] = how far each point reaches along face normal k
    proj = pts @ normals.T
    inside = proj.max(axis=-1) <= radius

    # Nearest face = the plane a voxel is pressed hardest against.
    nearest = proj.argmax(axis=-1)

    grid = np.zeros((size, size, size), dtype=np.uint8)
    grid[inside] = (nearest[inside] + 1).astype(np.uint8)

    # 20 hues so adjacent facets never share a colour — a faceting self-test.
    palette = []
    for i in range(20):
        r, g, b = colorsys.hsv_to_rgb((i * 7 % 20) / 20.0, 0.55, 0.95)
        palette.append((int(r * 255), int(g * 255), int(b * 255)))

    return grid, palette


def bone_palette() -> list[tuple[int, int, int]]:
    """Shipping look: one bone-white body. Doc M's starter die."""
    return [(232, 226, 208)] * 20


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--radius", type=int, default=14)
    ap.add_argument("--tile", type=int, default=8)
    args = ap.parse_args()

    grid, facet_palette = build(args.radius)
    print(f"d20  {stats(grid)}")
    print(f"     {len(np.unique(grid)) - 1} distinct faces detected (expect 20)")

    write_vox(OUT_VOX / "d20_facets.vox", grid, facet_palette)
    write_vox(OUT_VOX / "d20_bone.vox", grid, bone_palette())
    render_iso(grid, facet_palette, OUT_PNG / "d20_facets.png", tile=args.tile)
    render_iso(grid, bone_palette(), OUT_PNG / "d20_bone.png", tile=args.tile)

    print(f"     wrote {OUT_VOX}/d20_facets.vox, d20_bone.vox")
    print(f"     wrote {OUT_PNG}/d20_facets.png, d20_bone.png")


if __name__ == "__main__":
    main()
