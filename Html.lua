local CLASS_COLORS = {
    WARRIOR = "#C79C6E",
    PALADIN = "#F58CBA",
    HUNTER  = "#ABD473",
    ROGUE   = "#FFF569",
    PRIEST  = "#FFFFFF",
    SHAMAN  = "#0070DE",
    MAGE    = "#69CCF0",
    WARLOCK = "#9482C9",
    DRUID   = "#FF7D0A",
}

local QUALITY_CLASS = {
    [0] = "q0",
    [1] = "q1",
    [2] = "q2",
    [3] = "q3",
    [4] = "q4",
    [5] = "q5",
    [6] = "q6",
}

local function EscapeHtml(str)
    if str == nil then return "" end
    local s = tostring(str)
    s = string.gsub(s, "&", "&amp;")
    s = string.gsub(s, "<", "&lt;")
    s = string.gsub(s, ">", "&gt;")
    s = string.gsub(s, "\"", "&quot;")
    s = string.gsub(s, "'", "&#39;")
    -- Replace pipe with HTML entity so WoW 1.12 EditBox never interprets |c / |H / || escapes
    s = string.gsub(s, "|", "&#124;")
    return s
end

local function FormatTimestamp(ts)
    if not ts or ts <= 0 then
        return "Never"
    end
    return EscapeHtml(date("%Y-%m-%d %H:%M", ts))
end

local function ModInt(a, b)
    return a - math.floor(a / b) * b
end

local function SplitCopper(copper)
    local c = math.floor((copper or 0) + 0.5)
    if c < 0 then c = 0 end
    local gold = math.floor(c / 10000)
    local rem = ModInt(c, 10000)
    local silver = math.floor(rem / 100)
    local cop = ModInt(rem, 100)
    return gold, silver, cop
end

-- Formats integer with thousands commas (Lua 5.0 compatible)
local function FormatInt(n)
    local s = tostring(math.floor(n or 0))
    local len = string.len(s)
    if len <= 3 then return s end
    local out = ""
    local count = 0
    for i = len, 1, -1 do
        out = string.sub(s, i, i) .. out
        count = count + 1
        if ModInt(count, 3) == 0 and i > 1 then
            out = "," .. out
        end
    end
    return out
end

local function FormatMoneyHtml(copper, showZero)
    local c = math.floor((copper or 0) + 0.5)
    if c <= 0 then
        if showZero then
            return "<span class=\"m-zero\">0<span class=\"c\">c</span></span>"
        end
        return "<span class=\"m-na\">&mdash;</span>"
    end
    local g, s, cop = SplitCopper(c)
    local parts = {}
    if g > 0 then
        table.insert(parts, "<span class=\"g\">" .. FormatInt(g) .. "g</span>")
    end
    if s > 0 or g > 0 then
        local sStr = (g > 0 and s < 10) and ("0" .. tostring(s)) or tostring(s)
        table.insert(parts, "<span class=\"s\">" .. sStr .. "s</span>")
    end
    local cStr = ((g > 0 or s > 0) and cop < 10) and ("0" .. tostring(cop)) or tostring(cop)
    table.insert(parts, "<span class=\"c\">" .. cStr .. "c</span>")
    return "<span class=\"money\">" .. table.concat(parts, " ") .. "</span>"
end

local function FormatMoneyPlain(copper)
    local c = math.floor((copper or 0) + 0.5)
    if c <= 0 then return "0c" end
    local g, s, cop = SplitCopper(c)
    local parts = {}
    if g > 0 then table.insert(parts, FormatInt(g) .. "g") end
    if s > 0 or g > 0 then table.insert(parts, tostring(s) .. "s") end
    table.insert(parts, tostring(cop) .. "c")
    return table.concat(parts, " ")
end

local function BadgeHtml(priceInfo)
    local src = priceInfo.sourceType
    local cls = "bdg bdg-none"
    if src == "AuxAH" then
        cls = "bdg bdg-ah"
    elseif src == "ShaguVendor" then
        cls = "bdg bdg-st"
    elseif src == "AuxVendor" then
        cls = "bdg bdg-av"
    end
    return "<span class=\"" .. cls .. "\">" .. EscapeHtml(priceInfo.badgeLabel) .. "</span>"
end

local function BuildPriceTooltip(entry, priceInfo)
    local tips = {}
    local count = entry.count or 1
    if count > 1 and priceInfo.unitPrice and priceInfo.unitPrice > 0 then
        table.insert(tips, "Unit: " .. FormatMoneyPlain(priceInfo.unitPrice) .. " each")
    end
    if entry.bound then
        table.insert(tips, "Soulbound (cannot auction)")
    elseif priceInfo.ahUnit and priceInfo.ahUnit > 0 then
        local ahDesc = "Aux AH: " .. FormatMoneyPlain(priceInfo.ahUnit) .. " ea"
        if priceInfo.ahToday and priceInfo.ahHist and priceInfo.ahToday ~= priceInfo.ahHist then
            ahDesc = ahDesc .. " (Today: " .. FormatMoneyPlain(priceInfo.ahToday) .. ", Hist: " .. FormatMoneyPlain(priceInfo.ahHist) .. ")"
        end
        table.insert(tips, ahDesc)
    else
        table.insert(tips, "Aux AH: No auction data")
    end
    if priceInfo.vendorUnit and priceInfo.vendorUnit > 0 then
        local vName = (priceInfo.vendorSource == "AuxVendor") and "Aux Vendor" or "ShaguTweaks Vendor"
        table.insert(tips, vName .. ": " .. FormatMoneyPlain(priceInfo.vendorUnit) .. " ea")
    else
        table.insert(tips, "Vendor: No sell value")
    end
    return EscapeHtml(table.concat(tips, " / "))
end

local function RenderSectionRows(buf, items, locLabel, locCode, realm, faction)
    local sectionTotal = 0
    local sectionAhTotal = 0
    local sectionVendorTotal = 0
    local nItems = table.getn(items or {})

    for i = 1, nItems do
        local entry = items[i]
        local p = Bank2Html:ResolveItemPrice(entry, realm, faction)
        sectionTotal = sectionTotal + p.totalPrice
        if p.sourceType == "AuxAH" then
            sectionAhTotal = sectionAhTotal + p.totalPrice
        elseif p.sourceType == "ShaguVendor" or p.sourceType == "AuxVendor" then
            sectionVendorTotal = sectionVendorTotal + p.totalPrice
        end

        local qCls = QUALITY_CLASS[entry.quality or 1] or "q1"
        local count = entry.count or 1
        local stacksNote = ""
        if (entry.stacks or 1) > 1 then
            stacksNote = " <span class=\"stk\">(" .. tostring(entry.stacks) .. " stacks)</span>"
        end
        local boundTag = entry.bound and " <span class=\"sb\">Soulbound</span>" or ""
        local unitNote = ""
        if count > 1 and p.unitPrice > 0 then
            unitNote = "<span class=\"unit\">" .. FormatMoneyPlain(p.unitPrice) .. " ea</span>"
        end

        local tip = BuildPriceTooltip(entry, p)
        local searchName = EscapeHtml(string.lower(entry.name or ""))

        table.insert(buf,
            "<tr class=\"it-row\" data-name=\"" .. searchName .. "\" data-src=\"" .. p.sourceType .. "\" data-loc=\"" .. locCode .. "\" data-val=\"" .. tostring(p.totalPrice) .. "\">" ..
            "<td class=\"col-loc\"><span class=\"loc loc-" .. locCode .. "\">" .. locLabel .. "</span></td>" ..
            "<td class=\"col-qty\">" .. tostring(count) .. "</td>" ..
            "<td class=\"col-item\"><span class=\"iname " .. qCls .. "\">[" .. EscapeHtml(entry.name) .. "]</span>" .. boundTag .. stacksNote .. "</td>" ..
            "<td class=\"col-price\" title=\"" .. tip .. "\">" .. unitNote .. FormatMoneyHtml(p.totalPrice, false) .. " " .. BadgeHtml(p) .. "</td>" ..
            "</tr>"
        )
    end

    return sectionTotal, sectionAhTotal, sectionVendorTotal, nItems
end

function Bank2Html:GenerateHTML()
    self:EnsureDB()
    -- Refresh current logged-in character's inventory and gold before generating
    if self.bankIsOpen and BankFrame and BankFrame:IsVisible() then
        self:ScanBankAndInventory(false)
    else
        self:ScanInventory()
    end

    local charRecords = {}
    for _, rec in pairs(Bank2HtmlDB.characters) do
        if type(rec) == "table" and rec.name then
            table.insert(charRecords, rec)
        end
    end

    -- Pre-compute per-character totals and account grand totals
    local accountGold = 0
    local accountBankVal = 0
    local accountBagVal = 0
    local accountAhVal = 0
    local accountVendorVal = 0
    local accountItemStacks = 0
    local charSummaries = {}

    for i = 1, table.getn(charRecords) do
        local rec = charRecords[i]
        local rowBuf = {}

        local bankTotal, bankAh, bankVendor, bankRows = 0, 0, 0, 0
        if rec.bankScanned and type(rec.bank) == "table" then
            bankTotal, bankAh, bankVendor, bankRows = RenderSectionRows(rowBuf, rec.bank, "Bank", "bank", rec.realm, rec.faction)
        end

        local bagTotal, bagAh, bagVendor, bagRows = 0, 0, 0, 0
        if type(rec.bags) == "table" then
            bagTotal, bagAh, bagVendor, bagRows = RenderSectionRows(rowBuf, rec.bags, "Bag", "bag", rec.realm, rec.faction)
        end

        local rawGold = rec.money or 0
        local itemsVal = bankTotal + bagTotal
        local netWorth = rawGold + itemsVal

        accountGold = accountGold + rawGold
        accountBankVal = accountBankVal + bankTotal
        accountBagVal = accountBagVal + bagTotal
        accountAhVal = accountAhVal + bankAh + bagAh
        accountVendorVal = accountVendorVal + bankVendor + bagVendor
        accountItemStacks = accountItemStacks + bankRows + bagRows

        table.insert(charSummaries, {
            rec = rec,
            rowsHtml = table.concat(rowBuf, "\n"),
            rowCount = bankRows + bagRows,
            bankRows = bankRows,
            bagRows = bagRows,
            rawGold = rawGold,
            bankTotal = bankTotal,
            bagTotal = bagTotal,
            itemsVal = itemsVal,
            ahVal = bankAh + bagAh,
            vendorVal = bankVendor + bagVendor,
            netWorth = netWorth,
        })
    end

    table.sort(charSummaries, function(a, b)
        if a.netWorth ~= b.netWorth then
            return a.netWorth > b.netWorth
        end
        return (a.rec.name or "") < (b.rec.name or "")
    end)

    local accountNetWorth = accountGold + accountBankVal + accountBagVal
    local generatedAt = EscapeHtml(date("%Y-%m-%d %H:%M:%S"))
    local auxActive = (type(_G.aux) == "table") and "Connected" or "Saved Cache"
    local stActive = (type(_G.ShaguTweaks) == "table" and type(_G.ShaguTweaks.SellValueDB) == "table") and "Connected" or "Saved Cache"

    local out = {}
    table.insert(out, "<!DOCTYPE html>")
    table.insert(out, "<html lang=\"en\">")
    table.insert(out, "<head>")
    table.insert(out, "<meta charset=\"utf-8\">")
    table.insert(out, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
    table.insert(out, "<title>Bank2Html - Account Inventory &amp; Net Worth</title>")
    table.insert(out, "<style>")
    table.insert(out, [[
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0b0e14;color:#e5e9f0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;line-height:1.5;padding:28px 18px 60px}
.wrap{max-width:1180px;margin:0 auto}
.hero{background:linear-gradient(135deg,#151b26 0%,#101520 60%,#1b1610 100%);border:1px solid #2c3548;border-radius:14px;padding:24px 28px;margin-bottom:22px;box-shadow:0 12px 32px rgba(0,0,0,.45)}
.hero-top{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:20px;border-bottom:1px solid #232b3a;padding-bottom:18px}
.title{font-size:1.65rem;font-weight:800;letter-spacing:.3px;color:#f8d568}
.subtitle{font-size:.86rem;color:#94a3b8;margin-top:4px}
.acct-nw-box{text-align:right;background:#0d1119;border:1px solid #3d3319;border-radius:10px;padding:12px 18px}
.acct-nw-lbl{font-size:.74rem;text-transform:uppercase;letter-spacing:1.1px;color:#eab308;font-weight:700}
.acct-nw-val{font-size:1.6rem;font-weight:800;margin-top:2px}
.kpi-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px}
.kpi{background:#0f141d;border:1px solid #222a38;border-radius:10px;padding:12px 15px}
.kpi-lbl{font-size:.73rem;text-transform:uppercase;letter-spacing:.8px;color:#8a99ad;margin-bottom:4px}
.kpi-val{font-size:1.08rem;font-weight:700}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;background:#121722;border:1px solid #242d3d;border-radius:11px;padding:12px 16px;margin-bottom:22px}
.search{background:#0a0d13;border:1px solid #2f3b52;color:#f1f5f9;padding:8px 13px;border-radius:8px;min-width:250px;font-size:.9rem;outline:none}
.search:focus{border-color:#eab308}
.filters{display:flex;flex-wrap:wrap;gap:6px}
.fbtn{background:#182030;border:1px solid #2c3850;color:#cbd5e1;padding:6px 12px;border-radius:7px;font-size:.8rem;font-weight:600;cursor:pointer}
.fbtn:hover,.fbtn.active{background:#29354d;border-color:#f8d568;color:#f8d568}
.char-nav{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:20px}
.cjump{text-decoration:none;background:#131924;border:1px solid #253044;padding:6px 12px;border-radius:8px;font-size:.83rem;color:#e2e8f0;font-weight:600}
.cjump:hover{border-color:#64748b;background:#1a2232}
.card{background:#121722;border:1px solid #252f42;border-radius:13px;margin-bottom:22px;overflow:hidden;box-shadow:0 6px 20px rgba(0,0,0,.32)}
.card-hd{background:#171e2c;padding:16px 20px;border-bottom:1px solid #242e42;display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;gap:14px}
.cname{font-size:1.28rem;font-weight:800}
.cmeta{font-size:.82rem;color:#94a3b8;margin-top:2px}
.cstats{display:flex;flex-wrap:wrap;gap:14px;align-items:center}
.cstat{background:#0e131c;border:1px solid #222c3f;border-radius:8px;padding:7px 12px;text-align:right}
.cstat-nw{border-color:#4b3f1c;background:#14130e}
.cstat-lbl{font-size:.69rem;text-transform:uppercase;letter-spacing:.7px;color:#8a99ad}
.cstat-nw .cstat-lbl{color:#facc15}
.cstat-val{font-size:.98rem;font-weight:700;margin-top:1px}
.notice{padding:11px 20px;background:#1c1912;border-bottom:1px solid #332b17;color:#fcd34d;font-size:.83rem}
table{width:100%;border-collapse:collapse;font-size:.9rem}
th{background:#0f141e;color:#8a99ad;font-size:.73rem;text-transform:uppercase;letter-spacing:.8px;padding:9px 14px;text-align:left;border-bottom:1px solid #222b3c}
th.r,td.col-price,td.col-qty{text-align:right}
td{padding:8px 14px;border-bottom:1px solid #1b2230;vertical-align:middle}
tr.it-row:hover{background:#182030}
.col-loc{width:76px}
.col-qty{width:64px;font-variant-numeric:tabular-nums;color:#cbd5e1;font-weight:600}
.col-price{white-space:nowrap;font-variant-numeric:tabular-nums}
.loc{display:inline-block;padding:2px 8px;border-radius:5px;font-size:.71rem;font-weight:700;text-transform:uppercase;letter-spacing:.5px}
.loc-bank{background:#231c38;color:#c4b5fd;border:1px solid #3e3163}
.loc-bag{background:#152936;color:#7dd3fc;border:1px solid #234961}
.iname{font-weight:600}
.q0{color:#9d9d9d}.q1{color:#ffffff}.q2{color:#1eff00}.q3{color:#4da3ff}.q4{color:#c65cff}.q5{color:#ff8000}.q6{color:#e6cc80}
.sb{display:inline-block;margin-left:6px;padding:1px 6px;border-radius:4px;font-size:.69rem;background:#262c3a;color:#94a3b8;border:1px solid #364054}
.stk{color:#64748b;font-size:.78rem;margin-left:4px}
.unit{color:#64748b;font-size:.77rem;margin-right:10px}
.money{font-weight:700}
.g{color:#ffd700;font-weight:700}.s{color:#d1d5db;font-weight:700}.c{color:#d98b5f;font-weight:700}
.m-zero,.m-na{color:#475569}
.bdg{display:inline-block;margin-left:8px;padding:2px 8px;border-radius:999px;font-size:.7rem;font-weight:700;letter-spacing:.3px;vertical-align:middle}
.bdg-ah{background:#2b2108;color:#fbbf24;border:1px solid #6b4f12}
.bdg-st{background:#0b2922;color:#34d399;border:1px solid #165947}
.bdg-av{background:#0c2633;color:#38bdf8;border:1px solid #194d66}
.bdg-none{background:#1b202c;color:#64748b;border:1px solid #2d3648}
.empty{padding:20px;color:#64748b;font-size:.88rem;text-align:center}
.char-ft{background:#0e131c;padding:11px 20px;display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;font-size:.84rem;color:#94a3b8}
.grand-ft{background:linear-gradient(135deg,#1a160c 0%,#121722 100%);border:1px solid #4d3f18;border-radius:12px;padding:18px 24px;display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;gap:14px;margin-top:26px}
.grand-lbl{font-size:1.05rem;font-weight:800;color:#f8d568;text-transform:uppercase;letter-spacing:.8px}
.grand-val{font-size:1.5rem;font-weight:800}
]])
    table.insert(out, "</style>")
    table.insert(out, "</head>")
    table.insert(out, "<body>")
    table.insert(out, "<div class=\"wrap\">")

    -- Account Overview Hero
    table.insert(out, "<header class=\"hero\">")
    table.insert(out, "<div class=\"hero-top\">")
    table.insert(out, "<div>")
    table.insert(out, "<h1 class=\"title\">Bank2Html Account Ledger</h1>")
    table.insert(out, "<div class=\"subtitle\">Generated " .. generatedAt .. " &bull; Characters: " .. tostring(table.getn(charSummaries)) .. " &bull; Aux: " .. auxActive .. " &bull; ShaguTweaks: " .. stActive .. "</div>")
    table.insert(out, "</div>")
    table.insert(out, "<div class=\"acct-nw-box\">")
    table.insert(out, "<div class=\"acct-nw-lbl\">Total Account Net Worth</div>")
    table.insert(out, "<div class=\"acct-nw-val\">" .. FormatMoneyHtml(accountNetWorth, true) .. "</div>")
    table.insert(out, "</div>")
    table.insert(out, "</div>")

    table.insert(out, "<div class=\"kpi-grid\">")
    table.insert(out, "<div class=\"kpi\"><div class=\"kpi-lbl\">Liquid Gold</div><div class=\"kpi-val\">" .. FormatMoneyHtml(accountGold, true) .. "</div></div>")
    table.insert(out, "<div class=\"kpi\"><div class=\"kpi-lbl\">Aux Auction Value</div><div class=\"kpi-val\">" .. FormatMoneyHtml(accountAhVal, true) .. "</div></div>")
    table.insert(out, "<div class=\"kpi\"><div class=\"kpi-lbl\">Vendor Value</div><div class=\"kpi-val\">" .. FormatMoneyHtml(accountVendorVal, true) .. "</div></div>")
    table.insert(out, "<div class=\"kpi\"><div class=\"kpi-lbl\">Bank + Bag Items</div><div class=\"kpi-val\">" .. FormatMoneyHtml(accountBankVal + accountBagVal, true) .. " <span class=\"stk\">(" .. tostring(accountItemStacks) .. " entries)</span></div></div>")
    table.insert(out, "</div>")
    table.insert(out, "</header>")

    -- Interactive Search & Source Filter Toolbar
    table.insert(out, "<div class=\"toolbar\">")
    table.insert(out, "<input id=\"b2h-q\" class=\"search\" type=\"search\" placeholder=\"Filter items across all characters...\" oninput=\"b2hFilter()\">")
    table.insert(out, "<div class=\"filters\">")
    table.insert(out, "<button class=\"fbtn active\" data-f=\"all\" onclick=\"b2hSetF(this)\">All Items</button>")
    table.insert(out, "<button class=\"fbtn\" data-f=\"AuxAH\" onclick=\"b2hSetF(this)\">Auction</button>")
    table.insert(out, "<button class=\"fbtn\" data-f=\"Vendor\" onclick=\"b2hSetF(this)\">Vendor</button>")
    table.insert(out, "<button class=\"fbtn\" data-f=\"bank\" onclick=\"b2hSetF(this)\">Bank Only</button>")
    table.insert(out, "<button class=\"fbtn\" data-f=\"bag\" onclick=\"b2hSetF(this)\">Inventory Only</button>")
    table.insert(out, "</div>")
    table.insert(out, "</div>")

    -- Quick Jump Navigation
    if table.getn(charSummaries) > 1 then
        table.insert(out, "<nav class=\"char-nav\">")
        for i = 1, table.getn(charSummaries) do
            local cs = charSummaries[i]
            local cColor = CLASS_COLORS[cs.rec.class or ""] or "#e2e8f0"
            table.insert(out,
                "<a class=\"cjump\" href=\"#char-" .. tostring(i) .. "\">" ..
                "<span style=\"color:" .. cColor .. "\">" .. EscapeHtml(cs.rec.name) .. "</span> &middot; " ..
                FormatMoneyHtml(cs.netWorth, true) ..
                "</a>"
            )
        end
        table.insert(out, "</nav>")
    end

    -- Per-Character Sections
    for i = 1, table.getn(charSummaries) do
        local cs = charSummaries[i]
        local rec = cs.rec
        local cColor = CLASS_COLORS[rec.class or ""] or "#f8fafc"
        local lvlText = rec.level and ("Lv " .. tostring(rec.level) .. " ") or ""
        local clsText = EscapeHtml(rec.classLocalized or rec.class or "")
        local realmText = EscapeHtml(rec.realm or "")
        local facText = EscapeHtml(rec.faction or "")

        table.insert(out, "<section class=\"card\" id=\"char-" .. tostring(i) .. "\">")
        table.insert(out, "<div class=\"card-hd\">")
        table.insert(out, "<div>")
        table.insert(out, "<div class=\"cname\" style=\"color:" .. cColor .. "\">" .. EscapeHtml(rec.name) .. "</div>")
        table.insert(out, "<div class=\"cmeta\">" .. lvlText .. clsText .. " &bull; " .. realmText .. " (" .. facText .. ") &bull; Bank Scanned: " .. FormatTimestamp(rec.lastBankScan) .. " &bull; Bags Scanned: " .. FormatTimestamp(rec.lastBagScan) .. "</div>")
        table.insert(out, "</div>")

        table.insert(out, "<div class=\"cstats\">")
        table.insert(out, "<div class=\"cstat\"><div class=\"cstat-lbl\">Gold</div><div class=\"cstat-val\">" .. FormatMoneyHtml(cs.rawGold, true) .. "</div></div>")
        table.insert(out, "<div class=\"cstat\"><div class=\"cstat-lbl\">Bank Value</div><div class=\"cstat-val\">" .. FormatMoneyHtml(cs.bankTotal, true) .. "</div></div>")
        table.insert(out, "<div class=\"cstat\"><div class=\"cstat-lbl\">Bags Value</div><div class=\"cstat-val\">" .. FormatMoneyHtml(cs.bagTotal, true) .. "</div></div>")
        table.insert(out, "<div class=\"cstat cstat-nw\"><div class=\"cstat-lbl\">Character Net Worth</div><div class=\"cstat-val\">" .. FormatMoneyHtml(cs.netWorth, true) .. "</div></div>")
        table.insert(out, "</div>")
        table.insert(out, "</div>")

        if not rec.bankScanned then
            table.insert(out, "<div class=\"notice\">Bank not yet scanned on " .. EscapeHtml(rec.name) .. ". Open your bank in-game to include bank items.</div>")
        end

        if cs.rowCount > 0 then
            table.insert(out, "<table>")
            table.insert(out, "<thead><tr><th class=\"col-loc\">Loc</th><th class=\"col-qty\">Qty</th><th>Item</th><th class=\"r\">Price &amp; Source</th></tr></thead>")
            table.insert(out, "<tbody>")
            table.insert(out, cs.rowsHtml)
            table.insert(out, "</tbody>")
            table.insert(out, "</table>")
        else
            table.insert(out, "<div class=\"empty\">No items recorded in bank or inventory.</div>")
        end

        table.insert(out, "<div class=\"char-ft\">")
        table.insert(out, "<span>Aux AH Subtotal: " .. FormatMoneyHtml(cs.ahVal, true) .. " &bull; Vendor Subtotal: " .. FormatMoneyHtml(cs.vendorVal, true) .. " &bull; Gold: " .. FormatMoneyHtml(cs.rawGold, true) .. "</span>")
        table.insert(out, "<span><strong>" .. EscapeHtml(rec.name) .. " Net Worth:</strong> " .. FormatMoneyHtml(cs.netWorth, true) .. "</span>")
        table.insert(out, "</div>")
        table.insert(out, "</section>")
    end

    -- Final Total Net Worth Footer
    table.insert(out, "<footer class=\"grand-ft\">")
    table.insert(out, "<div>")
    table.insert(out, "<div class=\"grand-lbl\">Final Account Total Net Worth</div>")
    table.insert(out, "<div class=\"subtitle\">Combined Gold (" .. FormatMoneyPlain(accountGold) .. ") + Aux Auction Items (" .. FormatMoneyPlain(accountAhVal) .. ") + ShaguTweaks/Vendor Items (" .. FormatMoneyPlain(accountVendorVal) .. ") across " .. tostring(table.getn(charSummaries)) .. " character(s)</div>")
    table.insert(out, "</div>")
    table.insert(out, "<div class=\"grand-val\">" .. FormatMoneyHtml(accountNetWorth, true) .. "</div>")
    table.insert(out, "</footer>")

    -- Lightweight progressive-enhancement filter script (zero pipe characters used!)
    table.insert(out, "<script>")
    table.insert(out, [[
var b2hMode = "all";
function b2hSetF(btn) {
  b2hMode = btn.getAttribute("data-f");
  var btns = document.querySelectorAll(".fbtn");
  for (var i = 0; i < btns.length; i++) {
    btns[i].className = (btns[i] === btn) ? "fbtn active" : "fbtn";
  }
  b2hFilter();
}
function b2hFilter() {
  var q = document.getElementById("b2h-q").value.toLowerCase();
  var cards = document.querySelectorAll(".card");
  for (var c = 0; c < cards.length; c++) {
    var rows = cards[c].querySelectorAll(".it-row");
    var visible = 0;
    for (var r = 0; r < rows.length; r++) {
      var row = rows[r];
      var nm = row.getAttribute("data-name");
      var src = row.getAttribute("data-src");
      var loc = row.getAttribute("data-loc");
      var matchQ = (q === "") ? true : (nm.indexOf(q) !== -1);
      var matchF = true;
      if (b2hMode === "AuxAH") { matchF = (src === "AuxAH"); }
      else if (b2hMode === "Vendor") {
        matchF = (src === "ShaguVendor") ? true : (src === "AuxVendor");
      }
      else if (b2hMode === "bank") { matchF = (loc === "bank"); }
      else if (b2hMode === "bag") { matchF = (loc === "bag"); }
      if (matchQ && matchF) {
        row.style.display = "";
        visible = visible + 1;
      } else {
        row.style.display = "none";
      }
    }
    if (q !== "" && visible === 0 && rows.length > 0) {
      cards[c].style.display = "none";
    } else {
      cards[c].style.display = "";
    }
  }
}
]])
    table.insert(out, "</script>")
    table.insert(out, "</div>")
    table.insert(out, "</body>")
    table.insert(out, "</html>")

    return table.concat(out, "\n"), accountNetWorth, table.getn(charSummaries)
end
