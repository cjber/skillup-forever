---@meta

-- SkillUp Forever's public API (version 1), read by other addons. A read returns a fresh table on every call; a
-- field SkillUp can't establish is nil, and a read with nothing to answer adds a reason as its second value.

---@alias SkillUpAPIStepKind 'buy'|'craft'|'train'|'gather'
---@alias SkillUpAPIReagentSource 'vendor'|'craft'|'gather'|'auction'
---@alias SkillUpAPIReason 'loading'|'disabled'|'none'|'invalid'
---@alias SkillUpAPIChangeName 'professions'|'shopping'
---@alias SkillUpAPIChanges table<SkillUpAPIChangeName, true>

---@class SkillUpAPIStep
---@field kind SkillUpAPIStepKind
---@field text string Short imperative line, "Craft 3 Toughened Leather Gloves".
---@field detail? string "142 to 145", "Name, Zone · fee".
---@field itemID? integer Reagent to get, the craft's product, or a rank's book or a recipe's scroll to buy or read.
---@field spellID? integer Recipe to craft or train.
---@field questID? integer The quest that teaches a rank no trainer or book does (a train step).
---@field count? number
---@field cost? number Copper: a purchase or training fee.
---@field nav boolean Navigate can route to the vendor, trainer or quest giver.

---@class SkillUpAPIRecipe
---@field spellID integer
---@field itemID? integer
---@field name? string
---@field count number Crafts planned.
---@field fromRank number Base skill.
---@field toRank number
---@field learned boolean
---@field color? 'orange'|'yellow'|'green'|'grey'
---@field trainAt? number Base skill where the route first uses it, when it's still to train.
---@field cost? number Training fee in copper, when it's still to train.

---@class SkillUpAPIReagent
---@field itemID integer
---@field need number For the whole route.
---@field have number Bags and bank.
---@field source? SkillUpAPIReagentSource

---@class SkillUpAPIProfessionLimits
---@field steps? integer Whole number from 1 to 25; the default is 3.
---@field recipes? integer Whole number from 1 to 25; the default is 5.

---@class SkillUpAPIProfession
---@field name string Localized.
---@field skillLineID integer
---@field icon fileID
---@field rank number Base skill.
---@field maxRank number Current cap.
---@field title? string
---@field steps SkillUpAPIStep[] In order; three by default, up to 25 with limits.
---@field recipes SkillUpAPIRecipe[] Five by default, up to 25 with limits.
---@field reagents SkillUpAPIReagent[]

---@class SkillUpAPIStat
---@field addon 'SkillUpForever'
---@field metric 'recipes_observed_learned'
---@field subject 'all'
---@field value number This character's distinct observed recipes.
---@field eventUnix? number The last observation's time, absent before the first.

---@class SkillUpPublicAPI
---@field version integer
---@field minor integer Raised with each addition; docs/api.md keeps the history.
---@field Professions fun(limits?: SkillUpAPIProfessionLimits): SkillUpAPIProfession[]?, SkillUpAPIReason? Most actionable first; nil, "loading" before the saved variables load, nil, "invalid" for a bad limit.
---@field Navigate fun(skillLineID: integer, stepIndex: integer): boolean
---@field OpenRecipes fun(skillLineID: integer): boolean
---@field IsTracked fun(skillLineID: integer): boolean?, SkillUpAPIReason? nil, "loading" before the saved variables load.
---@field SetTracked fun(skillLineID: integer, tracked: boolean): boolean?, SkillUpAPIReason? True when it changed the setting; false for a bad or unchanged choice.
---@field ShoppingList fun(skillLineID?: integer): SkillUpAPIShoppingProfession[] Fresh copy for tracked routes; empty when no matching tracked route exists.
---@field ShoppingTrip fun(skillLineID?: integer): boolean Starts the same shopping trip the shopping list button does.
---@field RequiredMaterials fun(recipeID: integer, crafts?: number): {itemID: integer, count: number}[]?, SkillUpAPIReason? Raw inputs after known, cheaper sub-crafts are expanded; nil, "none" when SkillUp has no such recipe.
---@field SubComponents fun(recipeID: integer, crafts?: number): SkillUpSubCraft[]?, SkillUpAPIReason? Known cheaper recipes needed to make the recipe's inputs; nil, "none" when SkillUp has no such recipe.
---@field Stats fun(): SkillUpAPIStat[] This character's own recipe observations.
---@field Subscribe fun(callback: fun(changes: SkillUpAPIChanges)): fun() Calls back the frame after the answers change, once per burst; returns an unsubscribe.

---@class SkillUpAPIShoppingItem
---@field itemID integer
---@field need number
---@field have number
---@field missing number
---@field source SkillUpShoppingSource
---@field price? number Copper per item.
---@field priceAge? number Days since Auctionator's observation.
---@field cost? number Copper for missing units; nil if unpriced.
---@field alt {name: string, count: number}[]

---@class SkillUpAPIShoppingProfession
---@field profession string Localized route name.
---@field skillLine integer
---@field target number Base skill the profession's plan buys to.
---@field items SkillUpAPIShoppingItem[]
---@field total number Copper for priced missing items.
---@field unpriced integer Count of missing items without a price.

---@class SkillUpPublicAddon
---@field API SkillUpPublicAPI
---@type SkillUpPublicAddon
SkillUpForever = nil
