# Hunt Lista – Updater

Prosty programik do aktualizacji listy graczy **bez ręcznego ściągania** z GitHuba.

## Jak używać

1. Skopiuj cały folder `updater` gdzie chcesz (np. na Pulpit).
2. **Dwuklik** na `Update-HuntLista.bat`
3. Za pierwszym razem może zapytać o ścieżkę do folderu `HuntLista` (jeśli nie znajdzie automatycznie).
4. Gotowe – w grze `/reload`.

## Co robi

- Pobiera najnowszy `Data.lua` z repozytorium:  
  https://github.com/frethborn/HuntLista
- Nadpisuje plik w Twoim folderze addona
- Robi kopię zapasową starego pliku (`Data.lua.bak`)
- Pokazuje wersję danych

## Wymagania

- Windows 10 / 11
- PowerShell (jest wbudowany)
- Internet

## Uwagi

- Ścieżka do addona jest zapamiętywana w pliku `updater-config.txt` (obok skryptu).
- Jeśli przeniesiesz WoW, usuń `updater-config.txt` – updater zapyta ponownie.
