-- ============================================================
-- Hunt Lista - Okienko po smierci z nickiem zabojcy
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

local playerGUID
local lastAttackerName = nil
local lastAttackerTime = 0
local deathFrame

local function StripRealm(name)
    if not name then return nil end
    name = strtrim(name)
    local base = name:match("^(.-)%-.+$")
    if base and base ~= "" then
        return base
    end
    return name
end

local function CreateDeathFrame()
    if deathFrame then return deathFrame end

    local f = CreateFrame("Frame", "HuntListaDeathFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 140)
    f:SetPoint("CENTER", 0, 120)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("|cffff4444Zabil cie|r")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetTextColor(0.7, 0.7, 0.7)
    sub:SetText("Zaznaczony nick - Ctrl+C aby skopiowac")
    f.sub = sub

    -- EditBox z nickiem (latwe kopiowanie)
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(240, 28)
    eb:SetPoint("TOP", sub, "BOTTOM", 0, -12)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightLarge")
    eb:SetJustifyH("CENTER")
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:HighlightText()
        self:SetFocus()
    end)
    f.editBox = eb

    local onList = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    onList:SetPoint("TOP", eb, "BOTTOM", 0, -8)
    onList:SetText("")
    f.onListText = onList

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(80, 24)
    close:SetPoint("BOTTOM", 0, 16)
    close:SetText("Zamknij")
    close:SetScript("OnClick", function() f:Hide() end)

    local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectBtn:SetSize(100, 24)
    selectBtn:SetPoint("BOTTOMLEFT", 24, 16)
    selectBtn:SetText("Zaznacz")
    selectBtn:SetScript("OnClick", function()
        eb:HighlightText()
        eb:SetFocus()
    end)

    close:SetPoint("BOTTOMRIGHT", -24, 16)

    deathFrame = f
    return f
end

function HL:ShowKillerPopup(name)
    if HuntListaDB and HuntListaDB.deathPopup == false then return end
    if not name or name == "" then return end

    name = StripRealm(name)
    local f = CreateDeathFrame()
    f.editBox:SetText(name)
    f.editBox:HighlightText()
    f.editBox:SetFocus()

    local info = HL:GetInfo(name)
    if info then
        f.onListText:SetText("|cffff6666Juz na Hunt Liscie|r")
    else
        f.onListText:SetText("|cffaaaaaaNie ma na liscie - wklej na Discord /hunt add|r")
    end

    f:Show()
end

function HL:HideKillerPopup()
    if deathFrame then deathFrame:Hide() end
end

-- Sledzenie ostatniego atakujacego przez combat log
local cleu = CreateFrame("Frame")
cleu:RegisterEvent("PLAYER_LOGIN")
cleu:RegisterEvent("PLAYER_DEAD")
cleu:RegisterEvent("PLAYER_ALIVE")
cleu:RegisterEvent("PLAYER_UNGHOST")
cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

cleu:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        return
    end

    if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        -- po wstawieniu nie trzymamy okna na sile; user moze zamknac
        return
    end

    if event == "PLAYER_DEAD" then
        if lastAttackerName and (GetTime() - lastAttackerTime) < 15 then
            HL:ShowKillerPopup(lastAttackerName)
        else
            -- fallback: target/focus jesli to gracz
            local fallback = nil
            if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("target", "player") then
                fallback = UnitName("target")
            end
            if fallback then
                HL:ShowKillerPopup(fallback)
            end
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not playerGUID then
            playerGUID = UnitGUID("player")
        end

        local _, subevent, _, sourceGUID, sourceName, _, _, destGUID = CombatLogGetCurrentEventInfo()

        if not destGUID or destGUID ~= playerGUID then return end
        if not sourceGUID or sourceGUID == playerGUID then return end
        if not sourceName or sourceName == "" then return end

        -- obrazenia / zabojcze efekty
        if subevent == "SWING_DAMAGE"
            or subevent == "RANGE_DAMAGE"
            or subevent == "SPELL_DAMAGE"
            or subevent == "SPELL_PERIODIC_DAMAGE"
            or subevent == "SPELL_BUILDING_DAMAGE"
            or subevent == "ENVIRONMENTAL_DAMAGE" then

            lastAttackerName = sourceName
            lastAttackerTime = GetTime()

        elseif subevent == "UNIT_DIED" then
            -- smierc z combat loga - pokaz od razu jesli znamy atakujacego
            if lastAttackerName and (GetTime() - lastAttackerTime) < 15 then
                HL:ShowKillerPopup(lastAttackerName)
            end
        end
    end
end)

-- /hl killer  - pokazuje ostatniego atakujacego (test)
-- podpiecie w Core przez HL.ShowKillerPopup
