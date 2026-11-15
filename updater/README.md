# Hunt Lista – Updater

Prosty programik do aktualizacji listy graczy **bez ręcznego ściągania** z GitHuba.

## Jak używać

1. Skopiuj cały folder `updater`, w tym `HuntLista-Data.ps1`, gdzie chcesz (np. na Pulpit).
2. **Dwuklik** na `Update-HuntLista.bat`
3. Za pierwszym razem może zapytać o ścieżkę do folderu `HuntLista` (jeśli nie znajdzie automatycznie).
4. Gotowe – w grze `/reload`.

## Co robi

- Pobiera najnowszy `Data.lua` z repozytorium:  
  https://github.com/frethborn/HuntLista
- Sprawdza UTF-8, składnię i strukturę danych bez wykonywania kodu Lua
- Podmienia poprawny plik atomowo; błędne pobranie nie zmienia zainstalowanych danych
- Zachowuje poprzedni poprawny plik jako `Data.lua.bak`; uszkodzony lokalny plik nie nadpisuje tej kopii
- Pokazuje wersję danych
- Blokuje równoległe pobieranie i zapis tego samego pliku przez nowe wersje obu updaterów; po 3 sekundach oczekiwania zgłasza zajętość, bez zmiany danych

## Wymagania

- Windows 10 / 11
- PowerShell (jest wbudowany)
- Internet

Walidacja używa wbudowanego .NET i obsługuje format danych generowany przez bota. Nie wymaga Node.js ani Lua. Po błędzie sprawdź komunikat updatera; nie zastępuj działającej listy ręcznie niezweryfikowanym pobraniem.

Przy aktualizacji pobierz nowy helper także do Auto Updatera, jeśli go używasz. Starsze wersje nie respektują blokady między procesami.

## Uwagi

- Ścieżka do addona jest zapamiętywana w pliku `updater-config.txt` (obok skryptu).
- Jeśli przeniesiesz WoW, usuń `updater-config.txt` – updater zapyta ponownie.
