"""Icon concepts for the app (light backgrounds).

The app icon is `even ocean` (design/icon.svg).

    python design/make_concepts.py <oneline|coin|glass|tree|tide|level> > icon.svg
    python design/make_concepts.py even [original|ocean|berry|earth|noir|sunset] > icon.svg

Full 1024 x 1024 square, no rounded corners (iOS rounds them itself).
"""
import sys

GOLD = """
  <linearGradient id="gold" x1="0" x2="1" y1="0" y2="1">
    <stop offset="0" stop-color="#FCE7A6"/><stop offset="0.5" stop-color="#E4B354"/><stop offset="1" stop-color="#B27C22"/>
  </linearGradient>
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#5A3E12" flood-opacity="0.22"/>
  </filter>
"""


def svg(defs, body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
        f"<defs>{GOLD}{defs}</defs>{body}</svg>"
    )


def leaf(x, y, angle, size, fill):
    L, W = size, size * 0.42
    return (
        f'<path transform="translate({x} {y}) rotate({angle})" '
        f'd="M0 0 C{L*0.3} {-W} {L*0.75} {-W*0.9} {L} 0 C{L*0.75} {W*0.9} {L*0.3} {W} 0 0 Z" fill="{fill}"/>'
    )


def oneline():
    """One continuous ink line draws the jar, then rises inside like a savings graph and ends in a leaf."""
    ink = "#1E4636"
    line = (
        "M420 240 L604 240 M436 240 L436 300 C436 330 330 350 330 450 L330 760 C330 820 370 850 430 850 "
        "L594 850 C654 850 694 820 694 760 L694 450 C694 350 588 330 588 300 L588 240"
    )
    graph = "M380 780 L450 700 L510 735 L590 600 L560 470 C552 420 540 380 520 330"
    return svg(
        '<radialGradient id="bg" cx="0.5" cy="0.35" r="0.8"><stop offset="0" stop-color="#FFFCF5"/>'
        '<stop offset="1" stop-color="#F1E7D4"/></radialGradient>',
        '<rect width="1024" height="1024" fill="url(#bg)"/>'
        '<path d="M330 760 L694 760 L694 760 C694 820 654 850 594 850 L430 850 C370 850 330 820 330 760 Z" fill="url(#gold)" opacity="0.9"/>'
        f'<path d="{line}" fill="none" stroke="{ink}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="{graph}" fill="none" stroke="{ink}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>'
        + leaf(520, 334, -120, 120, "url(#gold)")
        + leaf(522, 340, -55, 104, "#3E8A5C")
        + '<circle cx="380" cy="780" r="20" fill="url(#gold)" stroke="#1E4636" stroke-width="8"/>',
    )


def coin():
    """A big gold coin; the jar is cut out of it as negative space, half full of gold, with a sprout."""
    bg = "#FBEDE6"
    jar = (
        "M440 300 L584 300 L584 336 C584 356 650 366 650 430 L650 700 C650 740 624 760 586 760 "
        "L438 760 C400 760 374 740 374 700 L374 430 C374 366 440 356 440 336 Z"
    )
    return svg(
        f'<clipPath id="jar"><path d="{jar}"/></clipPath>',
        f'<rect width="1024" height="1024" fill="{bg}"/>'
        '<g filter="url(#shadow)"><circle cx="512" cy="520" r="340" fill="url(#gold)"/></g>'
        '<circle cx="512" cy="520" r="300" fill="none" stroke="#FFF1C8" stroke-width="10" opacity="0.7"/>'
        '<circle cx="512" cy="520" r="318" fill="none" stroke="#9A6A1A" stroke-width="4" opacity="0.4"/>'
        f'<path d="{jar}" fill="{bg}"/>'
        '<g clip-path="url(#jar)">'
        '<path d="M360 590 C430 565 470 610 512 590 C560 568 600 610 670 585 L670 780 L360 780 Z" fill="url(#gold)"/>'
        '<path d="M360 590 C430 565 470 610 512 590 C560 568 600 610 670 585" fill="none" stroke="#FFF1C8" stroke-width="8" opacity="0.8"/>'
        '</g>'
        '<path d="M512 585 C512 520 506 470 512 410" stroke="#2F6B48" stroke-width="14" fill="none" stroke-linecap="round"/>'
        + leaf(512, 450, -150, 110, "#3E8A5C")
        + leaf(512, 420, -35, 120, "#5FAE73"),
    )


def glass():
    """Modern frosted glass jar on a soft pastel glow; gold rising inside and a coin dropping in."""
    jar = (
        "M400 300 L624 300 L624 345 C624 372 720 384 720 470 L720 770 C720 826 684 852 630 852 "
        "L394 852 C340 852 304 826 304 770 L304 470 C304 384 400 372 400 345 Z"
    )
    return svg(
        '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="#FFE3CF"/><stop offset="0.55" stop-color="#F7D9E6"/><stop offset="1" stop-color="#DCD2F6"/>'
        "</linearGradient>"
        '<radialGradient id="blob" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.85"/>'
        '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>'
        '<linearGradient id="liquid" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE08C"/>'
        '<stop offset="1" stop-color="#D89A2E"/></linearGradient>'
        f'<clipPath id="jar"><path d="{jar}"/></clipPath>',
        '<rect width="1024" height="1024" fill="url(#bg)"/>'
        '<circle cx="300" cy="260" r="330" fill="url(#blob)"/>'
        f'<path d="{jar}" fill="#FFFFFF" fill-opacity="0.38" filter="url(#shadow)"/>'
        '<g clip-path="url(#jar)">'
        '<path d="M290 640 C380 600 450 670 512 640 C580 608 640 668 740 630 L740 870 L290 870 Z" fill="url(#liquid)"/>'
        '<path d="M290 640 C380 600 450 670 512 640 C580 608 640 668 740 630" fill="none" stroke="#FFF6D6" stroke-width="10"/>'
        '<circle cx="420" cy="740" r="12" fill="#FFF6D6" opacity="0.8"/><circle cx="600" cy="780" r="9" fill="#FFF6D6" opacity="0.7"/>'
        '<circle cx="520" cy="710" r="7" fill="#FFF6D6" opacity="0.7"/>'
        "</g>"
        f'<path d="{jar}" fill="none" stroke="#FFFFFF" stroke-width="10" stroke-opacity="0.95" stroke-linejoin="round"/>'
        '<path d="M344 500 C340 580 340 660 346 740" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round" opacity="0.8" fill="none"/>'
        # coin dropping in, tilted, with motion lines
        '<g transform="rotate(-22 520 220)">'
        '<ellipse cx="528" cy="226" rx="66" ry="66" fill="#B27C22"/>'
        '<ellipse cx="520" cy="220" rx="66" ry="66" fill="url(#gold)"/>'
        '<ellipse cx="520" cy="220" rx="46" ry="46" fill="none" stroke="#FFF1C8" stroke-width="6" opacity="0.8"/>'
        "</g>"
        '<path d="M470 110 L470 60 M520 96 L520 30 M570 110 L570 66" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.85"/>',
    )


def tree():
    """A money tree: the trunk is a stack of coins, the crown is coins and leaves, inside an arch."""
    parts = ['<rect width="1024" height="1024" fill="url(#bg)"/>']
    parts.append('<path d="M300 860 L300 470 A212 212 0 0 1 724 470 L724 860 Z" fill="#FFFFFF" fill-opacity="0.55" '
                 'stroke="#2F5D47" stroke-width="12"/>')
    # trunk: stacked coins seen from the side
    for i in range(6):
        y = 820 - i * 34
        parts.append(f'<rect x="452" y="{y-24}" width="120" height="30" rx="15" fill="url(#gold)" stroke="#9A6A1A" stroke-width="3"/>')
    # crown: overlapping discs, gold coins and green leaves
    for x, y, r, c in [(430, 480, 92, "#3E8A5C"), (594, 470, 96, "#5FAE73"), (512, 400, 100, "#2F6B48"),
                       (452, 560, 70, "url(#gold)"), (585, 560, 74, "url(#gold)"), (512, 500, 80, "#79C08A"),
                       (520, 330, 54, "url(#gold)")]:
        parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>')
    parts.append('<circle cx="520" cy="330" r="36" fill="none" stroke="#FFF1C8" stroke-width="6" opacity="0.8"/>')
    return svg(
        '<radialGradient id="bg" cx="0.5" cy="0.35" r="0.8"><stop offset="0" stop-color="#F8FBF3"/>'
        '<stop offset="1" stop-color="#D7E3CF"/></radialGradient>',
        "".join(parts),
    )


# --- Concepts built on what the app does: money in, money out, a balance. ---


def tide():
    """'Tide': money flows in and out like the sea. The waterline is your balance."""
    return svg(
        '<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF8EC"/>'
        '<stop offset="1" stop-color="#FCE9CF"/></linearGradient>'
        '<linearGradient id="sea" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2E7D78"/>'
        '<stop offset="1" stop-color="#173F4A"/></linearGradient>'
        '<clipPath id="disc"><circle cx="512" cy="512" r="330"/></clipPath>',
        '<rect width="1024" height="1024" fill="#F6EFE4"/>'
        '<g filter="url(#shadow)"><circle cx="512" cy="512" r="330" fill="url(#sky)"/></g>'
        '<g clip-path="url(#disc)">'
        '<path d="M150 520 C250 470 340 570 440 520 C540 470 620 570 720 520 C800 480 850 520 880 530 L880 900 L150 900 Z" fill="url(#gold)"/>'
        '<path d="M150 580 C250 535 340 625 440 580 C540 535 620 625 720 580 C800 545 850 580 880 590 L880 900 L150 900 Z" fill="url(#sea)"/>'
        '<path d="M150 520 C250 470 340 570 440 520 C540 470 620 570 720 520 C800 480 850 520 880 530" fill="none" stroke="#FFF4D2" stroke-width="10"/>'
        '</g>'
        '<path d="M512 300 L512 400 M462 350 L562 350" stroke="#2E7D78" stroke-width="30" stroke-linecap="round"/>'
        '<path d="M462 700 L562 700" stroke="#FCE9CF" stroke-width="30" stroke-linecap="round"/>',
    )


def level():
    """'Level': a spirit level. The bubble shows if you're in the plus or the minus."""
    return svg(
        '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F1F8F3"/>'
        '<stop offset="1" stop-color="#CFE5D7"/></linearGradient>'
        '<linearGradient id="liq" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D7F08A"/>'
        '<stop offset="1" stop-color="#8CC63F"/></linearGradient>'
        '<clipPath id="tube"><rect x="212" y="412" width="600" height="200" rx="100"/></clipPath>',
        '<rect width="1024" height="1024" fill="url(#bg)"/>'
        '<g filter="url(#shadow)"><rect x="172" y="372" width="680" height="280" rx="140" fill="#1F3D33"/></g>'
        '<g clip-path="url(#tube)">'
        '<rect x="212" y="412" width="600" height="200" fill="url(#liq)"/>'
        '<rect x="212" y="412" width="600" height="60" fill="#FFFFFF" opacity="0.25"/>'
        '<ellipse cx="560" cy="470" rx="96" ry="44" fill="#FFFFFF" opacity="0.92"/>'
        '<ellipse cx="532" cy="456" rx="34" ry="12" fill="#FFFFFF"/>'
        '</g>'
        '<path d="M442 412 L442 612 M582 412 L582 612" stroke="#1F3D33" stroke-width="10" opacity="0.8"/>'
        '<path d="M262 512 L322 512" stroke="#E86A5A" stroke-width="24" stroke-linecap="round"/>'
        '<path d="M702 512 L762 512 M732 482 L732 542" stroke="#1F3D33" stroke-width="24" stroke-linecap="round"/>',
    )


# Colour sets for 'Even': (money in, money out, background centre, background edge).
EVEN_PALETTES = {
    "original": ("#3FA77A", "#F07A64", "#FFFBF5", "#F2E6DA"),
    "ocean": ("#1F8A8A", "#4B5BD6", "#F5F8FC", "#DCE5F2"),
    "berry": ("#6D3FA0", "#F07FA8", "#FFF7FA", "#F1DCE6"),
    "earth": ("#6E8B3D", "#C9673F", "#FBF7EE", "#EADFCB"),
    "noir": ("#26262B", "#A89F97", "#FAF8F5", "#E6E0D9"),
    "sunset": ("#FF7A4D", "#7A5CE6", "#FFF8F2", "#F3E2EF"),
}


def even(palette="original"):
    """'Even': money in and money out overlap; where they meet is your balance (gold)."""
    inc, out, bg1, bg2 = EVEN_PALETTES[palette]
    return svg(
        f'<radialGradient id="bg" cx="0.5" cy="0.35" r="0.8"><stop offset="0" stop-color="{bg1}"/>'
        f'<stop offset="1" stop-color="{bg2}"/></radialGradient>'
        '<clipPath id="left"><circle cx="410" cy="512" r="230"/></clipPath>',
        '<rect width="1024" height="1024" fill="url(#bg)"/>'
        '<g filter="url(#shadow)">'
        f'<circle cx="410" cy="512" r="230" fill="{inc}"/>'
        f'<circle cx="614" cy="512" r="230" fill="{out}"/>'
        '</g>'
        '<g clip-path="url(#left)"><circle cx="614" cy="512" r="230" fill="url(#gold)"/></g>'
        '<path d="M330 512 L410 512 M370 472 L370 552" stroke="#FFFFFF" stroke-width="22" stroke-linecap="round"/>'
        '<path d="M620 512 L700 512" stroke="#FFFFFF" stroke-width="22" stroke-linecap="round"/>'
        '<circle cx="512" cy="512" r="18" fill="#FFFFFF"/>',
    )


if __name__ == "__main__":
    name = sys.argv[1]
    if name == "even":
        print(even(sys.argv[2] if len(sys.argv) > 2 else "original"))
    else:
        print({"oneline": oneline, "coin": coin, "glass": glass, "tree": tree,
               "tide": tide, "level": level}[name]())
