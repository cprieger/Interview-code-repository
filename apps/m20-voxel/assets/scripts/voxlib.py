"""Minimal MagicaVoxel .vox writer + isometric previewer.

Deliberately dependency-free beyond numpy/pillow: the .vox format is a simple
RIFF-like chunk layout, and vendoring ~100 lines beats taking a dependency we
can't install in every environment.

Godot imports .vox natively via VoxelVoxLoader.

Coordinate convention: MagicaVoxel is Z-up. Grids here are numpy arrays indexed
[x, y, z] holding uint8 palette indices, where 0 means empty.
"""

from __future__ import annotations

import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

MAX_DIM = 256


def _chunk(chunk_id: bytes, content: bytes = b"", children: bytes = b"") -> bytes:
    return chunk_id + struct.pack("<ii", len(content), len(children)) + content + children


def write_vox(path: str | Path, grid: np.ndarray, palette: list[tuple[int, int, int]]) -> Path:
    """Write an [x, y, z] uint8 grid to a .vox file.

    palette is a list of (r, g, b); entry i corresponds to grid value i + 1.
    Grid value 0 is empty space.
    """
    if grid.ndim != 3:
        raise ValueError(f"grid must be 3D, got shape {grid.shape}")
    if any(d > MAX_DIM for d in grid.shape):
        raise ValueError(f"grid {grid.shape} exceeds MagicaVoxel's {MAX_DIM} limit")
    if len(palette) > 255:
        raise ValueError(f"palette has {len(palette)} entries, max 255")

    sx, sy, sz = grid.shape
    filled = np.argwhere(grid > 0)

    size = _chunk(b"SIZE", struct.pack("<iii", sx, sy, sz))

    voxels = bytearray(struct.pack("<i", len(filled)))
    for x, y, z in filled:
        voxels += struct.pack("<BBBB", int(x), int(y), int(z), int(grid[x, y, z]))
    xyzi = _chunk(b"XYZI", bytes(voxels))

    # RGBA is always 256 entries. Index i in XYZI reads palette slot i-1.
    rgba = bytearray()
    for i in range(256):
        if i < len(palette):
            r, g, b = palette[i]
            rgba += struct.pack("<BBBB", r, g, b, 255)
        else:
            rgba += struct.pack("<BBBB", 0, 0, 0, 255)
    rgba_chunk = _chunk(b"RGBA", bytes(rgba))

    main = _chunk(b"MAIN", b"", size + xyzi + rgba_chunk)
    data = b"VOX " + struct.pack("<i", 150) + main

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def _shade(rgb: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(min(255, max(0, int(c * factor))) for c in rgb)


def render_iso(
    grid: np.ndarray,
    palette: list[tuple[int, int, int]],
    path: str | Path,
    tile: int = 8,
    bg: tuple[int, int, int, int] = (28, 28, 34, 255),
) -> Path:
    """Render an isometric preview PNG so a human (or an agent) can look at it.

    A voxel model you haven't looked at is a model you don't know is correct.
    """
    W = tile
    H = tile // 2
    V = tile

    sx, sy, sz = grid.shape
    img_w = (sx + sy) * W + 4 * tile
    img_h = (sx + sy) * H + sz * V + 4 * tile
    img = Image.new("RGBA", (img_w, img_h), bg)
    draw = ImageDraw.Draw(img)

    ox = sy * W + 2 * tile
    oy = 2 * tile

    filled = np.argwhere(grid > 0)
    # Painter's algorithm: ascending x+y+z draws far-to-near for a (+1,+1,+1) camera.
    order = filled[np.argsort(filled.sum(axis=1))]

    for x, y, z in order:
        rgb = palette[int(grid[x, y, z]) - 1]
        px = ox + (int(x) - int(y)) * W
        py = oy + (int(x) + int(y)) * H + (sz - int(z)) * V

        top = [(px, py - H), (px + W, py), (px, py + H), (px - W, py)]
        left = [(px - W, py), (px, py + H), (px, py + H + V), (px - W, py + V)]
        right = [(px, py + H), (px + W, py), (px + W, py + V), (px, py + H + V)]

        draw.polygon(left, fill=_shade(rgb, 0.55))
        draw.polygon(right, fill=_shade(rgb, 0.78))
        draw.polygon(top, fill=_shade(rgb, 1.0))

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return path


def stats(grid: np.ndarray) -> str:
    filled = int((grid > 0).sum())
    total = int(grid.size)
    return f"{grid.shape[0]}x{grid.shape[1]}x{grid.shape[2]}  {filled} voxels  ({100*filled/total:.1f}% fill)"
