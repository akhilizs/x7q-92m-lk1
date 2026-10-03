"""Turns the rough muscle shapes in shapes.py into the final map.

Each muscle is grown until it nearly meets its neighbours (the body is split between muscles
by nearest muscle), clipped to the body outline, then shrunk a little so a thin line of the
silhouette shows between muscles — like an anatomy chart. Joints, hands, feet and the head
stay as plain silhouette because no muscle reaches them.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapely.geometry import Polygon, MultiPoint, MultiPolygon
from shapely.ops import unary_union, voronoi_diagram
from shapely import STRtree
from shapes import FRONT, BACK, expand

GROW = 1.4       # how far a muscle may spread from its rough shape
GAP = 0.9        # the line left between neighbouring muscles
RIM = 0.6        # the silhouette edge left around the muscles
ROUND = 0.9      # corner rounding, so muscles stay organic rather than panel-like
SIMPLIFY = 0.2   # drop points closer than this to the outline (the map is drawn at most ~2pt per unit)

def spline(pts, steps=10):
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

def largest(geom):
    if isinstance(geom, MultiPolygon):
        return max(geom.geoms, key=lambda g: g.area)
    return geom

def build_view(shapes, grow=None, gap=None, rounding=None):
    grow = GROW if grow is None else grow
    gap = GAP if gap is None else gap
    rounding = ROUND if rounding is None else rounding
    parts = expand(shapes)
    body = unary_union([Polygon(spline(p)).buffer(0) for k, p in parts if k == 'base'])
    body = body.buffer(0.6, join_style=1).buffer(-0.6, join_style=1)   # round off the joins
    inside = body.buffer(-RIM, join_style=1)
    seeds = [(k, Polygon(spline(p)).buffer(0)) for k, p in parts if k not in ('base', 'body')]

    # Split the body between muscles: Voronoi cells of points sampled along each muscle's edge.
    samples, owner = [], []
    for i, (_, poly) in enumerate(seeds):
        ring = poly.exterior
        n = max(12, int(ring.length / 0.6))
        for j in range(n):
            pt = ring.interpolate(j / n, normalized=True)
            samples.append(pt); owner.append(i)
    cells = voronoi_diagram(MultiPoint(samples), envelope=body.envelope.buffer(10))
    by_owner = [[] for _ in seeds]
    # Each cell belongs to the muscle whose edge sample it contains.
    tree = STRtree(samples)
    for cell in cells.geoms:
        hits = tree.query(cell, predicate='contains')
        if len(hits):
            by_owner[owner[int(hits[0])]].append(cell)

    outline = largest(body).simplify(SIMPLIFY)
    out = [('base', [(round(x, 2), round(y, 2)) for x, y in list(outline.exterior.coords)[:-1]])]
    for i, (kind, poly) in enumerate(seeds):
        region = unary_union(by_owner[i]).union(poly)
        grown = poly.buffer(grow, join_style=1).intersection(region).intersection(inside)
        shape = largest(grown.buffer(-gap / 2, join_style=1))
        if shape.is_empty:
            continue
        shape = shape.buffer(-rounding, join_style=1).buffer(rounding, join_style=1).simplify(SIMPLIFY)
        if shape.is_empty:
            continue
        shape = largest(shape)
        out.append((kind, [(round(x, 2), round(y, 2)) for x, y in list(shape.exterior.coords)[:-1]]))
    return out

def build(**settings):
    return {'front': build_view(FRONT, **settings), 'back': build_view(BACK, **settings)}
