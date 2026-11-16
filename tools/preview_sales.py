"""Illustrative provider values, drawn from the production recipe tooltip's Lua output.

Run from the repository root with FOREVER_CORE set to the pinned checkout. Observations
are synthetic; recipe and item IDs are Linen Bandage 3275/1251 and Linen Cloth 2589.
These mocks are not native-client captures.
"""

import hashlib
import json
import subprocess
from pathlib import Path

from screenshots import (
    BAR_PADDING,
    FONTS,
    TOOLTIP_LINE_GAP,
    TOOLTIP_PADDING,
    UI_ART_BUILD,
    TooltipLine,
    Ui,
    scene,
    skill_bar,
    tooltip,
)


def main():
    raw = subprocess.check_output(["luajit", "tools/preview_sales.lua"], text=True)
    samples = {name: json.loads(value) for name, value in (line.split("\t", 1) for line in raw.splitlines())}
    for name, expected in (("reported", "12.50"), ("zero", "0.00"), ("unknown", None)):
        volumes = [row.get("right") for row in samples[name] if row["left"] == "TSM regional sales per day"]
        assert volumes == ([] if expected is None else [expected]), (name, volumes)
    ui = Ui(build=UI_ART_BUILD, scale=2)
    panels, x = [], 0
    for rows in samples.values():
        lines = [TooltipLine(row["left"], right=row.get("right")) for row in rows]
        canvas = tooltip(ui, lines)
        fonts = [FONTS["GameTooltipHeaderText"], FONTS["GameTooltipText"]]
        top = TOOLTIP_PADDING + sum(font.height + TOOLTIP_LINE_GAP for font in fonts)
        bar, margin = skill_bar(ui, [1, 30, 45, 60], 20)
        canvas.paste(bar, TOOLTIP_PADDING - margin, top + BAR_PADDING - margin)
        panels.append((canvas, x, 0))
        x += canvas.image.width / ui.scale + 24
    output = Path("docs/previews")
    output.mkdir(parents=True, exist_ok=True)
    target = output / "sales-volume.png"
    scene(ui, panels).save(target)
    (output / "sales-volume.json").write_text(json.dumps(samples, indent=2) + "\n")
    print(hashlib.sha256(target.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
