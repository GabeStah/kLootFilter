local ADDON_NAME = 'kLootFilter'
local _G, _ = _G, _
local table, tinsert, tremove, wipe, sort, date, time, random = table, table.insert, table.remove, wipe, sort, date, time, random
local math, tostring, string, strjoin, strlower, strsplit, strsub, strtrim, strupper, floor, tonumber = math, tostring, string, string.join, string.lower, string.split, string.sub, string.trim, string.upper, math.floor, tonumber
local select, pairs, print, next, type, unpack = select, pairs, print, next, type, unpack
local loadstring, assert, error = loadstring, assert, error
local addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "kLib-1.0",
    "kLibColor-1.0",
    "kLibComm-1.0",
    "kLibItem-1.0",
    "kLibOptions-1.0",
    "kLibTimer-1.0",
    "kLibUtility-1.0",
    "kLibView-1.0")
local AceConfigDialog = LibStub('AceConfigDialog-3.0')

local epoch = 0 -- time of the last auto loot

local LOOT_DELAY = 0.3 -- constant interval that prevents rapid looting

addon.defaults = {
	profile = {
        debug = {
			enabled = false,
			threshold = 1,
		},
		enabled = true,
        filtered = {},
        outputFiltering = true,
        isWhitelist = false,
	},
	global = {},
}

--- Generate the options table.
local function GetOptions(uiType, uiName)
    local handlerProto = setmetatable({
        SetItem = function(self, opt, item, added)
            if added then
                addon:AddItemToFilter(item)
            else
                addon:RemoveItemFromFilter(item)
            end
            AceConfigDialog:SelectGroup(ADDON_NAME, "filtered")
        end
	}, { __index = {} })
	local handlerMeta = { __index = handlerProto }

    local optionProto = {
        type = "group",
        name = GetAddOnMetadata(ADDON_NAME, "Title"),
        args = {
            desc = {
                type = "description",
                order = 0,
                name = GetAddOnMetadata(ADDON_NAME, "Notes"),
            },
            debug = {
                name = 'Debug',
                type = 'group',
                order = 99,
                args = {
                    enabled = {
                        name = 'Enabled',
                        type = 'toggle',
                        desc = 'Toggle Debug mode',
                        set = function(info,value) addon.db.profile.debug.enabled = value end,
                        get = function(info) return addon.db.profile.debug.enabled end,
                    },
                    threshold = {
                        name = 'Threshold',
                        desc = 'Description for Debug Threshold',
                        type = 'select',
                        values = {
                            [1] = 'Low',
                            [2] = 'Normal',
                            [3] = 'High',
                        },
                        style = 'dropdown',
                        set = function(info,value) addon.db.profile.debug.threshold = value end,
                        get = function(info) return addon.db.profile.debug.threshold end,
                    },
                },
                cmdHidden = true,
            },
            enabled = {
                name = "Enabled",
                desc = ("Toggle if %s is enabled."):format(ADDON_NAME),
                type = "toggle",
                order = 1,
                get = function()
                    return addon.db.profile.enabled
                end,
                set = function()
                    addon.db.profile.enabled = not addon.db.profile.enabled
                    if addon.db.profile.enabled then
                        addon:Enable()
                    else
                        addon:Disable()
                    end
                end,
            },
            filtered = {
                name = "Filtered Items",
                type = "group",
                order = 1,
                args = {
                    desc = {
                        type = "description",
                        order = 0,
                        name = "List of items that are filtered (and thus ignored) when looting.",
                    },
                    isWhitelist = {
                        name = "Filter as Whitelist",
                        desc = "If enabled, will use the filtered item list as a whitelist, looting only the specified, filtered items.",
                        type = "toggle",
                        order = 1,
                        get = function()
                            return addon.db.profile.isWhitelist
                        end,
                        set = function()
                            addon.db.profile.isWhitelist = not addon.db.profile.isWhitelist
                        end,
                        width = 'normal',
                    },
                    outputFiltering = {
                        name = "Output Filter Messages",
                        desc = "If enabled, will output a message when an item is filtered.",
                        type = "toggle",
                        order = 5,
                        get = function()
                            return addon.db.profile.outputFiltering
                        end,
                        set = function()
                            addon.db.profile.isWhitelist = not addon.db.profile.outputFiltering
                        end,
                        width = 'normal',
                    },
                    items = {
                        name = 'Items',
                        desc = 'Click on a item to remove it from the list. You can drop an item on the empty slot to add it to the list.',
                        type = 'multiselect',
                        dialogControl = 'ItemList',
                        order = 40,
                        get = function() return true end,
                        set = 'SetItem',
                        values = function() return addon.db.profile.filtered end,
                        width = 'full',
                    },
                },
            },
        },
    }
    local optionMeta = { __index = optionProto }

    return setmetatable({handler = setmetatable({values = {}}, handlerMeta)}, optionMeta)
end

function addon:OnEnable()
    -- If option to enable is set, register events.
    if self.db.profile.enabled then
        -- Cannot process with autoloot enabled.
        if GetCVarBool("autoLootDefault") then
            local name = self:Color_String(ADDON_NAME, 1, 0.5, 0.25, 1)
            local interface = self:Color_String("Interface > Controls > Auto Loot", 0.1, 0.75, 0.35, 1)
            print(("%s -- Cannot filter loot when Auto Loot is enabled.  To use %s, please disable Auto Loot in %s, then re-enable %s by typing /klootfilter and checking Enabled."):format(name, name, interface, name))
            self.db.profile.enabled = false
            self:Disable()
        else
            self:RegisterEvent('LOOT_READY', 'ProcessLoot')
        end
    else
        self:Disable()
    end
end

function addon:OnDisable()
    self:UnregisterEvent('LOOT_READY')
end

function addon:OnInitialize()
    -- Load Database
    self.db = LibStub("AceDB-3.0"):New(("%sDB"):format(ADDON_NAME), self.defaults, true)

    -- Options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, GetAddOnMetadata(ADDON_NAME, "Title"))

    -- Register slash commands.
    self:RegisterChatCommand("klf", 'OpenOptions')
    self:RegisterChatCommand("klootfilter", 'OpenOptions')
end

--- Adds the passed item to the filter, if necessary.
function addon:AddItemToFilter(item)
    local id = self:Item_Id(item)
    -- If no id returned, invalid item error.
    if not id then
        self:Error(("Could not add item %s, invalid item or item not cached."):format(item))
        return
    end
    -- Check if item exists
    if self:IsItemFiltered(item) then
        self:Error(("Item %s already exists in filtered list."):format(item))
        return
    end
    -- Add item
    self.db.profile.filtered[id] = {enabled = true}
end

--- Get the current filtered item list for options display.
function addon:GetFilteredList()
    local list = {}
    for id, data in pairs(self.db.profile.filtered) do
        local name = self:Item_Name(id)
        if not name then
            -- No name, use ID
            name = id
        end
        list[id] = name
    end
    return list
end

--- Determined if the passed item is already in the list.
function addon:IsItemFiltered(item)
    local id = self:Item_Id(item)
    if not id then return end
    -- Check in blacklist.
    return self.db.profile.filtered[id] and true or false
end

--- Open options dialog window.
function addon:OpenOptions()
    AceConfigDialog:Open(ADDON_NAME)
end

--- Processes all loot filtering.
function addon:ProcessLoot()
    -- slows method calls to once a LOOT_DELAY interval since LOOT_READY event fires twice
    if (GetTime() - epoch >= LOOT_DELAY) then
        epoch = GetTime()
        if not GetCVarBool("autoLootDefault") then -- Autoloot disabled
            for slot = 1, GetNumLootItems() do
                self:ProcessSlot(slot)
            end
            -- Close loot window.
            CloseLoot()
            -- Reset epoch time.
            epoch = GetTime()
        end
    end
end

--- Determine if item slot should be looted.
function addon:ProcessSlot(slot)
    local item = GetLootSlotLink(slot)
    if item then
        local id = tonumber(self:Item_Id(item))
        local filtered = self:IsItemFiltered(item)
        local blacklist, whitelist = not self.db.profile.isWhitelist, self.db.profile.isWhitelist
        -- Determine if blacklist or whitelist
        -- if blacklist and item filtered, ignore it.
        -- if whitelist and item not filtered, ignore it.
        -- if whitelist and item filtered, loot it.
        -- if blacklist and item not filtered, loot it.
        if (blacklist and filtered) or (whitelist and not filtered) then
            -- Output filtering message, if set.
            if self.db.profile.outputFiltering then
                print(("%s: %s [%s] %s"):format(ADDON_NAME, item, id, self:Color_String("ignored.", 1, 0, 0, 1)))
            end
        elseif (blacklist and not filtered) or (whitelist and filtered) then
             LootSlot(slot)
        end
    end
end

--- Removes passed item from filter.
function addon:RemoveItemFromFilter(item)
    local id = self:Item_Id(item)
    -- If no id returned, invalid item.
    if not id then
        return
    end
    if self.db.profile.filtered[id] then
        self.db.profile.filtered[id] = nil
        return true
    end
end