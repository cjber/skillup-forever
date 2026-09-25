---@meta

-- The client passes this same table to each TOC file; no runtime import is available.
---@class SkillUpNamespace
---@field Print fun(msg: string)
---@field ProfessionSkillLine fun(name?: string, reported?: integer): integer?
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
---@field CraftValue fun(recipeID: integer): SkillUpValue?
---@field LearnReagents fun()
---@field RecipeCost fun(recipeID: integer): number?
---@field NetCost fun(recipeID: integer): number?
---@field ScanAuctions fun(force: boolean)
---@field InitPrices fun()
---@field AttachRecipeList fun()
---@field RefreshRecipeList fun()
---@field RouteProfessions fun(): table<integer, SkillUpProfession>
---@field RouteTarget fun(profession: SkillUpContext): number
---@field RouteSnapshot fun(profession: SkillUpContext, known?: table<integer, boolean>): SkillUpSnapshot
---@field TrainingFor fun(profession: SkillUpContext, recipeID: integer): number[]?
---@field InvalidatePlans fun()
---@field PlanRoute fun(profession: SkillUpProfession): SkillUpPlan
---@field RankText fun(rank: SkillUpRank): string
---@field CreateList fun(parent: Frame, columns: SkillUpColumn[]): SkillUpList
---@field NextCraft fun(profession: SkillUpProfession, route: SkillUpPlan): SkillUpCraft
---@field RefreshRoute fun()
---@field OpenSkillLine fun(): integer?
---@field ShowRecipe fun(recipeID: integer)
---@field RefreshRouteTab fun()
---@field AttachRoute fun()
---@field RegisterSettings fun()
---@field SetSortMode fun(mode: string)
---@field OpenSettings fun()
---@field HasAuctionator fun(): boolean
---@field Have fun(itemID: integer): number
---@field AltCounts fun(itemID: integer): {name: string, count: number}[]
---@field RouteReagents fun(route: SkillUpRoute): SkillUpNeededItem[]
---@field SendToAuctionator fun(profession: string, items: SkillUpNeededItem[])
---@field IsTracked fun(skillLine?: integer): boolean
---@field TrackedNeeds fun(): SkillUpTracked[]
---@field TrackerAttached fun(): boolean
---@field RefreshTracker fun()
---@field SetTracked fun(skillLine: integer, tracked: boolean)
---@field InitShopping fun()
---@field NPCLocation fun(npcID: integer): SkillUpLocation
---@field LocationText fun(where: SkillUpLocation): string
---@field NearestNPC fun(npcIDs: integer[], byTravel?: boolean): integer?
---@field SetWaypoint fun(npcID: integer)
---@field SuggestionNPC fun(suggestion: SkillUpSuggestion): integer?
---@field RecipeSuggestions fun(profession: SkillUpContext, skill: number): SkillUpSuggestion[]
---@field ScrollPrice fun(source: SkillUpSource): number?
---@field AddSourceLines fun(tooltip: GameTooltip, source: SkillUpSource)
---@field NearestTrainer fun(profession: SkillUpContext, cap: number, byTravel?: boolean): integer?
---@field NearestVendor fun(itemID: integer, byTravel?: boolean): integer?
---@field AddNearest fun(tooltip: GameTooltip, label: string, npcID?: integer)
---@field FormatNet fun(copper: number, profit: boolean): string
---@field FormatAge fun(timestamp: number): string
---@field PriceAge fun(price: SkillUpPrice): number
---@field PriceAgeText fun(price: SkillUpPrice): string
---@field PriceSourceText fun(price: SkillUpPrice): string
---@field ShowRecipeTooltip fun(_: SkillUpNamespace, row: SkillUpRecipeRow, data: SkillUpRecipeNodeData)
---@field AttachItemTooltips fun()
---@field RefreshTrainer fun()
---@field AttachTrainer fun()
---@field PricesChanged fun()
---@field SORT_OPTIONS string[][]
---@field REAGENT_TOOLTIP_OPTIONS string[][]
---@field TITLE string
---@field COLORS table<string, ColorMixin>
---@field Model SkillUpModel
---@field db SkillUpDB
---@field DEFAULTS SkillUpDefaults
---@field Thresholds table<integer, number[]>
---@field VendorPrices table<integer, number>
---@field RecipeData table<integer, SkillUpRecipe>
---@field ItemSellPrices table<integer, number>
---@field RecipeNames table<integer, table<string, integer|false>>
---@field ProfessionSkillLines table<string, integer>
---@field TrainerFees table<integer, number[]>
---@field TrainerRanks table<integer, number[][]>
---@field RecipeSources table<integer, SkillUpSource>
---@field SourceNPCs table<integer, SkillUpNPC>
---@field SourceQuests table<integer, string[]>
---@field ProfessionTrainers table<integer, number[][]>
---@field ReagentVendors table<integer, integer[]>
---@field GatheredBy table<integer, integer>
---@field InstanceNames table<integer, string>

---@class SkillUpDefaults
---@field showRowText boolean
---@field showSkill boolean
---@field showTooltip boolean
---@field showCost boolean
---@field scanAuctions boolean
---@field craftValue 'none'|'vendor'|'auction'
---@field sortMode 'blizzard'|'skill'|'chance'|'cost'
---@field showTrainer boolean
---@field showRouteTab boolean
---@field reagentTooltip 'off'|'route'|'full'
---@field gatherFree boolean
---@field routeTargets table<integer, number>
---@field learned table<string, table<integer, boolean>>
---@field professionIDs table<string, integer>
---@field trackedProfessions table<integer, boolean>
---@field trainer table<integer, table<integer, number[]>>
---@field vendor table<integer, number>
---@field tracked table<integer, boolean>
---@field auctions table<string, table<integer, SkillUpScan>>

---@class SkillUpDB : SkillUpDefaults
---@field showReagentTooltip? boolean Legacy migration only.

---@type SkillUpDB
SkillUpForeverDB = nil

---@class SkillUpScan
---@field copper? number
---@field time number

---@class SkillUpReagent
---@field itemID integer
---@field quantity number

---@class SkillUpRecipe : SkillUpSchematic
---@field skillLine integer

---@class SkillUpSchematic
---@field reagents SkillUpReagent[]
---@field output? SkillUpReagent|false

---@class SkillUpSource
---@field item integer
---@field skill number
---@field price? number
---@field vendors? integer[]
---@field limited? integer[]
---@field quests? integer[]
---@field drops? number[][]
---@field world? boolean

---@class SkillUpNPC
---@field [1] string Name.
---@field [2] string Faction code.
---@field [3] integer World map.
---@field [4] number World X.
---@field [5] number World Y.

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
---@field reqSkill? number

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
---@field excluded {unpriced: integer}
---@field stopReason? 'no_recipe'

---@class SkillUpTrainedRoute : SkillUpRoute
---@field training SkillUpTraining[]
---@field trainingCost number

---@class SkillUpPlan : SkillUpTrainedRoute
---@field profession string
---@field target number
---@field ranks SkillUpRank[]

---@class SkillUpShoppingItem
---@field itemID integer
---@field count number

---@alias SkillUpPriceSource 'vendor'|'scan'|'auctionator'|'gather'
---@class SkillUpPrice
---@field copper number
---@field source SkillUpPriceSource
---@field time? number Scan timestamps only.
---@field days? number Auctionator ages only.
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
---@field source SkillUpSource
---@field kind integer
---@field kindText string
---@field npcID? integer
---@field reach number

---@class SkillUpNeededItem
---@field itemID integer
---@field need number
---@field source 'gather'|'vendor'|'auction'|'unknown'

---@class SkillUpTracked
---@field skillLine integer
---@field professionInfo SkillUpProfession
---@field route SkillUpPlan
---@field items SkillUpNeededItem[]
---@field modifier number

---@class SkillUpCraft
---@field text string
---@field recipeID? integer
---@field count? number
---@field reason? string

---@alias SkillUpSortKey fun(info: TradeSkillRecipeInfo, ctx: SkillUpContext?): number

---@class SkillUpListEntry
---@field text string
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

---@class SkillUpPage : Frame
---@field Craft SkillUpCraftButton
---@field Profession DropdownButton
---@field Skill FontString
---@field Target EditBox
---@field Track Button
---@field Auctionator Button
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
