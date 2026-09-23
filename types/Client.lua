---@meta

-- FrameXML surfaces absent from Ketho's pinned Core annotations. Signatures follow
-- Gethe/wow-ui-source forever @ c6e89983189e4f626f549204a23c2d2bea93080a.
-- These declarations never load in the client.
---@type table<string, fun(msg: string)>
SlashCmdList = {}
---@type MessageFrame
DEFAULT_CHAT_FRAME = nil
---@type Frame
AuctionHouseFrame = nil
---@type Frame
MerchantFrame = nil
---@type table<string, number>
SOUNDKIT = {}
---@type {Refresh: number}
MenuResponse = {}
---@type {ContinueOnAddOnLoaded: fun(name: string, callback: fun())}
EventUtil = {}

---@class SkillUpProfessionFrame : Frame
---@field CraftingPage SkillUpCraftingPage
---@field BookPage Frame
---@field professionInfo? ProfessionInfo
---@field ProfessionsOverviewTab SkillUpSideTab
---@field rightProfessionTabs SkillUpSideTab[]
---@field SetPortraitToAsset fun(self: SkillUpProfessionFrame, asset: fileID|string)
---@field GetPortrait fun(self: SkillUpProfessionFrame): Texture
---@field RightTabSelected fun(self: SkillUpProfessionFrame, tab: SkillUpSideTab)
---@field RefreshRightTabs fun(self: SkillUpProfessionFrame)
---@type SkillUpProfessionFrame
ProfessionsFrame = nil

---@class SkillUpCraftingPage : Frame
---@field RecipeList SkillUpRecipeList
---@field Init fun(self: SkillUpCraftingPage, info: ProfessionInfo)

---@class SkillUpRecipeList : Frame
---@field ScrollBox SkillUpRecipeScrollBox
---@field FilterDropdown DropdownButton
---@field SelectRecipe fun(self: SkillUpRecipeList, info: TradeSkillRecipeInfo, scroll: boolean)

---@class SkillUpRecipeRow : Button
---@field Count FontString
---@field LockedIcon Texture
---@field SkillUps FontString
---@field Label FontString
---@field SkillUpText? FontString

---@class SkillUpRecipeNodeData
---@field recipeInfo? TradeSkillRecipeInfo
---@field isDivider? boolean
---@field dividerHeight? number

---@class SkillUpTreeNode
---@field GetData fun(self: SkillUpTreeNode): SkillUpRecipeNodeData
---@field GetNodes fun(self: SkillUpTreeNode): SkillUpTreeNode[]

---@class SkillUpTreeProvider
---@field GetRootNode fun(self: SkillUpTreeProvider): SkillUpTreeNode
---@field Insert fun(self: SkillUpTreeProvider, data: SkillUpRecipeNodeData)

---@return SkillUpTreeProvider
function CreateTreeDataProvider() end

---@class SkillUpScrollBox : Frame
---@field FullUpdate fun(self: SkillUpScrollBox, immediate?: boolean)
---@field ScrollToBegin fun(self: SkillUpScrollBox)

---@class SkillUpRecipeScrollBox : SkillUpScrollBox
---@field GetDataProvider fun(self: SkillUpRecipeScrollBox): SkillUpTreeProvider?
---@field SetDataProvider fun(self: SkillUpRecipeScrollBox, provider: SkillUpTreeProvider, retain?: boolean)

---@class SkillUpScrollBar : Frame
---@field SetHideIfUnscrollable fun(self: SkillUpScrollBar, hide: boolean)

---@class SkillUpScrollContent : Frame
---@field scrollable boolean

---@class SkillUpScrollView
---@field SetPanExtent fun(self: SkillUpScrollView, extent: number)
---@return SkillUpScrollView
function CreateScrollBoxLinearView() end

---@type {UpdateImmediately: boolean, RetainScrollPosition: boolean}
ScrollBoxConstants = {}
ScrollUtil = {}
---@param box SkillUpScrollBox
---@param bar SkillUpScrollBar
---@param view SkillUpScrollView
function ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view) end
---@param box SkillUpRecipeScrollBox
---@param callback fun(owner: SkillUpNamespace, row: SkillUpRecipeRow, node: SkillUpTreeNode)
---@param owner SkillUpNamespace
function ScrollUtil.AddInitializedFrameCallback(box, callback, owner) end

Professions = {}
---@return SkillUpProfessionInfo?
function Professions.GetProfessionInfo() end
---@param info TradeSkillRecipeInfo
---@return TradeSkillRecipeInfo?
function Professions.GetHighestLearnedRecipe(info) end

---@class SkillUpSideTab : Frame
---@field Icon Texture
---@field tooltipText string
---@field SetFillToInterior fun(self: SkillUpSideTab, fill: boolean)
---@field SetChecked fun(self: SkillUpSideTab, checked: boolean)
---@field SetCustomOnMouseUpHandler fun(self: SkillUpSideTab, callback: fun(tab: SkillUpSideTab, button: string, upInside: boolean))

---@class DropdownButton : Button
---@field SetupMenu fun(self: DropdownButton, generator: fun(owner: DropdownButton, root: RootMenuDescriptionProxy))
---@field GenerateMenu fun(self: DropdownButton)

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

---@param link string
---@return boolean
function ChatEdit_InsertLink(link) end
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

---@class SkillUpTrackerBlock : Frame
---@field id integer
---@field profession string
---@field professionInfo SkillUpProfession
---@field route SkillUpPlan
---@field items SkillUpNeededItem[]
---@field steps {skill: number, cap: number, text: string}[]
---@field vendorMissing {name: string, vendor: integer}[]
---@field SetHeader fun(self: SkillUpTrackerBlock, text: string)
---@field AddObjective fun(self: SkillUpTrackerBlock, id: string|number, text: string, template?: string, useFullHeight?: boolean, dashStyle?: number, colorStyle?: SkillUpObjectiveColor)

---@class SkillUpTrackerModule : Frame
---@field uiOrder number
---@field MarkDirty fun(self: SkillUpTrackerModule)
---@field SetHeader fun(self: SkillUpTrackerModule, text: string)
---@field GetContextMenuParent fun(self: SkillUpTrackerModule): Frame
---@field GetBlock fun(self: SkillUpTrackerModule, id: integer): SkillUpTrackerBlock
---@field LayoutBlock fun(self: SkillUpTrackerModule, block: SkillUpTrackerBlock): boolean
---@type Frame
ObjectiveTrackerFrame = nil
ObjectiveTrackerManager = {}
---@param module SkillUpTrackerModule
---@param container Frame
function ObjectiveTrackerManager:SetModuleContainer(module, container) end
---@param module SkillUpTrackerModule
---@return Frame?
function ObjectiveTrackerManager:GetContainerForModule(module) end
---@class SkillUpObjectiveColor : ColorRGBData
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
Settings = {}
Settings.VarType = { Boolean = "boolean", String = "string", Number = "number" }
---@param name string
---@return SkillUpCategory
function Settings.RegisterVerticalLayoutCategory(name) end
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
---@param setting SkillUpSetting
---@param tooltip string
function Settings.CreateCheckbox(category, setting, tooltip) end
---@param category SkillUpCategory
---@param setting SkillUpSetting
---@param options fun(): {value: SkillUpSettingValue, text: string}[]
---@param tooltip string
function Settings.CreateDropdown(category, setting, options, tooltip) end
---@return SkillUpSettingOptions
function Settings.CreateControlTextContainer() end
---@param category SkillUpCategory
function Settings.RegisterAddOnCategory(category) end
---@param variable string
---@param value SkillUpSettingValue
function Settings.SetValue(variable, value) end
---@param categoryID number
function Settings.OpenToCategory(categoryID) end

-- Professions decorates native recipe/profession records before dispatching callbacks.
---@class SkillUpProfessionInfo : ProfessionInfo
---@field displayName string

---@class TradeSkillRecipeInfo
---@field favoritesInstance? boolean

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
