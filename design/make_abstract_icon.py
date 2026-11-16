"""Abstract versions of the Spending Jar icon: a jar, money filling it, a tree
growing, and a little magic, made from simple shapes and light.

    python design/make_abstract_icon.py <a|b|c> > icon.svg

The app icon is version b (design/icon.svg).

Full 1024 x 1024 square, no rounded corners (iOS rounds them itself).
"""
import random
import sys

BG = ("#3A3A40", "#111114")

DEFS = f"""
  <radialGradient id="bg" cx="0.5" cy="0.32" r="0.85">
    <stop offset="0" stop-color="{BG[0]}"/><stop offset="1" stop-color="{BG[1]}"/>
  </radialGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#FFE29A" stop-opacity="0.5"/><stop offset="0.55" stop-color="#F2B94E" stop-opacity="0.12"/>
    <stop offset="1" stop-color="#F2B94E" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="gold" x1="0" x2="1" y1="0" y2="1">
    <stop offset="0" stop-color="#FBE3A0"/><stop offset="0.5" stop-color="#E2B457"/><stop offset="1" stop-color="#B07E26"/>
  </linearGradient>
  <filter id="blur" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="22"/></filter>
  <filter id="dotblur" x="-200%" y="-200%" width="500%" height="500%"><feGaussianBlur stdDeviation="6"/></filter>
"""

# Simple jar silhouette (rounded body, short neck).
JAR = (
    "M392 250 L632 250 L632 300 C632 330 724 340 724 420 L724 760 "
    "C724 812 690 840 640 840 L384 840 C334 840 300 812 300 760 L300 420 "
    "C300 340 392 330 392 300 Z"
)


def sparkle(x, y, r, o=1.0, c="#FBE7A8"):
    k = 0.14
    return (
        f'<path d="M{x} {y-r} Q{x+r*k} {y-r*k} {x+r} {y} Q{x+r*k} {y+r*k} {x} {y+r} '
        f'Q{x-r*k} {y+r*k} {x-r} {y} Q{x-r*k} {y-r*k} {x} {y-r} Z" fill="{c}" opacity="{o}"/>'
    )


def dot(x, y, r, o=1.0):
    return (
        f'<circle cx="{x}" cy="{y}" r="{r*3}" fill="#FFD777" opacity="{0.3*o:.2f}" filter="url(#dotblur)"/>'
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFF4CF" opacity="{o}"/>'
    )


def stars(n=40, seed=4):
    rnd = random.Random(seed)
    return "".join(
        f'<circle cx="{rnd.uniform(40, 984):.0f}" cy="{rnd.uniform(40, 984):.0f}" '
        f'r="{rnd.uniform(1, 2.4):.1f}" fill="#F3E7CF" opacity="{rnd.uniform(0.15, 0.45):.2f}"/>'
        for _ in range(n)
    )


def wrap(body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
        f'<defs>{DEFS}<clipPath id="in"><path d="{JAR}"/></clipPath></defs>'
        f'<rect width="1024" height="1024" fill="url(#bg)"/>{body}</svg>'
    )


def variant_a():
    """Line jar, gold bands of savings, a crown of overlapping see-through circles."""
    bands = "".join(
        f'<rect x="280" y="{y}" width="464" height="{h}" fill="{c}"/>'
        for y, h, c in [(790, 60, "#B07E26"), (730, 60, "#D3A246"), (676, 54, "#E8BE62"), (630, 46, "#F6D88E")]
    )
    crown = "".join(
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" opacity="{o}"/>'
        for x, y, r, c, o in [
            (470, 460, 92, "#2F7A4A", 0.85), (560, 450, 96, "#4FA36A", 0.75), (515, 385, 86, "#7CC48A", 0.7),
            (590, 520, 60, "#E2B457", 0.8), (440, 530, 54, "#F0CF7A", 0.75), (515, 470, 40, "#FFF0C2", 0.5),
        ]
    )
    trunk = '<path d="M512 630 C508 590 520 560 512 520" stroke="#E9DCC0" stroke-width="10" fill="none" stroke-linecap="round"/>'
    body = (
        stars()
        + '<circle cx="512" cy="480" r="300" fill="url(#glow)"/>'
        + f'<g clip-path="url(#in)">{bands}</g>'
        + trunk
        + f'<g style="mix-blend-mode:screen">{crown}</g>'
        + f'<path d="{JAR}" fill="none" stroke="#F3E7CF" stroke-width="12" stroke-linejoin="round" opacity="0.9"/>'
        + dot(380, 360, 5) + dot(650, 400, 4) + dot(512, 200, 4)
        + sparkle(600, 180, 22) + sparkle(420, 220, 14, 0.8) + sparkle(840, 210, 16, 0.6) + sparkle(180, 780, 12, 0.5)
    )
    return wrap(body)


def variant_b():
    """Glass jar, a honeycomb of gold coin dots filling up, a tree made of three leaves of light."""
    rnd = random.Random(2)
    coins = []
    for row in range(6):
        y = 800 - row * 46
        for col in range(9):
            x = 330 + col * 46 + (23 if row % 2 else 0)
            if x > 700 or (row == 5 and rnd.random() < 0.5):
                continue
            coins.append(f'<circle cx="{x}" cy="{y}" r="19" fill="url(#gold)"/>')
    tree = (
        '<path d="M512 560 L512 440" stroke="#F3E7CF" stroke-width="9" stroke-linecap="round"/>'
        '<path d="M512 470 C440 460 410 400 420 340 C480 350 512 400 512 470 Z" fill="#4FA36A"/>'
        '<path d="M512 430 C580 420 612 360 604 300 C544 312 512 360 512 430 Z" fill="#7CC48A"/>'
        '<path d="M512 470 C470 420 470 360 512 300 C554 360 554 420 512 470 Z" fill="#E2B457" opacity="0.9"/>'
    )
    body = (
        stars(30, 9)
        + '<circle cx="512" cy="420" r="280" fill="url(#glow)"/>'
        + f'<path d="{JAR}" fill="#FFFFFF" fill-opacity="0.07"/>'
        + f'<g clip-path="url(#in)">{"".join(coins)}</g>'
        + tree
        + f'<path d="{JAR}" fill="none" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="8" stroke-linejoin="round"/>'
        + dot(400, 300, 4) + dot(630, 340, 5) + dot(560, 220, 3.5) + sparkle(470, 200, 18) + sparkle(820, 260, 14, 0.6)
    )
    return wrap(body)


def variant_c():
    """Minimal: jar outline, a gold level like liquid light, one glowing coin-sun with a sprout."""
    wave = (
        '<path d="M280 660 C360 630 440 690 512 660 C584 630 664 690 744 660 L744 860 L280 860 Z" fill="url(#gold)"/>'
        '<path d="M280 700 C360 670 440 730 512 700 C584 670 664 730 744 700 L744 860 L280 860 Z" fill="#B07E26" opacity="0.55"/>'
    )
    sun = (
        '<circle cx="512" cy="500" r="150" fill="#FFE29A" opacity="0.35" filter="url(#blur)"/>'
        '<circle cx="512" cy="520" r="88" fill="url(#gold)"/>'
        '<circle cx="512" cy="520" r="66" fill="none" stroke="#FFF4CF" stroke-width="4" opacity="0.6"/>'
        '<path d="M512 432 L512 380" stroke="#3E7B47" stroke-width="8" stroke-linecap="round"/>'
        '<path d="M512 392 C480 392 462 370 462 344 C492 344 512 364 512 392 Z" fill="#4FA36A"/>'
        '<path d="M512 384 C546 384 566 360 566 330 C534 330 512 352 512 384 Z" fill="#7CC48A"/>'
    )
    body = (
        stars(35, 12)
        + f'<g clip-path="url(#in)">{wave}</g>'
        + sun
        + f'<path d="{JAR}" fill="none" stroke="#F3E7CF" stroke-width="10" stroke-linejoin="round" opacity="0.85"/>'
        + dot(400, 420, 4) + dot(630, 400, 4.5) + dot(560, 290, 3)
        + sparkle(600, 200, 20) + sparkle(430, 260, 12, 0.8) + sparkle(830, 200, 14, 0.6) + sparkle(190, 800, 10, 0.5)
    )
    return wrap(body)


if __name__ == "__main__":
    print({"a": variant_a, "b": variant_b, "c": variant_c}[sys.argv[1]]())
