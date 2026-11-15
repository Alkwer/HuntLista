param([string]$Helper, [string]$Directory, [string]$Role)
$ErrorActionPreference = 'Stop'
. $Helper
function Invoke-WebRequest {
    param($Uri, [switch]$UseBasicParsing, $TimeoutSec, $OutFile, $ErrorAction)
    [System.IO.File]::Copy((Join-Path $Directory 'remote.lua'), $OutFile, $true)
    [System.IO.File]::WriteAllText((Join-Path $Directory ($Role + '.download')), 'ready')
    if ($Role -eq 'first') {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not [System.IO.File]::Exists((Join-Path $Directory 'release'))) {
            if ($watch.Elapsed.TotalSeconds -gt 15) { throw 'Fixture release timed out' }
            Start-Sleep -Milliseconds 20
        }
    }
}
[System.IO.File]::WriteAllText((Join-Path $Directory ($Role + '.started')), 'ready')
try {
    $info = Update-HuntListaData -Uri 'https://unused.invalid/' -TargetPath (Join-Path $Directory 'Data.lua')
    Write-Output $info.Version
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
