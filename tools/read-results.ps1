<#
  read-results.ps1 — print the beacon log and summarise which sources fired.
#>
$log = Join-Path $env:TEMP "aa06-beacon.log"

if (-not (Test-Path $log)) {
  Write-Host "No beacon log at $log — no hooks fired."
  exit 0
}

Write-Host "=== AA-06 beacon log ($log) ==="
Get-Content $log

Write-Host ""
Write-Host "=== Sources that fired (unique) ==="
Get-Content $log | ForEach-Object {
  if ($_ -match 'source=(\S+)') { $matches[1] }
} | Sort-Object -Unique
