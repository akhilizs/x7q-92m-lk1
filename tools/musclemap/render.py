"""Writes a preview of the muscle map: python3 tools/musclemap/render.py [out.png]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from geometry import build

LIME = (212, 252, 96); SUPPORT = (140, 168, 69); BASE = (44, 44, 46); MUSCLE = (74, 74, 77); BG = (28, 28, 28)

def draw(geo, primary, secondary, scale=6):
    W, H = 100*scale, 200*scale
    img = Image.new('RGB', (W*2 + 20*scale, H), BG)
    d = ImageDraw.Draw(img)
    for vi, view in enumerate(['front', 'back']):
        ox = vi * (W + 20*scale)
        for kind, pts in geo[view]:
            if kind == 'base': col = BASE
            elif kind in primary: col = LIME
            elif kind in secondary: col = SUPPORT
            else: col = MUSCLE
            d.polygon([(ox + x*scale, y*scale) for x, y in pts], fill=col)
    return img.resize((img.width//2, img.height//2), Image.LANCZOS)

if __name__ == '__main__':
    geo = build()
    a = draw(geo, {'chest'}, {'shoulders', 'triceps'})
    b = draw(geo, {'quads', 'glutes'}, {'hamstrings', 'calves', 'core'})
    c = draw(geo, {'back', 'biceps'}, {'forearms', 'shoulders'})
    sheet = Image.new('RGB', (a.width*3 + 40, a.height), (0, 0, 0))
    for i, im in enumerate([a, b, c]): sheet.paste(im, (i*(a.width+20), 0))
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else 'muscle-map-preview.png'); print(sheet.size)
