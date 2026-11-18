### Fixed

- **The supply solver no longer runs every frame while idle.** Its frame now shows only when a snapshot is dirty or a job is still calculating and hides itself when that work drains, so the addon costs no per-frame work between price, bag and recipe changes.
