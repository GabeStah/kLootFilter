local frame = CreateFrame("Frame")
local epoch = 0 -- time of the last auto loot

local LOOT_DELAY = 0.3 -- constant interval that prevents rapid looting

local FILTER_BLACKLIST = {
  [133701] = true, -- Skrog Toenail (fishing bait, attracts Murloc)
}

-- loots items if auto loot is turned on xor toggle key is pressed
local function FilterLoot()
  -- slows method calls to once a LOOT_DELAY interval since LOOT_READY event fires twice
  if (GetTime() - epoch >= LOOT_DELAY) then
    epoch = GetTime()
    
    if not GetCVarBool("autoLootDefault") then -- Autoloot disabled
      for slot = 1, GetNumLootItems() do
        local itemLink = GetLootSlotLink(slot)
        if itemLink then
          local id = tonumber(kMiscellaneous:Item_Id(itemLink))
          if FILTER_BLACKLIST[id] then
            print(("kLootFilter: %s [%s] %s"):format(itemLink, id, kMiscellaneous:Color_String("Blacklisted (Ignored)", 1, 0, 0, 1)))
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

-- triggering events and actions to fire
frame:RegisterEvent("LOOT_READY")
frame:SetScript("OnEvent", FilterLoot)