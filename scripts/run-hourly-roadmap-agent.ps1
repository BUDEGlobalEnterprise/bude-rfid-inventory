param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$AgentCommand = "codex",
    [switch]$AllowDirtyStart,
    [switch]$NoPush,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$RunRoot = Join-Path $RepoRoot ".automation\roadmap-agent"
$LogRoot = Join-Path $RunRoot "logs"
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $LogRoot "run-$Stamp.log"
$SummaryFile = Join-Path $RunRoot "last-summary.md"
$PromptFile = Join-Path $RunRoot "prompt-$Stamp.md"
$LockFile = Join-Path $RunRoot "roadmap-agent.lock"

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "s"), $Message
    $line | Tee-Object -FilePath $LogFile -Append
}

function Invoke-External {
    param(
        [string]$Name,
        [scriptblock]$Command
    )
    Write-Log "START: $Name"
    & $Command *>&1 | Tee-Object -FilePath $LogFile -Append
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
    Write-Log "DONE: $Name"
}

function Get-GitStatus {
    Push-Location $RepoRoot
    try {
        return @(& git status --porcelain --untracked-files=all)
    }
    finally {
        Pop-Location
    }
}

New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
if (Test-Path -LiteralPath $LockFile) {
    $age = (Get-Date) - (Get-Item -LiteralPath $LockFile).LastWriteTime
    if ($age.TotalHours -lt 3) {
        Write-Log "Another roadmap agent run appears active. Exiting."
        exit 0
    }
    Remove-Item -LiteralPath $LockFile -Force
}

try {
    New-Item -ItemType File -Path $LockFile -Value "$PID`n$(Get-Date -Format o)" -ErrorAction Stop | Out-Null

    Push-Location $RepoRoot
    Write-Log "Repo: $RepoRoot"

    $branch = (& git branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Cannot run from a detached HEAD."
    }
    Write-Log "Branch: $branch"

    $dirtyBefore = @(Get-GitStatus)
    if ($dirtyBefore.Count -gt 0 -and -not $AllowDirtyStart) {
        Write-Log "Working tree is dirty before automation. Refusing to run."
        Write-Log "Commit, stash, or rerun with -AllowDirtyStart if you really want automation to include existing changes."
        exit 2
    }

    if ($dirtyBefore.Count -eq 0) {
        Invoke-External "git fetch origin" { & git fetch origin }
        Invoke-External "git pull --ff-only origin $branch" { & git pull --ff-only origin $branch }
    }
    else {
        Write-Log "AllowDirtyStart set; skipping pull to avoid mixing remote changes into local edits."
    }

    $prompt = @"
You are running as the unattended hourly roadmap worker for this repository.

Rules:
- Read ROADMAP.md first.
- Pick the highest-priority unfinished roadmap task or the next safe increment of an in-progress roadmap task.
- Implement one cohesive, testable increment only.
- Preserve unrelated user changes and do not revert existing work.
- Update ROADMAP.md with a short status note when the increment changes roadmap state.
- Add or update focused tests for the behavior you changed.
- Run the relevant backend and/or Flutter checks for your change.
- Do not commit or push; the outer scheduler will validate, commit, and push after you finish.

Current objective:
Make one hour-sized, production-quality increment toward completing the roadmap.
"@
    Set-Content -LiteralPath $PromptFile -Value $prompt -Encoding UTF8

    Write-Log "START: codex exec roadmap increment"
    Get-Content -LiteralPath $PromptFile -Raw |
        & $AgentCommand exec --cd $RepoRoot --sandbox workspace-write --ask-for-approval never --output-last-message $SummaryFile -
    if ($LASTEXITCODE -ne 0) {
        throw "codex exec failed with exit code $LASTEXITCODE"
    }
    Write-Log "DONE: codex exec roadmap increment"

    $dirtyAfter = @(Get-GitStatus)
    if ($dirtyAfter.Count -eq 0) {
        Write-Log "No repository changes produced. Nothing to commit."
        exit 0
    }

    if (-not $SkipValidation) {
        Push-Location (Join-Path $RepoRoot "backend\bude_api")
        try {
            Invoke-External "backend pytest" { & python -m pytest bude_api/tests }
        }
        finally {
            Pop-Location
        }

        Push-Location (Join-Path $RepoRoot "mobile-app\flutter_app")
        try {
            Invoke-External "flutter analyze" { & flutter analyze }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Log "Validation skipped by -SkipValidation."
    }

    Push-Location $RepoRoot
    try {
        Invoke-External "git add" { & git add -A }
        $commitMessageFile = Join-Path $RunRoot "commit-message-$Stamp.txt"
        $summary = ""
        if (Test-Path -LiteralPath $SummaryFile) {
            $summary = Get-Content -LiteralPath $SummaryFile -Raw
        }
        Set-Content -LiteralPath $commitMessageFile -Encoding UTF8 -Value @"
chore: hourly roadmap progress

Automated hourly roadmap worker.

$summary
"@
        Invoke-External "git commit" { & git commit -F $commitMessageFile }

        if ($NoPush) {
            Write-Log "NoPush set; commit created but not pushed."
        }
        else {
            Invoke-External "git push origin $branch" { & git push origin $branch }
        }
    }
    finally {
        Pop-Location
    }

    Write-Log "Hourly roadmap worker completed successfully."
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
}
