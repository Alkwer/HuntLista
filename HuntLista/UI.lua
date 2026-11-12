-- ============================================================
-- Hunt Lista - Okno z lista
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

local listFrame

local function CreateListFrame()
    if listFrame then return listFrame end

    local f = CreateFrame("Frame", "HuntListaFrame", UIParent, "BackdropTemplate")
    f:SetSize(440, 480)
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
    scroll:SetPoint("BOTTOMRIGHT", -36, 50)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(380, 1)
    scroll:SetScrollChild(content)
    f.content = content
    f.scroll = scroll

    local footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer:SetPoint("BOTTOM", 0, 18)
    footer:SetTextColor(0.6, 0.6, 0.6)
    footer:SetText("xN = ile RAZY TY ich zabiles (lokalnie na tej postaci)")
    f.footer = footer

    listFrame = f
    return f
end

function HL:RefreshList()
    local f = CreateListFrame()
    local content = f.content

    for i = content:GetNumChildren(), 1, -1 do
        local child = select(i, content:GetChildren())
        child:Hide()
        child:SetParent(nil)
    end

    local players = {}
    for key, info in pairs(HuntLista_Lookup) do
        table.insert(players, info)
    end
    table.sort(players, function(a, b)
        local ka = HL.GetKillCount and HL:GetKillCount(a.name) or 0
        local kb = HL.GetKillCount and HL:GetKillCount(b.name) or 0
        if ka ~= kb then return ka > kb end
        return a.name < b.name
    end)

    local totalKills = HL.GetTotalKills and HL:GetTotalKills() or 0
    f.versionText:SetText(string.format("Dane: %s  |  %d graczy  |  zabojstwa: %d",
        HL.dataVersion,
        #players,
        totalKills
    ))

    local y = -4
    if #players == 0 then
        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOP", 0, y)
        empty:SetText("Lista jest pusta.\nBot jeszcze nikogo nie dodal.")
        empty:SetTextColor(0.6, 0.6, 0.6)
        content:SetHeight(40)
    else
        for i, info in ipairs(players) do
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(380, 36)
            row:SetPoint("TOPLEFT", 0, y)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.04)
            row:SetScript("OnEnter", function() bg:SetColorTexture(1, 0.2, 0.2, 0.15) end)
            row:SetScript("OnLeave", function() bg:SetColorTexture(1, 1, 1, 0.04) end)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 4, 0)
            icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
            icon:SetVertexColor(1, 0.25, 0.25)

            local kills = HL.GetKillCount and HL:GetKillCount(info.name) or 0
            local killTxt = ""
            if kills > 0 then
                killTxt = "  |cff88ff88x" .. kills .. "|r"
            end

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameFS:SetPoint("LEFT", icon, "RIGHT", 8, 4)
            nameFS:SetText("|cffff6666" .. info.name .. "|r" .. killTxt)

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
        if HL.GetTotalKills then
            GameTooltip:AddLine("Zabojstwa: " .. HL:GetTotalKills(), 0.5, 1, 0.5)
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
