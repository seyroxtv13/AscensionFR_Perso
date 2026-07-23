# -*- coding: utf-8 -*-
"""Décors Compagnon — composition unique, lisible, sans cartes empilées."""
from __future__ import annotations

from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(__file__).resolve().parent / "assets" / "ui"
OUT.mkdir(parents=True, exist_ok=True)

BG = (12, 15, 22)
PANEL = (20, 25, 34)
CUIVRE = (210, 125, 55)
CUIVRE2 = (255, 170, 85)
GLACE = (130, 185, 220)
TEXTE = (240, 243, 248)
OK = (75, 185, 120)


def font(size, bold=False):
    for p in (
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def hexagone(cx, cy, r):
    return [
        (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
        for a in range(0, 360, 60)
    ]


def fond(w, h):
    img = Image.new("RGBA", (w, h), (*BG, 255))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(12 + 10 * t)
        g = int(15 + 8 * t)
        b = int(22 + 14 * t)
        d.line([(0, y), (w, y)], fill=(r, g, b, 255))
    # halo cuivre bas-gauche
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-120, h - 220, 280, h + 120], fill=(CUIVRE[0], CUIVRE[1], CUIVRE[2], 40))
    glow = glow.filter(ImageFilter.GaussianBlur(50))
    img = Image.alpha_composite(img, glow)
    # fine ligne décorative haut
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 3], fill=(*CUIVRE, 200))
    return img


def accent_bar(w, h=2):
    img = Image.new("RGBA", (w, h), (*CUIVRE, 220))
    return img


def bouton(w, h, label, style="primary"):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if style == "primary":
        top, bot = CUIVRE2, CUIVRE
        tc = (30, 14, 4, 255)
        edge = (*CUIVRE2, 255)
    elif style == "ghost":
        top, bot = (34, 42, 56), (26, 32, 44)
        tc = (*TEXTE, 255)
        edge = (70, 82, 104, 200)
    else:
        top, bot = (55, 130, 90), (40, 100, 70)
        tc = (*TEXTE, 255)
        edge = (*OK, 200)

    for y in range(4, h - 4):
        t = y / max(h - 1, 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        d.line([(8, y), (w - 9, y)], fill=(r, g, b, 255))
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=14, outline=edge, width=2)
    f = font(15, bold=True)
    bb = d.textbbox((0, 0), label, font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((w - tw) / 2, (h - th) / 2 - 1), label, font=f, fill=tc)
    return img


def crest(size=256):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = size / 2
    d.polygon(hexagone(cx, cy, size * 0.44), fill=(32, 40, 54, 255))
    d.polygon(hexagone(cx, cy, size * 0.36), fill=(22, 28, 38, 255))
    d.polygon(hexagone(cx, cy, size * 0.44), outline=(*CUIVRE, 255))
    for a in range(0, 360, 60):
        x = cx + size * 0.40 * math.cos(math.radians(a))
        y = cy + size * 0.40 * math.sin(math.radians(a))
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(*CUIVRE2, 255))
    f = font(int(size * 0.34), bold=True)
    bb = d.textbbox((0, 0), "AP", font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    tx, ty = (size - tw) / 2, (size - th) / 2 - 2
    d.text((tx + 1, ty + 1), "AP", font=f, fill=(8, 10, 14, 180))
    d.text((tx, ty), "AP", font=f, fill=(*CUIVRE2, 255))
    return img


def main():
    W, H = 520, 560
    pieces = {
        "fond.png": fond(W, H),
        "line.png": accent_bar(W - 64, 2),
        "btn_install.png": bouton(300, 50, "Installer Perso", "primary"),
        "btn_update.png": bouton(300, 50, "Mettre à jour", "primary"),
        "btn_reinstall.png": bouton(300, 50, "Réinstaller", "ghost"),
        "btn_browse.png": bouton(96, 32, "Changer", "ghost"),
        "btn_web.png": bouton(96, 32, "GitHub", "ghost"),
    }
    for nom, im in pieces.items():
        im.save(OUT / nom)
        print("OK", nom)

    assets = OUT.parent
    c = crest(256)
    c.save(assets / "crest.png")
    icon = Image.new("RGBA", (256, 256), (*BG, 255))
    icon.paste(c, (0, 0), c)
    icon.save(assets / "icon.png")
    print("OK crest + icon")


if __name__ == "__main__":
    main()
