<#
.SYNOPSIS
  Wire a local project to MATLAB/Simulink for Claude Code (Windows).

.DESCRIPTION
  Idempotent. Never overwrites an existing file unless -Force. Never downloads or installs anything unless
  -InstallToolkit is given. Run with -DryRun first to see exactly what it would do.

  What it does, in order:
    1. Finds MATLAB (or uses -MatlabRoot) and the toolkit under ~/.matlab/agentic-toolkits.
    2. (-InstallToolkit only) downloads agenticToolkitInstaller.mltbx from the official MathWorks release,
       installs the add-on and runs setupAgenticToolkit("install", Prompt=false).
    3. Creates a short log folder (default C:\mcplog) - REQUIRED by the MCP server's unix socket.
    4. Writes <Project>\.mcp.json with the verified flag set.
    5. Writes <Project>\startup.m (satk_initialize bootstrap) if there is none.
    6. Creates <Project>\.claude\skills\ with junctions to the vendor catalog (per -Profile) and copies this
       repo's own skills + cheat-sheets.
    7. Checks for dangling junctions and prints a status table.

.PARAMETER Project       Project root (default: current directory). This is where MATLAB will start.
.PARAMETER MatlabRoot    e.g. "C:\Program Files\MATLAB\R2026a". Auto-detected (newest) if omitted.
.PARAMETER LogFolder     Short, local, writable. Default C:\mcplog. Never OneDrive.
.PARAMETER Profile       core (default) | all
                           core = whole Simulink catalog + the general MATLAB groups (no RF/radar/robotics/...)
                           all  = every skill in both catalogs
.PARAMETER InstallToolkit  Allow downloading + installing the MathWorks toolkit (explicit consent).
.PARAMETER KeepTelemetry Do NOT add --disable-telemetry=true (the server collects usage data by default; opt-out is the default here).
.PARAMETER Force         Overwrite existing .mcp.json / startup.m (a .bak copy is kept).
.PARAMETER DryRun        Print actions, change nothing.
#>
[CmdletBinding()]
param(
  [string]$Project = (Get-Location).Path,
  [string]$MatlabRoot,
  [string]$LogFolder = 'C:\mcplog',
  [ValidateSet('core', 'all')][string]$Profile = 'core',
  [switch]$InstallToolkit,
  [switch]$KeepTelemetry,
  [switch]$Force,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Home_ = $env:USERPROFILE
$Toolkit = Join-Path $Home_ '.matlab\agentic-toolkits'
$Server = Join-Path $Toolkit 'bin\matlab-mcp-server.exe'
$telemetryOff = -not $KeepTelemetry

function Say($m)  { Write-Host "[install] $m" }
function Do-It($desc, [scriptblock]$sb) {
  if ($DryRun) { Say "DRY-RUN: $desc" } else { Say $desc; & $sb }
}
function Fwd($p) { $p -replace '\\', '/' }

# ---------- 1. MATLAB + toolkit ----------
if (-not $MatlabRoot) {
  $cand = Get-ChildItem 'C:\Program Files\MATLAB' -Directory -ErrorAction SilentlyContinue |
          Where-Object Name -Match '^R20\d\d[ab]$' | Sort-Object Name -Descending | Select-Object -First 1
  if ($cand) { $MatlabRoot = $cand.FullName }
}
if (-not $MatlabRoot -or -not (Test-Path (Join-Path $MatlabRoot 'bin\matlab.exe'))) {
  throw "MATLAB not found. Pass -MatlabRoot 'C:\Program Files\MATLAB\R20xxx' (needs R2023a or later)."
}
Say "MATLAB root: $MatlabRoot"

# ---------- 2. toolkit install (opt-in) ----------
if (-not (Test-Path $Server)) {
  if (-not $InstallToolkit) {
    Write-Warning "MCP server not found at $Server."
    Write-Host @"

  The MathWorks toolkit is not installed. Either re-run this script with -InstallToolkit (it will download
  agenticToolkitInstaller.mltbx from github.com/matlab/simulink-agentic-toolkit/releases and install it), or
  do it yourself in MATLAB:

      websave('agenticToolkitInstaller.mltbx','https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx');
      matlab.addons.toolbox.installToolbox('agenticToolkitInstaller.mltbx');
      setupAgenticToolkit('install', Toolkit=["matlab","simulink"], Prompt=false);

"@
    if (-not $DryRun) { exit 2 }
  } else {
    $tmp = Join-Path $env:TEMP 'mmg-install'; New-Item -ItemType Directory -Force $tmp | Out-Null
    $mltbx = Join-Path $tmp 'agenticToolkitInstaller.mltbx'
    $url = 'https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx'
    Do-It "download $url -> $mltbx" { Invoke-WebRequest -Uri $url -OutFile $mltbx -UseBasicParsing }
    $m = "matlab.addons.toolbox.installToolbox('$(Fwd $mltbx)'); setupAgenticToolkit('install', Toolkit=[""matlab"",""simulink""], Prompt=false);"
    Do-It "MATLAB batch: install add-on + setupAgenticToolkit('install', Prompt=false)  (takes minutes)" {
      & (Join-Path $MatlabRoot 'bin\matlab.exe') -wait -batch $m
    }
  }
}
if (-not $DryRun -and -not (Test-Path $Server)) { throw "Toolkit install did not produce $Server" }
$cfg = Join-Path $Toolkit 'config.json'
if (Test-Path $cfg) {
  $c = Get-Content $cfg -Raw | ConvertFrom-Json
  Say ("toolkit: matlab {0}, simulink {1}, MCP server {2}" -f $c.toolkits.matlab.version, $c.toolkits.simulink.version, $c.mcpServerVersion)
}

# ---------- 3. log folder ----------
if ($LogFolder -match 'OneDrive|%TEMP%|\\Temp\\') { throw "LogFolder must be short, local, not synced and not TEMP: $LogFolder" }
if ($LogFolder.Length -gt 20) { Write-Warning "LogFolder is long ($LogFolder); the server's unix socket path limit may bite." }
Do-It "create log folder $LogFolder" { New-Item -ItemType Directory -Force $LogFolder | Out-Null }

# ---------- 4. .mcp.json ----------
$Project = (Resolve-Path $Project).Path
$mcp = Join-Path $Project '.mcp.json'
$args_ = @(
  "--matlab-root=$(Fwd $MatlabRoot)",
  "--initial-working-folder=$(Fwd $Project)",
  '--matlab-session-mode=auto',
  '--matlab-display-mode=desktop',
  "--extension-file=$(Fwd (Join-Path $Toolkit 'simulink\tools\tools.json'))",
  "--log-folder=$(Fwd $LogFolder)",
  '--log-level=info'
)
if ($telemetryOff) { $args_ += '--disable-telemetry=true' }
$obj = [ordered]@{ mcpServers = [ordered]@{ matlab = [ordered]@{
  type = 'stdio'; command = (Fwd $Server); args = $args_; alwaysLoad = $true } } }
$json = $obj | ConvertTo-Json -Depth 6
if ((Test-Path $mcp) -and -not $Force) {
  Write-Warning ".mcp.json exists - left alone (use -Force to replace; a .bak is kept). Proposed content:"
  Write-Host $json
} else {
  Do-It "write $mcp" {
    if (Test-Path $mcp) { Copy-Item $mcp "$mcp.bak" -Force }
    [IO.File]::WriteAllText($mcp, $json + "`n", (New-Object Text.UTF8Encoding $false))
  }
}

# ---------- 5. startup.m ----------
$su = Join-Path $Project 'startup.m'
$tpl = Join-Path $Repo 'templates\startup.m.example'
if ((Test-Path $su) -and -not $Force) {
  if (-not (Select-String -Path $su -Pattern 'satk_initialize' -Quiet)) {
    Write-Warning "startup.m exists but does NOT call satk_initialize - every model_* tool will fail. Merge the lines from templates\startup.m.example."
  } else { Say "startup.m already calls satk_initialize - left alone" }
} else {
  Do-It "write $su from template" {
    if (Test-Path $su) { Copy-Item $su "$su.bak" -Force }
    Copy-Item $tpl $su -Force
  }
}

# ---------- 6. skills ----------
$skillsDir = Join-Path $Project '.claude\skills'
Do-It "ensure $skillsDir" { New-Item -ItemType Directory -Force $skillsDir | Out-Null }

$matlabKeep = 'matlab-core','matlab-software-development','matlab-data-import-and-analysis','matlab-app-building',
              'matlab-external-language-interfaces','matlab-programming','matlab-environment-and-settings'
$tmKeep = 'matlab-use-vehicle-network','matlab-import-export-vehicle-data'   # only if Vehicle Network Toolbox is licensed
$links = New-Object System.Collections.Generic.List[object]
foreach ($tk in 'simulink', 'matlab') {
  $root = Join-Path $Toolkit "$tk\skills-catalog"
  if (-not (Test-Path $root)) { Write-Warning "no catalog at $root"; continue }
  foreach ($g in Get-ChildItem $root -Directory) {
    $take = ($Profile -eq 'all') -or ($tk -eq 'simulink') -or ($matlabKeep -contains $g.Name) -or ($g.Name -eq 'test-and-measurement')
    if (-not $take) { continue }
    foreach ($s in Get-ChildItem $g.FullName -Directory) {
      if ($g.Name -eq 'test-and-measurement' -and $Profile -ne 'all' -and ($tmKeep -notcontains $s.Name)) { continue }
      if (-not (Test-Path (Join-Path $s.FullName 'SKILL.md'))) { continue }
      $links.Add([pscustomobject]@{ Name = $s.Name; Target = $s.FullName })
    }
  }
}
$made = 0
foreach ($l in $links) {
  $dst = Join-Path $skillsDir $l.Name
  if (Test-Path $dst) { continue }
  Do-It "junction $($l.Name)" { New-Item -ItemType Junction -Path $dst -Target $l.Target | Out-Null }
  $made++
}
Say "$($links.Count) vendor skills in profile '$Profile' ($made new junctions)"

# own skills + cheat-sheets (real copies; junctions into the repo would not survive a move)
foreach ($item in Get-ChildItem (Join-Path $Repo 'skills') -Force) {
  if ($item.Name -in 'README.md', 'check-authoring') { continue }   # check-authoring == catalog author-modeladvisor-checks
  $dst = Join-Path $skillsDir $item.Name
  if (Test-Path $dst) { Say "skip (exists): $($item.Name)"; continue }
  Do-It "copy skill $($item.Name)" { Copy-Item $item.FullName $dst -Recurse -Force }
}

# ---------- 7. integrity ----------
$bad = @()
if (-not $DryRun) {
  foreach ($d in Get-ChildItem $skillsDir -Directory -Force) {
    if ($d.LinkType -eq 'Junction') {
      $t = $d.Target; if ($t -is [array]) { $t = $t[0] }
      if (-not (Test-Path $t)) { $bad += $d.Name }
    }
  }
}
Write-Host ''
Write-Host '================ status ================'
Write-Host ("project        : {0}" -f $Project)
Write-Host ("MATLAB         : {0}" -f $MatlabRoot)
Write-Host ("server         : {0} ({1})" -f $Server, $(if (Test-Path $Server) { 'present' } else { 'MISSING' }))
Write-Host ("log folder     : {0}" -f $LogFolder)
Write-Host ("skills linked  : {0}   broken junctions: {1}" -f $links.Count, $bad.Count)
if ($bad) { Write-Warning ("BROKEN: " + ($bad -join ', ')) }
Write-Host ''
Write-Host 'NEXT: restart Claude Code in the project (MCP servers and skills load at session start), then ask:'
Write-Host '  "list installed MATLAB toolboxes"   -> detect_matlab_toolboxes (also settles which skills can run)'
Write-Host '  "give me an overview of <Model>.slx" -> proves startup.m / satk_initialize / the Simulink tools'
