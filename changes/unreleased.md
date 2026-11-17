### Changed

- **Missing-price hints name the price addon you chose.** With AHDB or Naowh Forever chosen, the reagent tooltip and a route stopped on prices say how to update that addon. A linked or guild profession window keeps the game's own recipe list.
- **Supply controls line up beside their labels.** The form waits for a merchant selling route reagents, and SkillUp's bottom tabs hide when you switch professions. Thanks to bromidious for the report (#787).
- **Item-level searches filter unlearned recipes too.** Exact levels, approximate levels and ranges now filter the bundled recipes by their output item level, thanks to kopuliak for the report (#662).
- **Closing Professions keeps gamepad controls working.** Sorted and unlearned recipes use their own list, leaving the game's recipe provider and footer bindings intact (#794).
- **Tracked professions have one visibility switch.** Hiding the reagent section uses the same setting as Show tracked professions. Section and profession menus include Open and keep their tracker options together (#771).
- **Gathered materials have a sale value by default.** Gathered and looted reagents cost what selling them would bring, for every player: the free setting older versions saved for everyone is reset once, and turning it off again sticks. The cost line no longer says 0 copper for leather you skin. Thanks to berserkerlxl and messajahswe on CurseForge for the reports (#780, #807).
- **Sort every learned recipe by craft profit.** Highest craft profit orders by net value per craft, including grey recipes, with unknown values last. Thanks to davef1n on CurseForge for the idea (#781).
- **AHDB can supply auction prices.** Choose AHDB under Prices, with other installed price addons filling gaps and tooltips showing the observation's age. Thanks to user_bvgv4fnauhmhf9i7 on CurseForge for the idea (#761).
- **Auction data can price a route before your first auction house visit.** SkillUp reads Naowh Forever's scans and nightly auction snapshot when installed, keeps its age and leaves missing prices unknown (#783, #561).
