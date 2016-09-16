local _G, _ = _G, _
local table, tinsert, tremove, wipe, sort, date, time, random = table, table.insert, table.remove, wipe, sort, date, time, random
local math, tostring, string, strjoin, strlower, strsplit, strsub, strtrim, strupper, floor, tonumber = math, tostring, string, string.join, string.lower, string.split, string.sub, string.trim, string.upper, math.floor, tonumber
local select, pairs, print, next, type, unpack = select, pairs, print, next, type, unpack
local loadstring, assert, error = loadstring, assert, error
local kLootFilter = LibStub("AceAddon-3.0"):NewAddon("kLootFilter",
    "kLib-1.0",
    "kLibColor-1.0",
    "kLibComm-1.0",
    "kLibItem-1.0",
    "kLibOptions-1.0",
    "kLibTimer-1.0",
    "kLibUtility-1.0",
    "kLibView-1.0")
_G.kLootFilter = kLootFilter

local epoch = 0 -- time of the last auto loot

local LOOT_DELAY = 0.3 -- constant interval that prevents rapid looting

local FILTER_BLACKLIST = {
    [133701] = true, -- Skrog Toenail (fishing bait, attracts Murloc)
}

function kLootFilter:OnEnable() end

function kLootFilter:OnDisable() end

function kLootFilter:OnInitialize()
    -- Load Database
    self.db = LibStub("AceDB-3.0"):New("kLootFilterDB", self.defaults)
    self.options = self.options or {}
    self.options.args = self.options.args or {}
    self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.config = LibStub("AceConfig-3.0"):RegisterOptionsTable("kLootFilter", self.options, { "klootfilter", "klf" })
    -- Init Events
    self:InitializeEvents()
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
                    print(("kLootFilter: %s [%s] %s"):format(itemLink, id, self:Color_String("Blacklisted (Ignored)", 1, 0, 0, 1)))
                else
                    LootSlot(slot)
                end
            end
        end
        -- Close loot window.
        CloseLoot()
        epoch = GetTime()
        end
    end
end

--- Registers all global events to appropriate functions.
function kLootFilter:InitializeEvents()
    self:RegisterEvent('LOOT_READY', 'ProcessLoot')
end