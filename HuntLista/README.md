# Hunt Lista

Gildyjny addon do oznaczania konkretnych graczy PvP w **WoW Forever**.

## Co robi

- Trzyma listę graczy (nick + powód + kto dodał)
- Pokazuje **czerwoną czaszkę** na nameplate i przy targetcie
- Wyświetla alert + dźwięk gdy ktoś z listy pojawi się w pobliżu
- Komenda `/hl` lub `/huntlista` → okno z całą listą
- Dane aktualizowane z GitHuba (przez Discord bota)

## Instalacja

1. Skopiuj folder `HuntLista` do:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
2. Włącz addon na ekranie wyboru postaci.
3. Po aktualizacji danych przez bota → pobierz nowy `Data.lua` z repo i nadpisz w folderze addona, potem `/reload`.

## Komendy w grze

| Komenda          | Co robi                  |
|------------------|--------------------------|
| `/hl`            | Otwiera listę            |
| `/hl status`     | Wersja danych + liczba   |
| `/hl reload`     | Przeładowuje lookup      |

## Jak działa aktualizacja

1. Ktoś na Discordzie używa `/hunt add Nick "powód"`
2. Bot aktualizuje plik `Data.lua` na GitHubie
3. Gracze ściągają nowy `Data.lua` (albo cały addon) i wrzucają do folderu
4. W grze `/reload` lub relog

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
# uzupełnij .env
npm install
npm start
```

### Komendy bota

- `/hunt add <nick> [powód]`
- `/hunt remove <nick>`
- `/hunt list`
- `/hunt info <nick>`

Po każdej zmianie bot pushuje nowy `Data.lua` na GitHub.
