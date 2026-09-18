import os
import math
from PIL import Image, ImageDraw, ImageFilter

size = 1024
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

# macOS Big Sur squircle bounds (roughly 824x824 inside 1024 with soft shadow)
margin = 100
card_w = size - 2 * margin
card_h = size - 2 * margin
radius = 185

# Create mask for squircle
mask = Image.new("L", (card_w, card_h), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle([0, 0, card_w, card_h], radius=radius, fill=255)

# Background gradient
bg_card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
for y in range(card_h):
    # smooth vertical gradient from deep cosmic violet to obsidian navy
    t = y / card_h
    r = int(22 * (1 - t) + 12 * t)
    g = int(24 * (1 - t) + 14 * t)
    b = int(42 * (1 - t) + 26 * t)
    line = Image.new("RGBA", (card_w, 1), (r, g, b, 255))
    bg_card.paste(line, (0, y))

# Draw inner bevel & border
card_draw = ImageDraw.Draw(bg_card)
card_draw.rounded_rectangle([1, 1, card_w - 2, card_h - 2], radius=radius, outline=(255, 255, 255, 36), width=3)
card_draw.rounded_rectangle([4, 4, card_w - 5, card_h - 5], radius=radius - 3, outline=(255, 255, 255, 16), width=2)

# Central Antigravity Symbol
center_x = card_w // 2
center_y = card_h // 2

# Draw subtle ambient glow
glow = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
glow_draw.ellipse([center_x - 220, center_y - 220, center_x + 220, center_y + 220], fill=(10, 132, 255, 45))
glow_draw.ellipse([center_x - 140, center_y - 140, center_x + 140, center_y + 140], fill=(94, 92, 230, 60))
glow = glow.filter(ImageFilter.GaussianBlur(35))
bg_card = Image.alpha_composite(bg_card, glow)

# Draw Antigravity floating rings / diamond glyph
icon_layer = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
icon_draw = ImageDraw.Draw(icon_layer)

# Outer orbiting ring
ring_radius = 170
for deg in range(0, 360, 2):
    rad = math.radians(deg)
    # elliptic tilt
    rx = center_x + int(ring_radius * math.cos(rad))
    ry = center_y + int(ring_radius * 0.45 * math.sin(rad))
    alpha = int(120 + 100 * math.sin(rad))
    icon_draw.ellipse([rx - 4, ry - 4, rx + 4, ry + 4], fill=(10, 132, 255, alpha))

# Floating core diamond / prism
core_points = [
    (center_x, center_y - 120),
    (center_x + 85, center_y),
    (center_x, center_y + 120),
    (center_x - 85, center_y)
]
icon_draw.polygon(core_points, fill=(20, 22, 36, 230), outline=(255, 255, 255, 180))

# Left facet
left_facet = [
    (center_x, center_y - 120),
    (center_x - 85, center_y),
    (center_x, center_y + 120)
]
icon_draw.polygon(left_facet, fill=(10, 132, 255, 160))

# Right facet
right_facet = [
    (center_x, center_y - 120),
    (center_x + 85, center_y),
    (center_x, center_y + 120)
]
icon_draw.polygon(right_facet, fill=(94, 92, 230, 200))

# Center light beam
icon_draw.line([center_x, center_y - 120, center_x, center_y + 120], fill=(255, 255, 255, 240), width=4)
icon_draw.ellipse([center_x - 12, center_y - 12, center_x + 12, center_y + 12], fill=(48, 209, 88, 255), outline=(255, 255, 255, 255), width=2)

bg_card = Image.alpha_composite(bg_card, icon_layer)

# Apply squircle mask
final_card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
final_card.paste(bg_card, (0, 0), mask=mask)

# Drop shadow for the squircle
shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.rounded_rectangle(
    [margin, margin + 14, margin + card_w, margin + card_h + 14],
    radius=radius,
    fill=(0, 0, 0, 120)
)
shadow = shadow.filter(ImageFilter.GaussianBlur(28))

# Compose shadow and card into 1024x1024
img.paste(shadow, (0, 0), mask=shadow)
img.paste(final_card, (margin, margin), mask=final_card)

# Output directory for iconset
iconset_dir = "/Users/yohanes/antigravity-switcher/app/AppIcon.iconset"
os.makedirs(iconset_dir, exist_ok=True)

# Generate Apple iconset sizes
sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for s, name in sizes:
    resized = img.resize((s, s), Image.Resampling.LANCZOS)
    resized.save(os.path.join(iconset_dir, name))

print("Iconset generated successfully.")
