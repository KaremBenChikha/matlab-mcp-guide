# Install: macOS, Windows, Linux

Three steps on every OS: **(1)** install the MathWorks Agentic Toolkit once per machine, **(2)** wire your
project, **(3)** restart Claude Code in the project and verify. The fastest path is to let the agent do it
(see the README); this page is the manual version.

| OS | Status |
|---|---|
| **macOS** (Apple Silicon, R2026b) | Verified 2026-10-16: toolkit install, `install.sh`, `validate_installation` all green, Simulink sim from a fresh project |
| **Windows 11** (R2026a) | Verified 2026-10-13 in daily production use (`install.ps1`) |
| **Linux** | Expected to work with `install.sh` (same code path as macOS), **not yet run**. Please open an issue with what you see |

Requirements: MATLAB **R2023a or later** (R2025a+ recommended), Simulink for the `model_*` tools, Claude Code,
and `git`. A MATLAB licence is required: the MathWorks toolkit licence restricts use to MathWorks products.

---

## 1. Install the MathWorks toolkit (once per machine)

The same three MATLAB lines on every OS. Run them in the MATLAB Command Window, or headless as shown below.
`Prompt=false` matters: without it the setup opens a numbered menu, and from an agent session that menu
wedges MATLAB until a human presses Ctrl-C.

```matlab
websave('agenticToolkitInstaller.mltbx', 'https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx');
matlab.addons.toolbox.installToolbox('agenticToolkitInstaller.mltbx');
setupAgenticToolkit("install", Toolkit=["matlab","simulink"], Prompt=false)
```

Result: `~/.matlab/agentic-toolkits/` with `bin/matlab-mcp-server` (~18 MB on macOS arm64), the MATLAB and
Simulink skill catalogs and `config.json`, plus the **MATLAB MCP Server Toolbox** add-on.

### macOS

```bash
MATLAB=$(ls -d /Applications/MATLAB_R20*.app | tail -1)
curl -fL -o /tmp/agenticToolkitInstaller.mltbx \
  https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx
"$MATLAB/bin/matlab" -batch "matlab.addons.toolbox.installToolbox('/tmp/agenticToolkitInstaller.mltbx'); setupAgenticToolkit('install', Toolkit=[\"matlab\",\"simulink\"], Prompt=false)"
```

- If Gatekeeper blocks the server: `xattr -d com.apple.quarantine ~/.matlab/agentic-toolkits/bin/matlab-mcp-server`
  (not needed in our run: the binary only carried `com.apple.provenance`).
- The add-on lands in `~/Library/Application Support/MathWorks/MATLAB Add-Ons/`. In `matlab -batch` sessions
  it was **not** on the path afterwards (`validate_installation`: *shareMATLABSession not found*), and
  `mpminstall` did not make it stick. The `startup.m` template adds it by path when missing; with it,
  `validate_installation` passes 7/7.

### Windows (PowerShell)

```powershell
cd sim2paper
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\path\to\project -DryRun -InstallToolkit
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\path\to\project -InstallToolkit
```

Or the three MATLAB lines above in the MATLAB desktop. Log folder: a short local path such as `C:\mcplog`
(deep paths fail with `socket path is too long`; `%TEMP%` failed with `access denied for socket file`).
Skills are linked as junctions (no admin needed). Never keep the project in OneDrive.

### Linux

```bash
MATLAB=$(ls -d /usr/local/MATLAB/R20* | tail -1)
curl -fL -o /tmp/agenticToolkitInstaller.mltbx \
  https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx
"$MATLAB/bin/matlab" -batch "matlab.addons.toolbox.installToolbox('/tmp/agenticToolkitInstaller.mltbx'); setupAgenticToolkit('install', Toolkit=[\"matlab\",\"simulink\"], Prompt=false)"
```

Unverified. `--matlab-display-mode=desktop` needs a display; on a headless box use `nodesktop`.

---

## 2. Wire the project

```bash
# macOS / Linux: dry run first, then for real
install/install.sh --project ~/my-project --profile core --dry-run
install/install.sh --project ~/my-project --profile core
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\my-project -Profile core
```

It writes, never overwriting without `--force` / `-Force`:

- `.mcp.json`: the `matlab` server with the flags in [GUIDE §4](GUIDE.md#4-configure-mcpjson)
  (`auto` session mode, `desktop` display, Simulink extension tools, short log folder, telemetry off).
- `startup.m`: runs `satk_initialize` (else every `model_*` tool fails) and the add-on fallback.
- `.claude/skills/`: symlinks/junctions into the vendor catalog for the chosen profile, plus copies of this
  repo's own skills and notes. `core` = Simulink + general MATLAB groups (82 on R2026b); `all` = every skill.

Prefer real copies over links (a repo you push, or a machine that updates the toolkit underneath you)?
Copy the skill folders instead and refresh them after toolkit updates.

Starting a paper or thesis? Copy [`research-template/`](../research-template) first, then wire it.

---

## 3. Restart and verify

MCP servers and skills load at session start, so **restart Claude Code in the project**. Then:

```bash
matlab -batch "validate_installation"                              # every check: pass
matlab -batch "addpath('examples'); verify_simulink_add"           # a = 5, b = 7 -> a + b = 12
```

In Claude Code, ask *"list installed MATLAB toolboxes"* (`detect_matlab_toolboxes`; first call ~30 s while
MATLAB boots), then *"build an a + b Simulink model and simulate it"*.

Updates: `setupAgenticToolkit("update", Prompt=false)`, then re-check `.mcp.json` (telemetry flag,
`auto` mode) and rebuild skill links (renamed skills leave dangling links).
