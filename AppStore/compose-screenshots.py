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
FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
CANVAS = (1320, 2868)
FILES = ["01_dashboard", "02_privacy", "03_quickentry", "04_analytics",
         "05_categories", "06_faceid", "07_export", "08_lifetime"]
CAP = {
 "EN": ["Your money, calmly in control", "Your data stays on your iPhone", "Log spending in seconds", "See where your money goes", "Organize by category and account", "Lock it behind Face ID", "Export to CSV, PDF, or Excel", "Yours to keep, for life"],
 "RU": ["Финансы под спокойным контролем", "Данные остаются на вашем iPhone", "Записывайте траты за секунды", "Видно, куда уходят деньги", "Категории и счета — всё на местах", "Защитите вход через Face ID", "Экспорт в CSV, PDF и Excel", "Останется с вами навсегда"],
 "ES": ["Tus finanzas, bajo control y en calma", "Tus datos se quedan en tu iPhone", "Registra tus gastos en segundos", "Mira a dónde va tu dinero", "Organiza por categoría y cuenta", "Protégelo con Face ID", "Exporta a CSV, PDF o Excel", "Tuyo para siempre"],
 "PT-BR": ["Suas finanças sob controle e tranquilas", "Seus dados ficam no seu iPhone", "Registre gastos em segundos", "Veja para onde vai seu dinheiro", "Organize por categoria e conta", "Proteja com Face ID", "Exporte para CSV, PDF ou Excel", "Seu para sempre"],
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
    font = ImageFont.truetype(FONT, 78)
    y = 170
    for ln in wrap(dr, CAP[locale][idx], font, 1120):
        w = dr.textlength(ln, font=font); dr.text(((CANVAS[0] - w) / 2, y), ln, font=font, fill=INK); y += 96
    dr.rectangle([(CANVAS[0] - 90) / 2, y + 24, (CANVAS[0] + 90) / 2, y + 32], fill=ACCENT)
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
