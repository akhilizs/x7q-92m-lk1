# Muscle map geometry on a 100 x 200 canvas per view (head at the top, feet at the bottom).
# Each entry: (kind, points, mirror). kind is a MuscleGroup raw value, "base" (the body
# silhouette, drawn first so the gaps between muscles read as definition lines) or "other"
# (muscles no exercise group trains, e.g. adductors). The muscle shapes are rough seeds:
# geometry.py grows them to fill the body.
# mirror=True also draws the shape flipped to the other side (x -> 100 - x).
import math

def E(cx, cy, rx, ry, n=12):
    return [(round(cx + rx*math.cos(2*math.pi*i/n - math.pi/2), 2), round(cy + ry*math.sin(2*math.pi*i/n - math.pi/2), 2)) for i in range(n)]

def sym(left):
    """A symmetric shape from its left half, listed from top centre to bottom centre."""
    right = [(round(100 - x, 2), y) for x, y in reversed(left) if abs(x - 50) > 0.01]
    return left + right

# --- Silhouette -------------------------------------------------------------------------
HEAD = E(50, 14.6, 7.8, 10.2)
NECK = [(45, 21), (55, 21), (56.6, 31), (50, 33), (43.4, 31)]
TORSO = sym([(50, 28.5), (44, 29.6), (37.5, 32), (31, 34.2), (33.6, 45), (34.4, 56), (36.4, 68), (37.4, 80),
             (36, 89), (35, 97), (42, 99), (50, 102)])
ARM = [(31, 34.2), (26.4, 36.8), (23.9, 42.6), (23, 50), (22.2, 58), (21.5, 66), (20.1, 73), (18.6, 80),
       (17.1, 89), (15.9, 97.5), (14.8, 103.5), (15.1, 109.5), (17.8, 113), (20.6, 111), (21.2, 104),
       (21.7, 98), (23.6, 89), (25.9, 80.5), (27.4, 73.4), (29.1, 66), (30.7, 58), (32.1, 50.5), (33.6, 44.5)]
LEG = [(36, 88), (34, 96), (33.1, 106), (33.5, 118), (35.1, 130), (37.3, 139.5), (36.9, 147.5), (35.5, 156),
       (36.1, 166), (37.9, 177), (38.6, 184.2), (37.2, 189), (38.9, 193.2), (45.2, 193.2), (46.5, 190),
       (45.6, 184), (46, 176), (47, 165), (47.3, 156), (46.7, 148), (46.4, 141), (47.4, 132), (48.8, 120),
       (49.6, 108), (50, 101), (47, 95), (42, 90.6)]
SILHOUETTE = [("base", HEAD, False), ("base", NECK, False), ("base", TORSO, False), ("base", ARM, True), ("base", LEG, True)]

# --- Shared shapes ----------------------------------------------------------------------
DELT = [(33.8, 35.2), (29.6, 35.5), (26.6, 38.3), (25, 43.6), (25.3, 49), (27.3, 51.6), (29.7, 47.4),
        (32.3, 42.4), (35.4, 38.6), (37.8, 36.3)]
FOREARM_OUTER = [(24.1, 72.6), (21.6, 77.8), (19.6, 85.2), (18.2, 94.6), (19.7, 95.8), (22.3, 87.2),
                 (24.7, 79.2), (26.1, 74.2)]
FOREARM_INNER = [(26.9, 74.8), (25.2, 80.2), (23, 88), (20.9, 96.2), (22.3, 96.8), (24.8, 89.2),
                 (27, 81.2), (27.9, 75.6)]

FRONT = SILHOUETTE + [
    ("back", [(44.4, 30.4), (39.6, 32.4), (34.8, 34.2), (40.4, 34.8), (44.8, 33.6)], True),          # trapezius
    ("other", [(46.6, 23.4), (48.7, 31.2), (47.4, 32.2), (45.2, 24.8)], True),                     # neck
    ("shoulders", DELT, True),                                                                     # deltoid
    ("chest", [(38.6, 36.6), (35.6, 39.6), (33.8, 44.6), (34.5, 49.6), (37.8, 53.2), (43.5, 54.5),
               (49.3, 53.3), (49.3, 36.8), (45, 35.3)], True),                                     # pectoralis
    ("biceps", [(27.2, 52.6), (24.9, 57.6), (24.2, 63), (24.9, 68.8), (27.4, 71.4), (29.6, 67.6),
                (30.7, 61.6), (30.9, 56.2), (29.6, 52.4)], True),                                  # biceps
    ("forearms", FOREARM_OUTER, True),
    ("forearms", FOREARM_INNER, True),
    ("core", [(35.2, 52.4), (38.6, 54.4), (38.4, 56.2), (35.5, 55.3)], True),                       # serratus
    ("core", [(35.6, 57), (38.8, 58.7), (38.6, 60.4), (35.9, 59.8)], True),
    ("core", [(36, 61.4), (39, 63), (38.8, 64.7), (36.4, 64.2)], True),
    ("core", [(36.6, 66), (39.8, 66.6), (42.6, 70.2), (43.3, 79), (42.3, 88.2), (39.6, 86.4), (37.7, 80),
              (37.4, 72.6)], True),                                                                # external oblique
    ("core", [(44.4, 56.2), (49.3, 55.8), (49.3, 62.4), (44.2, 62.8)], True),                       # rectus abdominis
    ("core", [(44.2, 63.8), (49.3, 63.6), (49.3, 70), (44.2, 70.2)], True),
    ("core", [(44.3, 71.2), (49.3, 71), (49.3, 77.6), (44.6, 77.8)], True),
    ("core", [(44.8, 78.8), (49.3, 78.6), (49.3, 92.4), (47.8, 91.4), (46, 86.4), (45, 82.2)], True),
    ("other", [(36.5, 88.6), (39.5, 88.2), (40.6, 93.2), (37.9, 98.6), (35.7, 96.4)], True),        # hip (TFL)
    ("quads", [(35.1, 99.2), (34.1, 107), (34.3, 118), (35.7, 128), (37.7, 135.6), (39.6, 133.2),
               (39.2, 122), (38.6, 110), (38.9, 101.4), (37.3, 97.8)], True),                     # vastus lateralis
    ("quads", [(40.5, 96.2), (39.7, 104), (39.9, 116), (41.1, 127), (42.6, 133.6), (44.4, 127.2),
               (45.4, 115), (45.2, 103), (43.1, 96.6)], True),                                     # rectus femoris
    ("quads", [(44.9, 121.8), (42.9, 130.2), (43.5, 135.8), (46.2, 136.6), (47.6, 132), (47.4, 126)], True),  # vastus medialis
    ("other", [(45.9, 96.8), (46.5, 104), (46.5, 115), (47.6, 120.8), (49.4, 110), (49.6, 101.6),
               (48, 96)], True),                                                                   # adductors
    ("calves", [(38.3, 146.4), (37.4, 154), (38.4, 166), (40.2, 177.2), (41.6, 177.6), (41.5, 166),
                (41.1, 154), (40.8, 146.8)], True),                                                # tibialis anterior
    ("calves", [(42.6, 145.8), (43.4, 152), (44.4, 160), (44.6, 166.4), (45.9, 160), (46.4, 151),
                (45.8, 145.6), (44.4, 144.4)], True),                                              # gastrocnemius (inner)
]

BACK = SILHOUETTE + [
    ("back", [(46, 26.6), (50, 25.6), (54, 26.6), (58, 31.6), (65.4, 34.6), (59.6, 39.6), (55.4, 48),
              (52.2, 60), (50, 63.2), (47.8, 60), (44.6, 48), (40.4, 39.6), (34.6, 34.6), (42, 31.6)], False),  # trapezius
    ("shoulders", DELT, True),                                                                     # rear deltoid
    ("back", [(37.2, 40), (34.3, 43.2), (34.9, 47.6), (38.6, 49.6), (43, 48.4), (42.5, 44), (40.4, 40.8)], True),  # infraspinatus
    ("back", [(34.7, 49.4), (35.5, 52.6), (39.2, 53.6), (42, 51.8), (38.6, 50.6)], True),          # teres major
    ("back", [(34.9, 54.4), (35.3, 61), (37.1, 69), (40.6, 76.6), (44.6, 80.6), (46.4, 75.6), (46.4, 67.6),
              (45.6, 61), (43.6, 55), (39.6, 55.4)], True),                                         # latissimus
    ("back", [(47, 63.6), (49.4, 64.4), (49.4, 87.2), (47, 87.6), (46.6, 81), (47.2, 72)], True),  # erector spinae
    ("triceps", [(28.7, 52.2), (27.1, 57.2), (26.9, 63.2), (28.3, 69.2), (30.2, 70.2), (31.4, 64.2),
                 (31.6, 57.6), (30.6, 52.6)], True),                                               # triceps long head
    ("triceps", [(26.2, 52), (24.6, 56.2), (24.3, 62.2), (25.1, 67.8), (26.3, 64.2), (26.5, 57.6)], True),  # lateral head
    ("forearms", FOREARM_OUTER, True),
    ("forearms", FOREARM_INNER, True),
    ("glutes", [(36.4, 86.6), (39.6, 84.8), (44.6, 85.4), (43, 89.8), (38, 91.4), (36.1, 90.2)], True),  # gluteus medius
    ("glutes", [(36.3, 92.6), (35.7, 99), (37.3, 105.6), (42, 108.6), (48.8, 107.6), (49.4, 99),
                (48.6, 90.8), (44.4, 89), (39.6, 91.2)], True),                                    # gluteus maximus
    ("hamstrings", [(35.7, 110.6), (34.9, 119), (35.7, 128), (37.7, 135.6), (40.6, 136.4), (41.2, 126),
                    (40.6, 116), (39.4, 110.8)], True),                                           # biceps femoris
    ("hamstrings", [(41.9, 111), (42.7, 120), (43.5, 129), (44.3, 136.2), (46.6, 135.2), (47.6, 125),
                    (48, 115), (46.8, 110.2)], True),                                             # semitendinosus
    ("other", [(48.3, 109.4), (49.4, 112), (49.4, 122), (48.5, 124)], True),                       # adductor
    ("calves", [(37.1, 145.2), (35.7, 152), (36.1, 160), (38.4, 166.4), (40.8, 164.6), (41.2, 155),
                (40.6, 147.6)], True),                                                             # gastrocnemius (outer)
    ("calves", [(42.2, 144.8), (41.9, 152), (42.5, 161), (43.9, 167.4), (46, 165), (46.8, 156),
                (46.4, 148.4), (44.8, 144.8)], True),                                              # gastrocnemius (inner)
    ("calves", [(37.9, 168.8), (38.9, 175), (40.6, 178), (41.6, 172), (39.9, 168.2)], True),       # soleus
    ("calves", [(44.1, 169.2), (45.6, 168.2), (45.2, 175), (43.7, 176.2)], True),
]

# --- Build ------------------------------------------------------------------------------
# The shapes above are drawn slim; these transforms give an athletic V-taper: broader
# shoulders, thicker arms angled slightly out from the body, and stronger legs.
ARM_SHAPES = {id(ARM), id(FOREARM_OUTER), id(FOREARM_INNER)}
ARM_KINDS = {"biceps", "triceps", "forearms"}
LEG_KINDS = {"quads", "hamstrings", "calves"}

def region(kind, pts):
    if id(pts) in ARM_SHAPES or kind in ARM_KINDS:
        return "arm"
    if id(pts) == id(LEG) or kind in LEG_KINDS:
        return "leg"
    if kind == "other" and min(y for _, y in pts) > 90:
        return "leg"            # adductors and the hip sit on the legs
    return "torso"

def taper(y):
    """How much wider the body is at height y (shoulders out, waist unchanged)."""
    if y <= 40: return 1.08
    if y >= 72: return 1.0
    return 1.08 - 0.08 * (y - 40) / 32

def athletic(kind, pts):
    part = region(kind, pts)
    out = []
    for x, y in pts:
        if part == "torso":
            x = 50 + (x - 50) * taper(y)
        elif part == "arm":
            cx = 28 + (y - 40) * (-9.5 / 58)           # the arm's centre line
            x = cx + (x - cx) * 1.2                    # thicker
            px, py, a = 29, 36, math.radians(6)        # swing out from the shoulder
            dx, dy = x - px, y - py
            x, y = px + dx * math.cos(a) - dy * math.sin(a), py + dx * math.sin(a) + dy * math.cos(a)
            x -= 21 * (taper(36) - 1)                  # follow the broader shoulders
        elif part == "leg":
            x = 50 - (50 - x) * 1.07                   # stronger thighs and calves
        out.append((round(x, 2), round(y, 2)))
    return out

def expand(shapes):
    out = []
    for kind, pts, mirror in shapes:
        pts = athletic(kind, pts)
        out.append((kind, pts))
        if mirror:
            out.append((kind, [(round(100 - x, 2), y) for x, y in reversed(pts)]))
    return out
