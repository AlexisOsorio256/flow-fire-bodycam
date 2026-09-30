#!/usr/bin/env python3
"""Generates authentic urban street graffiti murals and tags matching the reference video frames (sec_09.png, sec_17.png).
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parents[1]
OUT_DIR = REPO / "assets" / "textures" / "graffiti"
OUT_DIR.mkdir(parents=True, exist_ok=True)

def draw_spray_curve(img, control_points, color=(255, 255, 255, 255), width=10, drips=True):
    # Sample Catmull-Rom / smooth spline through control points
    spline_pts = []
    n = len(control_points)
    if n < 2:
        return
    for i in range(n - 1):
        p0 = control_points[max(0, i - 1)]
        p1 = control_points[i]
        p2 = control_points[i + 1]
        p3 = control_points[min(n - 1, i + 2)]
        steps = int(math.hypot(p2[0] - p1[0], p2[1] - p1[1]) * 1.5)
        steps = max(4, steps)
        for s in range(steps):
            t = s / float(steps)
            t2 = t * t
            t3 = t2 * t
            # Catmull-Rom formulation
            x = 0.5 * ((2 * p1[0]) +
                       (-p0[0] + p2[0]) * t +
                       (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) +
                       (-p0[1] + p2[1]) * t +
                       (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            spline_pts.append((x, y))
    spline_pts.append(control_points[-1])

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # 1. Soft overspray halo
    halo_col = (color[0], color[1], color[2], int(color[3] * 0.28))
    for pt in spline_pts:
        r = width * 1.3
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=halo_col)
    layer = layer.filter(ImageFilter.GaussianBlur(radius=width * 0.4))
    img.alpha_composite(layer)

    # 2. Solid core stroke
    core_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(core_layer)
    for idx, pt in enumerate(spline_pts):
        r = width * 0.5 * (1.0 + 0.15 * math.sin(idx * 0.1))
        alpha = int(color[3] * random.uniform(0.88, 1.0))
        cdraw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r],
                      fill=(color[0], color[1], color[2], alpha))

    if drips:
        for idx in range(0, len(spline_pts), max(1, len(spline_pts) // 5)):
            if random.random() < 0.55:
                px, py = spline_pts[idx]
                drip_len = random.randint(18, 55)
                w = max(2, int(width * 0.35))
                for d in range(drip_len):
                    w_curr = max(1, int(w * (1.0 - d / drip_len * 0.45)))
                    alpha = int(color[3] * (0.92 - (d / drip_len) * 0.25))
                    cdraw.ellipse([px - w_curr, py + d - w_curr, px + w_curr, py + d + w_curr],
                                  fill=(color[0], color[1], color[2], alpha))
                cdraw.ellipse([px - w, py + drip_len - w, px + w, py + drip_len + w],
                              fill=(color[0], color[1], color[2], int(color[3] * 0.95)))

    core_layer = core_layer.filter(ImageFilter.GaussianBlur(radius=0.75))
    img.alpha_composite(core_layer)


def generate_left_mural():
    """Generates the large cyan/teal 'DIRT' mural matching sec_09.png and sec_17.png left facade."""
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Orange / Red background aura / splash cloud
    aura_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura_img)
    random.seed(42)
    for _ in range(60):
        cx = random.randint(120, 900)
        cy = random.randint(120, 380)
        rx = random.randint(40, 110)
        ry = random.randint(30, 80)
        col = random.choice([
            (225, 45, 80, 110),
            (240, 110, 30, 100),
            (210, 30, 120, 80),
        ])
        aura_draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col)
    aura_img = aura_img.filter(ImageFilter.GaussianBlur(radius=18))
    img.alpha_composite(aura_img)

    # 2. 3D extruded shadow blocks (down-right shift)
    shadow_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_img)

    # Letter polygons for D - I - R - T
    letters = [
        # D
        [(110, 140), (220, 130), (280, 200), (275, 300), (210, 370), (105, 360), (100, 250)],
        # I
        [(310, 135), (375, 135), (370, 365), (305, 365)],
        # R
        [(410, 135), (520, 130), (550, 195), (510, 250), (560, 365), (495, 365), (465, 270), (455, 365), (405, 365)],
        # T
        [(580, 135), (750, 130), (745, 190), (690, 190), (680, 365), (620, 365), (625, 190), (580, 190)],
        # exclamation / mark
        [(790, 130), (845, 125), (830, 290), (785, 285)],
        [(780, 325), (830, 320), (825, 365), (775, 365)],
    ]

    # Draw dark blue / black 3D shadow extrusion
    for poly in letters:
        for offset in range(35, 0, -3):
            shifted = [(p[0] + offset, p[1] + offset * 0.75) for p in poly]
            s_draw.polygon(shifted, fill=(12, 18, 32, 230))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=3))
    img.alpha_composite(shadow_img)

    # 3. Letter Fills (Electric Teal / Cyan gradient with highlights)
    fill_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    f_draw = ImageDraw.Draw(fill_img)
    for poly in letters:
        # Base teal fill
        f_draw.polygon(poly, fill=(0, 185, 210, 255))
        # Top half brighter highlight
        top_half = []
        min_y = min(p[1] for p in poly)
        max_y = max(p[1] for p in poly)
        mid_y = min_y + (max_y - min_y) * 0.55
        for p in poly:
            if p[1] <= mid_y:
                top_half.append(p)
            else:
                top_half.append((p[0], mid_y))
        f_draw.polygon(top_half, fill=(90, 235, 255, 180))

    # Inner letter cutouts (hole in D and R)
    f_draw.polygon([(150, 190), (210, 185), (230, 245), (200, 305), (150, 300)], fill=(0, 0, 0, 0))
    f_draw.polygon([(445, 180), (490, 180), (495, 225), (445, 225)], fill=(0, 0, 0, 0))
    img.alpha_composite(fill_img)

    # 4. Outlines: Thick black strokes with dripping paint runs
    outline_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for poly in letters:
        draw_spray_curve(outline_img, poly + [poly[0]], color=(15, 15, 18, 255), width=14, drips=True)
    # Inner holes outlines
    draw_spray_curve(outline_img, [(150, 190), (210, 185), (230, 245), (200, 305), (150, 300), (150, 190)],
                    color=(15, 15, 18, 255), width=10, drips=False)
    draw_spray_curve(outline_img, [(445, 180), (490, 180), (495, 225), (445, 225), (445, 180)],
                    color=(15, 15, 18, 255), width=10, drips=False)

    # 5. Crisp white highlights & tags over letters
    for poly in letters:
        high_points = [p for p in poly if p[1] < 220]
        if len(high_points) >= 2:
            draw_spray_curve(outline_img, high_points, color=(255, 255, 255, 220), width=5, drips=False)

    img.alpha_composite(outline_img)
    return img

def generate_right_mural():
    """Generates the colorful bubble-letter 'IVES' throwup matching sec_17.png right facade."""
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    
    # 1. Orange background cloud / halo
    halo_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(halo_img)
    random.seed(99)
    for _ in range(50):
        cx = random.randint(140, 880)
        cy = random.randint(140, 360)
        rx = random.randint(45, 100)
        ry = random.randint(35, 75)
        col = random.choice([
            (235, 120, 20, 130),
            (250, 165, 30, 120),
            (220, 60, 20, 100),
        ])
        h_draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col)
    halo_img = halo_img.filter(ImageFilter.GaussianBlur(radius=16))
    img.alpha_composite(halo_img)

    # 2. Bubble letters: I - V - E - S
    bubble_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bubble_img)

    # Drop shadow
    shadow_bubbles = [
        # I
        (190, 250, 65, 120),
        # V left, right
        (310, 240, 55, 115), (390, 230, 55, 115),
        # E top, mid, bot
        (510, 180, 65, 55), (500, 250, 55, 45), (510, 320, 65, 55), (460, 250, 50, 115),
        # S top, bot
        (660, 190, 70, 65), (660, 310, 75, 70), (670, 250, 50, 45),
        # Extra cloud / mark
        (790, 250, 60, 90)
    ]
    for (cx, cy, rx, ry) in shadow_bubbles:
        b_draw.ellipse([cx + 25 - rx, cy + 25 - ry, cx + 25 + rx, cy + 25 + ry], fill=(10, 14, 25, 230))
    bubble_img = bubble_img.filter(ImageFilter.GaussianBlur(radius=4))
    img.alpha_composite(bubble_img)

    # 3. Main blue/cyan bubble fills
    fill_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    f_draw = ImageDraw.Draw(fill_img)
    for (cx, cy, rx, ry) in shadow_bubbles:
        f_draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(30, 140, 235, 255))
        # Top glossy highlight
        f_draw.ellipse([cx - int(rx*0.7), cy - int(ry*0.75), cx + int(rx*0.6), cy - int(ry*0.1)], fill=(120, 215, 255, 190))
    img.alpha_composite(fill_img)

    # 4. Outlines and heavy black drip marks
    line_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for (cx, cy, rx, ry) in shadow_bubbles:
        pts = []
        for a in range(0, 360, 15):
            rad = math.radians(a)
            px = cx + rx * math.cos(rad)
            py = cy + ry * math.sin(rad)
            pts.append((px, py))
        draw_spray_curve(line_img, pts + [pts[0]], color=(12, 12, 15, 255), width=13, drips=True)

    # White street tags over the piece
    tag_pts1 = [(250, 310), (320, 330), (390, 300), (430, 340)]
    tag_pts2 = [(580, 220), (630, 180), (700, 210), (740, 190)]
    draw_spray_curve(line_img, tag_pts1, color=(255, 255, 255, 230), width=5, drips=True)
    draw_spray_curve(line_img, tag_pts2, color=(255, 255, 255, 230), width=5, drips=True)

    img.alpha_composite(line_img)
    return img

def generate_white_tarp_tag():
    """Generates authentic white spray tag calligraphy for the green fence tarp."""
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    strokes = [
        # Letter 1: Bold C / K
        [(150, 160), (100, 200), (90, 280), (120, 350), (200, 370), (240, 340)],
        [(140, 240), (220, 170), (240, 150)],
        [(170, 250), (250, 360)],
        # Letter 2: R
        [(280, 370), (290, 160), (360, 150), (390, 190), (370, 250), (310, 260)],
        [(330, 260), (410, 370)],
        # Letter 3: U
        [(440, 160), (440, 320), (490, 360), (530, 320), (540, 160)],
        # Letter 4: Z
        [(580, 165), (690, 160), (590, 350), (710, 345)],
        # Underline flourish
        [(90, 410), (300, 425), (550, 420), (750, 390), (820, 350)],
        # Halo / crown at top
        [(320, 110), (420, 80), (520, 110)],
        # Dots
        [(760, 160), (770, 165)],
        [(765, 200), (775, 205)]
    ]

    for stroke in strokes:
        draw_spray_curve(img, stroke, color=(245, 245, 240, 245), width=9, drips=True)

    return img

if __name__ == "__main__":
    mural_l = generate_left_mural()
    mural_l.save(OUT_DIR / "mural_dirty_cyan.png")
    print("Saved mural_dirty_cyan.png")

    mural_r = generate_right_mural()
    mural_r.save(OUT_DIR / "mural_bubble_ives.png")
    print("Saved mural_bubble_ives.png")

    tarp_tag = generate_white_tarp_tag()
    tarp_tag.save(OUT_DIR / "tag_white_spray.png")
    print("Saved tag_white_spray.png")
