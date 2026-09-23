"""Render the README screenshots from the client's own UI art.

    python3 tools/screenshots.py

Needs Pillow and the wowmock library (env WOWMOCK, default ~/.claude/skills/wow-mock-screenshots). Assets
are fetched from wago.tools once and cached under ~/.cache/wowmock/<build>/.

Every number drawn comes from this repository: thresholds, reagents, sell prices and vendor
prices from Data/*.lua, pushed through a line-for-line port of Model.lua and the formatting in
Core.lua / Tooltip.lua. Only the scene's state (skill, bags, auction prices) is chosen here.
"""

import math
import os
import re
import sys
from pathlib import Path

WOWMOCK = Path(os.environ.get("WOWMOCK", Path.home() / ".claude" / "skills" / "wow-mock-screenshots"))
if not (WOWMOCK / "wowmock.py").exists():
    sys.exit(f"wowmock.py not found in {WOWMOCK}; set WOWMOCK to the directory that holds it")
sys.path.insert(0, str(WOWMOCK))

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "docs" / "screenshots"

# ------------------------------------------------------------------------------------------ Data/*.lua


def parse_lua_tables(text):
    """The `ns.Name = { ... }` constructors of a generated data file, as Python values. The files only use
    [number]/["string"]/name keys, numbers, strings, booleans and nested tables."""
    tokens = re.findall(r'--[^\n]*|"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_.]*|[{}\[\]=,;]', text)
    tokens = [t for t in tokens if not t.startswith("--")]
    position = 0

    def value():
        nonlocal position
        token = tokens[position]
        position += 1
        if token == "{":
            return table()
        if token.startswith('"'):
            return token[1:-1].encode().decode("unicode_escape")
        if token in ("true", "false"):
            return token == "true"
        if token == "nil":
            return None
        return float(token) if "." in token else int(token)

    def table():
        nonlocal position
        array, mapping = [], {}
        while tokens[position] != "}":
            if tokens[position] == "[":
                position += 1
                key = value()
                position += 2  # "]", "="
                mapping[key] = value()
            elif tokens[position + 1] == "=":
                key = tokens[position]
                position += 2
                mapping[key] = value()
            else:
                array.append(value())
            if tokens[position] in (",", ";"):
                position += 1
        position += 1
        if array and mapping:
            raise ValueError("mixed table")
        return array if array or not mapping else mapping

    result = {}
    while position < len(tokens):
        token = tokens[position]
        if token.startswith("ns.") and tokens[position + 1] == "=" and tokens[position + 2] == "{":
            position += 3
            result[token[3:]] = table()
        else:
            position += 1
    return result


def load_data():
    ns = {}
    for name in ("Recipes", "Thresholds", "Vendor"):
        ns.update(parse_lua_tables((REPO / "Data" / f"{name}.lua").read_text()))
    ns["RecipeName"] = {rid: name for names in ns["RecipeNames"].values() for name, rid in names.items()}
    return ns


NS = load_data()

# ------------------------------------------------------------------------------------ Model.lua port


def model_color(t, skill):
    if not t:
        return None
    for threshold, color in zip(t, ("red", "orange", "yellow", "green"), strict=False):
        if skill < threshold:
            return color
    return "grey"


def model_chance(t, skill):
    if not t or t[3] <= t[1] or skill < t[0]:
        return None
    if skill < t[1]:
        return 1
    if skill >= t[3]:
        return 0
    return (t[3] - skill) / (t[3] - t[1])


def model_recipe_cost(reagents, price):
    if not reagents:
        return None
    total = 0
    for reagent in reagents:
        each = price(reagent["itemID"])
        if each is None:
            return None
        total += each * reagent["quantity"]
    return total


def model_cost_per_skill_up(cost, chance):
    if cost is None or not chance or chance <= 0:
        return None
    return cost / chance


def model_craft_value(sell, auction, mode):
    if mode == "none":
        return None, None
    vendor = sell if sell and sell > 0 else None
    resale = auction * 0.95 if mode == "auction" and auction else None
    if resale and (not vendor or resale > vendor):
        return resale, "auction"
    return vendor, "vendor" if vendor else None


def round_money(copper):
    unit = 10000 if copper >= 1000000 else 100 if copper >= 100 else 1
    return max(math.floor(copper / unit + 0.5), 1) * unit


# ------------------------------------------------------------------------------------------- scene state

LEATHERWORKING = 165
COLORS = {  # Core.lua ns.COLORS: the client's GlobalColor rows it names
    "red": (1, 32 / 255, 32 / 255),  # RED_FONT_COLOR
    "orange": (1, 128 / 255, 64 / 255),  # DIFFICULT_DIFFICULTY_COLOR
    "yellow": (1, 1, 0),  # FAIR_DIFFICULTY_COLOR
    "green": (64 / 255, 192 / 255, 64 / 255),  # EASY_DIFFICULTY_COLOR
    "grey": (128 / 255, 128 / 255, 128 / 255),  # TRIVIAL_DIFFICULTY_COLOR
    "unknown": (128 / 255, 128 / 255, 128 / 255),  # GRAY_FONT_COLOR
}

# A Leatherworker/Miner at 48/75: Light Leather is bought (a Skinner would price it at 0 under the default
# "gathered reagents are free"). The recipes are the trainer's first ones, as in the old in-game capture.
SKILL, MAX_SKILL = 48, 75
LEARNED = [2152, 2149, 9058, 9059, 7126, 2153, 3753, 3816, 9060, 9062, 2881, 1229432]
UNLEARNED = [44953]  # Winter Boots: listed by Forever, taught by a Winter Veil quest
BAGS = {2318: 23}  # Light Leather
AUCTION = {2318: 90, 783: 320, 2934: 8}  # Light Leather, Light Hide, Ruined Leather Scraps (copper), from its scan
SCAN_AGE_MINUTES = 4
PROFESSIONS = [  # GetProfessions order, as the side tabs show them
    ("Leatherworking", 136247),
    ("Skinning", 134366),
    ("First Aid", 135966),
    ("Fishing", 136245),
    ("Cooking", 133971),
]


def price(item_id):
    """Prices.lua ns.Price: no gathering profession covers these reagents, so vendor (when it's no dearer
    than the auction house) else auction."""
    vendor, ah = NS["VendorPrices"].get(item_id), AUCTION.get(item_id)
    if vendor is not None and (ah is None or vendor <= ah):
        return {"copper": vendor, "source": "vendor"}
    if ah is not None:
        return {"copper": ah, "source": "scan"}
    return None


def unit_price(item_id):
    p = price(item_id)
    return p and p["copper"]


def reagents(recipe_id):
    return NS["RecipeData"][recipe_id]["reagents"]


def craft_value(recipe_id):
    output = NS["RecipeData"][recipe_id]["output"]
    if not output:
        return None
    each, source = model_craft_value(
        NS["ItemSellPrices"].get(output["itemID"]), AUCTION.get(output["itemID"]), "vendor"
    )
    if each is None:
        return None
    return {"copper": each * output["quantity"], "source": source, "quantity": output["quantity"]}


def recipe_cost(recipe_id):
    return model_recipe_cost(reagents(recipe_id), unit_price)


def net_cost(recipe_id):
    cost = recipe_cost(recipe_id)
    if cost is None:
        return None
    value = craft_value(recipe_id)
    return cost - (value["copper"] if value else 0)


def describe(recipe_id, learned=True):
    """Core.lua ns.Describe at SKILL. The live difficulty agrees with the thresholds (the audit's check)."""
    t = NS["Thresholds"].get(recipe_id)
    cost = recipe_cost(recipe_id)
    value = craft_value(recipe_id) if cost is not None else None
    net = cost - (value["copper"] if value else 0) if cost is not None else None
    chance = model_chance(t, SKILL)
    color = model_color(t, SKILL)
    if chance is not None and learned and color == "grey":
        chance = 0  # canSkillUp == false
    return {
        "thresholds": t,
        "color": color,
        "chance": chance,
        "cost": cost,
        "value": value,
        "net": net,
        "perSkillUp": model_cost_per_skill_up(net, chance),
    }


def row_color(d):
    return COLORS[d["color"] if d["chance"] is not None else ("red" if d["thresholds"] else "unknown")]


def recipe_name(recipe_id):
    return NS["RecipeName"][recipe_id]


def sorted_recipes():
    """RecipeList.lua BuildSorted with sortMode "cost": learned, then unlearned, each by perSkillUp, ties by
    name; None sorts last."""

    def key(recipe_id):
        per = describe(recipe_id, recipe_id in LEARNED)["perSkillUp"]
        return (math.inf if per is None else per, recipe_name(recipe_id).lower())

    return sorted(LEARNED, key=key), sorted(UNLEARNED, key=key)


def craftable_count(recipe_id):
    counts = [BAGS.get(r["itemID"], 0) // r["quantity"] for r in reagents(recipe_id)]
    return min(counts) if counts else 0


# ------------------------------------------------------------------------------------------------ render

from wowmock import (
    FONTS,
    NORMAL,
    TOOLTIP_LINE_GAP,
    TOOLTIP_PADDING,
    WHITE,
    Font,
    TooltipLine,
    Ui,
    coin_texture_string,
    filter_dropdown,
    minimal_checkbox,
    minimal_scrollbar,
    portrait_frame_art,
    scene,
    search_box,
    side_tab,
    three_slice_button,
    tooltip,
    wrap_text,
)

FRIZ = "fonts/frizqt__.ttf"
ARIAL = "fonts/arialn.ttf"
F_ROW = Font(FRIZ, 12, WHITE)  # GameFontHighlight_NoShadow
F_DIVIDER = Font(FRIZ, 12, NORMAL)  # GameFontNormal_NoShadow
F_NORMAL = FONTS["GameFontNormal"]
F_SMALL = FONTS["GameFontHighlightSmall"]
F_NORMAL_SMALL = FONTS["GameFontNormalSmall"]
F_RANK = Font(ARIAL, 12, WHITE, None, True)  # Number12FontOutline
F_SMALL2 = Font(FRIZ, 11, WHITE)  # GameFontHighlightSmall2
F_MED2 = Font(FRIZ, 14, WHITE, (1, -1))  # GameFontHighlightMed2
PROFESSION_RECIPE_COLOR = (226 / 255, 220 / 255, 214 / 255)
DISABLED_FONT_COLOR = (0.5, 0.5, 0.5)

FRAME_W, FRAME_H = 673, 594  # Camelot ProfessionsFrame
LIST_X, LIST_Y, LIST_W = 5, 72, 304  # CraftingPage.RecipeList (OverrideArt width)
LIST_H = FRAME_H - LIST_Y - 5
ROW_H, ROW_GAP, ROW_PAD = 20, 1, 5  # recipe rows; the tree view's spacing and top padding
DIVIDER_H = 70  # RecipeList.lua: the "Unlearned" divider after learned recipes
SCHEMATIC_W, SCHEMATIC_H = 360, 484
SKILL_UP_ICONS = {
    "orange": "Professions-Icon-Skill-High",
    "yellow": "Professions-Icon-Skill-Medium",
    "green": "Professions-Icon-Skill-Low",
}

SELECTED = 1229432  # Camp Tent
HOVERED = 9059  # Handstitched Leather Bracers


# GetCoinTextureString asks for 14-unit coins, but in the real captures they come out the height of the
# 12-unit text around them (coin ink 11 px at UI scale 1.2), so draw them at the line's height.
COIN_HEIGHT = 12


def money(copper):
    """Tooltip.lua Money: GetCoinTextureString of the rounded amount."""
    return coin_texture_string(math.floor(copper + 0.5), COIN_HEIGHT)


def format_row(d):
    """Core.lua ns.FormatRow with the default settings (showSkill off, showCost on)."""
    if not d["thresholds"]:
        return "?"
    if d["chance"] is None:
        return str(d["thresholds"][0])
    parts = [f"{math.floor(d['chance'] * 100 + 0.5)}%"]
    if d["perSkillUp"] is not None:
        per = d["perSkillUp"]
        parts.append(("|cff40ff40+|r" if per < 0 else "") + coin_texture_string(round_money(abs(per)), COIN_HEIGHT))
    return " · ".join(parts)


def age_text(minutes):
    return f"{minutes}m ago"


def source_text(p):
    return "vendor" if p["source"] == "vendor" else "AH, " + age_text(SCAN_AGE_MINUTES)


def recipe_tooltip_lines(ui, recipe_id):
    """Tooltip.lua ShowRecipeTooltip + AddCost for a learned recipe at SKILL. Returns the lines and the index
    of the first blank line GameTooltip_InsertFrame added for the bar."""
    d = describe(recipe_id)
    t = d["thresholds"]
    lines = [
        TooltipLine(recipe_name(recipe_id)),
        TooltipLine(f"Requires Leatherworking ({t[0]})", COLORS["red"] if SKILL < t[0] else WHITE),
    ]
    bar_line = len(lines)
    lines += [TooltipLine(" ")] * bar_blank_lines()
    lines.append(TooltipLine(f"Skill-up chance: {math.floor(d['chance'] * 100 + 0.5)}%", COLORS[d["color"]]))
    lines.append(TooltipLine(" "))
    gold = (1, 0.82, 0)
    for reagent in reagents(recipe_id):
        name = ui.item(reagent["itemID"]).name
        left = f"{name} x{reagent['quantity']}" if reagent["quantity"] > 1 else name
        p = price(reagent["itemID"])
        right = "{} |cff808080({})|r".format(money(p["copper"] * reagent["quantity"]), source_text(p))
        lines.append(TooltipLine(left, right=right))
    lines.append(TooltipLine("Reagents", gold, money(d["cost"])))
    value = d["value"]
    each = " x{:g}".format(value["quantity"]) if value["quantity"] != 1 else ""
    lines.append(
        TooltipLine(
            "Sells for" + each,
            gold,
            "{} |cff808080({})|r".format(money(value["copper"]), "AH" if value["source"] == "auction" else "vendor"),
        )
    )
    lines.append(TooltipLine("Profit per craft" if d["net"] < 0 else "Net per craft", gold, money(abs(d["net"]))))
    per = d["perSkillUp"]
    lines.append(
        TooltipLine(
            "Profit per skill-up" if per < 0 else "Per skill-up",
            gold,
            ("|cff40ff40+|r" if per < 0 else "") + money(abs(per)),
        )
    )
    return lines, bar_line


BAR_WIDTH, BAR_HEIGHT, MIN_LABEL_GAP = 250, 12, 18  # Tooltip.lua
BAR_FRAME_HEIGHT = BAR_HEIGHT + 30
BAR_PADDING = 4  # GameTooltip_InsertFrame(tooltip, bar, 4)


def bar_blank_lines():
    """GameTooltip_InsertFrame: enough blank GameTooltipText lines to hold the frame and its padding."""
    text_height = FONTS["GameTooltipText"].height
    return math.ceil(round(BAR_FRAME_HEIGHT + BAR_PADDING) / (text_height + TOOLTIP_LINE_GAP))


def skill_bar(ui, t, skill):
    """Tooltip.lua CreateBar + LayoutBar: the rank-bar art at tooltip size, the difficulty bands, threshold
    labels and the pip at the player's skill. Returns a canvas with the frame's TOPLEFT at (m, m)."""
    m = 8
    canvas = ui.canvas(BAR_WIDTH + 2 * m, BAR_FRAME_HEIGHT + 2 * m)
    s = BAR_HEIGHT / 18
    canvas.draw(ui.atlas("Professions-skillbar-bg"), m - 5 * s, m - 3 * s, BAR_WIDTH + 12 * s, 29 * s)
    lo, hi = t[0], t[3] + max(3, math.floor((t[3] - t[0]) * 0.12 + 0.5))

    def x_of(value):
        return (min(max(value, lo), hi) - lo) / (hi - lo) * BAR_WIDTH

    band = ui.texture("interface/targetingframe/ui-statusbar.blp")
    edges = [t[0], t[1], t[2], t[3], hi]
    for i, color in enumerate(("orange", "yellow", "green", "grey")):
        left, right = x_of(edges[i]), x_of(edges[i + 1])
        if right > left:
            canvas.draw(band, m + left, m, max(right - left, 0.1), BAR_HEIGHT, COLORS[color])
    canvas.draw(ui.atlas("Professions-skillbar-frame"), m - 5 * s, m - 3 * s, BAR_WIDTH + 10 * s, 29 * s)
    marker_h = BAR_HEIGHT * 1.3
    marker_w = marker_h * 10 / 14
    mx = x_of(skill)
    canvas.draw(
        ui.atlas("ui-hud-experiencebar-frame-pip-camelot"),
        m + mx - marker_w / 2,
        m + BAR_HEIGHT / 2 - marker_h / 2,
        marker_w,
        marker_h,
    )
    last = -math.inf
    for i, value in enumerate(t):
        x = x_of(value)
        if x - last < MIN_LABEL_GAP:
            continue
        last = x
        width = canvas.text_width(str(value), F_SMALL)
        left = 0 if i == 0 else x - width / 2
        canvas.text(m + left, m + BAR_HEIGHT + 4, str(value), F_SMALL)
    you = f"You: {skill}"
    centre = min(max(mx, 24), BAR_WIDTH - 24)
    canvas.text(m + centre - canvas.text_width(you, F_SMALL) / 2, m + BAR_HEIGHT + 16, you, F_SMALL)
    return canvas, m


def recipe_tooltip(ui, recipe_id):
    lines, bar_line = recipe_tooltip_lines(ui, recipe_id)
    canvas = tooltip(ui, lines)
    fonts = [FONTS["GameTooltipHeaderText"]] + [FONTS["GameTooltipText"]] * (len(lines) - 1)
    top = TOOLTIP_PADDING + sum(f.height + TOOLTIP_LINE_GAP for f in fonts[:bar_line])
    bar, m = skill_bar(ui, describe(recipe_id)["thresholds"], SKILL)
    canvas.paste(bar, TOOLTIP_PADDING - m, top + BAR_PADDING - m)
    return canvas


def list_rows():
    """The recipe list's rows top to bottom: ("recipe", id, learned) and ("divider",)."""
    learned, unlearned = sorted_recipes()
    rows = [("recipe", rid, True) for rid in learned]
    if unlearned:
        rows.append(("divider",))
        rows += [("recipe", rid, False) for rid in unlearned]
    return rows


def recipe_row(canvas, x, y, w, recipe_id, learned, selected, hovered):
    """ProfessionsRecipeListRecipeTemplate (20 high) at (x, y, w) with SkillUp's text on its right."""
    ui = canvas.ui
    d = describe(recipe_id, learned)
    icon_atlas = SKILL_UP_ICONS.get(d["color"])
    skill_ups_y = y + (ROW_H - 15) / 2 - (1 if d["color"] == "orange" else 0)
    if icon_atlas:
        icon = ui.atlas(icon_atlas)
        # SkillUps (26x15) at LEFT (-9, yOfs); its icon at RIGHT (0, -1), atlas size.
        canvas.draw(icon, x - 9 + 26 - icon.width, skill_ups_y + (15 - icon.height) / 2 + 1)
    label_x = x - 9 + 26 + 4
    color = WHITE if hovered else (PROFESSION_RECIPE_COLOR if learned else DISABLED_FONT_COLOR)
    label_w = canvas.text(label_x, y, recipe_name(recipe_id), F_ROW, color, box_height=ROW_H)
    count = craftable_count(recipe_id) if learned else 0
    if count > 0:
        canvas.text(label_x + label_w, y, f" [{count}] ", F_ROW, color, box_height=ROW_H)
    text = format_row(d)
    canvas.text(x, y, text, F_ROW, row_color(d), box_height=ROW_H, justify="RIGHT", width=w - 4)
    if selected:
        overlay = ui.atlas("Professions_Recipe_Active")
        canvas.draw(overlay, x + (w - overlay.width) / 2, y + (ROW_H - overlay.height) / 2 + 1)
    if hovered:
        overlay = ui.atlas("Professions_Recipe_Hover")
        canvas.draw(overlay, x + (w - overlay.width) / 2, y + (ROW_H - overlay.height) / 2 + 1, color=(1, 1, 1, 0.5))


def divider_row(canvas, x, y, w):
    """ProfessionsRecipeListDividerTemplate at SkillUp's height: "Unlearned" and the gold rule."""
    ui = canvas.ui
    bottom = y + DIVIDER_H
    canvas.text(x + 10, bottom - 10 - 13, "Unlearned", F_DIVIDER, box_height=13)
    rule = ui.atlas("Options_HorizontalDivider")
    canvas.draw(rule, x + 5, bottom - 5 - 2, 250, 2, NORMAL)
    canvas.draw(rule, x + 5, bottom - 5 - 2, 250, 2, (*NORMAL, 0.5), blend="ADD")


def recipe_list(canvas, x, y):
    """CraftingPage.RecipeList at (x, y). Returns the hovered row's rect."""
    ui = canvas.ui
    canvas.draw(ui.atlas("Professions-background-summarylist"), x, y, LIST_W, LIST_H)
    filter_x, _, _, _ = filter_dropdown(canvas, x + LIST_W - 8, y + 9)
    search_box(canvas, x + 13, y + 8, filter_x - 4 - (x + 13))
    box_x, box_y, box_w = x + 8, y + 35, LIST_W - 8 - 20
    minimal_scrollbar(canvas, box_x + box_w, box_y, LIST_H - 35 - 5)
    top = box_y + ROW_PAD
    hovered_rect = None
    for row in list_rows():
        if row[0] == "divider":
            divider_row(canvas, box_x, top, box_w)
            top += DIVIDER_H + ROW_GAP
            continue
        _, rid, learned = row
        recipe_row(canvas, box_x, top, box_w, rid, learned, rid == SELECTED, rid == HOVERED)
        if rid == HOVERED:
            hovered_rect = (box_x, top, box_w, ROW_H)
        top += ROW_H + ROW_GAP
    return hovered_rect


def rank_bar(canvas, x, y, name, skill, max_skill):
    """ProfessionsRankBarTemplate at (x, y): the profession's fill flipbook (first frame) masked to the
    progress, border, "Name skill/max" and the expansion dropdown arrow."""
    ui = canvas.ui
    canvas.draw(ui.atlas("Professions-skillbar-bg"), x, y)
    fill = ui.atlas("Skillbar_Fill_Flipbook_Leatherworking")
    frame = fill.image.crop((0, 0, fill.image.width // 2, fill.image.height // 30))  # 30 rows x 2 columns
    layer = ui.canvas(canvas.width, canvas.height)
    layer.draw(frame, x + 5, y + 3, 441, 18)
    mask = ui.atlas("Professions-skillbar-mask")
    mask_w = 453 * skill / max_skill
    layer.mask(mask.image, x + 5 + 1, y + 3 + 9 - mask.height / 2, mask_w, mask.height)
    canvas.paste(layer, 0, 0)
    canvas.draw(ui.atlas("Professions-skillbar-frame"), x, y, 451, 29)
    canvas.text(x, y + 3, f"{name} {skill}/{max_skill}", F_RANK, justify="CENTER", width=453, box_height=18)
    # The ExpansionDropdownButton hides itself with a single child profession, as on Forever. The crafting
    # page's LinkButton (23x23) sits at the bar's RIGHT (-2, -4): the tertiary square with the chat-link icon.
    bx, by = x + 453 - 2, y + 9 + 4 - 23 / 2
    background = ui.atlas("common-button-tertiary-square-normal")
    canvas.draw(background, bx + (23 - background.width) / 2, by + (23 - background.height) / 2)
    # The -2x member's override (50) is in 2x canvas units; the 1x member's is the real 25.
    canvas.draw(ui.atlas("common-icon-chatlink"), bx - 1, by - 1, 25, 25)


def schematic(canvas, x, y, recipe_id):
    """SchematicFormCraftingTemplate (Camelot, 360 wide) for a recipe: card art, the output icon and name,
    description, reagent slots, Track Recipe."""
    ui = canvas.ui
    data = NS["RecipeData"][recipe_id]
    canvas.draw(ui.atlas("Profession-background-card-leatherworking"), x, y, SCHEMATIC_W, SCHEMATIC_H)
    canvas.draw(ui.atlas("common-insideframe"), x, y, SCHEMATIC_W, SCHEMATIC_H)
    # OutputIcon (47x47) at (28, -28); Camelot's 53x53 icon centred, masked round, the quality ring over it.
    ox, oy = x + 28, y + 28
    item = ui.item(data["output"]["itemID"])
    layer = ui.canvas(canvas.width, canvas.height)
    layer.draw(
        ui.texture(item.icon).crop(_texcoord_box(ui.texture(item.icon), 0.078125, 0.921875)),
        ox + 23.5 - 26.5,
        oy + 23.5 - 26.5,
        53,
        53,
    )
    layer.mask(
        ui.texture("interface/characterframe/tempportraitalphamask.blp"),
        ox + 23.5 - 26.5 + 2,
        oy + 23.5 - 26.5 + 2,
        49,
        49,
    )
    canvas.paste(layer, 0, 0)
    ring = ui.atlas("auctionhouse-itemicon-border-white")
    canvas.draw(ring, ox + 23.5 - 34, oy + 23.5 - 34, 68, 68)
    name_x = ox + 47 + 14
    name_w = canvas.text(name_x, oy + 23.5 - 17 - F_MED2.height / 2, item.name, F_MED2)
    fav = ui.atlas("auctionhouse-icon-favorite")
    canvas.draw(fav, name_x + name_w + 4, oy + 23.5 - 17 - 9 - 1, 20, 18, (1, 1, 1, 0.5))
    description_y = oy + 47 + 12
    canvas.text(ox - 1, description_y, f"Craft a {item.name}.", F_SMALL2)
    # Init re-anchors the reagents: TOPLEFT at the description's BOTTOMLEFT (0, -20); the label is 20 high
    # and the slots start at (1, -20).
    rx, ry = ox - 1, description_y + F_SMALL2.height + 20
    canvas.text(rx, ry, "Reagents:", F_NORMAL_SMALL, box_height=20)
    sx, sy = rx + 1, ry + 20
    for reagent in reagents(recipe_id):
        reagent_slot(canvas, sx, sy, reagent)
        sx += 180 + 5
    minimal_checkbox(canvas, x + 17, y + SCHEMATIC_H - 11 - 26, "Track Recipe", color=DISABLED_FONT_COLOR)


def _texcoord_box(image, lo, hi):
    return (round(image.width * lo), round(image.height * lo), round(image.width * hi), round(image.height * hi))


def reagent_slot(canvas, x, y, reagent):
    """ProfessionsReagentSlotTemplate (180x50): the 39x39 button at LEFT and "have/need Name" beside it."""
    ui = canvas.ui
    item = ui.item(reagent["itemID"])
    bx, by = x, y + (50 - 39) / 2
    canvas.draw(ui.atlas("Professions-Slot-bg"), bx, by, 39, 39)
    canvas.draw(ui.texture(item.icon), bx, by, 39, 39)
    canvas.draw(ui.atlas("Professions-Slot-Frame"), bx, by, 40, 40)
    text = f"{BAGS.get(reagent['itemID'], 0)}/{reagent['quantity']} {item.name}"
    # The Name box is 108 wide, but the client wraps "23/5 Light Leather" (105.5-106.7 units by our metrics,
    # depending on the render scale) in it, so it keeps some slack at the right edge.
    lines = wrap_text(canvas, text, F_ROW, 108 - 4)
    top = y + 25 - len(lines) * F_ROW.height / 2
    for i, line in enumerate(lines):
        canvas.text(x + 46, top + i * F_ROW.height, line, F_ROW)


def create_controls(canvas, fx, fy, count):
    """CraftingPage's bottom row, Camelot anchors: Create All, the quantity spinner, Create."""
    ui = canvas.ui
    right, bottom = fx + FRAME_W, fy + FRAME_H
    all_text = f"Create All [{count}]"
    all_w = max(80, canvas.text_width(all_text, F_NORMAL) + 30)
    three_slice_button(canvas, right - 362, bottom - 7 - 28, all_w, 28, all_text)
    create_w = max(80, canvas.text_width("Create", F_NORMAL) + 30)
    three_slice_button(canvas, right - 9 - create_w, bottom - 7 - 28, create_w, 28, "Create")
    # CreateMultipleInputBox: NumericInputSpinnerTemplate 31x20 at BOTTOMLEFT (-185, 11).
    ix, iy = right - 185, bottom - 11 - 20
    border = ui.texture("interface/common/common-input-border.blp")
    tw, th = border.width, border.height

    def piece(start, end):
        return border.crop((round(start * tw), 0, round(end * tw), round(0.625 * th)))

    canvas.draw(piece(0, 0.0625), ix - 5, iy, 8, 20)
    canvas.draw(piece(0.0625, 0.9375), ix + 3, iy, 31 - 8 - 3, 20)
    canvas.draw(piece(0.9375, 1), ix + 31 - 8, iy, 8, 20)
    canvas.text(ix, iy, "1", FONTS["GameFontHighlight"], box_height=20)
    canvas.draw(ui.texture("interface/buttons/ui-spellbookicon-nextpage-up.blp"), ix + 31, iy - 1, 23, 22)
    canvas.draw(ui.texture("interface/buttons/ui-spellbookicon-prevpage-up.blp"), ix - 5 - 6 - 23 + 5, iy - 1, 23, 22)


def profession_tabs(canvas, fx, fy, selected, route_selected=False):
    """The side tabs on the frame's right: overview, one per profession, then SkillUp's route tab."""
    x, y = fx + FRAME_W, fy + 60
    y += side_tab(canvas, x, y, OVERVIEW_TAB_ICON) + 2
    for name, icon in PROFESSIONS:
        y += side_tab(canvas, x, y, icon, selected=name == selected and not route_selected) + 2
    side_tab(canvas, x, y, "interface/icons/inv_scroll_03.blp", selected=route_selected)


# The overview tab's Interface/ICONS/INV_SideTab_Professions_c60 is in neither the community listfile nor
# ManifestInterfaceData, so its file data ID is unknown; Trade_BlacksmithingIcon stands in for it.
OVERVIEW_TAB_ICON = 136241

FRAME_MARGIN = 24  # room for the metal corners and portrait around the frame
TABS_MARGIN = 60


def professions_frame(ui):
    """The Leatherworking window at SKILL with SELECTED selected and HOVERED under the cursor. Returns the
    canvas and the hovered row's rect."""
    m = FRAME_MARGIN
    canvas = ui.canvas(FRAME_W + m + TABS_MARGIN, FRAME_H + 2 * m)
    fx, fy = m, m
    canvas.draw(ui.atlas("Profession-Background-Overview"), fx + 2, fy + 21, FRAME_W - 4, FRAME_H - 23)
    canvas.draw(ui.atlas("Profession-Background-Template2"), fx + 3, fy + 21)
    hovered = recipe_list(canvas, fx + LIST_X, fy + LIST_Y)
    schematic(canvas, fx + LIST_X + LIST_W + 2, fy + LIST_Y, SELECTED)
    create_controls(canvas, fx, fy, craftable_count(SELECTED))
    profession_tabs(canvas, fx, fy, "Leatherworking")
    portrait_frame_art(canvas, fx, fy, FRAME_W, FRAME_H, 136247, "Leatherworking")
    rank_bar(canvas, fx + 110, fy + 40, "Leatherworking", SKILL, MAX_SKILL)
    return canvas, hovered


def window_scene(ui):
    frame, (hx, hy, hw, _) = professions_frame(ui)
    tip = recipe_tooltip(ui, HOVERED)
    # SetOwner(row, "ANCHOR_RIGHT"): the tooltip's BOTTOMLEFT at the row's TOPRIGHT.
    return scene(ui, [(frame, 0, 0), (tip, hx + hw, hy - tip.height)])


def main():
    scale = float(os.environ.get("SCALE", "2"))
    ui = Ui(scale=scale)
    OUT.mkdir(parents=True, exist_ok=True)
    window_scene(ui).save(OUT / "window.png")
    scene(ui, [(recipe_tooltip(ui, HOVERED), 0, 0)]).save(OUT / "tooltip.png")


if __name__ == "__main__":
    main()
