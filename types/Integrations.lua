---@meta

-- Optional addons own these APIs; callers test availability before using them.
---@class SkillUpAuctionatorAPI
---@field GetAuctionPriceByItemID fun(caller: string, itemID: integer): number?
---@field GetAuctionAgeByItemID fun(caller: string, itemID: integer): number?
---@field RegisterForDBUpdate? fun(caller: string, callback: fun())
---@field CreateShoppingList fun(caller: string, name: string, searches: string[])
---@field ConvertToSearchString fun(caller: string, search: {searchString: string, isExact: boolean, quantity: number}): string
---@type {API: {v1: SkillUpAuctionatorAPI}}?
Auctionator = nil

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
-- or on bad input.
---@class SkillUpShortestPathAPI
---@field version integer
---@field Navigate? fun(owner: string, map: integer, x: number, y: number, title?: string): boolean
---@type {API: SkillUpShortestPathAPI?}?
ShortestPathForever = nil

---@class SkillUpTomTom
---@field AddWaypoint fun(self: SkillUpTomTom, mapID: integer, x: number, y: number, options: {title: string, from: string})
---@type SkillUpTomTom?
TomTom = nil
