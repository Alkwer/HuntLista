# Hunt Lista - Auto Updater

Prosty program z oknem (Windows), ktory co X minut sciaga `Data.lua` z GitHuba
i nadpisuje plik w folderze addona.

## Start

1. Pobierz folder `auto-updater`
2. Dwuklik **`Start-AutoUpdater.bat`**
3. Sprawdz / wybierz sciezke do folderu `HuntLista`
4. Ustaw interwal (np. 5 minut)
5. **Update teraz** = jednorazowo
6. **Start auto** = petla co X minut

## Po update

W grze: `/reload` albo `/hl reload`

## Uwagi

- Program musi byc uruchomiony w tle podczas gry
- WoW nie moze sam sciagac plikow z internetu - dlatego to zewnetrzny tool
- Wymaga Windows + PowerShell (wbudowany w system)
