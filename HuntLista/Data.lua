-- ============================================================
-- Hunt Lista - Dane (aktualizowane przez bota z Discorda / GitHub)
-- Nie edytuj ręcznie tego pliku jeśli używasz automatycznej aktualizacji.
-- ============================================================

HuntLista_Data = {
    version = "2026-11-09.1",          -- data + numer wersji danych
    lastUpdate = "2026-11-09 10:40",    -- kiedy bot ostatnio zaktualizował
    updatedBy = "DiscordBot",

    -- Lista graczy: klucz = nick (bez spacji, case-insensitive w kodzie)
    -- value = tabela z info
    players = {
        -- Przykład:
        -- ["NickGracza"] = {
        --     reason = "Gankał lowi / campował",
        --     addedBy = "Stary",
        --     addedAt = "2026-11-08",
        --     note = "Czerwony mount, często w STV",
        -- },
    }
}

-- Szybki lookup (tworzony przy starcie)
HuntLista_Lookup = {}
