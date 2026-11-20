### Fixed

- The Auctionator shopping list for a tracked route is written again at login. Since SkillUp Forever started carrying ForeverCore inside itself, it started after the game's loading signals it was waiting for, so the list was never refreshed (cjber/forever-core#980).
