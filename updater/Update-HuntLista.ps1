# ============================================================
# Hunt Lista - Updater v1.2
# ============================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$RepoOwner      = "frethborn"
$RepoName       = "HuntLista"
$DataPathInRepo = "HuntLista/Data.lua"
# cache-bust - GitHub raw czasem trzyma stary plik kilka minut
$RawUrl         = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$DataPathInRepo?t=$(Get-Date -UFormat %s)"
$ConfigFile     = Join-Path $PSScriptRoot "updater-config.txt"

function Pause-Exit($code = 0) {
    Write-Host ""
    Read-Host "  Nacisnij Enter, aby zamknac"
    exit $code
}

function Write-Title {
    Clear-Host
    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor Red
    Write-Host "       HUNT LISTA  -  UPDATER v1.2" -ForegroundColor Red
    Write-Host "  ======================================" -ForegroundColor Red
    Write-Host ""
}

function Download-Text($url) {
    # 1) Invoke-WebRequest
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
        if ($resp.Content) { return [string]$resp.Content }
    } catch {
        Write-Host "  Invoke-WebRequest fail: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }

    # 2) WebClient
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "HuntLista-Updater/1.2")
        $txt = $wc.DownloadString($url)
        if ($txt) { return [string]$txt }
    } catch {
        Write-Host "  WebClient fail: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }

    # 3) curl.exe (Windows 10+)
    try {
        $tmp = Join-Path $env:TEMP "huntlista-data.lua"
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if ($curl) {
            & curl.exe -fsSL $url -o $tmp
            if (Test-Path $tmp) {
                $txt = [System.IO.File]::ReadAllText($tmp)
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                if ($txt) { return $txt }
            }
        }
    } catch {
        Write-Host "  curl fail: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }

    throw "Nie udalo sie pobrac pliku zadna metoda"
}

Write-Title

# --- Szukanie folderu addona ---
$addonDir = $null
$forceAsk = $false

if ($args -contains "-reset") {
    if (Test-Path $ConfigFile) { Remove-Item $ConfigFile -Force }
    Write-Host "  Zresetowano zapisana sciezke." -ForegroundColor Yellow
    $forceAsk = $true
}

if (-not $forceAsk -and (Test-Path $ConfigFile)) {
    $saved = (Get-Content $ConfigFile -Raw -ErrorAction SilentlyContinue)
    if ($saved) {
        $saved = $saved.Trim().Trim([char]0xFEFF)
        if ($saved -and (Test-Path $saved)) {
            $addonDir = $saved
            Write-Host "  Znaleziono zapisana sciezke." -ForegroundColor DarkGray
        } else {
            Write-Host "  Zapisana sciezka jest nieaktualna - podaj nowa." -ForegroundColor Yellow
        }
    }
}

if (-not $addonDir) {
    $candidates = @(
        "${env:ProgramFiles(x86)}\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "${env:ProgramFiles}\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "$env:USERPROFILE\Games\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "D:\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "E:\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "C:\Games\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "D:\Games\World of Warcraft\_forever_\Interface\AddOns\HuntLista",
        "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\HuntLista"
    )

    foreach ($p in $candidates) {
        if (Test-Path $p) {
            $addonDir = $p
            Write-Host "  Automatycznie znaleziono folder addona." -ForegroundColor DarkGray
            break
        }
    }
}

if (-not $addonDir) {
    Write-Host "  Nie znaleziono folderu HuntLista automatycznie." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Podaj PELNA sciezke do folderu HuntLista." -ForegroundColor Gray
    Write-Host "  Przyklad:" -ForegroundColor DarkGray
    Write-Host "  C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\HuntLista" -ForegroundColor DarkGray
    Write-Host ""
    $inputPath = Read-Host "  Sciezka"
    $inputPath = $inputPath.Trim().Trim('"').Trim("'")

    if (-not $inputPath -or -not (Test-Path $inputPath)) {
        Write-Host ""
        Write-Host "  [BLAD] Taka sciezka nie istnieje." -ForegroundColor Red
        Pause-Exit 1
    }
    $addonDir = $inputPath
}

try {
    $addonDir | Set-Content -Path $ConfigFile -Encoding UTF8 -Force
} catch {}

$targetFile = Join-Path $addonDir "Data.lua"

Write-Host ""
Write-Host "  Folder addona : $addonDir" -ForegroundColor Cyan
Write-Host "  Plik docelowy : $targetFile" -ForegroundColor DarkGray
Write-Host "  Zrodlo        : https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$DataPathInRepo" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $addonDir)) {
    Write-Host "  [BLAD] Folder addona nie istnieje:" -ForegroundColor Red
    Write-Host "  $addonDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Usun plik updater-config.txt i sprobuj ponownie" -ForegroundColor Yellow
    Write-Host "  albo odpal: Update-HuntLista.bat -reset" -ForegroundColor Yellow
    Pause-Exit 1
}

# Backup
if (Test-Path $targetFile) {
    try {
        Copy-Item $targetFile (Join-Path $addonDir "Data.lua.bak") -Force
        Write-Host "  OK  Backup: Data.lua.bak" -ForegroundColor DarkGray
    } catch {
        Write-Host "  UWAGA backup: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "  Pobieram najnowsza liste z GitHuba..." -ForegroundColor Yellow

try {
    $content = Download-Text $RawUrl

    if (-not $content -or ($content -notmatch "HuntLista_Data")) {
        throw "Pobrany plik nie wyglada na Data.lua (brak HuntLista_Data). Cache GitHuba? Sprobuj za 1 min."
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    try {
        [System.IO.File]::WriteAllText($targetFile, $content, $utf8NoBom)
    } catch {
        throw "Nie moge zapisac do: $targetFile`n  $($_.Exception.Message)`n  Odpal BAT jako Administrator."
    }

    # Weryfikacja zapisu
    $verify = [System.IO.File]::ReadAllText($targetFile)
    if ($verify -notmatch "HuntLista_Data") {
        throw "Zapisano plik, ale weryfikacja nie widzi HuntLista_Data"
    }

    $version = "?"
    $lastUpdate = ""
    if ($content -match 'version\s*=\s*"([^"]+)"') { $version = $Matches[1] }
    if ($content -match 'lastUpdate\s*=\s*"([^"]+)"') { $lastUpdate = $Matches[1] }

    $playerNames = [regex]::Matches($content, '\["([^"]+)"\]\s*=') | ForEach-Object { $_.Groups[1].Value }
    $playerCount = $playerNames.Count

    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor Green
    Write-Host "   AKTUALIZACJA UDANA" -ForegroundColor Green
    Write-Host "  ======================================" -ForegroundColor Green
    Write-Host "  Wersja danych   : $version" -ForegroundColor White
    if ($lastUpdate) {
        Write-Host "  Ostatnia zmiana : $lastUpdate" -ForegroundColor White
    }
    Write-Host "  Graczy na liscie: $playerCount" -ForegroundColor White
    if ($playerCount -gt 0) {
        Write-Host "  Nicki:" -ForegroundColor DarkGray
        foreach ($n in $playerNames) {
            Write-Host "    - $n" -ForegroundColor Gray
        }
    }
    Write-Host ""
    Write-Host "  W grze wpisz:  /reload" -ForegroundColor Yellow
    Write-Host "  Potem:         /hl status" -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "  [BLAD] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Co sprobowac:" -ForegroundColor Yellow
    Write-Host "  1. Usun updater-config.txt i odpal ponownie" -ForegroundColor Gray
    Write-Host "  2. Odpal BAT jako Administrator" -ForegroundColor Gray
    Write-Host "  3. Sprawdz w przegladarce:" -ForegroundColor Gray
    Write-Host "     https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/$DataPathInRepo" -ForegroundColor DarkGray
    Write-Host ""
    Pause-Exit 1
}

Pause-Exit 0
