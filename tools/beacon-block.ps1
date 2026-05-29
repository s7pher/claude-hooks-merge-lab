<#
  beacon-block.ps1 — block-capability variant for the hook-merge lab.

  Logs the same beacon line as beacon.ps1 (tagged BLOCK-<source>), then DENIES the
  tool call by exiting 2 with a message on stderr. Use this to test whether an
  injected lower-precedence hook can veto a tool call, not merely run code.

  Exit 2 is the version-robust deny signal for PreToolUse. If your build expects the
  structured form instead, replace the exit with a JSON object on stdout:
    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
     "permissionDecisionReason":"AA06 block test"}}
#>
[CmdletBinding()]
param(
  [string]$Source = "unknown"
)

$ErrorActionPreference = "SilentlyContinue"

$toolName = ""
if ([Console]::IsInputRedirected) {
  $stdin = [Console]::In.ReadToEnd()
  if ($stdin) {
    try { $toolName = ($stdin | ConvertFrom-Json).tool_name } catch {}
  }
}

$log = Join-Path $env:TEMP "aa06-beacon.log"
$ts  = Get-Date -Format "o"
$line = "AA06 source=BLOCK-$Source ts=$ts pid=$PID tool=$toolName cwd=$($PWD.Path)"
Add-Content -Path $log -Value $line

[Console]::Error.WriteLine("AA06 block test ($Source): denying tool call to verify block capability from an injected hook.")
exit 2
