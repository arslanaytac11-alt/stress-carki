from PIL import Image, ImageDraw, ImageFilter
import math, os

def generate_icon(size):
    # High-res render then downscale for quality
    hi = size * 4
    img = Image.new('RGBA', (hi, hi), (3, 2, 10, 255))
    draw = ImageDraw.Draw(img)

    cx, cy = hi // 2, hi // 2
    r = int(hi * 0.42)

    # Outer glow - deep red
    glow = Image.new('RGBA', (hi, hi), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(30, 0, -1):
        alpha = int(40 * (1 - i / 30))
        gr = r + i * 4
        gd.ellipse([cx - gr, cy - gr, cx + gr, cy + gr], fill=(200, 40, 40, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=hi * 0.03))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Main gradient circle - rich red to dark red
    for i in range(r, 0, -1):
        t = i / r
        # Center: bright red (220, 50, 50) -> Edge: dark red (120, 20, 30)
        red = int(220 * (1 - t) + 140 * t)
        green = int(50 * (1 - t) + 20 * t)
        blue = int(50 * (1 - t) + 35 * t)
        draw.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(red, green, blue, 255))

    # Inner highlight - subtle bright spot top-left
    highlight = Image.new('RGBA', (hi, hi), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hx, hy = cx - int(r * 0.25), cy - int(r * 0.25)
    hr = int(r * 0.5)
    for i in range(hr, 0, -1):
        alpha = int(35 * (1 - i / hr))
        hd.ellipse([hx - i, hy - i, hx + i, hy + i], fill=(255, 120, 100, alpha))
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=hi * 0.04))
    img = Image.alpha_composite(img, highlight)

    # Cyclone arms - white, 3 spiral arms
    arm_layer = Image.new('RGBA', (hi, hi), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arm_layer)
    lw = max(3, int(r * 0.13))

    for arm in range(3):
        base = arm * (2 * math.pi / 3) - math.pi / 2
        points = []
        for step in range(80):
            t = step / 79.0
            angle = base + t * math.pi * 0.9
            dist = r * (0.1 + t * 0.72)
            px = cx + math.cos(angle) * dist
            py = cy + math.sin(angle) * dist
            points.append((px, py))

        # Draw with anti-aliased thick lines
        for j in range(len(points) - 1):
            # Taper: thicker at center, thinner at tip
            w = int(lw * (1.0 - j / len(points) * 0.3))
            ad.line([points[j], points[j + 1]], fill=(255, 255, 255, 230), width=w)

        # Round caps
        cap_r = lw // 2
        ad.ellipse([points[0][0] - cap_r, points[0][1] - cap_r,
                     points[0][0] + cap_r, points[0][1] + cap_r],
                    fill=(255, 255, 255, 230))
        tip_r = int(cap_r * 0.7)
        ad.ellipse([points[-1][0] - tip_r, points[-1][1] - tip_r,
                     points[-1][0] + tip_r, points[-1][1] + tip_r],
                    fill=(255, 255, 255, 230))

    # Center dot
    dot_r = max(3, int(r * 0.09))
    ad.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(255, 255, 255, 255))

    # Subtle shadow under arms
    shadow = arm_layer.copy()
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=hi * 0.008))
    img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, arm_layer)

    # Downscale with high quality
    img = img.convert('RGBA')
    img = img.resize((size, size), Image.LANCZOS)
    return img.convert('RGB')

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

base = r'C:\Users\User\Desktop\stress_carki_flutter\android\app\src\main\res'
for folder, sz in sizes.items():
    icon = generate_icon(sz)
    path = os.path.join(base, folder, 'ic_launcher.png')
    icon.save(path, optimize=True)
    print(f'Generated {path} ({sz}x{sz})')

print('Done!')
