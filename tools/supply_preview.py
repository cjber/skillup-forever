"""Render and audit Supply's real top-level form anchors via its native-widget fixture."""

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

import screenshots as shot


def render(destination, audit=False):
    ui = shot.Ui(build=shot.UI_ART_BUILD, scale=2)
    output = subprocess.check_output(["luajit", "tests/supply_ui_spec.lua", "--capture"], text=True)
    # Let the Lua fixture measure labels with the exact font the preview draws.
    widths = {}
    for line in output.splitlines()[1:]:
        parts = line.split("\t")
        if parts[1] == "FontString":
            widths[parts[9]] = ui.canvas(1, 1).text_width(parts[9], shot.FONTS["GameFontHighlightSmall"])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".lua") as metrics:
        metrics.write("return {" + ",".join(f"[{json.dumps(k)}]={v}" for k, v in widths.items()) + "}")
        metrics.flush()
        output = subprocess.check_output(
            ["luajit", "tests/supply_ui_spec.lua", "--capture"],
            text=True,
            env=dict(os.environ, SUPPLY_FONT_WIDTHS=metrics.name),
        )
    nodes = {}
    lines = output.splitlines()
    _, scroll_x, scroll_y = lines.pop(0).split("\t")
    for line in lines:
        key, kind, w, h, point, relative, edge, x, y, text, enabled, color = line.split("\t")
        nodes[int(key)] = dict(
            kind=kind,
            w=float(w),
            h=float(h),
            point=point,
            relative=int(relative),
            edge=edge,
            x=float(x),
            y=-float(y),
            text=text,
            enabled=enabled == "true",
            color=tuple(float(value) for value in color.split(",")),
        )
    factors = {"TOPLEFT": (0, 0), "LEFT": (0, 0.5), "RIGHT": (1, 0.5), "CENTER": (0.5, 0.5)}

    def resolve(node):
        if "rect" in node:
            return node["rect"]
        x, y = node["x"], node["y"]
        if node["relative"]:
            rx, ry, rw, rh = resolve(nodes[node["relative"]])
            ex, ey = factors[node["edge"]]
            x, y = x + rx + ex * rw, y + ry + ey * rh
        px, py = factors[node["point"]]
        node["rect"] = (x - px * node["w"], y - py * node["h"], node["w"], node["h"])
        return node["rect"]

    canvas = ui.canvas(940, 680)
    shot.extend_art(canvas, "Profession-Background-Overview", 26, 45, 846, 571, shot.BACKGROUND_ART)
    for node in nodes.values():
        x, y, w, h = resolve(node)
        x, y = x + 24 + float(scroll_x), y + 24 - float(scroll_y)
        if node["kind"] == "EditBox":
            shot.input_box(canvas, x, y, w, h, node["text"])
        elif node["kind"] == "CheckButton":
            canvas.draw(ui.texture("interface/buttons/ui-checkbox-up.blp"), x, y, w, h)
        elif node["kind"] == "Button":
            shot.ui_panel_button(canvas, x, y, w, h, node["text"], state="normal" if node["enabled"] else "disabled")
        elif node["kind"] == "FontString":
            for index, line in enumerate(
                shot.wrap_text(canvas, node["text"].replace(" | ", "\n"), shot.FONTS["GameFontHighlightSmall"], w)
            ):
                canvas.text(x, y + index * 12, line, shot.FONTS["GameFontHighlightSmall"], node["color"])
    shot.profession_tabs(canvas, 24, 24, "supply", frame_w=850)
    shot.portrait_frame_art(canvas, 24, 24, 850, 594, 136247, "Leatherworking")
    canvas.save(destination)
    findings = []
    controls = [n for n in nodes.values() if n["kind"] in ("CheckButton", "EditBox", "Button")]
    labels = [n for n in nodes.values() if n["kind"] == "FontString"]
    for control in controls:
        x, y, w, h = resolve(control)
        for label in labels:
            lx, ly, lw, lh = resolve(label)
            lw = min(lw, canvas.text_width(label["text"], shot.FONTS["GameFontHighlightSmall"]))
            left = x - (5 if control["kind"] == "EditBox" else 0)
            if left < lx + lw and x + w > lx and y < ly + lh and y + h > ly:
                findings.append(f"{control['kind']} overlaps {label['text']!r}")
    for node in nodes.values():
        x, y, w, h = resolve(node)
        # The native checkbox frame extends left so its inset art aligns with the content.
        if x < (-4 if node["kind"] == "CheckButton" else 0) or y < 0 or x + w > 806:
            findings.append(f"{node['kind']} outside content bounds")
    manifest = {
        "host": {"template": "PortraitFrameTemplate", "rect": [24, 24, 850, 594]},
        "bottomTabs": {"template": "PanelTabButtonTemplate", "edge": "BOTTOMLEFT"},
        "widgets": [dict(node, rect=list(resolve(node))) for node in nodes.values()],
        "findings": findings,
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".layout.json") as layout:
        layout.write(json.dumps(manifest, indent=2) + "\n")
        layout.flush()
    print("Supply geometry: " + ("; ".join(findings) if findings else "passed"))
    if audit and findings:
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--audit", action="store_true")
    args = parser.parse_args()
    render(args.destination, args.audit)
