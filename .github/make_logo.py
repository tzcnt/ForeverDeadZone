"""Forever Dead Zone logo: range rings seen from above, with the dead zone band lit red.
All original vector drawing (no game art). Drawn at 4x and downsampled for clean edges.
usage: python make_logo.py logo.png [icon.tga]"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
S = 4
N = 1024 * S
INK = (14, 11, 9)
ORANGE = (210, 98, 31)      # the Forever addons' chat colour, d2621f
GREEN = (62, 178, 84)
RED = (222, 52, 44)
BLUE = (70, 140, 235)

img = Image.new("RGB", (N, N), INK)
glow = Image.new("L", (N, N), 0)
ImageDraw.Draw(glow).ellipse([N * 0.08, N * 0.08, N * 0.92, N * 0.92], fill=140)
glow = glow.filter(ImageFilter.GaussianBlur(N * 0.10))
img = Image.composite(Image.new("RGB", (N, N), (60, 30, 14)), img, glow)

d = ImageDraw.Draw(img, "RGBA")
cx = cy = N // 2


def ring(r_out, r_in, colour, alpha):
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=colour + (alpha,))
    ld.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=(0, 0, 0, 0))
    img.paste(layer, (0, 0), layer)


R = N * 0.40
ring(int(R), int(R * 0.46), GREEN, 215)            # shooting range, 8 to 35 yards
ring(int(R * 0.46), int(R * 0.27), RED, 245)       # the dead zone
ring(int(R * 0.27), 0, BLUE, 235)                  # melee

d = ImageDraw.Draw(img, "RGBA")
for r in (R, R * 0.46, R * 0.27):                  # crisp edges between the bands
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK + (255,), width=int(N * 0.008))

# the hunter at the centre
dot = N * 0.035
d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=(250, 244, 232, 255))

# an arrow flying out through the bands, up and to the right
ang = math.radians(-38)
ux, uy = math.cos(ang), math.sin(ang)
x0, y0 = cx + ux * R * 0.10, cy + uy * R * 0.10
x1, y1 = cx + ux * R * 1.06, cy + uy * R * 1.06
d.line([(x0, y0), (x1, y1)], fill=(250, 244, 232, 255), width=int(N * 0.014))
head = N * 0.06
for side in (2.55, -2.55):
    hx, hy = x1 + math.cos(ang + side) * head, y1 + math.sin(ang + side) * head
    d.line([(x1, y1), (hx, hy)], fill=(250, 244, 232, 255), width=int(N * 0.014))

# orange frame, matching the other Forever addons
m = int(N * 0.035)
d.rounded_rectangle([m, m, N - m, N - m], radius=int(N * 0.07), outline=ORANGE + (255,), width=int(N * 0.014))

final = img.resize((1024, 1024), Image.LANCZOS)
final.save(OUT)
if len(sys.argv) > 2:
    final.resize((64, 64), Image.LANCZOS).save(sys.argv[2])
print("wrote", OUT)
