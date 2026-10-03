import sys, math
from PIL import Image, ImageDraw
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from shapes import FRONT, BACK, expand

def spline(pts, steps=14):
    n = len(pts); out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i-1) % n], pts[i], pts[(i+1) % n], pts[(i+2) % n]
        c1 = (p1[0] + (p2[0]-p0[0])/6, p1[1] + (p2[1]-p0[1])/6)
        c2 = (p2[0] - (p3[0]-p1[0])/6, p2[1] - (p3[1]-p1[1])/6)
        for s in range(steps):
            t = s/steps; u = 1-t
            out.append((u**3*p1[0] + 3*u*u*t*c1[0] + 3*u*t*t*c2[0] + t**3*p2[0],
                        u**3*p1[1] + 3*u*u*t*c1[1] + 3*u*t*t*c2[1] + t**3*p2[1]))
    return out

VOLT = (212, 255, 0); BASE = (30, 30, 34); BODY = (44, 44, 50); DIM = (62, 62, 70)
def draw(primary, secondary, scale=6, bg=(14, 14, 16)):
    W, H = 100*scale, 200*scale
    img = Image.new('RGB', (W*2 + 20*scale, H), bg)
    d = ImageDraw.Draw(img)
    for vi, shapes in enumerate([FRONT, BACK]):
        ox = vi * (W + 20*scale)
        for kind, pts in expand(shapes):
            if kind == 'base': col = BASE
            elif kind == 'body': col = BODY
            elif kind in primary: col = VOLT
            elif kind in secondary: col = tuple(int(VOLT[i]*0.42 + DIM[i]*0.58) for i in range(3))
            else: col = DIM
            poly = [(ox + x*scale, y*scale) for x, y in spline(pts)]
            d.polygon(poly, fill=col)
    return img.resize((img.width//2, img.height//2), Image.LANCZOS)

if __name__ == '__main__':
    a = draw({'chest'}, {'shoulders', 'triceps'})
    b = draw({'quads', 'glutes'}, {'hamstrings', 'calves', 'core'})
    c = draw({'back', 'biceps'}, {'forearms', 'shoulders'})
    sheet = Image.new('RGB', (a.width*3 + 40, a.height), (0, 0, 0))
    for i, im in enumerate([a, b, c]): sheet.paste(im, (i*(a.width+20), 0))
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else 'muscle-map-preview.png'); print(sheet.size)
