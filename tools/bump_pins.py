#!/usr/bin/env python3
"""Move each generator pin to its newest upstream and print what moved, one line (stdlib only).

Prints nothing when every pin is current. CLASSICDB_COMMIT is a named waiver in AGENTS.md and stays.
The forever-db release the refresh guard diffs against moves too: `FDB_TAG`, `FDB_ASSET` and `FDB_SHA256`
in tools/fdb_pin.py follow the newest `data-v*` release of fitzforge/polestar whose SHA256SUMS asset states
the zip's checksum.
"""

import argparse
import datetime
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import fdb_pin
from latest_build import USER_AGENT, forever, newest

TOOLS = Path(__file__).resolve().parent
BUILD = re.compile(r"\d+(\.\d+){3}")
COMMIT = re.compile(r"[0-9a-f]{40}")


def fetch(url):
    headers = {"User-Agent": USER_AGENT}
    # The API allows an address 60 requests an hour without a token; a workflow passes its own.
    if url.startswith("https://api.github.com/") and os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        return response.read()


def file_commit(repository, path):
    """The pin for one file of an upstream repository: it moves only when the file's bytes do."""

    def latest(pinned):
        query = urllib.parse.urlencode({"path": path, "per_page": 1})
        commit = json.loads(fetch(f"https://api.github.com/repos/{repository}/commits?{query}"))[0]["sha"]
        raw = f"https://raw.githubusercontent.com/{repository}/{{}}/{urllib.parse.quote(path)}"
        if commit != pinned and fetch(raw.format(commit)) == fetch(raw.format(pinned)):
            return pinned
        return commit

    return latest


# Pin name: the generator that holds it, the label a pull request shows, the value's shape and its upstream.
PINS = {
    "BUILD": ("gen_thresholds.py", "Forever", BUILD, lambda _: forever()),
    # Classic Era builds are 1.1x.
    "TEACH_BUILD": ("gen_thresholds.py", "Classic Era", BUILD, lambda _: newest("wow_classic_era", "1.1")),
    "PT_COMMIT": (
        "gen_vendor.py",
        "LibPeriodicTable",
        COMMIT,
        file_commit(
            "doadin/libperiodictable-3-1", "LibPeriodicTable-3.1-Tradeskill/LibPeriodicTable-3.1-Tradeskill.lua"
        ),
    ),
}


def repin(source, name, value):
    """source with the module-level `name = "..."` set to value, and the value it held."""
    line = re.compile(rf'^{name} = "([^"]*)"$', re.MULTILINE)
    found = line.findall(source)
    if len(found) != 1:
        raise SystemExit(f"expected one {name} pin, found {len(found)}")
    return line.sub(f'{name} = "{value}"', source), found[0]


def version_key(version):
    return tuple(int(part) for part in version.split("."))


def fdb_zip_asset(release):
    """The (name, download URL) of `release`'s forever-db zip asset, matched by its `forever-db-` prefix."""
    for asset in release.get("assets", ()):
        name = asset.get("name", "")
        if name.startswith("forever-db-") and name.endswith(".zip"):
            return name, asset.get("browser_download_url", "")
    raise SystemExit(f"forever-db release {release.get('tag_name', '?')} carries no zip asset")


def fdb_digest(release, asset):
    """The sha256 of `asset` as the release's SHA256SUMS asset states it, so the pin never reads a moved file."""
    url = next(
        (
            entry.get("browser_download_url", "")
            for entry in release.get("assets", ())
            if entry.get("name") == "SHA256SUMS"
        ),
        None,
    )
    if url is None:
        raise SystemExit(f"forever-db release {release.get('tag_name', '?')} carries no SHA256SUMS asset")
    sums = fetch(url).decode("utf-8")
    for line in sums.splitlines():
        digest, _, stated = line.strip().partition(" ")
        if stated.lstrip() == asset:
            if not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise SystemExit(f"forever-db {asset}: SHA256SUMS states {digest!r}, not a sha256")
            return digest
    raise SystemExit(f"forever-db {asset}: the release's SHA256SUMS names no {asset}")


def newest_fdb_release():
    """The newest non-draft, non-prerelease `data-v*` release of fitzforge/polestar carrying a zip asset."""
    releases = json.loads(fetch("https://api.github.com/repos/fitzforge/polestar/releases?per_page=30"))
    candidates = [
        release
        for release in releases
        if not release.get("draft")
        and not release.get("prerelease")
        and re.fullmatch(r"data-v\d+(?:\.\d+)*", release.get("tag_name", ""))
        and any(
            asset.get("name", "").startswith("forever-db-") and asset.get("name", "").endswith(".zip")
            for asset in release.get("assets", ())
        )
    ]
    if not candidates:
        raise SystemExit("no forever-db `data-v*` release on the polestar page carries a zip asset")
    return max(candidates, key=lambda release: version_key(release["tag_name"][len("data-v") :]))


def newest_fdb_tag(pinned, tag):
    """The newer of the pinned forever-db `data-vX.Y.Z` tag and `tag`, or `pinned` when `tag` is not newer."""
    if not re.fullmatch(r"data-v\d+(?:\.\d+)*", tag):
        raise SystemExit(f"forever-db release tag {tag!r} is not data-vX.Y.Z")
    return max([pinned, tag], key=lambda value: version_key(value[len("data-v") :]))


def parse_args(argv=None):
    """`--help` prints the usage; anything unrecognised exits 2 before a single pin is touched."""
    return argparse.ArgumentParser(
        prog="bump_pins.py",
        description="Move each generator pin to its newest upstream and print what moved, one line.",
    ).parse_args(argv)


def main(argv=None):
    parse_args(argv)
    moved = []
    for name, (filename, label, shape, latest) in PINS.items():
        path = TOOLS / filename
        source = path.read_text(encoding="utf-8")
        _, pinned = repin(source, name, "")
        value = latest(pinned)
        if not shape.fullmatch(value):
            raise SystemExit(f"{name}: upstream gave {value!r}")
        if value == pinned:
            print(f"{name}: already on {pinned}", file=sys.stderr)
            continue
        path.write_text(repin(source, name, value)[0], encoding="utf-8")
        moved.append(f"{label} {value[:12]}")
    data_moved = bool(moved)
    release = newest_fdb_release()
    tag = newest_fdb_tag(fdb_pin.FDB_TAG, release["tag_name"])
    if tag != fdb_pin.FDB_TAG:
        asset, _ = fdb_zip_asset(release)
        path = TOOLS / "fdb_pin.py"
        source = path.read_text(encoding="utf-8")
        source = repin(source, "FDB_TAG", tag)[0]
        source = repin(source, "FDB_ASSET", asset)[0]
        path.write_text(repin(source, "FDB_SHA256", fdb_digest(release, asset))[0], encoding="utf-8")
        moved.append(f"forever-db {tag}")
    else:
        print(f"FDB_TAG: already on {fdb_pin.FDB_TAG}", file=sys.stderr)
    if data_moved:
        # The date a generator pin moved, which the generated headers carry. The forever-db pin feeds no
        # generator, so moving it alone does not date the data.
        path = TOOLS / "gen_thresholds.py"
        today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        path.write_text(repin(path.read_text(encoding="utf-8"), "SOURCE_DATE", today)[0], encoding="utf-8")
    if moved:
        print(", ".join(moved))


if __name__ == "__main__":
    main()
