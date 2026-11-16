"""Builds an animated GIF from raw RGB frames (see tests/shoot_gif.gd).

Pure Python, no packages: one shared 255-colour palette (median cut), and
pixels unchanged from the last frame are left transparent so the mostly
still camera compresses well.

Usage: python make_gif.py <frames.raw> <width> <height> <fps> <out.gif>
"""

import struct
import sys

TRANSPARENT = 255


def median_cut(counts, n_colours):
    """counts: {(r, g, b): weight}. Returns up to n_colours average colours."""
    boxes = [list(counts.items())]
    while len(boxes) < n_colours:
        # Split the box with the widest channel range (weighted by pixel count).
        best, best_score, best_ch = None, -1, 0
        for i, box in enumerate(boxes):
            if len(box) < 2:
                continue
            for ch in range(3):
                vals = [c[0][ch] for c in box]
                score = (max(vals) - min(vals)) * sum(c[1] for c in box) ** 0.5
                if score > best_score:
                    best, best_score, best_ch = i, score, ch
        if best is None:
            break
        box = sorted(boxes.pop(best), key=lambda c: c[0][best_ch])
        total = sum(c[1] for c in box)
        acc, cut = 0, 1
        for j, c in enumerate(box):
            acc += c[1]
            if acc >= total / 2:
                cut = max(1, min(j, len(box) - 1))
                break
        boxes.append(box[:cut])
        boxes.append(box[cut:])
    palette = []
    for box in boxes:
        w = sum(c[1] for c in box)
        palette.append(tuple(round(sum(c[0][k] * c[1] for c in box) / w) for k in range(3)))
    return palette


def lzw(indices, min_size=8):
    clear, end = 1 << min_size, (1 << min_size) + 1
    out, bits, nbits = bytearray(), 0, 0
    size = min_size + 1

    def emit(code):
        nonlocal bits, nbits
        bits |= code << nbits
        nbits += size
        while nbits >= 8:
            out.append(bits & 0xFF)
            bits >>= 8
            nbits -= 8

    table = {bytes([i]): i for i in range(clear)}
    next_code = end + 1
    emit(clear)
    w = b""
    for i in indices:
        wc = w + bytes([i])
        if wc in table:
            w = wc
            continue
        emit(table[w])
        if next_code < 4096:
            table[wc] = next_code
            next_code += 1
            if next_code > (1 << size) and size < 12:
                size += 1
        else:
            emit(clear)
            table = {bytes([k]): k for k in range(clear)}
            next_code = end + 1
            size = min_size + 1
        w = bytes([i])
    if w:
        emit(table[w])
    emit(end)
    if nbits:
        out.append(bits & 0xFF)
    return bytes(out)


def sub_blocks(data):
    out = bytearray()
    for i in range(0, len(data), 255):
        chunk = data[i:i + 255]
        out.append(len(chunk))
        out += chunk
    out.append(0)
    return bytes(out)


def main():
    raw_path, w, h, fps, out_path = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    data = open(raw_path, "rb").read()
    frame_bytes = w * h * 3
    frames = [data[i:i + frame_bytes] for i in range(0, len(data) - frame_bytes + 1, frame_bytes)]

    # Palette from 5-bit-per-channel colours, sampled across all frames.
    counts = {}
    for f in frames[::2]:
        for p in range(0, frame_bytes, 3 * 3):
            key = (f[p] >> 3, f[p + 1] >> 3, f[p + 2] >> 3)
            counts[key] = counts.get(key, 0) + 1
    palette = median_cut({(k[0] * 8 + 4, k[1] * 8 + 4, k[2] * 8 + 4): v for k, v in counts.items()}, 255)

    # Every 5-bit colour maps to its nearest palette entry.
    lookup = bytearray(32768)
    for key in range(32768):
        r, g, b = (key >> 10) * 8 + 4, ((key >> 5) & 31) * 8 + 4, (key & 31) * 8 + 4
        lookup[key] = min(range(len(palette)), key=lambda i: (palette[i][0] - r) ** 2 * 3 + (palette[i][1] - g) ** 2 * 4 + (palette[i][2] - b) ** 2 * 2)

    gif = bytearray(b"GIF89a")
    gif += struct.pack("<HHBBB", w, h, 0xF7, 0, 0)  # global table, 256 entries
    for c in palette + [(0, 0, 0)] * (256 - len(palette)):
        gif += bytes(c)
    gif += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"  # loop forever
    delay = round(100 / fps)
    shown = None
    for f in frames:
        idx = bytes(lookup[(f[p] >> 3) << 10 | (f[p + 1] >> 3) << 5 | f[p + 2] >> 3] for p in range(0, frame_bytes, 3))
        if shown is None:
            draw = idx
        else:
            draw = bytes(TRANSPARENT if a == b else a for a, b in zip(idx, shown))
        shown = idx
        gif += struct.pack("<BBBBHBB", 0x21, 0xF9, 4, 0x05, delay, TRANSPARENT, 0)  # keep, transparent
        gif += struct.pack("<BHHHHB", 0x2C, 0, 0, w, h, 0)
        gif += bytes([8]) + sub_blocks(lzw(draw))
    gif += b"\x3B"
    open(out_path, "wb").write(gif)
    print("RESULT %d frames, %d colours, %.1f MB -> %s" % (len(frames), len(palette), len(gif) / 1e6, out_path))


if __name__ == "__main__":
    main()
