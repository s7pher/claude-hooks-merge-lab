<#
  cleanup.ps1 — remove the beacon log between runs / at teardown.
#>
$log = Join-Path $env:TEMP "aa06-beacon.log"
Remove-Item $log -ErrorAction SilentlyContinue
Write-Host "Removed $log (if it existed)."
Write-Host "Reminder: also remove .claude\settings.json and .claude\settings.local.json"
Write-Host "from any project you dropped them into, and restore/clear the managed file if you populated it."
