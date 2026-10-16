<div align="center">

# sim2paper

**Give Claude Code real hands on MATLAB and Simulink, then take your simulations all the way to a reproducible paper.**

[![MATLAB](https://img.shields.io/badge/MATLAB-R2023a%2B-e16737)](docs/INSTALL.md)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-MCP-8a63d2)](docs/GUIDE.md)
[![macOS](https://img.shields.io/badge/macOS-verified-2ea44f)](docs/INSTALL.md#macos)
[![Windows](https://img.shields.io/badge/Windows-verified-2ea44f)](docs/INSTALL.md#windows-powershell)
[![Linux](https://img.shields.io/badge/Linux-untested-lightgrey)](docs/INSTALL.md#linux)
[![License: MIT](https://img.shields.io/badge/guide-MIT-blue)](LICENSE)

</div>

---

Connecting an AI agent to MATLAB takes ten minutes. Learning what *not* to let it do took weeks:
`model_edit` that silently doesn't save, a setup command that freezes MATLAB until a human presses Ctrl-C,
logs that keep 1000 samples and drop the rest, skills that confidently run toolboxes you don't own.

**sim2paper** is that experience, packaged:

- 🔌 **One-prompt install** of the MathWorks Agentic Toolkit MCP server on macOS, Windows and Linux, with the
  flags that actually work and an installer that never overwrites your files.
- 🧠 **~80 field-tested Simulink traps**, scripting idioms and a troubleshooting table, written from daily
  production use on a large model under Git.
- 🧰 **Skills and templates** for Claude Code: `.mcp.json`, `startup.m`, a project `CLAUDE.md`, the rules every
  agent session should load.
- 📄 **A research template**: MATLAB sims → generated figures → LaTeX paper → Overleaf, where every number in
  the PDF traces back to a script.

## ⚡ Quick start: let the agent do it

Open Claude Code in **your** MATLAB project and say:

> **Install the MATLAB setup from https://github.com/KaremBenChikha/sim2paper into this project.**

The agent reads [`CLAUDE.md`](CLAUDE.md), a runbook written *for it*: it checks your machine, asks before
touching anything outside the project, installs and wires everything, verifies it, and writes the rules into
your project's own `CLAUDE.md` so the next session starts smart.

## 🛠 Manual install

<details open>
<summary><b>macOS</b> (verified, R2026b on Apple Silicon)</summary>

```bash
git clone https://github.com/KaremBenChikha/sim2paper && cd sim2paper
MATLAB=$(ls -d /Applications/MATLAB_R20*.app | tail -1)
curl -fL -o /tmp/agenticToolkitInstaller.mltbx \
  https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx
"$MATLAB/bin/matlab" -batch "matlab.addons.toolbox.installToolbox('/tmp/agenticToolkitInstaller.mltbx'); setupAgenticToolkit('install', Toolkit=[\"matlab\",\"simulink\"], Prompt=false)"
install/install.sh --project ~/my-project --profile core --dry-run   # look first
install/install.sh --project ~/my-project --profile core
```
</details>

<details>
<summary><b>Windows</b> (verified, R2026a on Windows 11)</summary>

```powershell
git clone https://github.com/KaremBenChikha/sim2paper; cd sim2paper
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\path\to\project -DryRun -InstallToolkit
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\path\to\project -InstallToolkit
```
</details>

<details>
<summary><b>Linux</b> (same script as macOS, not yet run: reports welcome)</summary>

```bash
git clone https://github.com/KaremBenChikha/sim2paper && cd sim2paper
MATLAB=$(ls -d /usr/local/MATLAB/R20* | tail -1)
curl -fL -o /tmp/agenticToolkitInstaller.mltbx \
  https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx
"$MATLAB/bin/matlab" -batch "matlab.addons.toolbox.installToolbox('/tmp/agenticToolkitInstaller.mltbx'); setupAgenticToolkit('install', Toolkit=[\"matlab\",\"simulink\"], Prompt=false)"
install/install.sh --project ~/my-project --profile core
```
</details>

Then **restart Claude Code in the project** (MCP servers load at session start) and check:

```bash
matlab -batch "validate_installation"                        # every check: pass
matlab -batch "addpath('examples'); verify_simulink_add"     # Simulink OK: a = 5, b = 7 -> a + b = 12
```

In Claude Code: *"list installed MATLAB toolboxes"*. The first call takes ~30 s while MATLAB boots: not a hang.
Full per-OS notes and gotchas: **[docs/INSTALL.md](docs/INSTALL.md)**.

## 📄 From simulation to paper

```
inbox/ (originals)  →  matlab/src + sims  →  results/figures, tables  →  paper/main.tex  →  PDF / Overleaf
```

```bash
cp -R research-template ~/my-paper && cd ~/my-paper && git init
make test     # matlab.unittest, headless
make sims     # regenerate every figure and table
make paper    # LaTeX via tectonic
make overleaf-zip
```

Drop your thesis, draft, reviewer comments and old MATLAB code into `inbox/`; the agent ports and tests the
code, reproduces the original figures before changing anything, tracks every comment to the line that fixes it,
and never pastes a number into the paper by hand. Why it is built this way:
**[docs/RESEARCH_WORKFLOW.md](docs/RESEARCH_WORKFLOW.md)**.

## 🗺 What's inside

| | |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Agent runbook: decision tree, consent rules, install, verify, licence map, seeding your project |
| [`docs/INSTALL.md`](docs/INSTALL.md) | macOS / Windows / Linux, step by step |
| [`docs/GUIDE.md`](docs/GUIDE.md) | Every MCP flag explained, writing a project `CLAUDE.md`, lessons L1 to L13, Git for binary `.slx`, troubleshooting |
| [`docs/SIMULINK_TRAPS.md`](docs/SIMULINK_TRAPS.md) | ~80 traps: `model_edit` quirks, buses and ports, lines, types and rates, logging, dictionaries, Model Advisor |
| [`docs/SCRIPTING_IDIOMS.md`](docs/SCRIPTING_IDIOMS.md) | Copy-paste snippets for scripted model edits, safe `sim`, MATLAB Function to blocks |
| [`docs/WORKFLOW.md`](docs/WORKFLOW.md) · [`docs/MULTI_SESSION.md`](docs/MULTI_SESSION.md) | How an agent should behave on a long project; several sessions sharing one MATLAB |
| [`docs/RESEARCH_WORKFLOW.md`](docs/RESEARCH_WORKFLOW.md) | The sim-to-paper pipeline and the rules that keep an agent honest |
| [`research-template/`](research-template) | Ready-to-copy paper project: MATLAB layout, tests, LaTeX, Makefile, Overleaf export |
| [`install/`](install) | `install.sh` (macOS/Linux) and `install.ps1` (Windows): idempotent, dry-run first |
| [`templates/`](templates) | `.mcp.json`, `startup.m`, project `CLAUDE.md`, paste-in agent rules, `.gitattributes`, `.gitignore` |
| [`skills/`](skills) | `simulink-tile-layout` (original), four Simulink cheat-sheets, profiler/debugger skills |
| [`examples/`](examples) | `verify_simulink_add.m`: builds, simulates and removes a tiny model |
| [`SKILLS_CATALOG.md`](SKILLS_CATALOG.md) | All 177 MathWorks vendor skills with the descriptions the agent sees |

## 🧷 Ten sentences that save the most time

1. `model_edit` **does not save and cannot be undone**: commit first.
2. `startup.m` must call `satk_initialize`, or every `model_*` tool fails.
3. Never call `setupAgenticToolkit` from an agent without `Prompt=false`: it hangs MATLAB until a human hits Ctrl-C.
4. `--log-folder` must be short, local and writable: the server opens a unix socket there.
5. `--matlab-session-mode=auto`, not `existing` (the vendor default only works if MATLAB is already running).
6. Check `detect_matlab_toolboxes`: a skill whose toolbox you lack must say so and stop, never fake output.
7. `ToWorkspace` logs 1000 samples unless `MaxDataPoints='inf'`.
8. Prove cosmetic or routing changes **bit-identical** against a baseline.
9. Every Claude session shares one desktop MATLAB; run extra checks in `matlab -batch`.
10. Never put a Git working copy in OneDrive; mark `*.slx binary`; keep `resources/project/` under Git.

## ✅ Verified on

| | Windows | macOS |
|---|---|---|
| MATLAB | R2026a Update 5, Windows 11 | R2026b, Apple Silicon |
| MCP server | 0.13.0 | 0.15.0 |
| Toolkit | matlab 2026.08.27, simulink 2026.09.a | matlab 2026.10.a, simulink 2026.10.b |
| Licence tested | MATLAB, Simulink, MATLAB/Simulink Coder only (so the blocked-skill paths are documented too) | Full product set |
| Date | 2026-10-13 | 2026-10-16 |

## 📜 Licence

Guide, docs, installers, templates, research template, examples and `skills/simulink-tile-layout`: **MIT**
([LICENSE](LICENSE)). Other material under `skills/` is **MathWorks-authored**, redistributed under BSD-3-Clause
plus a clause restricting use to MathWorks products: see [NOTICE](NOTICE). The MCP server and the vendor skill
catalogs are **not** included; get them from MathWorks
([simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit),
[matlab-mcp-core-server](https://github.com/matlab/matlab-mcp-core-server)). Not affiliated with MathWorks or Anthropic.

## 🕰 History

- **2026-10-16** · v3 *sim2paper*: verified on macOS (R2026b), per-OS install guide, `startup.m` add-on fallback,
  research template and sim-to-paper workflow, Simulink verify example. Previous edition: branch
  [`archive/v2-2026-10-13`](../../tree/archive/v2-2026-10-13).
- **2026-10-13** · v2: rebuilt as a transferable pack (agent runbook, installers, traps, multi-session notes).
- **2026** · v1: the original field guide, kept in [`archive/v1-2026/`](archive/v1-2026).

Found a trap that isn't here, or something that's wrong? Issues and PRs welcome: corrections are recorded, not
silently overwritten.
