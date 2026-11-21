---@meta

-- Optional addons own these APIs; callers test availability before using them.
---@class SkillUpAuctionatorAPI
---@field GetAuctionPriceByItemID fun(caller: string, itemID: integer): number?
---@field GetAuctionAgeByItemID fun(caller: string, itemID: integer): number?
---@field RegisterForDBUpdate? fun(caller: string, callback: fun())
---@field CreateShoppingList fun(caller: string, name: string, searches: string[])
---@field DeleteShoppingList? fun(caller: string, name: string)
-- A list's search strings in its own order; it raises for a name no list has, so a caller reads a gone list from
-- the error.
---@field GetShoppingListItems? fun(caller: string, name: string): string[]
---@field ConvertToSearchString fun(caller: string, search: {searchString: string, isExact: boolean, quantity: number}): string
---@field MultiSearchAdvanced? fun(caller: string, searches: {searchString: string, isExact: boolean, quantity: number}[])
---@field MultiSearchExact? fun(caller: string, names: string[])
-- Config is Auctionator's own settings table, which has no public API contract.
---@type {API: {v1: SkillUpAuctionatorAPI}, Config?: {Options: {AUTO_LIST_SEARCH: string}, Get: fun(name: string): any}}?
Auctionator = nil

-- TradeSkillMaster's public API: the price is in copper, nil with a message when it has none.
---@class SkillUpTSMAPI
---@field GetCustomPriceValue fun(customPrice: string, itemString: string): number?, string?
---@type SkillUpTSMAPI?
TSM_API = nil

---@class SkillUpInventoryCharacter
---@field character string
---@field realmNormalized string
---@field bags number
---@field bank number
---@field mail number
---@class SkillUpSyndicatorAPI
---@field IsReady fun(): boolean
---@field GetInventoryInfoByItemID fun(itemID: integer, sameConnectedRealm: boolean, sameFaction: boolean): {characters: SkillUpInventoryCharacter[]}?
---@type {API: SkillUpSyndicatorAPI}?
Syndicator = nil

-- Shortest Path Forever's public API (version 1): uiMapID and 0-1 coordinates.
-- Navigate returns false in combat, with journeys off, without a player position
-- or on bad input; Estimate's travel seconds are nil with the reason.
---@class SkillUpShortestPathAPI
---@field version integer
---@field Navigate? fun(owner: string, map: integer, x: number, y: number, title?: string): boolean
---@field NavigateRoute? fun(owner: string, stops: {map: integer, x: number, y: number, title?: string, kind?: string}[]): boolean
---@field Estimate? fun(fromMap: integer, fromX: number, fromY: number, toMap: integer, toX: number, toY: number): seconds: number?, reason: ("combat"|"invalid"|"unreachable")?
---@type {API: SkillUpShortestPathAPI?}?
ShortestPathForever = nil

---@class SkillUpTomTom
---@field AddWaypoint fun(self: SkillUpTomTom, mapID: integer, x: number, y: number, options: {title: string, from: string})
---@type SkillUpTomTom?
TomTom = nil

-- QuestieDB's public tables (contract 2), as Integrations/Questie.lua reads them.
---@class SkillUpQuestieEntity
---@field GetAll fun(id: integer, fields: string[]): any[]?
---@field GetAllIds fun(): integer[]
---@class SkillUpQuestieDB
---@field RequireContract fun(required: integer): boolean, string?
---@field Meta table<string, table<string, table<string, integer>>>
---@field Support {Get: fun(name: string): table?}
---@field Item SkillUpQuestieEntity
---@field Npc SkillUpQuestieEntity
---@field Quest SkillUpQuestieEntity
---@type SkillUpQuestieDB?
LibQuestieDB = nil

---@class SkillUpQuestieZones
---@field area table<integer, integer>
---@field areaOverride table<integer, integer>
---@field parent table<integer, integer>
---@field parentOverride table<integer, integer>

---@type {API: {RegisterOnReady: fun(callback: fun())?}?}?
Questie = nil

-- AtlasLoot's public data modules.
---@class SkillUpAtlasLootRecipes
---@field GetRecipeForSpell fun(spellID: integer): integer?
---@field GetRecipeData fun(itemID: integer): number[]?
---@class SkillUpAtlasLootDroprate
---@field GetData fun(self: SkillUpAtlasLootDroprate, npcID: integer, itemID: integer): number?
---@type {Data: {Recipe: SkillUpAtlasLootRecipes?, Droprate: SkillUpAtlasLootDroprate?}?}?
AtlasLoot = nil

---@class SkillUpAHDB
---@field LastPrice fun(self: SkillUpAHDB, itemID: integer, house: string): number[]?
---@field ViewHouse fun(self: SkillUpAHDB): string
---@field Listen? fun(self: SkillUpAHDB, event: string, callback: fun())
---@type SkillUpAHDB?
AuctionDB = nil

---@type {AuctionPrice: fun(itemID: integer): number?, number?}?
NaowhForever = nil

-- Forever Ledger's read-only API over its own auction scans, in copper with times from time(). An item it never
-- scanned answers nothing; one it scanned with none listed has no price and a count of 0.
---@class SkillUpForeverLedgerListing
---@field price number
---@field count integer

---@alias SkillUpForeverLedgerWindow 'week'|'month'|'3months'|'6months'|'year'|'all'

---@class SkillUpForeverLedgerAPI
---@field version integer
---@field GetPrice fun(itemID: integer): typical: number?, cheapest: number?, listed: integer?, scannedAt: number?
---@field GetListings fun(itemID: integer): listings: SkillUpForeverLedgerListing[]?, listed: integer?, scannedAt: number?
---@field GetCost fun(itemID: integer, quantity: integer): copper: number?, priced: integer?, scannedAt: number?
---@field GetUsualPrice fun(itemID: integer, window?: SkillUpForeverLedgerWindow): copper: number?, days: integer?
---@field GetLastFullScan fun(): number?
---@type SkillUpForeverLedgerAPI?
ForeverLedgerAPI = nil
