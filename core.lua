local ADDON_NAME = 'kLootFilter'
local _G, _ = _G, _
local table, tinsert, tremove, wipe, sort, date, time, random = table, table.insert, table.remove, wipe, sort, date, time, random
local math, tostring, string, strjoin, strlower, strsplit, strsub, strtrim, strupper, floor, tonumber = math, tostring, string, string.join, string.lower, string.split, string.sub, string.trim, string.upper, math.floor, tonumber
local select, pairs, print, next, type, unpack = select, pairs, print, next, type, unpack
local loadstring, assert, error = loadstring, assert, error
local kLootFilter = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME,
    "AceEvent-3.0",
    "kLib-1.0",
    "kLibColor-1.0",
    "kLibComm-1.0",
    "kLibItem-1.0",
    "kLibOptions-1.0",
    "kLibTimer-1.0",
    "kLibUtility-1.0",
    "kLibView-1.0")
_G.kLootFilter = kLootFilter
local self = kLootFilter

local epoch = 0 -- time of the last auto loot

local LOOT_DELAY = 0.3 -- constant interval that prevents rapid looting

local FILTER_BLACKLIST = {
    [133607] = true, -- Silver Mackerel
    [133701] = true, -- Skrog Toenail (fishing bait, attracts Murloc)
}

self.defaults = {
	profile = {
		enabled = true,
        filtered = {},
        selected_filtered_item = nil,
	},
	global = {},
}

local function GetOptions(uiType, uiName)
    local options = {
        type = "group",
        name = GetAddOnMetadata(ADDON_NAME, "Title"),
        args = {
            desc = {
                type = "description",
                order = 0,
                name = GetAddOnMetadata(ADDON_NAME, "Notes"),
            },
            enabled = {
                name = "Enabled",
                desc = ("Toggle if %s is enabled."):format(ADDON_NAME),
                type = "toggle",
                order = 1,
                get = function()
                    return self.db.profile.enabled
                end,
                set = function()
                    self.db.profile.enabled = not self.db.profile.enabled
                end,
            },
            filtered = {
                name = "Filtered Items",
                type = "group",
                args = {
                    desc = {
                        type = "description",
                        order = 0,
                        name = "List of items that are filtered (and thus ignored) when looting.",
                    },
                    input = {
                        type = "input",
                        name = "Add an Item",
                        desc = "Enter an item ID number if possible, otherwise an item name.",
                        get = function() return end,
                        set = function(self, val)
                            kLootFilter:AddItemToFilter(val)
                        end,
                    },
                    list = {
                        type = "select",
                        name = "Filtered Items",
                        values = function()
                            return self:GetFilteredList()
                        end,
                        get = function()
                            return self.db.profile.selected_filtered_item
                        end,
                        set = function(self, val)
                            kLootFilter.db.profile.selected_filtered_item = val
                        end
                    },
                },
            },
        },
    }
    return options
end

function kLootFilter:OnEnable() end

function kLootFilter:OnDisable() end

function kLootFilter:OnInitialize()
    -- Load Database
    self.db = LibStub("AceDB-3.0"):New(("%sDB"):format(ADDON_NAME), self.defaults, true)
    -- Options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, GetAddOnMetadata(ADDON_NAME, "Title"))
--    self.options = self.options or {}
--    self.options.args = self.options.args or {}
--    self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    -- TODO: Add configurable options.
    --self.config = LibStub("AceConfig-3.0"):RegisterOptionsTable("kLootFilter", self.options, { "klootfilter", "klf" })
    -- Init Events
    self:InitializeEvents()
end

--- Adds the passed item to the filter, if necessary.
function kLootFilter:AddItemToFilter(item)
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
function kLootFilter:GetFilteredList()
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
function kLootFilter:IsItemFiltered(item)
    local id = self:Item_Id(item)
    if not id then return end
    if #self.db.profile.filtered == 0 then return false end
    -- Check in blacklist.
    return self.db.profile.filtered[id] and true or false
end

--- Processes all loot filtering.
function kLootFilter:ProcessLoot()
    -- slows method calls to once a LOOT_DELAY interval since LOOT_READY event fires twice
    if (GetTime() - epoch >= LOOT_DELAY) then
        epoch = GetTime()
        if not GetCVarBool("autoLootDefault") then -- Autoloot disabled
            for slot = 1, GetNumLootItems() do
                local itemLink = GetLootSlotLink(slot)
                if itemLink then
                    local id = tonumber(self:Item_Id(itemLink))
                    if FILTER_BLACKLIST[id] then
                        print(("%s: %s [%s] %s"):format(ADDON_NAME, itemLink, id, self:Color_String("Blacklisted (Ignored)", 1, 0, 0, 1)))
                    else
                        LootSlot(slot)
                    end
                end
            end
            -- Close loot window.
            CloseLoot()
            -- Reset epoch time.
            epoch = GetTime()
        end
    end
end

--- Registers all global events to appropriate functions.
function kLootFilter:InitializeEvents()
    self:RegisterEvent('LOOT_READY', 'ProcessLoot')
end