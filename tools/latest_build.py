#!/usr/bin/env python3
"""Print the newest WoW: Forever client build listed on wago.tools (stdlib only)."""

import json
import urllib.request

try:
    from tools.forever_tools.latest_build import latest, version_key
except ModuleNotFoundError:
    from forever_tools.latest_build import latest, version_key

USER_AGENT = "SkillUpForever/1.0"


def newest(product, prefix):
    """The highest build wago.tools lists for a product, among the versions starting with prefix."""
    request = urllib.request.Request("https://wago.tools/api/builds", headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        builds = json.load(response)[product]
    versions = [b["version"] for b in builds if b["version"].startswith(prefix)]
    if not versions:
        raise SystemExit(f"no {prefix}x build of {product} listed on wago.tools")
    return max(versions, key=version_key)


def forever():
    """The newest Forever build; wow_classic_beta carries other Classic betas too, and Forever builds are 1.6x."""
    return latest(USER_AGENT)


if __name__ == "__main__":
    print(latest(USER_AGENT))
