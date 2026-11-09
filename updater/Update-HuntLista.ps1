# ============================================================
# Hunt Lista - Updater
# Pobiera najnowszy Data.lua z GitHuba i nadpisuje lokalny plik.
# ============================================================

$ErrorActionPreference = "Stop"

# --- KONFIGURACJA ---
$RepoOwner   = "frethborn"
$RepoName    = "HuntLista"
$DataPathInRepo = "HuntLista/Data.lua"
$RawUrl      = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$DataPathInRepo"

# Domyślne ścieżki instalacji WoW Forever (kolejność sprawdzania)
$PossiblePaths = @(
    "${env:ProgramFiles(x86)}\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
    "${env:ProgramFiles}\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
    "$env:USERPROFILE\Games\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
    "D:\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
    "E:\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
    "C:\Games\World of Warcraft\_forever_\Interface\AddOns\HuntLista"
)

# Plik z zapisaną ścieżką (żeby nie pytać za każdym razem)
$ConfigFile = Join-Path $PSScriptRoot "updater-config.txt"

function Write-Title {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║       HUNT LISTA  •  UPDATER         ║" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

function Find-AddonFolder {
    # 1. Zapisana ścieżka
    if (Test-Path $ConfigFile) {
        $saved = (Get-Content $ConfigFile -Raw).Trim()
        if ($saved -and (Test-Path $saved)) {
            return $saved
        }
    }

    # 2. Typowe lokalizacje
    foreach ($p in $PossiblePaths) {
        if (Test-Path $p) {
            return $p
        }
    }

    # 3. Szukamy po dyskach (tylko raz, może chwilę potrwać)
    Write-Host "  Szukam folderu HuntLista..." -ForegroundColor Yellow
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
    foreach ($d in $drives) {
        $candidate = Join-Path $d.Root "World of Warcraft\_forever_\Interface\AddOns\HuntLista"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Ask-ForPath {
    Write-Host "  Nie znaleziono folderu addona automatycznie." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Podaj pełną ścieżkę do folderu HuntLista, np.:" -ForegroundColor Gray
    Write-Host "  C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\HuntLista" -ForegroundColor DarkGray
    Write-Host ""
    $inputPath = Read-Host "  Ścieżka"
    $inputPath = $inputPath.Trim().Trim('"')

    if (-not (Test-Path $inputPath)) {
        Write-Host "  [BŁĄD] Taka ścieżka nie istnieje." -ForegroundColor Red
        return $null
    }
    return $inputPath
}

# --- GŁÓWNA LOGIKA ---
Write-Title

$addonDir = Find-AddonFolder
if (-not $addonDir) {
    $addonDir = Ask-ForPath
    if (-not $addonDir) {
        Write-Host "  Anulowano." -ForegroundColor Red
        Read-Host "  Naciśnij Enter, aby zamknąć"
        exit 1
    }
}

# Zapisz ścieżkę na przyszłość
$addonDir | Set-Content -Path $ConfigFile -Encoding UTF8

$targetFile = Join-Path $addonDir "Data.lua"

Write-Host "  Folder addona : $addonDir" -ForegroundColor Cyan
Write-Host "  Źródło        : $RawUrl" -ForegroundColor DarkGray
Write-Host ""

# Backup starego pliku
if (Test-Path $targetFile) {
    $backup = Join-Path $addonDir "Data.lua.bak"
    Copy-Item $targetFile $backup -Force
    Write-Host "  ✓ Stary Data.lua zapisany jako Data.lua.bak" -ForegroundColor DarkGray
}

# Pobieranie
Write-Host "  Pobieram najnowszą listę..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $RawUrl -UseBasicParsing -TimeoutSec 20
    $content  = $response.Content

    if ($content -notmatch "HuntLista_Data") {
        throw "Pobrany plik nie wygląda na poprawny Data.lua"
    }

    # Zapis
    [System.IO.File]::WriteAllText($targetFile, $content, [System.Text.UTF8Encoding]::new($false))

    # Wyciągnij wersję z pliku
    $version = "nieznana"
    if ($content -match 'version\s*=\s*"([^"]+)"') {
        $version = $Matches[1]
    }
    $lastUpdate = ""
    if ($content -match 'lastUpdate\s*=\s*"([^"]+)"') {
        $lastUpdate = $Matches[1]
    }

    Write-Host ""
    Write-Host "  ══════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✓  AKTUALIZACJA UDANA" -ForegroundColor Green
    Write-Host "  ══════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Wersja danych : $version" -ForegroundColor White
    if ($lastUpdate) {
        Write-Host "  Ostatnia zmiana: $lastUpdate" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  W grze wpisz:  /reload" -ForegroundColor Yellow
    Write-Host "  (lub wyloguj i zaloguj)" -ForegroundColor DarkGray
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "  [BŁĄD] Nie udało się pobrać pliku:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Sprawdź internet / czy repo istnieje:" -ForegroundColor Yellow
    Write-Host "  https://github.com/$RepoOwner/$RepoName" -ForegroundColor Cyan
    Write-Host ""
}

Read-Host "  Naciśnij Enter, aby zamknąć"
