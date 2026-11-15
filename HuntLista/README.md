# Hunt Lista

Gildyjny addon do oznaczania konkretnych graczy PvP w **WoW Forever**.

## Co robi

- Trzyma listę graczy (nick + powód + kto dodał)
- Pokazuje **czerwoną czaszkę** na nameplate i przy targetcie
- Wyświetla alert + dźwięk gdy ktoś z listy pojawi się w pobliżu
- Komenda `/hl` lub `/huntlista` → okno z całą listą
- Dane aktualizowane z GitHuba (przez Discord bota)
- Od 1.3.9: własne zabójstwa graczy z listy (także przez peta) wykrywane przez `PARTY_KILL`, z lokalnym licznikiem i powiadomieniem gildii. Ukryte dane i brak pełnego nicku są pomijane; `/hl status` pokazuje diagnostykę. Wspólny ranking nadal aktualizuje `/hunt kill Nick` na Discordzie.

## Instalacja

1. Skopiuj folder `HuntLista` do:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
2. Włącz addon na ekranie wyboru postaci.

Przy aktualizacji pobierz cały folder, również `KillDetection.lua` i `HuntLista.toc`, i uruchom ponownie grę. Updater danych nie aktualizuje kodu. Szczegóły i próba w grze: [wykrywanie zabójstw](../docs/forever-kill-detection.md).

## Aktualizacja listy (zalecane)

Użyj **Updatera** (folder `updater/` w repo):

1. Skopiuj folder `updater` np. na Pulpit
2. Dwuklik na `Update-HuntLista.bat`
3. W grze `/reload`

Updater sam ściąga najnowszy `Data.lua` z GitHuba i nadpisuje plik w folderze addona.

## Komendy w grze

| Komenda          | Co robi                  |
|------------------|--------------------------|
| `/hl`            | Otwiera listę            |
| `/hl status`     | Wersja danych + liczba   |
| `/reload`        | Wczytuje nowe dane z dysku |
| `/hl reload`     | Przypomina o użyciu `/reload` |
| `/hl killreset Nick` | Zeruje lokalny licznik pełnego nicku |
| `/hl killreset all confirm` | Zeruje wszystkie lokalne liczniki |

## Jak działa aktualizacja

1. Ktoś na Discordzie używa `/hunt add Nick "powód"`
2. Bot aktualizuje plik `Data.lua` na GitHubie
3. Gracze odpalają **Update-HuntLista.bat** (albo ściągają ręcznie)
4. W grze `/reload`

---

## Discord Bot

Osobny folder `HuntListaBot`.

### Setup bota

1. Stwórz aplikację na https://discord.com/developers/applications
2. Bot → Reset Token → skopiuj token
3. OAuth2 → URL Generator → scopes: `bot`, `applications.commands` → uprawnienia: Send Messages
4. Zaproś bota na serwer

### Setup GitHuba

1. Repo: https://github.com/frethborn/HuntLista
2. Personal Access Token (classic) z uprawnieniem `repo`
3. W `.env` ustaw `GITHUB_OWNER=frethborn` i `GITHUB_REPO=HuntLista`

### Uruchomienie

```bash
cd HuntListaBot
cp .env.example .env
# uzupełnij .env, w tym wymagane CLIENT_ID i GUILD_ID
npm install
npm start
```

### Komendy bota

- `/hunt add <nick> [powód]`
- `/hunt remove <nick>`
- `/hunt list [strona]`
- `/hunt info <nick>`
- `/hunt kills [strona]`

Komendy działają wyłącznie na serwerze wskazanym przez `GUILD_ID`. Domyślnie zapis jest dostępny administratorom; opcjonalne `CONTRIBUTOR_ROLE_IDS` i `MODERATOR_ROLE_IDS` nadają dostęp do odpowiednich operacji. Szczegóły uprawnień i migracji: [główne README](../README.md#discord-bot-dla-adminów).

Po każdej zmianie bot pushuje nowy `Data.lua` na GitHub.
