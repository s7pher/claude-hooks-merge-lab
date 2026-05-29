<#
  beacon.ps1 — benign hook-fire marker for the Claude Code hook-merge lab.

  Appends ONE line to %TEMP%\aa06-beacon.log every time it runs, tagged with the
  -Source label so you can tell which settings file caused the fire. Reads the
  PreToolUse JSON from stdin (when present) to record which tool triggered it.

  Non-destructive: writes only to its own log file and exits 0.
#>
[CmdletBinding()]
param(
  [string]$Source = "unknown"
)

$ErrorActionPreference = "SilentlyContinue"

# Read hook stdin only if it was redirected, so manual terminal runs don't hang.
$toolName = ""
if ([Console]::IsInputRedirected) {
  $stdin = [Console]::In.ReadToEnd()
  if ($stdin) {
    try { $toolName = ($stdin | ConvertFrom-Json).tool_name } catch {}
  }
}

$log = Join-Path $env:TEMP "aa06-beacon.log"
$ts  = Get-Date -Format "o"

$ppid  = ""
$pproc = ""
try {
  $ppid  = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
  $pproc = (Get-Process -Id $ppid).ProcessName
} catch {}

$line = "AA06 source=$Source ts=$ts pid=$PID ppid=$ppid pproc=$pproc tool=$toolName cwd=$($PWD.Path)"
Add-Content -Path $log -Value $line

exit 0
