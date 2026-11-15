"""Genera landing/public/og-image.png (1200x630) con la marca de Muyuy.

Uso:  python scripts/make-og-image.py

Se dibuja a 2x y se reduce con LANCZOS para que el texto quede nitido.
Todas las capas se componen con alpha real (alpha_composite), asi que el
resultado final es opaco y no depende del visor.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "public" / "muyuy-logo.png"
OUT = ROOT / "public" / "og-image.png"

W, H, SCALE = 1200, 630, 2
CW, CH = W * SCALE, H * SCALE

BG_TOP = (9, 9, 11)
BG_BOTTOM = (20, 32, 26)
ACCENT = (202, 220, 166)
MUTED = (150, 159, 143)
WHITE = (244, 244, 241)

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def vertical_gradient(size: tuple[int, int]) -> Image.Image:
    """Gradiente vertical opaco."""
    column = Image.new("RGB", (1, size[1]))
    for y in range(size[1]):
        ratio = y / max(1, size[1] - 1)
        column.putpixel((0, y), tuple(round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * ratio) for i in range(3)))
    return column.resize(size, Image.BILINEAR).convert("RGBA")


def glow_layer(size: tuple[int, int], center: tuple[int, int], radius: int, color: tuple[int, int, int]) -> Image.Image:
    """Halo radial continuo calculado con numpy (sin bandas)."""
    cx, cy = center
    yy, xx = np.mgrid[0 : size[1], 0 : size[0]]
    distance = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(1, radius)
    falloff = np.clip(1.0 - distance, 0.0, 1.0) ** 2.4
    alpha = (falloff * 130).astype(np.uint8)
    rgb = np.zeros((size[1], size[0], 3), dtype=np.uint8)
    rgb[:, :] = color
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def grid_layer(size: tuple[int, int], step: int, alpha: int) -> Image.Image:
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    fill = (223, 235, 212, alpha)
    for x in range(0, size[0], step):
        draw.line([(x, 0), (x, size[1])], fill=fill, width=1)
    for y in range(0, size[1], step):
        draw.line([(0, y), (size[0], y)], fill=fill, width=1)
    return img


def centered_text(draw: ImageDraw.ImageDraw, text: str, size: int, y: int, fill: tuple[int, int, int]) -> None:
    f = font(size)
    box = draw.textbbox((0, 0), text, font=f)
    draw.text(((CW - (box[2] - box[0])) // 2, y), text, font=f, fill=(*fill, 255))


def main() -> int:
    if not LOGO.exists():
        print(f"falta el logo: {LOGO}", file=sys.stderr)
        return 1

    canvas = vertical_gradient((CW, CH))
    canvas = Image.alpha_composite(canvas, glow_layer((CW, CH), (CW // 2, int(CH * 0.30)), int(CW * 0.46), (128, 176, 100)))
    canvas = Image.alpha_composite(canvas, grid_layer((CW, CH), 42 * SCALE, 12))

    # el texto y el chip van en su propia capa transparente
    text_layer = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(text_layer)

    centered_text(draw, "Offline agro-climatic intelligence", 52 * SCALE, int(CH * 0.52), WHITE)
    centered_text(draw, "NASA POWER 1985\u20132024  \u00b7  Hu\u00e1nuco, Per\u00fa", 30 * SCALE, int(CH * 0.66), ACCENT)

    chip_text = "NASA SPACE APPS CHALLENGE 2026"
    chip_font = font(22 * SCALE)
    box = draw.textbbox((0, 0), chip_text, font=chip_font)
    text_w, text_h = box[2] - box[0], box[3] - box[1]
    pad_x, pad_y = 22 * SCALE, 12 * SCALE
    chip_w, chip_h = text_w + pad_x * 2, text_h + pad_y * 2
    chip_x, chip_y = (CW - chip_w) // 2, int(CH * 0.80)
    draw.rounded_rectangle(
        [chip_x, chip_y, chip_x + chip_w, chip_y + chip_h],
        radius=chip_h // 2,
        outline=(*ACCENT, 110),
        width=2 * SCALE,
    )
    draw.text((chip_x + pad_x, chip_y + pad_y - box[1]), chip_text, font=chip_font, fill=(*MUTED, 255))

    canvas = Image.alpha_composite(canvas, text_layer)

    # logo encima del halo
    logo = Image.open(LOGO).convert("RGBA")
    logo_w = int(CW * 0.42)
    logo = logo.resize((logo_w, round(logo.height * logo_w / logo.width)), Image.LANCZOS)
    canvas.alpha_composite(logo, ((CW - logo_w) // 2, int(CH * 0.14)))

    canvas.convert("RGB").resize((W, H), Image.LANCZOS).save(OUT, "PNG", optimize=True)
    print(f"escrito {OUT} ({OUT.stat().st_size / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
