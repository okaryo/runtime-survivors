"""Run with FontTools: python3 tool/subset_japanese_font.py /path/to/NotoSansJP.ttf.

Source: https://github.com/google/fonts/tree/main/ofl/notosansjp
Keep Japanese glyph forms and the variable weight axis; strip unused characters.
The output and OFL license are bundled, so builds need no font download.
"""
from pathlib import Path
import sys

from fontTools import subset

root = Path(__file__).resolve().parent.parent
points = set(range(0x20, 0x100))
for start, end in [(0x3000, 0x3100), (0x2000, 0x2070), (0x2190, 0x2300),
                   (0x2500, 0x2600), (0xFF00, 0xFFF0)]:
    points.update(range(start, end))
for source in (root / "lib").rglob("*.dart"):
    points.update(map(ord, source.read_text()))
options = subset.Options()
options.layout_features = ["*"]
options.name_IDs = ["*"]
options.name_legacy = True
options.name_languages = ["*"]
font = subset.load_font(sys.argv[1], options)
available = set(font.getBestCmap())
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=points & available)
subsetter.subset(font)
directory = root / "assets/fonts/noto_sans_jp"
font.save(directory / "RuntimeSansJP.ttf")
(directory / "codepoints.txt").write_text(
    "\n".join(f"{p:04X}" for p in sorted(font.getBestCmap())) + "\n"
)
print(f"Bundled {len(font.getBestCmap())} characters, "
      f"{(directory / 'RuntimeSansJP.ttf').stat().st_size:,} bytes")
