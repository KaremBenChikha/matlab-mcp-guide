#!/usr/bin/env bash
# Wire a local project to MATLAB/Simulink for Claude Code (macOS / Linux).
# Same behaviour as install.ps1: idempotent, never overwrites without --force, never downloads without
# --install-toolkit.  NOTE: written from the verified Windows flow; NOT yet run on macOS/Linux - read the
# --dry-run output before trusting it, and fix this script (and the docs) if it differs from reality.
#
# usage: install/install.sh [--project DIR] [--matlab-root DIR] [--log-folder DIR] [--profile core|all]
#                           [--install-toolkit] [--keep-telemetry] [--force] [--dry-run]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PWD"; MATLAB_ROOT=""; LOG_FOLDER="$HOME/mcplog"; PROFILE=core
INSTALL=0; TELEMETRY_OFF=1; FORCE=0; DRY=0
while [ $# -gt 0 ]; do case "$1" in
  --project) PROJECT="$2"; shift 2;;
  --matlab-root) MATLAB_ROOT="$2"; shift 2;;
  --log-folder) LOG_FOLDER="$2"; shift 2;;
  --profile) PROFILE="$2"; shift 2;;
  --install-toolkit) INSTALL=1; shift;;
  --keep-telemetry) TELEMETRY_OFF=0; shift;;
  --force) FORCE=1; shift;;
  --dry-run) DRY=1; shift;;
  *) echo "unknown option $1" >&2; exit 64;;
esac; done

say() { echo "[install] $*"; }
run() { if [ "$DRY" = 1 ]; then say "DRY-RUN: $*"; else say "$*"; eval "$@"; fi; }

TOOLKIT="$HOME/.matlab/agentic-toolkits"; SERVER="$TOOLKIT/bin/matlab-mcp-server"
PROJECT="$(cd "$PROJECT" && pwd)"

# 1. MATLAB
if [ -z "$MATLAB_ROOT" ]; then
  for c in /Applications/MATLAB_R20*.app /usr/local/MATLAB/R20*; do [ -d "$c" ] && MATLAB_ROOT="$c"; done
fi
[ -x "$MATLAB_ROOT/bin/matlab" ] || { echo "MATLAB not found; pass --matlab-root (needs R2023a+)" >&2; exit 1; }
say "MATLAB root: $MATLAB_ROOT"

# 2. toolkit
if [ ! -x "$SERVER" ]; then
  if [ "$INSTALL" = 0 ]; then
    cat >&2 <<EOT
The MathWorks toolkit is not installed. Re-run with --install-toolkit, or in MATLAB:
  websave('agenticToolkitInstaller.mltbx','https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx');
  matlab.addons.toolbox.installToolbox('agenticToolkitInstaller.mltbx');
  setupAgenticToolkit('install', Toolkit=["matlab","simulink"], Prompt=false);
EOT
    [ "$DRY" = 1 ] || exit 2
  else
    T="$(mktemp -d)"
    run "curl -fL -o '$T/agenticToolkitInstaller.mltbx' https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx"
    run "'$MATLAB_ROOT/bin/matlab' -batch \"matlab.addons.toolbox.installToolbox('$T/agenticToolkitInstaller.mltbx'); setupAgenticToolkit('install', Toolkit=[\\\"matlab\\\",\\\"simulink\\\"], Prompt=false);\""
  fi
fi
[ "$DRY" = 1 ] || [ -x "$SERVER" ] || { echo "toolkit install did not produce $SERVER" >&2; exit 1; }

# 3. log folder (short, local, not synced)
case "$LOG_FOLDER" in *OneDrive*|*Dropbox*|/tmp/*) echo "LOG_FOLDER must be local, short, not synced/tmp" >&2; exit 1;; esac
run "mkdir -p '$LOG_FOLDER'"

# 4. .mcp.json
MCP="$PROJECT/.mcp.json"
TEL=""; [ "$TELEMETRY_OFF" = 1 ] && TEL=',
        "--disable-telemetry=true"'
JSON=$(cat <<EOT
{
  "mcpServers": {
    "matlab": {
      "type": "stdio",
      "command": "$SERVER",
      "args": [
        "--matlab-root=$MATLAB_ROOT",
        "--initial-working-folder=$PROJECT",
        "--matlab-session-mode=auto",
        "--matlab-display-mode=desktop",
        "--extension-file=$TOOLKIT/simulink/tools/tools.json",
        "--log-folder=$LOG_FOLDER",
        "--log-level=info"$TEL
      ],
      "alwaysLoad": true
    }
  }
}
EOT
)
if [ -e "$MCP" ] && [ "$FORCE" = 0 ]; then say ".mcp.json exists - left alone (--force to replace). Proposed:"; echo "$JSON"
else [ -e "$MCP" ] && run "cp '$MCP' '$MCP.bak'"; if [ "$DRY" = 1 ]; then say "DRY-RUN: write $MCP"; else printf '%s\n' "$JSON" > "$MCP"; say "wrote $MCP"; fi; fi

# 5. startup.m
SU="$PROJECT/startup.m"
if [ -e "$SU" ] && [ "$FORCE" = 0 ]; then
  grep -q satk_initialize "$SU" && say "startup.m already calls satk_initialize" || say "WARNING: startup.m lacks satk_initialize - merge templates/startup.m.example"
else run "cp '$REPO/templates/startup.m.example' '$SU'"; fi

# 6. skills (symlinks into the vendor catalog + copies of this repo's own skills)
SK="$PROJECT/.claude/skills"; run "mkdir -p '$SK'"
MATLAB_KEEP=" matlab-core matlab-software-development matlab-data-import-and-analysis matlab-app-building matlab-external-language-interfaces matlab-programming matlab-environment-and-settings "
n=0
for tk in simulink matlab; do
  root="$TOOLKIT/$tk/skills-catalog"; [ -d "$root" ] || continue
  for g in "$root"/*/; do gn="$(basename "$g")"
    if [ "$PROFILE" != all ] && [ "$tk" = matlab ] && [[ "$MATLAB_KEEP" != *" $gn "* ]] && [ "$gn" != test-and-measurement ]; then continue; fi
    for s in "$g"*/; do sn="$(basename "$s")"; [ -f "$s/SKILL.md" ] || continue
      if [ "$gn" = test-and-measurement ] && [ "$PROFILE" != all ] && [ "$sn" != matlab-use-vehicle-network ] && [ "$sn" != matlab-import-export-vehicle-data ]; then continue; fi
      n=$((n+1)); [ -e "$SK/$sn" ] || run "ln -s '${s%/}' '$SK/$sn'"
    done
  done
done
say "$n vendor skills in profile '$PROFILE'"
for item in "$REPO"/skills/*; do b="$(basename "$item")"
  case "$b" in README.md|check-authoring) continue;; esac
  [ -e "$SK/$b" ] && { say "skip (exists): $b"; continue; }
  run "cp -R '$item' '$SK/$b'"
done

# 7. integrity
bad=0; for l in "$SK"/*; do [ -L "$l" ] && [ ! -e "$l" ] && { echo "BROKEN: $l"; bad=$((bad+1)); }; done
say "broken links: $bad"
echo "NEXT: restart Claude Code in $PROJECT, then ask: 'list installed MATLAB toolboxes' and 'give me an overview of <Model>.slx'"
