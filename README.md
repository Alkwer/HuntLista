# Hunt Lista

Gildyjny addon do **WoW Forever** — lista graczy PvP do oznaczania ("hunt list").

Gdy ktoś z listy pojawi się w grze, dostajesz **alert**, **dźwięk** i **czerwoną czaszkę** przy nameplate / targetcie.

Lista jest wspólna dla gildii: dodajecie ludzi przez **bota na Discordzie**, a addon ściąga aktualne dane z tego repo.

---

## Instalacja addona

1. Pobierz najnowszy release: **[Releases](https://github.com/frethborn/HuntLista/releases)**  
   albo folder [`HuntLista/`](https://github.com/frethborn/HuntLista/tree/main/HuntLista) z repo.
2. Wrzuć folder `HuntLista` do:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
3. Na ekranie wyboru postaci włącz **Hunt Lista**.
4. W grze wpisz `/hl` — powinno otworzyć się okno z listą.

---

## Komendy w grze

| Komenda | Opis |
|--------|------|
| `/hl` | Otwiera listę huntowanych graczy |
| `/hl status` | Wersja danych, liczba graczy, status |
| `/hl reload` | Przeładowuje listę z `Data.lua` |
| `/hl test` | **Tryb testowy** — alertuje też sojuszników (do testów) |
| `/hl test off` | Wyłącza tryb testowy (tylko wrogowie) |
| `/hl check` | Debug: sprawdza aktualny target / mouseover |
| `/hl debug` | Włącza/wyłącza logi w chacie |

---

## Aktualizacja listy graczy

Lista żyje w pliku `HuntLista/Data.lua`. Gdy ktoś doda osobę przez Discord, plik zmienia się na GitHubie — trzeba go zaciągnąć do gry.

### Opcja A — Updater (zalecane)

1. Pobierz folder [`updater/`](https://github.com/frethborn/HuntLista/tree/main/updater)
2. Odpal **`Update-HuntLista.bat`** (dwuklik)
3. W grze: `/reload`

### Opcja B — ręcznie

1. Pobierz [Data.lua](https://raw.githubusercontent.com/frethborn/HuntLista/main/HuntLista/Data.lua)
2. Nadpisz plik w `Interface\AddOns\HuntLista\Data.lua`
3. W grze: `/reload`

---

## Jak wygląda flow w gildii

```
Discord  →  /hunt add Nick "powod"
    ↓
Bot zapisuje Data.lua na GitHubie
    ↓
Gracze odpalaja updater (albo sciagaja Data.lua)
    ↓
W grze /reload  →  czaszka + alert dzialaja
```

---

## Discord bot (dla adminów gildii)

Folder: [`HuntListaBot/`](https://github.com/frethborn/HuntLista/tree/main/HuntListaBot)

### Komendy na Discordzie

| Komenda | Opis |
|--------|------|
| `/hunt add <nick> [powód]` | Dodaje gracza na listę |
| `/hunt remove <nick>` | Usuwa z listy |
| `/hunt list` | Pokazuje aktualną listę |
| `/hunt info <nick>` | Szczegóły wpisu |

### Szybki setup bota

1. Stwórz aplikację: [Discord Developer Portal](https://discord.com/developers/applications)
2. Bot → skopiuj token
3. Zaproś bota na serwer (scope: `bot` + `applications.commands`)
4. GitHub → Personal Access Token z uprawnieniem `repo`
5. W folderze bota:
   ```bash
   cp .env.example .env
   # uzupelnij DISCORD_TOKEN, GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO
   npm install
   npm start
   ```

Szczegóły: [`HuntListaBot/.env.example`](https://github.com/frethborn/HuntLista/blob/main/HuntListaBot/.env.example)

---

## Struktura repo

```
HuntLista/          ← addon do skopiowania do AddOns
  HuntLista.toc
  Core.lua
  Alerts.lua
  UI.lua
  Data.lua          ← lista graczy (aktualizowana przez bota)
HuntListaBot/       ← bot Discord + push na GitHub
updater/            ← skrypt Windows do sciagania Data.lua
```

---

## Uwagi (WoW Forever)

- Nicki ze spacją (np. `Mega Chad`) — gra czasem zwraca tylko pierwsze słowo; addon to obsługuje.
- Domyślnie alerty tylko na **przeciwną frakcję**. Do testów na sojusznikach: `/hl test`.
- Po zmianie `Data.lua` zawsze `/reload` w grze.

---

**Autor / repo:** [frethborn/HuntLista](https://github.com/frethborn/HuntLista)
