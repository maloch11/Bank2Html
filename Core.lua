local _G = getfenv(0)

Bank2Html = Bank2Html or {}
Bank2Html.VERSION = "1.0.0"

-- Items priced per charge in Aux (matches aux.util.info.max_item_charges)
local MAX_ITEM_CHARGES = {
    [20744] = 5,  -- Minor Wizard Oil
    [20746] = 5,  -- Lesser Wizard Oil
    [20750] = 5,  -- Wizard Oil
    [20749] = 5,  -- Brilliant Wizard Oil
    [20745] = 5,  -- Minor Mana Oil
    [20747] = 5,  -- Lesser Mana Oil
    [20748] = 5,  -- Brilliant Mana Oil
    [4388]  = 5,  -- Discombobulator Ray
    [4381]  = 10, -- Minor Recombobulator
    [18637] = 10, -- Major Recombobulator
    [4376]  = 5,  -- Flame Deflector
    [4386]  = 5,  -- Ice Deflector
}

local COLOR_TO_QUALITY = {
    ["ff9d9d9d"] = 0, -- Poor
    ["ffffffff"] = 1, -- Common
    ["ff1eff00"] = 2, -- Uncommon
    ["ff0070dd"] = 3, -- Rare
    ["ffa335ee"] = 4, -- Epic
    ["ffff8000"] = 5, -- Legendary
    ["ffe6cc80"] = 6, -- Artifact
}

function Bank2Html:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[Bank2Html]|r " .. tostring(msg or ""))
    end
end

-- Build Charge regex from WoW's localized ITEM_SPELL_CHARGES_P1 if present
local chargesPattern = nil
if ITEM_SPELL_CHARGES_P1 then
    local pat = string.gsub(ITEM_SPELL_CHARGES_P1, "%%d", "(%%d+)")
    pat = string.gsub(pat, "%%%d+%$d", "(%%d+)")
    chargesPattern = "^" .. pat .. "$"
end

-- Hidden tooltip used strictly for soulbound/quest/conjured and charge detection
local scanTooltip = CreateFrame("GameTooltip", "Bank2HtmlScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

function Bank2Html:EnsureDB()
    if type(Bank2HtmlDB) ~= "table" then
        Bank2HtmlDB = {}
    end
    if type(Bank2HtmlDB.characters) ~= "table" then
        Bank2HtmlDB.characters = {}
    end
    Bank2HtmlDB.version = 1
end

function Bank2Html:GetRealmName()
    if GetRealmName then
        local r = GetRealmName()
        if r and r ~= "" then return r end
    end
    if GetCVar then
        local r = GetCVar("realmName")
        if r and r ~= "" then return r end
    end
    return "Unknown Realm"
end

function Bank2Html:GetCharacterKey()
    local name = UnitName("player")
    if not name or name == "" or name == UNKNOWNOBJECT then
        return nil
    end
    local realm = self:GetRealmName()
    return realm .. ":" .. name, realm, name
end

function Bank2Html:GetOrCreateCurrentChar()
    self:EnsureDB()
    local key, realm, name = self:GetCharacterKey()
    if not key then return nil end

    local rec = Bank2HtmlDB.characters[key]
    if type(rec) ~= "table" then
        rec = {
            name = name,
            realm = realm,
            bags = {},
            bank = {},
            bankScanned = false,
        }
        Bank2HtmlDB.characters[key] = rec
    end

    local localizedClass, englishClass = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local level = UnitLevel("player")

    rec.name = name
    rec.realm = realm
    rec.class = englishClass or rec.class or "UNKNOWN"
    rec.classLocalized = localizedClass or rec.classLocalized or "Unknown"
    rec.faction = faction or rec.faction or "Neutral"
    if level and level > 0 then
        rec.level = level
    end
    rec.money = GetMoney() or rec.money or 0

    return rec
end

function Bank2Html:ParseItemLink(link)
    if not link then return nil end
    local _, _, colorHex = string.find(link, "|c(%x%x%x%x%x%x%x%x)")
    local _, _, itemIdStr, enchantIdStr, suffixIdStr, uniqueIdStr, name =
        string.find(link, "|Hitem:(%d*):(%d*):(%d*):(%d*)[:%-0-9]*|h%[(.-)%]|h")
    if not itemIdStr or itemIdStr == "" then
        return nil
    end
    local itemId = tonumber(itemIdStr)
    if not itemId then return nil end
    local suffixId = tonumber(suffixIdStr) or 0
    local enchantId = tonumber(enchantIdStr) or 0
    local uniqueId = tonumber(uniqueIdStr) or 0
    local linkQuality = colorHex and COLOR_TO_QUALITY[string.lower(colorHex)] or nil
    return itemId, suffixId, enchantId, uniqueId, name, linkQuality
end

function Bank2Html:InspectSlotTooltip(bag, slot, maxCharges)
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()

    if bag == BANK_CONTAINER then
        if BankButtonIDToInvSlotID then
            local invSlot = BankButtonIDToInvSlotID(slot)
            if invSlot then
                scanTooltip:SetInventoryItem("player", invSlot)
            end
        end
    elseif KEYRING_CONTAINER and bag == KEYRING_CONTAINER and KeyRingButtonIDToInvSlotID then
        local invSlot = KeyRingButtonIDToInvSlotID(slot)
        if invSlot then
            scanTooltip:SetInventoryItem("player", invSlot)
        end
    else
        scanTooltip:SetBagItem(bag, slot)
    end

    local isBound = false
    local charges = nil
    local numLines = scanTooltip:NumLines() or 0

    for i = 1, numLines do
        local leftFont = _G["Bank2HtmlScanTooltipTextLeft" .. i]
        local rightFont = _G["Bank2HtmlScanTooltipTextRight" .. i]
        local leftText = leftFont and leftFont:GetText() or nil
        local rightText = (rightFont and rightFont:IsVisible()) and rightFont:GetText() or nil

        if leftText then
            if leftText == ITEM_SOULBOUND
                or leftText == ITEM_BIND_ON_PICKUP
                or leftText == ITEM_BIND_QUEST
                or (ITEM_CONJURED and string.find(leftText, ITEM_CONJURED, 1, true)) then
                isBound = true
            end
            if maxCharges and chargesPattern and not charges then
                local _, _, cStr = string.find(leftText, chargesPattern)
                if cStr then
                    charges = tonumber(cStr)
                end
            end
        end

        if rightText and maxCharges and chargesPattern and not charges then
            local _, _, cStr = string.find(rightText, chargesPattern)
            if cStr then
                charges = tonumber(cStr)
            end
        end
    end

    if maxCharges then
        if not charges or charges < 1 then
            charges = maxCharges
        end
    end

    return isBound, charges
end

-------------------------------------------
-- Aux and ShaguTweaks Price Integration --
-------------------------------------------

local function SplitString(str, sep)
    local out = {}
    if not str or str == "" then return out end
    local startIdx = 1
    local sepLen = string.len(sep)
    while true do
        local pos = string.find(str, sep, startIdx, true)
        if not pos then
            table.insert(out, string.sub(str, startIdx))
            break
        end
        table.insert(out, string.sub(str, startIdx, pos - 1))
        startIdx = pos + sepLen
    end
    return out
end

local function RoundNumber(v)
    if v >= 0 then
        return math.floor(v + 0.5)
    else
        return math.ceil(v - 0.5)
    end
end

-- Fallback reader for Aux SavedVariables (_G.aux.faction[factionKey].history[itemKey])
-- Used when querying alts on another realm/faction or if aux.core.history isn't active for that faction
function Bank2Html:ReadRawAuxHistory(itemKey, realm, faction)
    if type(_G.aux) ~= "table" or type(_G.aux.faction) ~= "table" then
        return nil, nil
    end
    local r = realm or self:GetRealmName()
    local f = faction or UnitFactionGroup("player") or "Alliance"
    if r == "Nordanaar" then
        f = "Horde"
    end
    local fKey = r .. "|" .. f
    local facTable = _G.aux.faction[fKey]
    if type(facTable) ~= "table" or type(facTable.history) ~= "table" then
        return nil, nil
    end

    local raw = facTable.history[itemKey]
    if type(raw) ~= "string" or raw == "" then
        return nil, nil
    end

    -- Schema: next_push#daily_min_buyout#val@time;val@time...
    local parts = SplitString(raw, "#")
    local dailyMin = tonumber(parts[2] or "")
    local dpStr = parts[3] or ""

    local dataPoints = {}
    if dpStr ~= "" then
        local entries = SplitString(dpStr, ";")
        for i = 1, table.getn(entries) do
            local pair = SplitString(entries[i], "@")
            local val = tonumber(pair[1] or "")
            local tm = tonumber(pair[2] or "")
            if val and tm then
                table.insert(dataPoints, { value = val, time = tm })
            end
        end
    end

    local histValue = nil
    local nPoints = table.getn(dataPoints)
    if nPoints > 0 then
        local refTime = dataPoints[1].time
        local totalWeight = 0
        local weighted = {}
        for i = 1, nPoints do
            local dp = dataPoints[i]
            local days = RoundNumber((refTime - dp.time) / 86400)
            local w = 0.99 ^ days
            totalWeight = totalWeight + w
            table.insert(weighted, { value = dp.value, weight = w })
        end
        if totalWeight > 0 then
            table.sort(weighted, function(a, b) return a.value < b.value end)
            local acc = 0
            for i = 1, table.getn(weighted) do
                acc = acc + (weighted[i].weight / totalWeight)
                if acc >= 0.5 then
                    histValue = weighted[i].value
                    break
                end
            end
        end
    else
        histValue = dailyMin
    end

    return dailyMin, histValue
end

function Bank2Html:GetAuxAuctionUnitPrice(itemKey, realm, faction)
    if not itemKey then return nil, nil, nil end

    local curRealm = self:GetRealmName()
    local curFaction = UnitFactionGroup("player")
    local sameAuxPool = (not realm or realm == curRealm)
        and (curRealm == "Nordanaar" or not faction or faction == curFaction)

    local todayBuyout, histValue = nil, nil

    if sameAuxPool and type(_G.require) == "function" and type(_G.aux) == "table" then
        local ok, historyMod = pcall(_G.require, "aux.core.history")
        if ok and type(historyMod) == "table" then
            if type(historyMod.market_value) == "function" then
                local okM, mv = pcall(historyMod.market_value, itemKey)
                if okM and type(mv) == "number" and mv > 0 then
                    todayBuyout = mv
                end
            end
            if type(historyMod.value) == "function" then
                local okV, hv = pcall(historyMod.value, itemKey)
                if okV and type(hv) == "number" and hv > 0 then
                    histValue = hv
                end
            end
        end
    end

    if not todayBuyout and not histValue then
        local rawDaily, rawHist = self:ReadRawAuxHistory(itemKey, realm, faction)
        if rawDaily and rawDaily > 0 then todayBuyout = rawDaily end
        if rawHist and rawHist > 0 then histValue = rawHist end
    end

    local effectiveAh = todayBuyout or histValue
    if effectiveAh and effectiveAh > 0 then
        return RoundNumber(effectiveAh), todayBuyout, histValue
    end
    return nil, nil, nil
end

function Bank2Html:GetVendorUnitPrice(itemId)
    if not itemId then return nil, nil end
    local maxCharges = MAX_ITEM_CHARGES[itemId]

    -- 1. Primary: ShaguTweaks.SellValueDB
    if type(_G.ShaguTweaks) == "table" and type(_G.ShaguTweaks.SellValueDB) == "table" then
        local stVal = _G.ShaguTweaks.SellValueDB[itemId]
        if type(stVal) == "number" and stVal > 0 then
            if maxCharges and maxCharges > 1 then
                stVal = stVal / maxCharges
            end
            return RoundNumber(stVal), "ShaguTweaks"
        end
    end

    -- 2. Secondary fallback: Aux merchant_sell cache (if item not in ShaguTweaks DB)
    if type(_G.aux) == "table" and type(_G.aux.account) == "table" and type(_G.aux.account.merchant_sell) == "table" then
        local auxSell = _G.aux.account.merchant_sell[itemId]
        if type(auxSell) == "number" and auxSell > 0 then
            return RoundNumber(auxSell), "AuxVendor"
        end
    end

    return nil, nil
end

-- Resolves final unit and stack pricing and badge metadata for an item entry
function Bank2Html:ResolveItemPrice(entry, realm, faction)
    local qty = entry.auxQty or entry.count or 1
    if qty < 1 then qty = 1 end

    local ahUnit, ahToday, ahHist = nil, nil, nil
    if not entry.bound then
        ahUnit, ahToday, ahHist = self:GetAuxAuctionUnitPrice(entry.itemKey, realm, faction)
        if not ahUnit and entry.cachedAhUnit and entry.cachedAhUnit > 0 then
            ahUnit = entry.cachedAhUnit
        end
    end

    local vendorUnit, vendorSource = self:GetVendorUnitPrice(entry.itemId)
    if not vendorUnit and entry.cachedVendorUnit and entry.cachedVendorUnit > 0 then
        vendorUnit = entry.cachedVendorUnit
        vendorSource = entry.cachedVendorSrc or "ShaguTweaks"
    end

    local chosenUnit = 0
    local sourceType = "None"
    local badgeLabel = "No Price"

    if not entry.bound and ahUnit and ahUnit > 0 and (not vendorUnit or ahUnit >= vendorUnit) then
        chosenUnit = ahUnit
        sourceType = "AuxAH"
        badgeLabel = "Auction"
    elseif vendorUnit and vendorUnit > 0 then
        chosenUnit = vendorUnit
        if vendorSource == "AuxVendor" then
            sourceType = "AuxVendor"
            badgeLabel = "Vendor"
        else
            sourceType = "ShaguVendor"
            badgeLabel = "Vendor"
        end
    end

    local totalPrice = RoundNumber(chosenUnit * qty)
    local displayCount = entry.count or 1
    local displayUnit = displayCount > 0 and RoundNumber(totalPrice / displayCount) or chosenUnit

    return {
        unitPrice = displayUnit,
        totalPrice = totalPrice,
        sourceType = sourceType,
        badgeLabel = badgeLabel,
        ahUnit = ahUnit,
        ahToday = ahToday,
        ahHist = ahHist,
        vendorUnit = vendorUnit,
        vendorSource = vendorSource,
    }
end

------------------------
-- Container Scanning --
------------------------

function Bank2Html:ScanContainerList(containerIds)
    local byKey = {}
    local list = {}

    local charRec = self:GetOrCreateCurrentChar()
    local realm = charRec and charRec.realm or self:GetRealmName()
    local faction = charRec and charRec.faction or UnitFactionGroup("player")

    for i = 1, table.getn(containerIds) do
        local bag = containerIds[i]
        local numSlots = GetContainerNumSlots(bag) or 0
        if bag == BANK_CONTAINER and numSlots == 0 and NUM_BANKGENERIC_SLOTS then
            numSlots = NUM_BANKGENERIC_SLOTS
        end

        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId, suffixId, enchantId, uniqueId, linkName, linkQuality = self:ParseItemLink(link)
                if itemId then
                    local slotTexture, slotCount, _, slotQuality = GetContainerItemInfo(bag, slot)
                    local count = slotCount or 1
                    if count < 1 then count = 1 end

                    local itemString = "item:" .. itemId .. ":" .. enchantId .. ":" .. suffixId .. ":" .. uniqueId
                    local infoName, _, infoQuality, _, itemType, itemSubType, _, _, infoTexture = GetItemInfo(itemString)
                    if not infoName then
                        infoName, _, infoQuality, _, itemType, itemSubType, _, _, infoTexture = GetItemInfo("item:" .. itemId .. ":0:0:0")
                    end

                    local name = linkName or infoName or ("Item #" .. tostring(itemId))
                    local quality = infoQuality
                    if quality == nil or quality < 0 then
                        if linkQuality ~= nil then
                            quality = linkQuality
                        elseif slotQuality and slotQuality >= 0 then
                            quality = slotQuality
                        else
                            quality = 1
                        end
                    end

                    local maxCharges = MAX_ITEM_CHARGES[itemId]
                    local isBound, charges = self:InspectSlotTooltip(bag, slot, maxCharges)
                    local auxQty = charges or count

                    local itemKey = tostring(itemId) .. ":" .. tostring(suffixId or 0)
                    local groupKey = itemKey .. ":" .. (isBound and "1" or "0")

                    local existing = byKey[groupKey]
                    if existing then
                        existing.count = existing.count + count
                        existing.auxQty = existing.auxQty + auxQty
                        existing.stacks = existing.stacks + 1
                    else
                        local ahUnit = nil
                        if not isBound then
                            ahUnit = self:GetAuxAuctionUnitPrice(itemKey, realm, faction)
                        end
                        local vendorUnit, vendorSrc = self:GetVendorUnitPrice(itemId)

                        local entry = {
                            itemId = itemId,
                            suffixId = suffixId or 0,
                            itemKey = itemKey,
                            name = name,
                            quality = quality,
                            itemType = itemType or "",
                            itemSubType = itemSubType or "",
                            texture = infoTexture or slotTexture or "",
                            bound = isBound and true or false,
                            count = count,
                            auxQty = auxQty,
                            stacks = 1,
                            cachedAhUnit = ahUnit,
                            cachedVendorUnit = vendorUnit,
                            cachedVendorSrc = vendorSrc,
                        }
                        byKey[groupKey] = entry
                        table.insert(list, entry)
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b)
        if (a.quality or 0) ~= (b.quality or 0) then
            return (a.quality or 0) > (b.quality or 0)
        end
        return (a.name or "") < (b.name or "")
    end)

    return list
end

function Bank2Html:ScanInventory()
    local charRec = self:GetOrCreateCurrentChar()
    if not charRec then return nil end

    local bagIds = { 0 }
    local maxBags = NUM_BAG_SLOTS or 4
    for bag = 1, maxBags do
        table.insert(bagIds, bag)
    end
    if KEYRING_CONTAINER and GetContainerNumSlots(KEYRING_CONTAINER) and GetContainerNumSlots(KEYRING_CONTAINER) > 0 then
        table.insert(bagIds, KEYRING_CONTAINER)
    end

    charRec.bags = self:ScanContainerList(bagIds)
    charRec.money = GetMoney() or charRec.money or 0
    charRec.lastBagScan = time()
    return charRec
end

function Bank2Html:ScanBankAndInventory()
    local charRec = self:ScanInventory()
    if not charRec then return nil end

    local bankIds = { BANK_CONTAINER or -1 }
    local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
    local lastBankBag = (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6)
    for bag = firstBankBag, lastBankBag do
        table.insert(bankIds, bag)
    end

    charRec.bank = self:ScanContainerList(bankIds)
    charRec.bankScanned = true
    charRec.lastBankScan = time()
    charRec.money = GetMoney() or charRec.money or 0

    return charRec
end

--------------------
-- Event Handling --
--------------------

local eventFrame = CreateFrame("Frame", "Bank2HtmlEventFrame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")

local scanTimer = 0

eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        Bank2Html:EnsureDB()
    elseif event == "BANKFRAME_OPENED" then
        Bank2Html:ScanBankAndInventory()
    end
end)