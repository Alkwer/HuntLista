-- ============================================================
-- Hunt Lista - Death.lua (poll mode)
-- Pelne nicki spoza listy: chat systemowy + tooltip (bez CLEU)
-- ============================================================

HuntLista = HuntLista or {}
local HL = HuntLista

local lastAttackerName = nil
local lastAttackerTime = 0
local deathFrame
local popupShownForDeath = false
local wasDead = false

HL.NameCache = HL.NameCache or {}

local function CleanPlayerName(name)
    if not name or name == "" then return nil end
    if type(name) ~= "string" then return nil end

    local ok, cleaned = pcall(function()
        local n = strtrim(name)
        n = n:gsub("|c%x%x%x%x%x%x%x%x", "")
        n = n:gsub("|r", "")
        n = n:gsub("|T.-|t", "")
        n = n:gsub("|H.-|h", "")
        n = n:gsub("|h", "")
        local nl = n:find(string.char(10), 1, true)
        if nl then n = n:sub(1, nl - 1) end
        n = strtrim(n)
        if #n > 0 and n:sub(1, 1) == "<" and n:sub(-1) == ">" then return nil end
        n = n:gsub(" *<[^>]*> *", " ")
        n = strtrim(n)
        -- odetnij kropke / wykrzyknik na koncu z wiadomosci chatu
        n = n:gsub("[%.%!%?]+$", "")
        local before = n:match("^(.+)%-[^%- ]+$")
        if before then n = before end
        n = strtrim(n)
        n = n:gsub("  +", " ")
        if n == "" then return nil end
        return n
    end)

    if ok then return cleaned end
    return nil
end

local function FirstWord(name)
    if not name or type(name) ~= "string" then return nil end
    local ok, w = pcall(function()
        return strlower(strtrim(name):match("^(%S+)") or name)
    end)
    if ok then return w end
    return nil
end

function HL:CacheFullName(full)
    full = CleanPlayerName(full)
    if not full then return end
    local fw = FirstWord(full)
    if not fw or #fw < 2 then return end
    local prev = HL.NameCache[fw]
    -- preferuj dluzszy (ze spacja = pelny nick Forever)
    if not prev or (#full > #prev) then
        HL.NameCache[fw] = full
    end
end

local function SeedCacheFromData()
    if not HuntLista_Data or not HuntLista_Data.players then return end
    for name, _ in pairs(HuntLista_Data.players) do
        HL:CacheFullName(name)
    end
end

function HL:ResolveFullName(name)
    name = CleanPlayerName(name)
    if not name then return nil end

    local fw = FirstWord(name)
    local cached = fw and HL.NameCache[fw]
    if cached then
        cached = CleanPlayerName(cached)
        if cached and #cached >= #name then return cached end
    end

    if HL.GetInfo then
        local info = HL:GetInfo(name)
        if info and info.name then
            local n = CleanPlayerName(info.name)
            if n then return n end
        end
    end

    if HuntLista_Data and HuntLista_Data.players and fw then
        for full, _ in pairs(HuntLista_Data.players) do
            local key = strlower(strtrim(full))
            if key == fw or key:sub(1, #fw + 1) == fw .. " " then
                return CleanPlayerName(full) or full
            end
        end
    end

    return name
end

-- Tooltip scan (czasem ma pelna nazwe gdy UnitName ucina)
local scanTip
local function TryTooltipName(unit)
    if not unit or not UnitExists(unit) then return nil end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "HuntListaScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    local ok = pcall(function()
        scanTip:ClearLines()
        scanTip:SetUnit(unit)
    end)
    if not ok then return nil end

    local ok2, text = pcall(function()
        local fs = _G["HuntListaScanTipTextLeft1"]
        if fs and fs.GetText then
            local t = fs:GetText()
            if type(t) == "string" then return t end
        end
        return nil
    end)
    if ok2 and text then
        return CleanPlayerName(text)
    end
    return nil
end

local function BestUnitName(unit)
    if not unit or not UnitExists(unit) then return nil end
    local n = UnitName(unit)
    if type(n) ~= "string" then n = nil end

    local tip = TryTooltipName(unit)
    if tip and (not n or #tip > #n) then
        HL:CacheFullName(tip)
        return tip
    end

    if n then
        local resolved = HL:ResolveFullName(n)
        return resolved or n
    end
    return nil
end

function HL:CacheUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    local n = BestUnitName(unit)
    if n then HL:CacheFullName(n) end
end

local function RememberAttacker(name, reason)
    if type(name) ~= "string" then return end
    name = CleanPlayerName(name)
    if not name then return end

    local full = HL:ResolveFullName(name)
    if full then name = full end

    lastAttackerName = name
    lastAttackerTime = GetTime()
    HL:CacheFullName(name)

    if HuntListaDB and HuntListaDB.debug then
        print("|cff888888[HL death]|r attacker=" .. name .. " (" .. tostring(reason) .. ")")
    end
end

-- Chat: "You were slain by Name" / PL warianty - bez RegisterEvent
local CHAT_PATTERNS = {
    "slain by (.+)$",
    "killed by (.+)$",
    "zabit[ya]? przez (.+)$",
    "zabil[a]? ci[eę] (.+)$",
    "zostaje[sz]? zabit[ya]? przez (.+)$",
    "dies from (.+) impairments",
    "defeated by (.+)$",
}

local function TryParseKillerFromChat(msg)
    if type(msg) ~= "string" then return end
    local lower = strlower(msg)
    for _, pat in ipairs(CHAT_PATTERNS) do
        local m = lower:match(pat)
        if m then
            -- wez oryginalna kapitalizacje z msg
            local startPos, endPos = lower:find(pat)
            -- prostsze: Clean z match na oryginale case-insensitive
            local original = msg:match("(?i)" .. pat) -- Lua nie ma (?i)
            break
        end
    end
    for _, pat in ipairs({
        "[Ss]lain by (.+)$",
        "[Kk]illed by (.+)$",
        "[Zz]abit[ya]? przez (.+)$",
        "[Zz]abil[a]? ci[eę] (.+)$",
        "[Dd]efeated by (.+)$",
    }) do
        local m = msg:match(pat)
        if m then
            m = CleanPlayerName(m)
            if m then
                RememberAttacker(m, "chat")
                return m
            end
        end
    end
end

if ChatFrame_AddMessageEventFilter then
    local function chatFilter(_, _, msg)
        TryParseKillerFromChat(msg)
        return false
    end
    pcall(function()
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", chatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", chatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_HOSTILE_DEATH", chatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", chatFilter)
    end)
end

local function CreateDeathFrame()
    if deathFrame then return deathFrame end

    local f = CreateFrame("Frame", "HuntListaDeathFrame", UIParent, "BackdropTemplate")
    f:SetSize(340, 150)
    f:SetPoint("CENTER", 0, 120)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cffff4444Zabil cie|r")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetTextColor(0.7, 0.7, 0.7)
    sub:SetText("Kliknij w nick, Ctrl+C aby skopiowac")

    local eb = CreateFrame("EditBox", nil, f)
    eb:SetSize(260, 32)
    eb:SetPoint("TOP", sub, "BOTTOM", 0, -12)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightLarge")
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetMaxLetters(64)
    eb:EnableKeyboard(false)

    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus(); self:EnableKeyboard(false); f:Hide()
    end)
    eb:SetScript("OnMouseDown", function(self)
        self:EnableKeyboard(true); self:SetFocus(); self:HighlightText()
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:EnableKeyboard(true); self:HighlightText()
    end)
    eb:SetScript("OnEditFocusLost", function(self) self:EnableKeyboard(false) end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus(); self:EnableKeyboard(false)
    end)
    f.editBox = eb

    local onList = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    onList:SetPoint("TOP", eb, "BOTTOM", 0, -8)
    f.onListText = onList

    local function MakeBtn(w, label)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w, 26)
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.2, 0.05, 0.05, 0.95)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText(label)
        b:SetScript("OnEnter", function() t:SetColorTexture(0.35, 0.1, 0.1, 1) end)
        b:SetScript("OnLeave", function() t:SetColorTexture(0.2, 0.05, 0.05, 0.95) end)
        return b
    end

    local selectBtn = MakeBtn(110, "Zaznacz")
    selectBtn:SetPoint("BOTTOMLEFT", 28, 14)
    selectBtn:SetScript("OnClick", function()
        eb:EnableKeyboard(true); eb:SetFocus(); eb:HighlightText()
    end)

    local close = MakeBtn(110, "Zamknij")
    close:SetPoint("BOTTOMRIGHT", -28, 14)
    close:SetScript("OnClick", function()
        eb:ClearFocus(); eb:EnableKeyboard(false); f:Hide()
    end)

    f:SetScript("OnHide", function()
        eb:ClearFocus(); eb:EnableKeyboard(false)
    end)

    deathFrame = f
    return f
end

function HL:ShowKillerPopup(name)
    if HuntListaDB and HuntListaDB.deathPopup == false then return end
    if not name or name == "" then return end

    SeedCacheFromData()
    name = HL:ResolveFullName(name) or name
    name = CleanPlayerName(name)
    if not name then return end

    local f = CreateDeathFrame()
    f.editBox:EnableKeyboard(false)
    f.editBox:ClearFocus()
    f.editBox:SetText(name)

    local info = HL.GetInfo and HL:GetInfo(name) or nil
    if info then
        f.onListText:SetText("|cffff6666Juz na Hunt Liscie|r")
    else
        f.onListText:SetText("|cffaaaaaaNie ma na liscie - dopisz nazwisko i wklej na Discord|r")
    end

    print("|cffff4444[Hunt Lista]|r Zabojca: |cffffff00" .. name .. "|r")
    f:Show()
end

function HL:HideKillerPopup()
    if deathFrame then
        if deathFrame.editBox then
            deathFrame.editBox:ClearFocus()
            deathFrame.editBox:EnableKeyboard(false)
        end
        deathFrame:Hide()
    end
end

local function TryShowOnDeath(source)
    if popupShownForDeath then return end
    if HuntListaDB and HuntListaDB.deathPopup == false then return end

    local name = lastAttackerName
    local age = lastAttackerName and (GetTime() - lastAttackerTime) or 999

    if UnitExists("target") and UnitIsPlayer("target") then
        local best = BestUnitName("target")
        if best and (not name or age > 45 or #best > #name) then
            name = best
            age = 0
        end
    end

    if HuntListaDB and HuntListaDB.debug then
        print("|cff888888[HL death]|r TryShow source=" .. tostring(source)
            .. " last=" .. tostring(lastAttackerName)
            .. " age=" .. string.format("%.1f", age))
    end

    if name and age <= 45 then
        popupShownForDeath = true
        HL:ShowKillerPopup(name)
    elseif HuntListaDB and HuntListaDB.debug then
        print("|cff888888[HL death]|r brak zabojcy do pokazania")
    end
end

function HL:OnTargetChangedDeath()
    if UnitExists("target") and UnitIsPlayer("target") then
        if UnitCanAttack("player", "target") or (HuntListaDB and HuntListaDB.testMode) then
            local n = BestUnitName("target")
            if n then RememberAttacker(n, "target") end
        end
    end
end

local poll = CreateFrame("Frame")
poll:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.15 then return end
    self.t = 0

    if UnitAffectingCombat("player") then
        if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("player", "target") then
            local n = BestUnitName("target")
            if n then RememberAttacker(n, "combat-target") end
        end
    end

    local dead = UnitIsDeadOrGhost("player")
    if dead and not wasDead then
        wasDead = true
        -- male opoznienie - chat ze slain by moze dojsc ułamek po smierci
        C_Timer.After(0.3, function()
            TryShowOnDeath("HEALTH")
        end)
    elseif not dead and wasDead then
        wasDead = false
        popupShownForDeath = false
    end
end)

function HL:InitDeathModule()
    SeedCacheFromData()
    print("|cff00ff00Hunt Lista|r Death.lua OK (poll + chat/tooltip)")
end

HuntLista.ShowKillerPopup = HL.ShowKillerPopup
HuntLista.HideKillerPopup = HL.HideKillerPopup
HuntLista.CacheUnit = HL.CacheUnit
HuntLista.CacheFullName = HL.CacheFullName
HuntLista.ResolveFullName = HL.ResolveFullName
HuntLista.OnTargetChangedDeath = HL.OnTargetChangedDeath
HuntLista.InitDeathModule = HL.InitDeathModule
