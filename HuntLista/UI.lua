-- ============================================================
-- Hunt Lista - Okno z lista + ustawienia dzwieku
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

local listFrame

local SOUND_ORDER = { "raid", "alarm", "bell", "tell", "map", "level", "aggro", "pvp", "gong" }

local function MakeBtn(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local t = b:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0.18, 0.18, 0.18, 0.95)
    b.bg = t
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    b.label = fs
    b:SetScript("OnEnter", function()
        t:SetColorTexture(0.32, 0.22, 0.12, 1)
    end)
    b:SetScript("OnLeave", function()
        t:SetColorTexture(0.18, 0.18, 0.18, 0.95)
    end)
    return b
end

local function UpdateSoundUI(f)
    if not f or not f.soundToggle then return end
    local on = not HuntListaDB or HuntListaDB.sound ~= false
    local key = (HuntListaDB and HuntListaDB.soundPreset) or "raid"
    local preset = HL.SoundPresets and HL.SoundPresets[key]
    local label = (preset and preset.label) or key

    if on then
        f.soundToggle.label:SetText("|cff88ff88Dzwiek: ON|r")
    else
        f.soundToggle.label:SetText("|cffff6666Dzwiek: OFF|r")
    end
    f.presetLabel:SetText("|cffffff00" .. label .. "|r")
end

local function CyclePreset(dir)
    if not HL.SoundPresets then return end
    local cur = (HuntListaDB and HuntListaDB.soundPreset) or "raid"
    local idx = 1
    for i, k in ipairs(SOUND_ORDER) do
        if k == cur then idx = i break end
    end
    idx = idx + dir
    if idx < 1 then idx = #SOUND_ORDER end
    if idx > #SOUND_ORDER then idx = 1 end
    local key = SOUND_ORDER[idx]
    if not HuntListaDB then HuntListaDB = {} end
    HuntListaDB.soundPreset = key
    HuntListaDB.sound = true
    if listFrame then UpdateSoundUI(listFrame) end
    if HL.PlayHuntSound then HL:PlayHuntSound() end
end

local function CreateListFrame()
    if listFrame then return listFrame end

    local f = CreateFrame("Frame", "HuntListaFrame", UIParent, "BackdropTemplate")
    f:SetSize(460, 520)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("|cffff4444Hunt Lista|r")

    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("TOP", title, "BOTTOM", 0, -4)
    ver:SetTextColor(0.7, 0.7, 0.7)
    f.versionText = ver

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() f:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -55)
    scroll:SetPoint("BOTTOMRIGHT", -36, 78)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 1)
    scroll:SetScrollChild(content)
    f.content = content
    f.scroll = scroll

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 14, 14)
    bar:SetPoint("BOTTOMRIGHT", -14, 14)
    bar:SetHeight(52)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.08, 0.08, 0.08, 0.85)

    local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 8, -4)
    hint:SetTextColor(0.55, 0.55, 0.55)
    hint:SetText("xN = kille gildii (Discord)  |  dzwiek alertu:")

    local soundToggle = MakeBtn(bar, 100, 24, "Dzwiek: ON")
    soundToggle:SetPoint("BOTTOMLEFT", 8, 6)
    soundToggle:SetScript("OnClick", function()
        if not HuntListaDB then HuntListaDB = {} end
        HuntListaDB.sound = not (HuntListaDB.sound ~= false)
        UpdateSoundUI(f)
        if HuntListaDB.sound ~= false and HL.PlayHuntSound then
            HL:PlayHuntSound()
        end
    end)
    f.soundToggle = soundToggle

    local prev = MakeBtn(bar, 28, 24, "<")
    prev:SetPoint("LEFT", soundToggle, "RIGHT", 8, 0)
    prev:SetScript("OnClick", function() CyclePreset(-1) end)

    local presetLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetLabel:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    presetLabel:SetWidth(120)
    presetLabel:SetJustifyH("CENTER")
    f.presetLabel = presetLabel

    local nextBtn = MakeBtn(bar, 28, 24, ">")
    nextBtn:SetPoint("LEFT", presetLabel, "RIGHT", 6, 0)
    nextBtn:SetScript("OnClick", function() CyclePreset(1) end)

    local testBtn = MakeBtn(bar, 70, 24, "Test")
    testBtn:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)
    testBtn:SetScript("OnClick", function()
        if not HuntListaDB then HuntListaDB = {} end
        HuntListaDB.sound = true
        UpdateSoundUI(f)
        if HL.PlayHuntSound then HL:PlayHuntSound() end
    end)

    UpdateSoundUI(f)

    listFrame = f
    return f
end

function HL:RefreshList()
    local f = CreateListFrame()
    local content = f.content

    UpdateSoundUI(f)

    for i = content:GetNumChildren(), 1, -1 do
        local child = select(i, content:GetChildren())
        child:Hide()
        child:SetParent(nil)
    end
    if content.emptyLabel then
        content.emptyLabel:Hide()
    end

    local players = {}
    for key, info in pairs(HuntLista_Lookup) do
        table.insert(players, info)
    end
    table.sort(players, function(a, b)
        local ka = tonumber(a.kills) or 0
        local kb = tonumber(b.kills) or 0
        if ka ~= kb then return ka > kb end
        return (a.name or "") < (b.name or "")
    end)

    f.versionText:SetText(
        "dane: " .. (HL.dataVersion or "?")
        .. "  |  graczy: " .. tostring(#players)
        .. (HL.GetSharedTotalKills and ("  |  kille: " .. HL:GetSharedTotalKills()) or "")
    )

    local y = -4
    if #players == 0 then
        if not content.emptyLabel then
            content.emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        end
        local empty = content.emptyLabel
        empty:ClearAllPoints()
        empty:SetPoint("TOP", 0, y)
        empty:SetTextColor(0.7, 0.7, 0.7)
        empty:SetText("Lista pusta - dodaj na Discord: /hunt add")
        empty:Show()
        content:SetHeight(40)
    else
        for _, info in ipairs(players) do
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(390, 36)
            row:SetPoint("TOPLEFT", 0, y)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.12, 0.12, 0.12, 0.6)

            local icon = row:CreateTexture(nil, "OVERLAY")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 6, 0)
            icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
            icon:SetVertexColor(1, 0.2, 0.2)

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameFS:SetPoint("LEFT", icon, "RIGHT", 8, 6)
            nameFS:SetTextColor(1, 0.85, 0.4)
            nameFS:SetText(info.name or "?")

            local kills = tonumber(info.kills) or 0
            if kills > 0 then
                local killTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                killTxt:SetPoint("LEFT", nameFS, "RIGHT", 8, 0)
                killTxt:SetTextColor(0.4, 1, 0.4)
                killTxt:SetText("x" .. kills)
            end

            local reasonFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            reasonFS:SetPoint("LEFT", icon, "RIGHT", 8, -10)
            reasonFS:SetTextColor(0.75, 0.75, 0.75)
            local extra = info.reason or ""
            if info.note and info.note ~= "" then
                extra = extra .. (extra ~= "" and " - " or "") .. info.note
            end
            reasonFS:SetText(extra ~= "" and extra or "-")

            if info.addedBy and info.addedBy ~= "" then
                local by = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                by:SetPoint("RIGHT", -8, 0)
                by:SetTextColor(0.5, 0.5, 0.5)
                by:SetText(info.addedBy)
            end

            y = y - 38
        end
        content:SetHeight(math.abs(y) + 10)
    end
end

function HL:ToggleList()
    local f = CreateListFrame()
    if f:IsShown() then
        f:Hide()
    else
        HL:RefreshList()
        f:Show()
    end
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "HuntListaMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self) self:StartMoving() end)
    btn:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetSize(20, 20)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    btn.icon:SetVertexColor(1, 0.2, 0.2)

    btn:SetScript("OnClick", function()
        HL:ToggleList()
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Hunt Lista")
        GameTooltip:AddLine("Kliknij, aby otworzyc liste", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Graczy: " .. HL:GetPlayerCount(), 0.7, 0.7, 0.7)
        if HL.GetSharedTotalKills then
            GameTooltip:AddLine("Kille gildii: " .. HL:GetSharedTotalKills(), 0.5, 1, 0.5)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if HuntListaDB and HuntListaDB.minimapButton then
        CreateMinimapButton()
    end
end)
