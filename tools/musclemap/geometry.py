"""Turns the muscle shapes in shapes.py into the final map (needs numpy, scipy, scikit-image,
shapely and pillow).

The body is drawn as a picture. Every point of it goes to the nearest muscle shape (so neighbouring
muscles meet half way), each muscle then gives up a thin band along its edges so the silhouette
shows between muscles as an even line, and the result is blurred and traced back to an outline,
which rounds every corner. Head, hands, feet and joints stay plain silhouette because no muscle
reaches them.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage import measure
from shapely.geometry import Polygon
from shapes import FRONT, BACK, expand

RES = 10         # pixels per unit while fitting
GROW = 2.4       # how far a muscle may spread to meet its neighbours
GAP = 0.75       # the silhouette line between neighbouring muscles
RIM = 0.1        # extra silhouette edge around the muscles (on top of half a gap)
SMOOTH = 0.75    # corner rounding
SIMPLIFY = 0.1   # drop points closer than this to the outline
W, H = 100 * RES, 200 * RES

def spline(pts, steps=8):
    """A closed Catmull-Rom curve through the points."""
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

def raster(pts):
    img = Image.new('L', (W, H), 0)
    ImageDraw.Draw(img).polygon([(x * RES, y * RES) for x, y in spline(pts)], fill=255)
    return np.asarray(img) > 127

def bbox(mask, margin):
    ys, xs = np.nonzero(mask)
    return (max(ys.min() - margin, 0), min(ys.max() + margin + 1, H),
            max(xs.min() - margin, 0), min(xs.max() + margin + 1, W))

def trace(mask, sigma):
    """The blurred mask's outline (largest piece) in canvas units."""
    y0, y1, x0, x1 = bbox(mask, int(4 * sigma * RES) + 2)
    field = ndimage.gaussian_filter(mask[y0:y1, x0:x1].astype(np.float32), sigma * RES)
    contours = measure.find_contours(field, 0.5)
    if not contours:
        return None
    ring = max(contours, key=lambda c: Polygon(c).area if len(c) > 3 else 0)
    poly = Polygon([((x0 + c + 0.5) / RES, (y0 + r + 0.5) / RES) for r, c in ring]).buffer(0)
    if poly.is_empty or poly.area < 0.5:
        return None
    if poly.geom_type == 'MultiPolygon':
        poly = max(poly.geoms, key=lambda g: g.area)
    poly = poly.simplify(SIMPLIFY)
    return [(round(x, 2), round(y, 2)) for x, y in list(poly.exterior.coords)[:-1]]

def build_view(shapes):
    parts = expand(shapes)
    body = np.zeros((H, W), bool)
    for kind, pts in parts:
        if kind == 'base':
            body |= raster(pts)
    body = ndimage.gaussian_filter(body.astype(np.float32), 0.5 * RES) > 0.5   # soften the joins
    inside = ndimage.distance_transform_edt(body) >= RIM * RES

    seeds = [(kind, raster(pts)) for kind, pts in parts if kind != 'base']
    nearest = np.full((H, W), np.inf, np.float32)
    owner = np.full((H, W), -1, np.int32)
    margin = int(GROW * RES) + 2
    for i, (_, mask) in enumerate(seeds):
        y0, y1, x0, x1 = bbox(mask, margin)
        dist = ndimage.distance_transform_edt(~mask[y0:y1, x0:x1])
        best = nearest[y0:y1, x0:x1]
        closer = dist < best
        best[closer] = dist[closer]
        owner[y0:y1, x0:x1][closer] = i
    claimed = inside & (nearest <= GROW * RES)

    out = [('base', trace(body, 0.01))]
    for i, (kind, _) in enumerate(seeds):
        region = claimed & (owner == i)
        if not region.any():
            continue
        y0, y1, x0, x1 = bbox(region, 2)
        core = np.zeros_like(region)
        core[y0:y1, x0:x1] = ndimage.distance_transform_edt(region[y0:y1, x0:x1]) > GAP / 2 * RES
        if not core.any():
            continue
        pts = trace(core, SMOOTH)
        if pts:
            out.append((kind, pts))
    return out

def build():
    return {'front': build_view(FRONT), 'back': build_view(BACK)}
