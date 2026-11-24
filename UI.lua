local _G = getfenv(0)

local htmlFrame = nil
local currentHtmlContent = ""

local function ModInt(a, b)
    return a - math.floor(a / b) * b
end

local function FormatShortMoney(copper)
    local c = math.floor((copper or 0) + 0.5)
    local g = math.floor(c / 10000)
    local s = math.floor(ModInt(c, 10000) / 100)
    local cop = ModInt(c, 100)
    return "|cffffd700" .. tostring(g) .. "g|r |cffc7c7cf" .. tostring(s) .. "s|r |cffeda55f" .. tostring(cop) .. "c|r"
end

function Bank2Html:CreateExportFrame()
    if htmlFrame then return htmlFrame end

    local f = CreateFrame("Frame", "Bank2HtmlFrame", UIParent)
    f:SetWidth(680)
    f:SetHeight(480)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0.06, 0.08, 0.12, 0.96)

    -- Header banner
    local headerTex = f:CreateTexture(nil, "ARTWORK")
    headerTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTex:SetWidth(320)
    headerTex:SetHeight(64)
    headerTex:SetPoint("TOP", f, "TOP", 0, 12)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", headerTex, "TOP", 0, -14)
    title:SetText("Bank2Html Export")

    -- Top-right close X button
    local closeX = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    -- Info / instructions bar
    local infoText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -34)
    infoText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -34)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("Press |cffffd700Ctrl+C|r to copy the HTML below, save it as |cff69ccf0bank.html|r, and open it in your browser.")
    f.infoText = infoText

    local summaryText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -4)
    summaryText:SetPoint("TOPRIGHT", infoText, "BOTTOMRIGHT", 0, -4)
    summaryText:SetJustifyH("LEFT")
    f.summaryText = summaryText

    -- Inner recessed container for ScrollFrame
    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -68)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 48)
    inset:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    inset:SetBackdropColor(0.03, 0.04, 0.06, 0.95)
    inset:SetBackdropBorderColor(0.35, 0.42, 0.55, 0.9)

    local scrollFrame = CreateFrame("ScrollFrame", "Bank2HtmlScrollFrame", inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "Bank2HtmlEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(9999999)
    if editBox.SetMaxBytes then
        editBox:SetMaxBytes(9999999)
    end
    editBox:SetAutoFocus(false)
    editBox:SetWidth(598)
    editBox:SetHeight(360)
    editBox:SetTextInsets(6, 6, 6, 6)
    editBox:SetFont("Fonts\\ARIALN.TTF", 12)
    editBox:SetTextColor(0.90, 0.93, 0.98, 1)

    editBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        f:Hide()
    end)

    editBox:SetScript("OnTextChanged", function()
        scrollFrame:UpdateScrollChildRect()
    end)

    -- Prevent accidental typing from overwriting the generated HTML while allowing Ctrl+C / Ctrl+A
    editBox:SetScript("OnChar", function()
        if currentHtmlContent ~= "" then
            this:SetText(currentHtmlContent)
            this:HighlightText()
        end
    end)

    scrollFrame:SetScrollChild(editBox)

    -- Clicking anywhere in the scroll area focuses and highlights the HTML for instant copying
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local sb = _G["Bank2HtmlScrollFrameScrollBar"]
        if sb then
            local step = 36
            local cur = sb:GetValue() or 0
            local minVal, maxVal = sb:GetMinMaxValues()
            local target = (arg1 and arg1 > 0) and (cur - step) or (cur + step)
            if minVal and target < minVal then target = minVal end
            if maxVal and target > maxVal then target = maxVal end
            sb:SetValue(target)
        end
    end)

    -- Bottom action buttons
    local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectBtn:SetWidth(130)
    selectBtn:SetHeight(24)
    selectBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetWidth(130)
    refreshBtn:SetHeight(24)
    refreshBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)
    refreshBtn:SetText("Refresh HTML")
    refreshBtn:SetScript("OnClick", function()
        Bank2Html:ShowExportFrame()
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(100)
    closeBtn:SetHeight(24)
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    f.editBox = editBox
    f.scrollFrame = scrollFrame

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "Bank2HtmlFrame")
    end

    f:Hide()
    htmlFrame = f
    return f
end

function Bank2Html:ShowExportFrame()
    local f = self:CreateExportFrame()
    local html, totalNetWorth, charCount = self:GenerateHTML()
    currentHtmlContent = html

    f.summaryText:SetText(
        "Characters Tracked: |cffffffff" .. tostring(charCount) .. "|r   " ..
        "Account Net Worth: " .. FormatShortMoney(totalNetWorth) .. "   " ..
        "HTML Size: |cff94a3b8" .. tostring(string.len(html)) .. " chars|r"
    )

    f:Show()
    local sb = _G["Bank2HtmlScrollFrameScrollBar"]
    if sb then
        sb:SetValue(0)
    end
    f.editBox:SetText(html)
    f.scrollFrame:UpdateScrollChildRect()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

-----------------------------------------
-- Slash Commands: /bank2html and /b2h --
-----------------------------------------

SLASH_BANK2HTML1 = "/bank2html"
SLASH_BANK2HTML2 = "/b2h"

SlashCmdList["BANK2HTML"] = function(msg)
    local raw = msg or ""
    local _, _, cmd, rest = string.find(raw, "^%s*(%S+)%s*(.-)%s*$")
    cmd = cmd and string.lower(cmd) or ""

    if cmd == "scan" then
        if Bank2Html.bankIsOpen and BankFrame and BankFrame:IsVisible() then
            Bank2Html:ScanBankAndInventory(true)
        else
            local rec = Bank2Html:ScanInventory()
            if rec then
                Bank2Html:Print("Scanned current inventory and gold for " .. rec.name .. " (" .. table.getn(rec.bags) .. " bag item types). Open your bank to scan bank slots.")
            end
        end
    elseif cmd == "delete" and rest and rest ~= "" then
        Bank2Html:EnsureDB()
        local target = string.lower(rest)
        local removed = 0
        for k, rec in pairs(Bank2HtmlDB.characters) do
            if type(rec) == "table" and rec.name and string.lower(rec.name) == target then
                Bank2HtmlDB.characters[k] = nil
                removed = removed + 1
            end
        end
        if removed > 0 then
            Bank2Html:Print("Removed " .. tostring(removed) .. " character record(s) matching '" .. rest .. "'.")
        else
            Bank2Html:Print("No saved character found matching '" .. rest .. "'.")
        end
    elseif cmd == "reset" then
        Bank2HtmlDB = { version = 1, characters = {} }
        Bank2Html:ScanInventory()
        Bank2Html:Print("Reset all saved character data and re-scanned current character's inventory.")
    elseif cmd == "help" then
        Bank2Html:Print("Commands:")
        Bank2Html:Print("  /bank2html - Generate and display the account-wide HTML report")
        Bank2Html:Print("  /bank2html scan - Force scan bags (and bank if currently open)")
        Bank2Html:Print("  /bank2html delete <name> - Remove a character from saved data")
        Bank2Html:Print("  /bank2html reset - Clear all saved character data")
    else
        Bank2Html:ShowExportFrame()
    end
end
