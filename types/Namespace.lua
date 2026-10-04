---@meta

-- The client passes this same table to each TOC file; no runtime import is available.
---@class SkillUpNamespace
---@field TrackerHost? ForeverTrackerHostAPI
---@field TrackerHostSettings fun(): ForeverTrackerSettings
---@field Print fun(msg: string)
---@field Changed fun(kind: SkillUpChange)
---@field WhenStale fun(name: SkillUpStale, handler: fun())
---@field WhenEvent fun(event: WowEvent, watcher: fun(): SkillUpChange?)
---@field ProfessionSkillLine fun(name?: string, reported?: integer): integer?
---@field CharacterKey fun(): string
---@field CollectMode fun(): SkillUpCollectMode
---@field SetCollectMode fun(mode: SkillUpCollectMode)
---@field SkillContext fun(): SkillUpContext?
---@field PlayerProfessions fun(): table<integer, SkillUpProfession>
---@field IsLearned fun(recipeID: integer): boolean
---@field Describe fun(recipeInfo: TradeSkillRecipeInfo|SkillUpRecipeInfo, ctx?: SkillUpContext): SkillUpDescription
---@field FormatRow fun(d: SkillUpDescription): string
---@field RowColor fun(d: SkillUpDescription): ColorMixin
---@field Price fun(itemID: integer): SkillUpPrice?
---@field PriceSource fun(itemID: integer): SkillUpPriceSource?
---@field Reagents fun(recipeID: integer): SkillUpReagent[]?
---@field UsedIn fun(itemID: integer): integer[]
---@field CraftCost fun(recipeID: integer): number?, SkillUpValue?, number?
---@field NetCost fun(recipeID: integer): number?
---@field InitPrices fun()
---@field AttachRecipeList fun()
---@field RouteProfessions fun(): table<integer, SkillUpProfession>
---@field CraftedGear fun(level: number, classID: integer): SkillUpGearSlot[]
---@field Gear SkillUpGear
---@field TrainingFor fun(profession: SkillUpContext, recipeID: integer): number[]?
---@field RankName fun(cap: number): string?
---@field RecipeBands fun(profession: SkillUpContext, recipeID: integer): SkillUpBand[]
---@field BestTraining fun(profession: SkillUpContext, known: table<integer, boolean>, offers: {recipeID: integer, fee: number}[]): integer?
---@field RouteBlocked fun(plan: SkillUpPlan): string?
---@field UnpricedReagents fun(plan: SkillUpPlan): integer[]
---@field PlanRoute fun(profession: SkillUpProfession): SkillUpPlan
---@field RankText fun(rank: SkillUpRank): string
---@field CreateList fun(parent: Frame, columns: SkillUpColumn[]): SkillUpList
---@field NextCraft fun(plan: SkillUpPlan): SkillUpCraft
---@field OpenSkillLine fun(): integer?
---@field ShowRecipe fun(recipeID: integer)
---@field AttachRoute fun()
---@field AttachGear fun()
---@field RouteTab? SkillUpSideTab
---@field GearTab? SkillUpSideTab
---@field HideRoute? fun()
---@field HideGear? fun()
---@field PlaceGearTab? fun()
---@field RegisterSettings fun()
---@field SetSortMode fun(mode: string)
---@field OpenSettings fun()
---@field HasAuctionator fun(): boolean
---@field Have fun(itemID: integer): number
---@field AltCounts fun(itemID: integer): {name: string, count: number}[]
---@field RouteReagents fun(plan: SkillUpPlan): SkillUpNeededItem[]
---@field SendToAuctionator fun(profession: string, items: SkillUpNeededItem[])
---@field IsTracked fun(skillLine?: integer): boolean
---@field TrackedNeeds fun(): SkillUpTracked[]
---@field TrackerAttached fun(): boolean
---@field SetTracked fun(skillLine: integer, tracked: boolean)
---@field AutoTrack fun(skillLine?: integer): boolean
---@field InitShopping fun()
---@field NPCLocation fun(npcID: integer): SkillUpLocation
---@field LocationText fun(where: SkillUpLocation): string
---@field SeeVendor fun(itemIDs: integer[]): boolean
---@field NearestNPC fun(npcIDs: integer[], byTravel?: boolean): integer?
---@field SetWaypoint fun(npcID: integer): boolean
---@field SuggestionNPC fun(suggestion: SkillUpSuggestion): integer?
---@field RecipeSuggestions fun(profession: SkillUpContext, base: number): SkillUpSuggestion[]
---@field ScrollPrice fun(source: SkillUpScrollSource): number?
---@field ScrollSkill fun(recipeID: integer, source: SkillUpScrollSource): number
---@field AddSourceLines fun(tooltip: GameTooltip, source: SkillUpScrollSource, first?: integer)
---@field NearestTrainer fun(profession: SkillUpContext, cap: number, byTravel?: boolean): integer?
---@field NearestVendor fun(itemID: integer, byTravel?: boolean): integer?
---@field AddNearest fun(tooltip: GameTooltip, label: string, npcID?: integer)
---@field AddCompanionHint fun(tooltip: GameTooltip)
---@field AnnounceUpdate fun()
---@field WHATS_NEW string
---@field FormatNet fun(copper: number, profit: boolean): string
---@field PriceAge fun(price: SkillUpPrice): number?
---@field PriceAgeText fun(price: SkillUpPrice): string
---@field PriceSourceText fun(price: SkillUpPrice): string
---@field UnpricedHint fun(): string
---@field ShowRecipeTooltip fun(_: SkillUpNamespace, row: SkillUpRecipeRow, data: SkillUpRecipeNodeData)
---@field AttachItemTooltips fun()
---@field AttachTrainer fun()
---@field SORT_OPTIONS string[][]
---@field CRAFT_VALUE_OPTIONS string[][]
---@field REAGENT_TOOLTIP_OPTIONS string[][]
---@field TITLE string
---@field L table<string, string> English phrase to the client locale's translation, else the phrase
---@field COLORS table<string, ColorMixin>
---@field Model SkillUpModel
---@field db SkillUpDB
---@field DEFAULTS SkillUpDefaults
---@field Thresholds table<integer, number[]>
---@field VendorPrices table<integer, number>
---@field RecipeData table<integer, SkillUpRecipe>
---@field ItemGear table<integer, number[]>
---@field ItemSellPrices table<integer, number>
---@field RecipeNames table<integer, table<string, integer|false>>
---@field ProfessionSkillLines table<string, integer>
---@field TrainerFees table<integer, number[]>
---@field TrainerRanks table<integer, number[][]>
---@field ProfessionTrainers table<integer, number[][]>
---@field GatheredBy table<integer, integer>
---@field ScrollDrops table<integer, number[][]>
---@field WorldDrops table<integer, boolean>
---@field Questie SkillUpQuestie
---@field AtlasLoot SkillUpAtlasLoot
---@field Catalogue SkillUpCatalogue
---@field InitCatalogue fun()

---@class SkillUpDefaults
---@field showRowText boolean
---@field showSkill boolean
---@field showTooltip boolean
---@field showCost boolean
---@field craftValue 'none'|'vendor'|'auction'
---@field sortMode 'blizzard'|'skill'|'chance'|'cost'
---@field showTrainer boolean
---@field showRouteTab boolean
---@field showGearTab boolean
---@field reagentTooltip 'off'|'route'|'full'
---@field collectModes table<string, SkillUpCollectMode>
---@field whatsNew boolean
---@field companionHints boolean
---@field lastVersion string
---@field routeTargets table<integer, number>
---@field learned table<string, table<integer, boolean>>
---@field professionIDs table<string, integer>
---@field trackedProfessions table<integer, boolean>
---@field trainer table<integer, table<integer, number[]>>
---@field trainerRanks table<integer, table<integer, number>>
---@field vendor table<integer, number>
---@field sellers table<integer, SkillUpSeller>

-- A vendor seen at its own window: where the player stood, and what it sold that the addon has a use for.
---@class SkillUpSeller
---@field name string
---@field side? 'A'|'H'
---@field map integer
---@field x number
---@field y number
---@field items table<integer, true>

---@class SkillUpDB : SkillUpDefaults
---@field trackerHost? ForeverTrackerSettings
---@field showReagentTooltip? boolean Legacy migration only.
---@field scanAuctions? boolean Legacy migration only.
---@field tracked? table<integer, boolean> Legacy migration only.
---@field auctions? table Legacy migration only.
---@field gatherFree? boolean Legacy migration only.

---@type SkillUpDB
SkillUpForeverDB = nil

---@class SkillUpReagent
---@field itemID integer
---@field quantity number

---@class SkillUpRecipe : SkillUpSchematic
---@field skillLine integer

---@class SkillUpSchematic
---@field reagents SkillUpReagent[]
---@field output? SkillUpReagent|false

---@class SkillUpContext
---@field skillLine? integer
---@field skill number
---@field base number
---@field modifier number
---@field max number
---@field name? string
---@field capped boolean

---@class SkillUpProfession : SkillUpContext
---@field skillLine integer
---@field professionID? integer What GetProfessionInfo reports, which Forever's trade skill APIs take.
---@field name string
---@field icon fileID

---@class SkillUpCandidate
---@field recipeID integer
---@field thresholds number[]
---@field netCost? number

---@class SkillUpService : SkillUpCandidate
---@field fee number

---@class SkillUpSnapshot
---@field skill number
---@field target number
---@field recipes SkillUpCandidate[]

---@class SkillUpSegment
---@field recipeID integer
---@field fromSkill number
---@field toSkill number
---@field expectedCrafts number
---@field crafts number

---@class SkillUpTraining
---@field recipeID integer
---@field fee number
---@field atSkill number

-- The plan's own shapes are in base skill, the number the Professions window shows.
---@class SkillUpPlanCraft
---@field recipeID integer
---@field from number
---@field to number
---@field crafts number
---@field expectedCrafts number
---@field color string The recipe's colour where the craft starts.

---@class SkillUpPlanTraining
---@field recipeID integer
---@field fee number
---@field usedAt number Where the plan first crafts it.
---@field reqSkill number What the trainer wants for it.
---@field cap number The cap a trainer must teach to for it.

-- One of a rank to train, a recipe to train or a craft, in the order they are walked.
---@class SkillUpRouteStep
---@field rank? SkillUpRank
---@field training? SkillUpPlanTraining
---@field craft? SkillUpPlanCraft

---@class SkillUpBand
---@field color 'orange'|'yellow'|'green'|'grey'
---@field from number

---@class SkillUpRank
---@field name string
---@field cap number
---@field fee number
---@field reqSkill number
---@field level number

---@class SkillUpRoute
---@field segments SkillUpSegment[]
---@field expectedCost number
---@field reachedSkill number
---@field excluded {unpriced: integer, recipes: integer[]} Known recipes left out for an unpriced reagent.
---@field stopReason? 'no_recipe'

---@class SkillUpTrainedRoute : SkillUpRoute
---@field training SkillUpTraining[]
---@field trainingCost number

-- What Core/Plan.lua returns: the levelling plan as a player reads it.
---@class SkillUpPlan
---@field profession SkillUpProfession
---@field target number
---@field reached number Where the crafts get to: short of the target when the known recipes run out.
---@field steps SkillUpRouteStep[]
---@field crafts SkillUpPlanCraft[]
---@field training SkillUpPlanTraining[]
---@field ranks SkillUpRank[]
---@field cost number Expected crafting cost plus every fee.
---@field unpriced integer Known recipes left out for an unpriced reagent.
---@field unpricedRecipes integer[]
---@field stopReason? 'no_recipe'

---@class SkillUpShoppingItem
---@field itemID integer
---@field count number

-- What a writer or a game event says changed, and the caches and views Core/Changes.lua keeps fresh.
---@alias SkillUpChange 'recipes'|'skill'|'professions'|'prices'|'bags'|'items'|'names'|'level'|'zone'|'merchant'|'fees'|'sources'|'target'|'tracking'|'settings'
---@alias SkillUpStale 'schematics'|'prices'|'plans'|'api'|'route'|'recipeList'|'tracker'|'trainer'|'routeTab'|'gear'|'tooltip'
---@alias SkillUpPriceSource 'vendor'|'auctionator'|'gather'
---@alias SkillUpCollectMode 'gather'|'auction'
---@alias SkillUpShoppingSource 'gather'|'vendor'|'auction'|'unknown'
---@class SkillUpPrice
---@field copper number
---@field source SkillUpPriceSource
---@field days? number Auctionator ages only.
---@field ageUnavailable? boolean Auctionator age API unavailable or failed.
---@field profession? string Gathered reagents only.

---@class SkillUpValue
---@field copper number
---@field source 'vendor'|'auction'
---@field quantity number

---@class SkillUpDescription
---@field thresholds? number[]
---@field color string
---@field chance? number
---@field cost? number
---@field value? SkillUpValue
---@field net? number
---@field perSkillUp? number

---@class SkillUpRecipeInfo
---@field recipeID integer
---@field learned? boolean
---@field canSkillUp? boolean
---@field relativeDifficulty? number

---@class SkillUpLocation
---@field name string
---@field label string
---@field map? integer
---@field x? number
---@field y? number

---@class SkillUpSuggestion
---@field recipeID integer
---@field source SkillUpScrollSource
---@field kind integer
---@field kindText string
---@field npcID? integer
---@field reach number Base skill.
---@field color string Its colour at the skill the route stopped at.

---@class SkillUpNeededItem
---@field itemID integer
---@field need number
---@field source SkillUpShoppingSource

---@class SkillUpTracked
---@field plan SkillUpPlan
---@field items SkillUpNeededItem[]

---@class SkillUpCraft
---@field text string
---@field recipeID? integer
---@field count? number
---@field reason? string

---@alias SkillUpSortKey fun(info: TradeSkillRecipeInfo, ctx: SkillUpContext?): number

---@class SkillUpListEntry
---@field text string
---@field note? string a short label kept whole at the right of the name, which is cut to make room
---@field color? ColorMixin
---@field icon? fileID|string
---@field values? string[]
---@field valueColor? ColorMixin
---@field wrap? boolean
---@field tooltip? fun(tooltip: GameTooltip)
---@field click? fun()

---@class SkillUpListRow : Button
---@field entry SkillUpListEntry
---@field Icon Texture
---@field Text FontString
---@field Note FontString
---@field UpdateTooltip fun(self: SkillUpListRow) called by the tooltip this row owns, a few times a second
---@field Values FontString[]

---@class SkillUpColumn
---@field title string
---@field width number
---@field justify? JustifyHorizontal
---@field right? number

---@class SkillUpList
---@field rows SkillUpListRow[]
---@field count integer
---@field height number
---@field scrollBox SkillUpScrollBox
---@field Add fun(self: SkillUpList, entry: SkillUpListEntry)
---@field Message fun(self: SkillUpList, text: string, color?: ColorMixin)
---@field Finish fun(self: SkillUpList)

---@class SkillUpCraftButton : Button
---@field recipeID? integer
---@field count? number
---@field reason? string

-- A class's list of craftable items, one entry a slot, newest first.
---@class SkillUpGearItem
---@field recipeID integer
---@field itemID integer
---@field skillLine integer
---@field skill number The base skill the recipe needs.
---@field level number The item's required level.
---@field profession string
---@field learned boolean
---@field learnable boolean The character has the profession to learn it.

---@class SkillUpGearSlot
---@field slot integer The slot group's position in the view.
---@field name string
---@field items SkillUpGearItem[]

-- What Gear.List needs to know about the character and the data.
---@class SkillUpGearQuery
---@field level number
---@field classID integer
---@field learned fun(recipeID: integer): boolean
---@field professions table<integer, SkillUpProfession> The character's, by skill line.
---@field skill fun(recipeID: integer): number
---@field professionName fun(skillLine: integer): string

---@class SkillUpGearPage : Frame
---@field List SkillUpList

---@class SkillUpPage : Frame
---@field Craft SkillUpCraftButton
---@field Profession DropdownButton
---@field Skill FontString
---@field Target EditBox
---@field Track Button
---@field Auctionator Button
---@field Collect CheckButton
---@field CollectLabel FontString
---@field Vendor Button
---@field vendorItems integer[]
---@field RouteList SkillUpList
---@field ReagentList SkillUpList
---@field PriceAge FontString

---@class SkillUpBar : Frame
---@field track Frame
---@field segments Texture[]
---@field labels FontString[]
---@field marker Texture
---@field you FontString

---@class SkillUpUse
---@field recipeID integer
---@field t number[]
---@field skill number
---@field learned boolean

---@class SkillUpTrainerService
---@field name string
---@field kind string
---@field recipeID? integer
---@field ambiguous? boolean

---@class SkillUpTrainerState
---@field services SkillUpTrainerService[]
---@field ctx? SkillUpContext
---@field best? integer

---@alias SkillUpProviderState 'missing'|'unfit'|'waiting'|'ready'

-- What Questie says of an item: sorted NPC and quest IDs, and the recipe a scroll teaches.
---@class SkillUpItemSources
---@field vendors integer[]
---@field quests integer[]
---@field drops integer[]
---@field teaches? integer

---@class SkillUpSourceNPC
---@field name string
---@field side? ''|'A'|'H' Who can deal with it; nil when it is hostile to both.
---@field map? integer Its zone map, with x and y in 0-1.
---@field x? number
---@field y? number
---@field area? integer Its area, when it has no map point (a dungeon).
---@field world? {instance: integer, x: number, y: number}|false Its world position, worked out on first use.

---@class SkillUpSourceQuest
---@field title string
---@field side ''|'A'|'H'

-- Where a recipe's scroll comes from. The skill it needs is AtlasLoot's, so nil without it.
---@class SkillUpScrollSource
---@field item integer
---@field skill? number
---@field vendors integer[]
---@field quests integer[]
---@field drops number[][] { npc, chance % }, likeliest first.
---@field world boolean
