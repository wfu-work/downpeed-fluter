#!/usr/bin/env python3
"""Package square PNG files into a multi-resolution Windows ICO file."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(data: bytes, source: Path) -> tuple[int, int]:
    if len(data) < 24 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise ValueError(f"{source} is not a valid PNG file")
    return struct.unpack(">II", data[16:24])


def package_ico(output: Path, sources: list[Path]) -> None:
    images: list[tuple[int, bytes]] = []
    for source in sources:
        data = source.read_bytes()
        width, height = png_size(data, source)
        if width != height or not 1 <= width <= 256:
            raise ValueError(f"{source} must be a square PNG from 1px to 256px")
        images.append((width, data))

    images.sort(key=lambda item: item[0])
    if len({size for size, _ in images}) != len(images):
        raise ValueError("PNG sizes must be unique")

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + len(images) * 16
    entries = bytearray()
    payload = bytearray()
    for size, data in images:
        encoded_size = 0 if size == 256 else size
        entries.extend(
            struct.pack(
                "<BBBBHHII",
                encoded_size,
                encoded_size,
                0,
                0,
                1,
                32,
                len(data),
                offset,
            )
        )
        payload.extend(data)
        offset += len(data)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(header + entries + payload)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("png", type=Path, nargs="+")
    args = parser.parse_args()
    package_ico(args.output, args.png)


if __name__ == "__main__":
    main()
