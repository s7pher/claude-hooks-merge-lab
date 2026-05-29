<#
  verify-acls.ps1 — document the premise behind the merge test: are the managed
  settings file and the hook-script directory actually out of reach for the user
  context Claude runs as?

  Usage:  powershell -File tools\verify-acls.ps1 "C:\path\to\protected\hook\dir"

  Run this AS the account Claude Code runs under. "Write-protected" only means
  anything relative to a specific principal.
#>
param(
  [string]$HookDir
)

$managed = "C:\ProgramData\ClaudeCode\managed-settings.json"

Write-Host "=== Managed settings file: $managed ==="
if (Test-Path $managed) {
  icacls $managed
} else {
  Write-Host "Not present at this path."
}

if ($HookDir) {
  Write-Host ""
  Write-Host "=== Hook-script directory: $HookDir ==="
  if (Test-Path $HookDir) {
    icacls $HookDir
  } else {
    Write-Host "Not present at this path."
  }
}

Write-Host ""
Write-Host "=== Current identity / groups (whoami /all) ==="
whoami /all
