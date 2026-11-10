# Hunt Lista

Gildyjny addon do **WoW Forever** — wspólna lista graczy PvP do oznaczania ("hunt list").

Gdy ktoś z listy pojawi się w grze, dostajesz **alert**, **dźwięk** i **czerwoną czaszkę** przy nameplate / targetcie.
Po śmierci wyskakuje **okienko z nickiem zabójcy** do skopiowania.

Lista jest wspólna dla gildii: dodajecie ludzi przez **bota na Discordzie**, a addon ściąga aktualne dane z tego repo.

---

## Funkcje

| Funkcja | Opis |
|--------|------|
| Lista hunt | Wspólna baza graczy (nick + powód + kto dodał) |
| Czaszka na nameplate | Czerwona ikona przy osobach z listy |
| Alert + dźwięk | Raid warning gdy ktoś z listy jest w pobliżu / na targetcie |
| Okno listy | `/hl` — podgląd całej listy |
| Okienko po śmierci | Nick zabójcy do skopiowania (Ctrl+C) |
| Updater | Skrypt Windows ściągający `Data.lua` z GitHuba |
| Discord bot | `/hunt add` / `remove` / `list` → automatyczny push na GitHub |
| Tryb testowy | Alerty także na sojusznikach (do testów) |

---

## Instalacja addona

1. Pobierz folder [`HuntLista/`](https://github.com/frethborn/HuntLista/tree/main/HuntLista)  
   albo release z zakładki **Releases** (jeśli jest).
2. Wrzuć folder `HuntLista` do:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
3. Na ekranie wyboru postaci włącz **Hunt Lista**.
4. W grze: `/hl` — powinno otworzyć listę.

W folderze addona muszą być m.in.:
```
HuntLista.toc
Data.lua
Core.lua
UI.lua
Alerts.lua
Death.lua
```

---

## Komendy w grze

| Komenda | Opis |
|--------|------|
| `/hl` | Otwiera listę huntowanych graczy |
| `/hl status` | Wersja addona, wersja danych, liczba graczy, status modułów |
| `/hl reload` | Przeładowuje listę z `Data.lua` (bez `/reload` gry) |
| `/hl test` | **Tryb testowy ON** — alertuje też sojuszników |
| `/hl test off` | Tryb testowy OFF — tylko wroga frakcja |
| `/hl death` | Włącza okienko po śmierci |
| `/hl death off` | Wyłącza okienko po śmierci |
| `/hl killer` | Test okienka zabójcy (target albo przykładowy nick) |
| `/hl killer Nick` | Test okienka z podanym nickiem |
| `/hl check` | Debug: target / mouseover — czy jest na liście |
| `/hl debug` | Włącza/wyłącza logi w chacie |
| `/hl close` | Zamyka okienko zabójcy |

Alias: `/huntlista` działa tak samo jak `/hl`.

---

## Aktualizacja listy graczy

Lista żyje w `HuntLista/Data.lua`. Gdy ktoś doda osobę przez Discord, plik zmienia się na GitHubie — trzeba go zaciągnąć do gry.

### Opcja A — Updater (zalecane)

1. Pobierz folder [`updater/`](https://github.com/frethborn/HuntLista/tree/main/updater)
2. Odpal **`Update-HuntLista.bat`**
3. W grze: `/reload` (albo `/hl reload`)

### Opcja B — ręcznie

1. Pobierz [Data.lua](https://raw.githubusercontent.com/frethborn/HuntLista/main/HuntLista/Data.lua)
2. Nadpisz `Interface\AddOns\HuntLista\Data.lua`
3. W grze: `/reload`

---

## Flow w gildii

```
Discord  →  /hunt add Nick "powod"
    ↓
Bot zapisuje Data.lua na GitHubie
    ↓
Gracze odpalaja updater (albo sciagaja Data.lua)
    ↓
W grze /reload  →  czaszka + alert dzialaja
```

Po śmierci przeciwnika:
```
Smierc → okienko z nickiem → Ctrl+C → /hunt add na Discordzie
```

---

## Discord bot (dla adminów)

Folder: [`HuntListaBot/`](https://github.com/frethborn/HuntLista/tree/main/HuntListaBot)

### Komendy na Discordzie

| Komenda | Opis |
|--------|------|
| `/hunt add <nick> [powód]` | Dodaje gracza na listę |
| `/hunt remove <nick>` | Usuwa z listy |
| `/hunt list` | Pokazuje aktualną listę |
| `/hunt info <nick>` | Szczegóły wpisu |

### Szybki setup

1. [Discord Developer Portal](https://discord.com/developers/applications) — stwórz bota, skopiuj token
2. Zaproś bota (scope: `bot` + `applications.commands`)
3. GitHub → Personal Access Token z uprawnieniem `repo`
4. W folderze bota:
   ```bash
   cp .env.example .env
   # uzupelnij DISCORD_TOKEN, GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO
   npm install
   npm start
   ```

---

## Struktura repo

```
HuntLista/          ← addon do skopiowania do AddOns
  HuntLista.toc
  Core.lua          ← komendy, lookup listy
  Alerts.lua        ← czaszka, dzwieki, nameplate
  UI.lua            ← okno listy /hl
  Death.lua         ← okienko po smierci
  Data.lua          ← lista graczy (aktualizowana przez bota)
HuntListaBot/       ← bot Discord + push na GitHub
updater/            ← skrypt Windows do sciagania Data.lua
```

---

## Uwagi (WoW Forever)

- Nicki ze **spacją** (np. `Mega Chad`) — gra często zwraca tylko pierwsze słowo w API; addon stara się je uzupełniać z nameplate’ów i listy.
- Domyślnie alerty tylko na **przeciwną frakcję**. Do testów: `/hl test`.
- Po zmianie `Data.lua` zawsze `/reload` albo `/hl reload`.
- Czerwony komunikat Blizzarda o „blocked action” przy śmierci — kliknij **Ignore**; na listę i czaszkę nie wpływa.
- W `Death.lua` eventy wpinają się z lekkim opóźnieniem po logowaniu (omija błędy protected `RegisterEvent` na Forever).

---

**Repo:** [frethborn/HuntLista](https://github.com/frethborn/HuntLista)
