param(
    [string]$TaskName = "Bude Roadmap Agent Hourly",
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$AgentCommand = "codex",
    [switch]$AllowDirtyStart,
    [switch]$NoPush,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Runner = Join-Path $RepoRoot "scripts\run-hourly-roadmap-agent.ps1"
if (-not (Test-Path -LiteralPath $Runner)) {
    throw "Runner script not found: $Runner"
}

$args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$Runner`"",
    "-RepoRoot", "`"$RepoRoot`"",
    "-AgentCommand", "`"$AgentCommand`""
)
if ($AllowDirtyStart) { $args += "-AllowDirtyStart" }
if ($NoPush) { $args += "-NoPush" }
if ($SkipValidation) { $args += "-SkipValidation" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ($args -join " ")
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(5) `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Reads ROADMAP.md hourly, lets Codex implement one bounded increment, validates, commits, and pushes." `
    -Force | Out-Null

Write-Host "Installed scheduled task '$TaskName'."
Write-Host "Logs will be written under: $RepoRoot\.automation\roadmap-agent\logs"
Write-Host "Note: by default the runner refuses to start from a dirty working tree."
