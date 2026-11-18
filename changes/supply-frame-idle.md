### Fixed

- **The supply solver no longer runs every frame while idle.** It wakes when prices, bags, money, recipes, talents or a route's configuration change, and stops updating once that work is done, instead of checking for changes on every frame of the session.
