# matlab-mcp-guide

**Everything needed to give a Claude Code session real, working access to MATLAB and Simulink — and the
hard-won knowledge of how to use it without breaking your models.**

This is a transferable pack: an installer, a field guide, ~80 field-tested Simulink/tooling traps, a skills
set and templates, written from several weeks of daily production use (MATLAB R2026a, Windows 11, a large
Simulink model under Git with binary `.slx` files, several Claude sessions in parallel).

> ## 🔑 The one-line way to use it
> Open Claude Code in **your** MATLAB project and say:
>
> **"Install the MATLAB setup from https://github.com/KaremBenChikha/matlab-mcp-guide into this project."**
>
> The agent reads [`CLAUDE.md`](CLAUDE.md) — a step-by-step runbook written *for it* — checks your machine,
> asks consent before anything outside the project, installs/wires everything, verifies it, and seeds your
> project's own `CLAUDE.md` with the rules so the knowledge outlives the session.

---

## What you get

| Piece | Where | What it is |
|---|---|---|
| **Agent runbook** | [`CLAUDE.md`](CLAUDE.md) | Decision tree, consent rules, install, verify, licence map, the ten rules, seeding the project |
| **Installer** | [`install/install.ps1`](install/install.ps1) · [`install.sh`](install/install.sh) | Idempotent, `-DryRun`, never overwrites without `-Force`, never downloads without `-InstallToolkit`. Writes `.mcp.json`, `startup.m`, links skills, checks for broken links |
| **Field guide** | [`docs/GUIDE.md`](docs/GUIDE.md) | Install, every MCP flag, writing a project `CLAUDE.md`, skills layout, lessons L1–L13, Git hygiene for `.slx`, troubleshooting |
| **Traps** | [`docs/SIMULINK_TRAPS.md`](docs/SIMULINK_TRAPS.md) | ~80 traps: `model_edit` quirks, buses/ports, lines, types/rates, Subsystem References, logging, dictionaries, Model Advisor without Simulink Check |
| **Idioms** | [`docs/SCRIPTING_IDIOMS.md`](docs/SCRIPTING_IDIOMS.md) | Conventions + copy-paste snippets for scripted model edits; safe `sim`; MATLAB-Function → blocks recipe |
| **Workflow** | [`docs/WORKFLOW.md`](docs/WORKFLOW.md) | How an agent should behave on a long project; "my edits are gone" triage |
| **Multi-session** | [`docs/MULTI_SESSION.md`](docs/MULTI_SESSION.md) | Several Claude sessions share one MATLAB; batch-MATLAB recipe |
| **Skills** | [`skills/`](skills/) | `simulink-tile-layout` (original), four cheat-sheet notes, four MathWorks profiler/debugger skills no longer in the current catalog |
| **Catalog** | [`SKILLS_CATALOG.md`](SKILLS_CATALOG.md) | All 177 vendor skills with the descriptions the agent sees |
| **Templates** | [`templates/`](templates/) | `.mcp.json`, `startup.m`, project `CLAUDE.md`, paste-in `CLAUDE.matlab-rules.md`, `.gitattributes`, `.gitignore`, `RELINK.md`, local verify gate |

## Manual quick start (no agent)

```powershell
# 1. MATLAB R2023a+ with Simulink installed. 2. From this repo:
git clone https://github.com/KaremBenChikha/matlab-mcp-guide
cd matlab-mcp-guide
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\path\to\your\project -DryRun
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Project C:\path\to\your\project -InstallToolkit
# 3. Restart Claude Code in the project, then ask: "list installed MATLAB toolboxes"
```

macOS/Linux: `install/install.sh --project <dir> --dry-run` (**not yet run on macOS/Linux** — the Windows flow is
the verified one).

## The ten sentences that save the most time

1. `model_edit` **does not save and cannot be undone** — commit first.
2. `startup.m` must call `satk_initialize`, or every `model_*` tool fails.
3. Never call `setupAgenticToolkit` from an agent without `Prompt=false` — it hangs MATLAB until a human hits Ctrl-C.
4. `--log-folder` must be short, local, writable (`C:\mcplog`) — the server opens a unix socket there.
5. `--matlab-session-mode=auto`, not `existing` (the vendor writes `existing`; it only works if MATLAB is already running).
6. Check `detect_matlab_toolboxes`; a skill whose toolbox you lack must say so and stop, never fake output.
7. `ToWorkspace` logs 1000 samples unless `MaxDataPoints='inf'`.
8. Prove cosmetic/routing changes **bit-identical** against a baseline.
9. Every Claude session shares one desktop MATLAB; run extra checks in `matlab -batch` from an outside worktree.
10. Never put a Git working copy in OneDrive; mark `*.slx binary`; keep `resources/project/` under Git.

## Verified on

| | |
|---|---|
| MATLAB | R2026a (Update 5), Windows 11 |
| Toolkit | matlab `2026.08.27`, simulink `2026.09.a` |
| MCP server | `0.13.0` (MATLAB MCP Server Toolbox `0.4.0`) |
| Licensed | MATLAB, Simulink, MATLAB Coder, Simulink Coder — nothing else (so Model Advisor batch runs, Simulink Test, System Composer, Embedded Coder skills are *blocked*; the guide says how that looks and what to do) |
| Last verified | 2026-10-13 |

## Licence

Guide, templates, installers and `skills/simulink-tile-layout`: **MIT** ([LICENSE](LICENSE)).
`skills/` also holds **MathWorks-authored** material redistributed under BSD-3-Clause **plus a third clause**
restricting use to "in conjunction with MathWorks products and service offerings" — see [NOTICE](NOTICE).
The MCP server binary and the vendor skill catalogs are **not** included: get them from MathWorks with
`setupAgenticToolkit` (upstream: [simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit),
[matlab-mcp-core-server](https://github.com/matlab/matlab-mcp-core-server)).

## History

2026-10-13: rebuilt as a transferable pack (agent runbook, installers, traps, workflow, multi-session notes,
current catalog). The previous edition of the guide is preserved in [`archive/v1-2026/`](archive/v1-2026/).
