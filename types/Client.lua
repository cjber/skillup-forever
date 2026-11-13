---@meta

-- Core/ForeverRequire.lua, copied byte for byte from ForeverCore, collects pcall's results into one table and reads a
-- dependency name from it. LuaLS types that table from pcall's first result only, so the shared file needs pcall typed
-- as one value here. At runtime pcall still returns its truthy status and the call's results; this only widens what
-- the table constructor sees.
---@param f function
---@param ... any
---@return any
function pcall(f, ...) end

-- FrameXML surfaces absent from Ketho's pinned Core annotations. Signatures follow
-- Gethe/wow-ui-source forever @ c6e89983189e4f626f549204a23c2d2bea93080a.
-- These declarations never load in the client.
---@type table<string, fun(msg: string)>
SlashCmdList = {}
---@type MessageFrame
DEFAULT_CHAT_FRAME = nil
-- Frames Escape closes, by name.
---@type string[]
UISpecialFrames = {}
---@class SkillUpMerchantFrame : Frame
---@field selectedTab integer
---@type SkillUpMerchantFrame
MerchantFrame = nil

-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua: a frame's own tab row, one tab at a time.
---@param tab Frame
function PanelTemplates_SelectTab(tab) end

---@param tab Frame
function PanelTemplates_DeselectTab(tab) end

---@param tab Frame
---@param padding integer?
---@param absoluteSize number?
---@param minWidth number?
---@param maxWidth number?
---@param absoluteTextSize number?
function PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth, absoluteTextSize) end

-- The client's words for a buff effect's stat, armour, spell and resistance rows (GlobalStrings).
---@type string
STAT_ATTACK_POWER = ""
---@type string
STAT_ARMOR = ""
---@type string
STAT_SPELLDAMAGE = ""
---@type string
STAT_SPELLHEALING = ""
---@type string
STAT_CRITICAL_STRIKE = ""
---@type string
STAT_MOVEMENT_SPEED = ""
---@type string
RESISTANCE_LABEL = ""

-- Blizzard_ItemButton/Shared/ItemButtonTemplate.lua: the icon region an item button carries, under Icon, icon or
-- the $parentIconTexture name.
---@param button Frame
---@return Texture?
function GetItemButtonIconTexture(button) end
---@type table<string, number>
SOUNDKIT = {}
---@type {Refresh: number}
MenuResponse = {}
---@type {ContinueOnAddOnLoaded: fun(name: string, callback: fun()), ContinueAfterAllEvents: fun(callback: function, ...: string)}
EventUtil = {}

---@class EditModeManagerFrame : Frame
---@field IsEditModeActive fun(self: EditModeManagerFrame): boolean
---@type EditModeManagerFrame?
EditModeManagerFrame = nil

-- GlobalStrings the client defines from its GlobalStrings DB2 in the player's language
-- (enUS values from wago.tools, Forever build 1.60.1.70009).
APPRENTICE = "Apprentice"
UNKNOWN = "Unknown"
JOURNEYMAN = "Journeyman"
EXPERT = "Expert"
ARTISAN = "Artisan"
DEFAULT = "Default"
OFF = "Off"
TOTAL = "Total"
UNIT_SKINNABLE_LEATHER = "Skinnable"
UNIT_SKINNABLE_HERB = "Requires Herbalism"
UNIT_SKINNABLE_ROCK = "Requires Mining"
ITEM_MIN_SKILL = "Requires %s (%d)"

-- The window's crafting page, as SkillUp reads it: its recipe list and the schematic form beside it.
---@class SkillUpCraftingPage : ForeverProfessionPage
---@field RecipeList SkillUpRecipeList
---@field SchematicForm SkillUpSchematicForm
---@field CreateButton? Button
---@field CreateAllButton? Button
---@field Init fun(self: SkillUpCraftingPage, info: ProfessionInfo)

-- The client's Professions window is core's ForeverProfessionsWindow type (types/Client.lua there), which core no
-- longer declares as a global (ForeverCore 1.4.1). SkillUp reads a few more of its native members, so they are added
-- to the class here. Its CraftingPage is core's ForeverProfessionPage; a file that reads SkillUp's own recipe list
-- and schematic form casts it to SkillUpCraftingPage where it uses them.
---@class ForeverProfessionsWindow
---@field Bg Texture
---@field professionInfo? ProfessionInfo
---@field SetPortraitToAsset fun(self: ForeverProfessionsWindow, asset: fileID|string)
---@field GetPortrait fun(self: ForeverProfessionsWindow): Texture
---@field RightTabSelected fun(self: ForeverProfessionsWindow, tab: SkillUpSideTab)
---@field RefreshRightTabs fun(self: ForeverProfessionsWindow)
---@type ForeverProfessionsWindow
ProfessionsFrame = nil

---@class SkillUpSchematicForm : Frame
---@field Description FontString
---@field OutputText? FontString
---@field RequiredTools? FontString
---@field Reagents? Frame
---@field GetRecipeInfo? fun(self: SkillUpSchematicForm): TradeSkillRecipeInfo?

-- Blizzard_AuctionHouseUI's frame; its public SetSearchText fills the search box and queries nothing.
---@class SkillUpAuctionHouseFrame : Frame
---@field SetSearchText fun(self: SkillUpAuctionHouseFrame, text: string): boolean
---@type SkillUpAuctionHouseFrame?
AuctionHouseFrame = nil

---@class SkillUpRecipeList : Frame
---@field ScrollBox SkillUpRecipeScrollBox
---@field FilterDropdown DropdownButton
---@field SelectRecipe fun(self: SkillUpRecipeList, info: TradeSkillRecipeInfo, scroll: boolean)

---@class SkillUpRecipeRow : Button
---@field Count FontString
---@field LockedIcon Texture
---@field SkillUps FontString
---@field Label FontString
---@field subText FontString

---@class SkillUpRecipeNodeData
---@field recipeInfo? TradeSkillRecipeInfo
---@field categoryInfo? table
---@field isDivider? boolean
---@field dividerHeight? number
---@field topPadding? boolean
---@field bottomPadding? boolean

---@class SkillUpTreeNode
---@field GetData fun(self: SkillUpTreeNode): SkillUpRecipeNodeData
---@field GetNodes fun(self: SkillUpTreeNode): SkillUpTreeNode[]
---@field Insert fun(self: SkillUpTreeNode, data: SkillUpRecipeNodeData): SkillUpTreeNode
---@field IsCollapsed? fun(self: SkillUpTreeNode): boolean
---@field SetCollapsed? fun(self: SkillUpTreeNode, collapsed: boolean)

-- The shape the client's tree and list data providers share.
---@class SkillUpBaseDataProvider
---@field entries any[]

---@class SkillUpTreeProvider : SkillUpBaseDataProvider
---@field GetRootNode fun(self: SkillUpTreeProvider): SkillUpTreeNode
---@field Insert fun(self: SkillUpTreeProvider, data: SkillUpRecipeNodeData): SkillUpTreeNode

---@return SkillUpTreeProvider
function CreateTreeDataProvider() end

---@class SkillUpScrollBox : Frame
---@field ScrollToBegin fun(self: SkillUpScrollBox)
---@field SetDataProvider fun(self: SkillUpScrollBox, provider: SkillUpBaseDataProvider, retain?: boolean|integer)
---@field GetScrollPercentage fun(self: SkillUpScrollBox): number
---@field SetScrollPercentage fun(self: SkillUpScrollBox, percentage: number, noInterpolation?: boolean)

---@class SkillUpRecipeScrollBox : SkillUpScrollBox, CallbackRegistryMixin
---@field GetDataProvider fun(self: SkillUpRecipeScrollBox): SkillUpTreeProvider?
---@field SetDataProvider fun(self: SkillUpRecipeScrollBox, provider: SkillUpBaseDataProvider, retain?: boolean|integer)
---@field ForEachFrame fun(self: SkillUpRecipeScrollBox, callback: fun(frame: SkillUpRecipeRow, elementData: SkillUpTreeNode))

---@class SkillUpScrollBarThumb : Button
---@field Begin Texture
---@field End Texture
---@field Middle Texture
---@field isHorizontal boolean

---@class SkillUpScrollBarTrack : Frame
---@field Begin Texture
---@field End Texture
---@field Middle Texture
---@field Thumb SkillUpScrollBarThumb

---@class SkillUpScrollBar : Frame, CallbackRegistryMixin
---@field Track SkillUpScrollBarTrack
---@field Back Frame
---@field Forward Frame
---@field isHorizontal boolean
---@field thumbAnchor string
---@field SetHideIfUnscrollable fun(self: SkillUpScrollBar, hide: boolean)
---@field SetVisibleExtentPercentage fun(self: SkillUpScrollBar, percentage: number)
---@field GetVisibleExtentPercentage fun(self: SkillUpScrollBar): number
---@field SetScrollPercentage fun(self: SkillUpScrollBar, percentage: number, forceImmediate?: boolean)
---@field GetScrollPercentage fun(self: SkillUpScrollBar): number

---@class SkillUpDataProvider : SkillUpBaseDataProvider
---@field GetSize fun(self: SkillUpDataProvider): integer

---@param tbl? table
---@return SkillUpDataProvider
function CreateDataProvider(tbl) end

---@alias SkillUpElementInitializer fun(frame: Frame, elementData: SkillUpListElement)
---@alias SkillUpElementFactory fun(factory: fun(template: string, initializer: SkillUpElementInitializer), elementData: SkillUpListElement)

-- ForeverCore 1.8.0 no longer declares these client scroll types, so SkillUp declares what it uses.
---@class ForeverScrollBoxView
---@field SetElementInitializer fun(self: ForeverScrollBoxView, template: string, initializer: fun(button: Button, element: any))
---@field SetElementExtent fun(self: ForeverScrollBoxView, extent: number)
---@field SetPadding fun(self: ForeverScrollBoxView, ...: number)

---@class ForeverScrollUtil
---@field InitScrollBoxListWithScrollBar fun(box: Frame, bar: any, view: ForeverScrollBoxView)
---@type ForeverScrollUtil
ScrollUtil = nil

---@class SkillUpScrollView : ForeverScrollBoxView
---@field SetElementExtent fun(self: SkillUpScrollView, extent: number)
---@field SetElementExtentCalculator fun(self: SkillUpScrollView, calculator: fun(dataIndex: integer, elementData: SkillUpListElement): number)
---@field SetElementFactory fun(self: SkillUpScrollView, elementFactory: SkillUpElementFactory)
---@field SetElementInitializer fun(self: SkillUpScrollView, template: string, initializer: fun(button: Button, element: any))
---@field SetPadding fun(self: SkillUpScrollView, ...: number)
---@return SkillUpScrollView
function CreateScrollBoxListLinearView() end

---@class ForeverClassColor
---@field GetRGB fun(self: ForeverClassColor): number, number, number
---@type table<string, ForeverClassColor>?
RAID_CLASS_COLORS = nil

---@type {UpdateImmediately: boolean, RetainScrollPosition: boolean, NoScrollInterpolation: boolean}
ScrollBoxConstants = {}
---@class ForeverScrollUtil
---@field AddInitializedFrameCallback fun(box: SkillUpRecipeScrollBox, callback: fun(owner: SkillUpNamespace, row: SkillUpRecipeRow, node: SkillUpTreeNode), owner: SkillUpNamespace)

Professions = {}
---@return SkillUpProfessionInfo?
function Professions.GetProfessionInfo() end
---@param info TradeSkillRecipeInfo
---@return TradeSkillRecipeInfo?
function Professions.GetHighestLearnedRecipe(info) end

-- The character's own skill lines, from Forever's Skills pane (SkillInfoDocumentation.lua).
---@class SkillUpSkillLine
---@field skillID integer
---@field name string
---@field isHeader boolean
---@field rank number
---@field modifier number
---@field parentSkillLineID integer
---@field skillLineCategoryID integer

C_SkillInfo = {}
---@return integer
function C_SkillInfo.GetNumSkillLines() end
---@param index integer
---@return SkillUpSkillLine?
function C_SkillInfo.GetSkillLineInfo(index) end
---@param ID integer
---@return SkillUpSkillLine?
function C_SkillInfo.GetSkillLineInfoByID(ID) end

---@class SkillUpSideTab : Frame
---@field Icon Texture
---@field tooltipText string
---@field SetFillToInterior fun(self: SkillUpSideTab, fill: boolean)
---@field SetChecked fun(self: SkillUpSideTab, checked: boolean)
---@field SetCustomOnMouseUpHandler fun(self: SkillUpSideTab, callback: fun(tab: SkillUpSideTab, button: string, upInside: boolean))

---@class DropdownButton : Button
---@field SetupMenu fun(self: DropdownButton, generator: fun(owner: DropdownButton, root: RootMenuDescriptionProxy))
---@field GenerateMenu fun(self: DropdownButton)
---@field GetMenuDescription fun(self: DropdownButton): RootMenuDescriptionProxy?
---@field CollectSelectionData fun(self: DropdownButton): ElementMenuDescriptionProxy?, ElementMenuDescriptionProxy?, ElementMenuDescriptionProxy[]
---@field Pick fun(self: DropdownButton, description: ElementMenuDescriptionProxy|RootMenuDescriptionProxy, context: any): boolean
---@field OpenMenu fun(self: DropdownButton)

-- The client's gamepad-interface check, the screen errors line and the menu pieces around a dropdown.
---@class InputUtilAPI
---@field IsGamepadUIEnabled fun(): boolean
---@type InputUtilAPI
InputUtil = nil

---@class UIErrorsFrameAPI : Frame
---@field AddMessage fun(self: UIErrorsFrameAPI, text: string, r: number, g: number, b: number)
---@type UIErrorsFrameAPI
UIErrorsFrame = nil

---@class DropdownButtonMixinAPI
---@field OpenMenu fun(self: DropdownButton)
---@type DropdownButtonMixinAPI
DropdownButtonMixin = nil

---@class MenuInputContextEnum
---@field MouseWheel integer
---@type MenuInputContextEnum
MenuInputContext = nil

-- Ketho declares the native tooltip widget; Forever also mixes in GameTooltipDataMixin.
---@class GameTooltip
---@field RefreshData fun(self: GameTooltip)
---@return string? name
---@return string? link
---@return integer? itemID
function GameTooltip:GetItem() end

---@param tooltip GameTooltip
---@param title string
function GameTooltip_SetTitle(tooltip, title) end
---@param tooltip GameTooltip
function GameTooltip_AddBlankLineToTooltip(tooltip) end
---@param tooltip GameTooltip
---@param text string
---@param color ColorMixin
function GameTooltip_AddColoredLine(tooltip, text, color) end
---@param tooltip GameTooltip
---@param left string
---@param right string
---@param leftColor ColorMixin
---@param rightColor ColorMixin
function GameTooltip_AddColoredDoubleLine(tooltip, left, right, leftColor, rightColor) end
---@param tooltip GameTooltip
---@param text string
function GameTooltip_AddNormalLine(tooltip, text) end
---@param tooltip GameTooltip
---@param text string
function GameTooltip_AddDisabledLine(tooltip, text) end
---@param tooltip GameTooltip
---@param text string
function GameTooltip_AddHighlightLine(tooltip, text) end
---@param tooltip GameTooltip
---@param text string
function GameTooltip_AddInstructionLine(tooltip, text) end
---@param tooltip GameTooltip
---@param frame Frame
---@param padding? number
function GameTooltip_InsertFrame(tooltip, frame, padding) end
function GameTooltip_Hide() end

ChatFrameUtil = {}
---@param text string?
---@return boolean
function ChatFrameUtil.InsertLink(text) end
---@param link string
---@return boolean
function HandleModifiedItemClick(link) end

TooltipDataProcessor = {}
---@param kind Enum.TooltipDataType
---@param callback fun(tooltip: GameTooltip, data: TooltipData)
function TooltipDataProcessor.AddTooltipPostCall(kind, callback) end

UiMapPoint = {}
---@param mapID integer
---@param x number
---@param y number
---@return UiMapPoint
function UiMapPoint.CreateFromCoordinates(mapID, x, y) end

---@class SkillUpTrainerElement
---@field skillIndex? integer
---@field data? SkillUpTrainerElement

---@class SkillUpTrainerButton : Button
---@field SkillUpText? FontString
---@field subText FontString
---@field GetElementData fun(self: SkillUpTrainerButton): SkillUpTrainerElement

---@class SkillUpTrainerScrollBox : Frame
---@field ForEachFrame fun(self: SkillUpTrainerScrollBox, callback: fun(button: SkillUpTrainerButton))

---@class SkillUpTrainerFrame : Frame
---@field ScrollBox SkillUpTrainerScrollBox
---@field skillStepButton SkillUpTrainerButton
---@type SkillUpTrainerFrame
ClassTrainerFrame = nil
---@type {GetTrainerType: fun(): number}
C_Trainer = {}

---@class SkillUpTrackerStep
---@field text string
---@field book string|false|nil A rank's book, by name: got at a vendor, not a trainer.
---@field quest string|false|nil A rank's quest, by name: got from its giver, not a trainer.
---@field nearest fun(byTravel: boolean?): integer?, string The NPC to go to, and its tooltip label.

---@class SkillUpTrackerBlock : Frame
---@field id integer
---@field profession string
---@field plan SkillUpPlan
---@field items SkillUpNeededItem[]
---@field steps SkillUpTrackerStep[]
---@field vendorMissing {name: string, itemID: integer, vendor: integer}[]
---@field SetHeader fun(self: SkillUpTrackerBlock, text: string)
---@field AddObjective fun(self: SkillUpTrackerBlock, id: string|number, text: string, template?: string, useFullHeight?: boolean, dashStyle?: number, colorStyle?: ForeverObjectiveTrackerColor): Frame

---@class SkillUpTrackerModule : ForeverTrackerModule
---@field safeCall? ForeverSafeCall runs the section's header menu entries in SkillUp's journal
---@field MarkDirty fun(self: SkillUpTrackerModule)
---@field SetHeader fun(self: SkillUpTrackerModule, text: string)
---@field GetContextMenuParent fun(self: SkillUpTrackerModule): Frame
---@field GetBlock fun(self: SkillUpTrackerModule, id: integer): SkillUpTrackerBlock
---@field LayoutBlock fun(self: SkillUpTrackerModule, block: SkillUpTrackerBlock): boolean
---@type ForeverNativeTrackerFrame
ObjectiveTrackerFrame = nil

---@class SkillUpObjectiveColor : ForeverObjectiveTrackerColor
---@field reverse? SkillUpObjectiveColor
---@type {Complete: SkillUpObjectiveColor}
OBJECTIVE_TRACKER_COLOR = {}
---@type number
OBJECTIVE_DASH_STYLE_HIDE = nil

---@alias SkillUpSettingValue boolean|string|number
---@class SkillUpSetting
---@field SetValueChangedCallback fun(self: SkillUpSetting, callback: fun())
---@class SkillUpCategory
---@field GetID fun(self: SkillUpCategory): number
---@class SkillUpSettingOptions
---@field Add fun(self: SkillUpSettingOptions, value: SkillUpSettingValue, text: string)
---@field GetData fun(self: SkillUpSettingOptions): {value: SkillUpSettingValue, text: string}[]
-- The client's gamepad switch: the Forever addons page is a canvas page without it.
---@class SkillUpInputUtil
---@field IsGamepadUIEnabled fun(): boolean
---@type SkillUpInputUtil?
InputUtil = nil
Settings = {}
Settings.VarType = { Boolean = "boolean", String = "string", Number = "number" }
---@param name string
---@return SkillUpCategory
function Settings.RegisterVerticalLayoutCategory(name) end
---@return any
function Settings.RegisterCanvasLayoutCategory(frame, name) end
---@param parent SkillUpCategory|table
---@param name string
---@return SkillUpCategory
function Settings.RegisterVerticalLayoutSubcategory(parent, name) end
---@param parent SkillUpCategory|table
---@param frame Frame
---@param name string
---@return SkillUpCategory
function Settings.RegisterCanvasLayoutSubcategory(parent, frame, name) end
---@param category SkillUpCategory
---@param variable string
---@param key string
---@param db SkillUpDB
---@param varType string
---@param name string
---@param default SkillUpSettingValue
---@return SkillUpSetting
function Settings.RegisterAddOnSetting(category, variable, key, db, varType, name, default) end
---@param category SkillUpCategory
---@param variable string
---@param varType string
---@param name string
---@param default number|boolean
---@param getValue fun(): number|boolean
---@param setValue fun(value: number|boolean)
---@return SkillUpSetting
function Settings.RegisterProxySetting(category, variable, varType, name, default, getValue, setValue) end
---@param variable string
function Settings.NotifyUpdate(variable) end
---@class SkillUpSliderOptions
---@field SetLabelFormatter fun(self: SkillUpSliderOptions, labelType: number, formatter: fun(value: number): string)
---@param minValue number
---@param maxValue number
---@param step number
---@return SkillUpSliderOptions
function Settings.CreateSliderOptions(minValue, maxValue, step) end
---@param setting SkillUpSetting
---@param options SkillUpSliderOptions
---@param tooltip string
---@return SkillUpSettingInitializer
function Settings.CreateSliderInitializer(setting, options, tooltip) end
MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }
---@class SkillUpSettingInitializer
---@param setting SkillUpSetting
---@param options nil
---@param tooltip string
---@return SkillUpSettingInitializer
function Settings.CreateCheckboxInitializer(setting, options, tooltip) end
---@param setting SkillUpSetting
---@param options fun(): {value: SkillUpSettingValue, text: string}[]
---@param tooltip string
---@return SkillUpSettingInitializer
function Settings.CreateDropdownInitializer(setting, options, tooltip) end
---@param category SkillUpCategory
---@param setting SkillUpSetting
---@param tooltip string
function Settings.CreateCheckbox(category, setting, tooltip) end
---@param category SkillUpCategory
---@param initializer SkillUpSettingInitializer
function Settings.RegisterInitializer(category, initializer) end
---@return SkillUpSettingOptions
function Settings.CreateControlTextContainer() end
---@param category SkillUpCategory
function Settings.RegisterAddOnCategory(category) end
---@param variable string
---@param value SkillUpSettingValue
function Settings.SetValue(variable, value) end
---@param name string
---@param buttonText string
---@param onClick fun()
---@param tooltip string?
---@param addSearchTags boolean?
---@return SkillUpSettingInitializer
function CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags) end

-- Professions decorates native recipe/profession records before dispatching callbacks.
---@class SkillUpProfessionInfo : ProfessionInfo
---@field displayName string

---@class TradeSkillRecipeInfo
---@field favoritesInstance? boolean
---@field skillUpUnlearned? SkillUpUnlearnedRecipe

-- TooltipData's ID is supplied for item/spell tooltips in Forever, but is absent
-- from Ketho's hand-written TooltipData structure at the pinned revision.
---@class TooltipData
---@field id? integer

-- Ketho's legacy native declaration has no returns; Forever's trainer supplies
-- these together, and supplies no rank when the trainer has no profession.
---@return number? rank
---@return number? maxRank
---@return number? modifier
function GetTrainerTradeskillRankValues() end
