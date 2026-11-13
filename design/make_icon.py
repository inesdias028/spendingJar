"""Draws the Spending Jar app icon (realistic gold coin stacks) as an SVG.

    python design/make_icon.py <theme> > icon.svg

Themes are the background colours below. The SVG is a full square with no
rounded corners: iOS and Android round the corners themselves.
"""
import sys

THEMES = {
    "midnight": ("#22355E", "#0B1428"),
    "burgundy": ("#6E2337", "#2A0812"),
    "plum": ("#4E2A5C", "#1A0B21"),
    "charcoal": ("#3A3A40", "#111114"),
    "emerald": ("#2C5A4C", "#0F2620"),
}

RX, RY, T = 96, 31, 25  # coin radius x / y (perspective) and thickness


def coin_side(cx, y, i):
    """Edge of one coin whose bottom centre line is at y."""
    top = y - T
    side = (
        f'<path d="M{cx-RX} {top} L{cx-RX} {y} A{RX} {RY} 0 0 0 {cx+RX} {y} '
        f'L{cx+RX} {top} A{RX} {RY} 0 0 1 {cx-RX} {top} Z" fill="url(#edge)"/>'
    )
    # Ridges on the rim: a thick dashed stroke that follows the curve.
    ridges = (
        f'<path d="M{cx-RX+3} {y-T/2} A{RX-3} {RY} 0 0 0 {cx+RX-3} {y-T/2}" fill="none" '
        f'stroke="#5A3A0A" stroke-opacity="0.28" stroke-width="{T-8}" stroke-dasharray="2.2 5.5"/>'
    )
    seam = (
        f'<path d="M{cx-RX} {y} A{RX} {RY} 0 0 0 {cx+RX} {y}" fill="none" '
        f'stroke="#4A2E06" stroke-opacity="0.55" stroke-width="2.2"/>'
    )
    return side + ridges + seam


def coin_top(cx, y):
    """Face of the top coin, with rim and embossed euro sign."""
    return (
        f'<ellipse cx="{cx}" cy="{y}" rx="{RX}" ry="{RY}" fill="url(#face)" stroke="#8A5E14" stroke-width="2"/>'
        f'<ellipse cx="{cx}" cy="{y}" rx="{RX-14}" ry="{RY-5}" fill="none" stroke="#9C6C1C" stroke-width="3" stroke-opacity="0.6"/>'
        f'<ellipse cx="{cx}" cy="{y+1.5}" rx="{RX-16}" ry="{RY-6}" fill="none" stroke="#FFF1C4" stroke-width="1.5" stroke-opacity="0.5"/>'
        f'<g transform="translate({cx} {y}) scale(1 {RY/RX:.3f})">'
        f'<text x="2" y="27" text-anchor="middle" font-family="Georgia, \'Times New Roman\', serif" font-weight="700" font-size="78" fill="#FFF0C2" fill-opacity="0.55">€</text>'
        f'<text x="0" y="24" text-anchor="middle" font-family="Georgia, \'Times New Roman\', serif" font-weight="700" font-size="78" fill="#9A6A18">€</text>'
        f'</g>'
    )


def stack(cx, base, n, seed):
    parts = [f'<ellipse cx="{cx+14}" cy="{base+10}" rx="{RX+26}" ry="{RY+8}" fill="#000" opacity="0.45" filter="url(#soft)"/>']
    y = base
    top_x = cx
    for i in range(n):
        dx = ((seed * 7 + i * 13) % 11 - 5) * 1.4  # small hand-stacked wobble
        x = cx + dx
        parts.append(coin_side(x, y, i))
        top_x = x
        y -= T
    parts.append(coin_top(top_x, y))
    return "".join(parts), top_x, y


def sparkle(x, y, r, o=1.0):
    return (
        f'<path d="M{x} {y-r} Q{x+r*0.18} {y-r*0.18} {x+r} {y} Q{x+r*0.18} {y+r*0.18} {x} {y+r} '
        f'Q{x-r*0.18} {y+r*0.18} {x-r} {y} Q{x-r*0.18} {y-r*0.18} {x} {y-r} Z" fill="#F6DC94" opacity="{o}"/>'
    )


def icon(theme):
    light, dark = THEMES[theme]
    s1, _, _ = stack(282, 812, 4, 1)
    s2, _, _ = stack(512, 812, 7, 2)
    s3, x3, y3 = stack(742, 812, 10, 3)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <radialGradient id="bg" cx="0.5" cy="0.32" r="0.85">
    <stop offset="0" stop-color="{light}"/><stop offset="1" stop-color="{dark}"/>
  </radialGradient>
  <linearGradient id="edge" x1="0" x2="1" y1="0" y2="0">
    <stop offset="0" stop-color="#7A5210"/><stop offset="0.18" stop-color="#E9C26A"/>
    <stop offset="0.32" stop-color="#FBE3A0"/><stop offset="0.55" stop-color="#C9952F"/>
    <stop offset="0.85" stop-color="#8E6114"/><stop offset="1" stop-color="#5E3D08"/>
  </linearGradient>
  <radialGradient id="face" cx="0.38" cy="0.3" r="0.8">
    <stop offset="0" stop-color="#FFF0BE"/><stop offset="0.45" stop-color="#EBC46C"/>
    <stop offset="1" stop-color="#B88528"/>
  </radialGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#F6DC94" stop-opacity="0.28"/><stop offset="1" stop-color="#F6DC94" stop-opacity="0"/>
  </radialGradient>
  <filter id="soft" x="-30%" y="-80%" width="160%" height="260%"><feGaussianBlur stdDeviation="14"/></filter>
</defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<circle cx="862" cy="150" r="120" fill="url(#glow)"/>
<path d="M150 610 C270 570 330 440 470 430 C600 420 640 300 812 190" fill="none" stroke="#F3E7CF"
  stroke-width="12" stroke-linecap="round" stroke-dasharray="0.1 32" opacity="0.8"/>
{sparkle(862, 150, 46)}{sparkle(185, 250, 16, 0.8)}{sparkle(300, 150, 22, 0.9)}{sparkle(610, 225, 12, 0.7)}{sparkle(905, 330, 12, 0.6)}
{s1}{s2}{s3}
</svg>'''


if __name__ == "__main__":
    print(icon(sys.argv[1] if len(sys.argv) > 1 else "midnight"))
