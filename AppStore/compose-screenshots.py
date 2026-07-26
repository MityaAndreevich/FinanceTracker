#!/usr/bin/env python3
"""
compose-screenshots.py — App Store screenshot compositor (no Figma needed).

Takes the RAW device captures from capture-screenshots.sh and composes final
App Store-ready frames: solid background + localized caption headline + mint
accent + rounded device shot. Reproducible, all locales at once, re-runs on any
redesign. Part of the reusable "Crab Kit".

Run AFTER capture-screenshots.sh regenerates the (dark, redesigned) raws:
  python3 AppStore/compose-screenshots.py            # all locales, all screens
  python3 AppStore/compose-screenshots.py EN         # one locale

Input : AppStore/screenshots/<LOCALE>/NN_name.png   (1320x2868 raw captures)
Output: AppStore/composed/<LOCALE>/NN_name.png       (ready for ASC upload)

Font: Liberation Sans Bold (bundled on Linux). For premium type, drop an Inter
or SF-substitute .ttf and point FONT at it.
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont

ROOT = "AppStore/screenshots"; OUT = "AppStore/composed"
BG = (15, 20, 32); INK = (242, 245, 249); ACCENT = (61, 220, 151)
# Bold font with Latin + Cyrillic coverage (ru/uk). Prefer the bundled Linux
# Liberation Sans; fall back to macOS Arial Bold / Arial Unicode when running
# capture locally on a Mac. Override with FONT=/path/to.ttf in the environment.
_FONT_CANDIDATES = [
    os.environ.get("FONT", ""),
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]
FONT = next((p for p in _FONT_CANDIDATES if p and os.path.exists(p)), None)
if FONT is None:
    sys.exit("No usable bold font found. Set FONT=/path/to/font.ttf")
CANVAS = (1320, 2868)
FILES = ["01_dashboard", "02_privacy", "03_quickentry", "04_analytics",
         "05_split", "06_limits", "07_export", "08_lifetime"]
# Captions are OCR-indexed by Apple (2026) — keyword-rich, top-left, ≥40pt.
# Sequence (ASC_METADATA_FINAL "Screenshot captions"): Private/on-device →
# No bank linking → Track in 10s → Safe to spend → Export → Cancel anytime.
# Mapped onto the 8 storyboard screens; slot 2 combines the top-2 privacy props
# (highest-attention slot), slot 8 closes on honest billing.
#
# 1.0.3: slots 5 and 6 now carry the two new features. Their wording reuses the
# app's OWN shipped terms so the caption and the screen agree word-for-word —
# split.section ("Split across categories" / "Разделить по категориям" / …) and
# limit.sheet.title ("Monthly limit" / "Месячный лимит" / …). No caption may
# state a trial length: the 30-day intro offer is being removed for 1.0.3.
CAP = {
 "EN": ["Safe to spend, every day", "Private & on-device · No bank linking", "Track spending in 10 seconds", "See where your money goes", "Split one purchase across categories", "Gentle monthly limits, never a scolding", "Export anytime · CSV / PDF / Excel", "Cancel anytime · no ads"],
 "RU": ["Сколько можно тратить — каждый день", "Приватно, на устройстве · Без привязки банка", "Записывайте траты за 10 секунд", "Видно, куда уходят деньги", "Разделить покупку по категориям", "Мягкий месячный лимит, а не выговор", "Экспорт в любой момент · CSV / PDF / Excel", "Отмена в любой момент · без рекламы"],
 "ES": ["Cuánto puedes gastar, cada día", "Privado, en tu iPhone · Sin vincular banco", "Registra gastos en 10 segundos", "Mira a dónde va tu dinero", "Una compra, dividida entre categorías", "Límite mensual amable, nunca un regaño", "Exporta cuando quieras · CSV / PDF / Excel", "Cancela cuando quieras · sin anuncios"],
 "PT-BR": ["Quanto dá para gastar, todo dia", "Privado, no seu iPhone · Sem vincular banco", "Registre gastos em 10 segundos", "Veja para onde vai seu dinheiro", "Uma compra, dividida entre categorias", "Limite mensal gentil, nunca uma bronca", "Exporte quando quiser · CSV / PDF / Excel", "Cancele quando quiser · sem anúncios"],
 "UK": ["Скільки можна витрачати — щодня", "Приватно, на пристрої · Без прив'язки банку", "Записуйте витрати за 10 секунд", "Дивіться, куди йдуть гроші", "Розділити покупку за категоріями", "М'який місячний ліміт, а не докір", "Експорт будь-коли · CSV / PDF / Excel", "Скасування будь-коли · без реклами"],
}

def wrap(draw, text, font, maxw):
    words = text.split(); lines = []; cur = ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font) <= maxw: cur = t
        else: lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines

def rounded(img, rad):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius=rad, fill=255)
    out = img.convert("RGBA"); out.putalpha(mask); return out

def compose(locale, idx):
    raw = f"{ROOT}/{locale}/{FILES[idx]}.png"
    if not os.path.exists(raw): return None
    dev = Image.open(raw).convert("RGB")
    canvas = Image.new("RGB", CANVAS, BG); dr = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT, 78)  # 78pt » the ≥40pt OCR-indexing threshold
    # Top-left quadrant, left-aligned — matches the eye's scanning bias and the
    # region Apple's OCR weights most. Wrap narrow so text stays in the left ~60%.
    MARGIN = 100; y = 150
    for ln in wrap(dr, CAP[locale][idx], font, 820):
        dr.text((MARGIN, y), ln, font=font, fill=INK); y += 100
    dr.rectangle([MARGIN, y + 20, MARGIN + 120, y + 30], fill=ACCENT)
    scale = 0.80; dw = int(CANVAS[0] * scale); dh = int(dev.size[1] * dw / dev.size[0])
    dev = rounded(dev.resize((dw, dh)), 60)
    dx = (CANVAS[0] - dw) // 2; dy = CANVAS[1] - dh - 70
    canvas.paste(dev, (dx, dy), dev)
    os.makedirs(f"{OUT}/{locale}", exist_ok=True)
    p = f"{OUT}/{locale}/{FILES[idx]}.png"; canvas.save(p); return p

def main():
    locales = [sys.argv[1]] if len(sys.argv) > 1 else list(CAP.keys())
    n = 0
    for loc in locales:
        for i in range(len(FILES)):
            if compose(loc, i): n += 1
    print(f"composed {n} screenshots into {OUT}/")

if __name__ == "__main__":
    main()
