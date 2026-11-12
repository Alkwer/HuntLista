-- ============================================================
-- Hunt Lista - Death.lua
-- Forever: combat log "Name Melee hit You" + "[You died.]"
-- ============================================================

HuntLista = HuntLista or {}
local HL = HuntLista

local lastAttackerName = nil
local lastAttackerTime = 0
local lastAttackerSource = nil
local deathFrame
local popupShownForDeath = false
local wasDead = false
local deathObservedAt = 0

local CHAT_MAX_AGE = 12
local TARGET_MAX_AGE = 30

HL.NameCache = HL.NameCache or {}

local function CleanPlayerName(name)
    if not name or name == "" then return nil end
    if type(name) ~= "string" then return nil end
    if issecretvalue and issecretvalue(name) then return nil end

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
        -- odetnij [You died.] style brackets only if entire msg
        n = n:gsub("^%[", ""):gsub("%]$", "")
        if #n > 0 and n:sub(1, 1) == "<" and n:sub(-1) == ">" then return nil end
        n = n:gsub(" *<[^>]*> *", " ")
        n = strtrim(n)
        n = n:gsub("[%.%!%?]+$", "")
        local before = n:match("^(.+)%-[^%- ]+$")
        if before then n = before end
        n = strtrim(n)
        n = n:gsub("  +", " ")
        if n == "" then return nil end
        -- odrzuc oczywiste smieci z combat loga
        local lower = strlower(n)
        if lower == "you" or lower == "your" or lower == "died" or lower == "melee" then return nil end
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

local function SafeUnitName(unit)
    if not unit or not UnitExists(unit) then return nil end
    local ok, n = pcall(UnitName, unit)
    if not ok or type(n) ~= "string" then return nil end
    if issecretvalue and issecretvalue(n) then return nil end
    n = CleanPlayerName(n)
    if not n then return nil end
    return HL:ResolveFullName(n) or n
end

function HL:CacheUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    local n = SafeUnitName(unit)
    if n then HL:CacheFullName(n) end
end

local function RememberAttacker(name, reason)
    if type(name) ~= "string" then return end
    name = CleanPlayerName(name)
    if not name then return end

    -- chat/combatlog ma priorytet nad targetem
    if reason == "combat-target" and lastAttackerSource and lastAttackerSource ~= "combat-target" then
        if (GetTime() - lastAttackerTime) < CHAT_MAX_AGE then
            return
        end
    end

    local resolved = HL:ResolveFullName(name)
    if resolved then name = resolved end

    lastAttackerName = name
    lastAttackerTime = GetTime()
    lastAttackerSource = reason
    HL:CacheFullName(name)

    if HuntListaDB and HuntListaDB.debug then
        print("|cff888888[HL death]|r attacker=" .. name .. " (" .. tostring(reason) .. ")")
    end
end

-- Forever combat log z screenshota:
-- "Name Melee hit You 46 Physical."
-- "Name Deadly Poison II damaged You 97 Nature."
-- "Name Mutilate hit You 175 Physical. (77 Overkill)"
-- "[You died.]"
local function TryParseKillerFromChat(msg)
    if not msg or type(msg) ~= "string" then return end
    if issecretvalue and issecretvalue(msg) then return end

    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    msg = msg:gsub("|H.-|h", ""):gsub("|h", "")
    msg = strtrim(msg)

    -- klasyczne slain by
    for _, pat in ipairs({
        "^[Yy]ou were slain by (.+)$",
        "^[Yy]ou were killed by (.+)$",
        "^[Yy]ou have been slain by (.+)$",
        "^[Yy]ou have been killed by (.+)$",
        "^[Yy]ou were defeated by (.+)$",
        "^[Ss]lain by (.+)$",
        "^[Kk]illed by (.+)$",
        "^[Zz]abity przez (.+)$",
        "^[Zz]abita przez (.+)$",
        "^[Zz]abil cie (.+)$",
        "^[Zz]abila cie (.+)$",
        "^[Zz]abił cię (.+)$",
        "^[Zz]abiła cię (.+)$",
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

    -- Forever / combat log: "Something hit/damaged You ..."
    -- Nie lap "You hit ..." (to my bijemy).
    if not msg:match("^[Yy]ou%s") then
        local patterns = {
            "^(.+) Melee hit You",
            "^(.+) hit You",
            "^(.+) crit You",
            "^(.+) crits You",
            "^(.+) hits You",
            "^(.+) damaged You",
            "^(.+) damages You",
            "^(.+) suffers You", -- rare
            "^(.+) was blocked", -- skip-ish
        }
        for _, pat in ipairs({
            "^(.+) Melee hit You",
            "^(.+) hit You",
            "^(.+) hits You",
            "^(.+) crit You",
            "^(.+) crits You",
            "^(.+) damaged You",
            "^(.+) damages You",
            "^(.+) crushes You",
            "^(.+) crush You",
        }) do
            local m = msg:match(pat)
            if m then
                -- "Deadly Poison II" bywa w srodku: "Name Deadly Poison II damaged You"
                -- bierzemy caly prefix przed slowem kluczowym - bywa z ability
                -- Spróbuj odciac znana ability na koncu prefixu: ostanie 1-3 slowa jesli look like ability
                m = strtrim(m)
                -- Jesli pattern to "hit You" bez Melee, m moze byc "Name Mutilate"
                -- Zostawiamy pelne m; Clean odfiltruje smieci
                local cleaned = CleanPlayerName(m)
                if cleaned and #cleaned >= 2 then
                    -- Gdy m = "Name Ability Ability", a UnitName nie ma spacji ability...
                    -- Heurystyka: jesli 3+ slow, sprobuj pierwsze 2 (Forever full name)
                    local words = {}
                    for w in cleaned:gmatch("%S+") do table.insert(words, w) end
                    local candidate = cleaned
                    if #words >= 3 then
                        -- typowe: Name Name Ability  OR Name Ability Ability
                        -- Preferuj 2 pierwsze slowa (nick Forever ze spacja)
                        candidate = words[1] .. " " .. words[2]
                    elseif #words == 2 then
                        -- Name Ability  LUB Name Name - nie wiemy; zostaw oba, ResolveFullName z listy pomoże
                        candidate = cleaned
                    end
                    RememberAttacker(candidate, "combatlog")
                    -- zapisz tez pelniejsze jesli krotkie
                    if candidate ~= cleaned and #words >= 2 then
                        RememberAttacker(words[1] .. " " .. words[2], "combatlog")
                    end
                    return candidate
                end
            end
        end
    end
end

if ChatFrame_AddMessageEventFilter then
    local function chatFilter(_, _, msg)
        TryParseKillerFromChat(msg)
        return false
    end
    local events = {
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_COMBAT_MISC_INFO",
        "CHAT_MSG_COMBAT_HOSTILE_DEATH",
        "CHAT_MSG_COMBAT_XP_GAIN",
        "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
        "CHAT_MSG_COMBAT_SELF_HITS",
        "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_SELF_DAMAGE",
        "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
        "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
        "CHAT_MSG_COMBAT_PARTY_HITS",
        "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
    }
    for _, ev in ipairs(events) do
        pcall(ChatFrame_AddMessageEventFilter, ev, chatFilter)
    end
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
    eb:SetSize(280, 32)
    eb:SetPoint("TOP", sub, "BOTTOM", 0, -12)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightLarge")
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetMaxLetters(80)
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
        f.onListText:SetText("|cffaaaaaaNie ma na liscie - dopisz i wklej na Discord|r")
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
    local src = lastAttackerSource
    local maxAge = (src == "combat-target") and TARGET_MAX_AGE or CHAT_MAX_AGE

    if (not name or age > maxAge) and UnitExists("target") and UnitIsPlayer("target") then
        local best = SafeUnitName("target")
        if best then
            name = best
            age = 0
            src = "target-now"
            maxAge = TARGET_MAX_AGE
        end
    end

    if HuntListaDB and HuntListaDB.debug then
        print("|cff888888[HL death]|r TryShow source=" .. tostring(source)
            .. " last=" .. tostring(lastAttackerName)
            .. " via=" .. tostring(src)
            .. " age=" .. string.format("%.1f", age))
    end

    if name and age <= maxAge then
        popupShownForDeath = true
        HL:ShowKillerPopup(name)
    elseif HuntListaDB and HuntListaDB.debug then
        print("|cff888888[HL death]|r brak zabojcy")
    end
end

local poll = CreateFrame("Frame")
poll:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.15 then return end
    self.t = 0

    if UnitAffectingCombat("player") then
        if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("player", "target") then
            local n = SafeUnitName("target")
            if n then RememberAttacker(n, "combat-target") end
        end
    end

    local dead = UnitIsDeadOrGhost("player")
    if dead then
        if not wasDead then
            wasDead = true
            deathObservedAt = GetTime()
            if HuntListaDB and HuntListaDB.debug then
                print("|cff888888[HL death]|r detected death")
            end
        end
        local dt = GetTime() - deathObservedAt
        if dt >= 0.2 and dt < 8 then
            TryShowOnDeath("HEALTH")
        end
    elseif not dead and wasDead then
        wasDead = false
        popupShownForDeath = false
    end
end)

function HL:InitDeathModule()
    SeedCacheFromData()
    print("|cff00ff00Hunt Lista|r Death.lua OK (Forever combat log)")
end

HuntLista.ShowKillerPopup = HL.ShowKillerPopup
HuntLista.HideKillerPopup = HL.HideKillerPopup
HuntLista.CacheUnit = HL.CacheUnit
HuntLista.CacheFullName = HL.CacheFullName
HuntLista.ResolveFullName = HL.ResolveFullName
HuntLista.InitDeathModule = HL.InitDeathModule
