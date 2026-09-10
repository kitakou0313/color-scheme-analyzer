#!/usr/bin/env python3
"""E2E フィクスチャ画像（PNG）を標準ライブラリだけで生成する。

- sample-4x4.png : blueprint 6.1 の 4×4 フィクスチャ（期待値が手計算済み）
- hatching.png   : 赤と緑の斜線ハッチング。最頻色相法と平均色の差が出る
- gradient.png   : 横に色相、縦に明度が変わるグラデーション
- photo-like.png : 滑らかな色の塊にノイズを載せた写真風
"""
import math
import random
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "App" / "ColorSchemeAnalyzer" / "Fixtures"


def write_png(path, width, height, rows):
    """RGB 8bit の行データ（各行は width*3 バイト）を PNG に書く"""
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def hsv_to_rgb(h, s, v):
    """HSV（h: 0–360, s/v: 0–1）を 0–255 の RGB にする"""
    c = v * s
    x = c * (1 - abs((h / 60) % 2 - 1))
    m = v - c
    r, g, b = [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)][int(h // 60) % 6]
    return tuple(int(round((k + m) * 255)) for k in (r, g, b))


def sample_4x4():
    R, G, Y, B, L = (255, 0, 0), (0, 255, 0), (187, 187, 187), (0, 0, 255), (128, 128, 255)
    grid = [[R, R, G, G], [R, R, G, R], [Y, Y, B, L], [Y, R, L, B]]
    return 4, 4, [[c for px in row for c in px] for row in grid]


def hatching(size=256):
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            stripe = ((x + y) // 6) % 2 == 0
            row.extend((220, 30, 30) if stripe else (30, 200, 60))
        rows.append(row)
    return size, size, rows


def gradient(width=512, height=384):
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            row.extend(hsv_to_rgb(360 * x / width, 0.9, 1 - 0.8 * y / height))
        rows.append(row)
    return width, height, rows


def photo_like(width=512, height=384, seed=7):
    rng = random.Random(seed)
    blobs = [(rng.uniform(0, width), rng.uniform(0, height), rng.uniform(60, 160), rng.uniform(0, 360)) for _ in range(6)]
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            h_acc, w_acc = 0.0, 0.0
            for bx, by, radius, hue in blobs:
                w = math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (2 * radius**2))
                h_acc += w * hue
                w_acc += w
            hue = (h_acc / w_acc) if w_acc > 1e-6 else 200
            value = 0.35 + 0.6 * (1 - y / height) + rng.uniform(-0.05, 0.05)
            row.extend(hsv_to_rgb(hue % 360, 0.55, max(0, min(1, value))))
        rows.append(row)
    return width, height, rows


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("sample-4x4", sample_4x4), ("hatching", hatching), ("gradient", gradient), ("photo-like", photo_like)]:
        w, h, rows = fn()
        write_png(OUT / f"{name}.png", w, h, rows)
        print(f"{name}.png {w}x{h}")
