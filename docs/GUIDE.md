# The full guide — Claude Code + MATLAB/Simulink

> Part of [matlab-mcp-guide](../README.md). Agent-facing install instructions are in [`../CLAUDE.md`](../CLAUDE.md); this file is the long-form reasoning behind them. Companion docs: [WORKFLOW](WORKFLOW.md) · [SIMULINK_TRAPS](SIMULINK_TRAPS.md) · [SCRIPTING_IDIOMS](SCRIPTING_IDIOMS.md) · [MULTI_SESSION](MULTI_SESSION.md).

Connecting **Claude Code** to a local **MATLAB/Simulink** installation via the MathWorks
**Agentic Toolkit** MCP server: the install, the flags that matter, the folder layout, and how to
write a `CLAUDE.md` that makes the agent behave.

Written from production use, not from the docs: a small Simulink team with binary `.slx` models under
Git and no CI. Everything marked **Verified** was actually run; everything marked **Vendor** comes
from the toolkit's own documentation. Where the two disagree, that is called out rather than
smoothed over.

The parts you cannot get from the vendor README are [§9 Lessons learned](#9-lessons-learned) and
[§7 Writing a CLAUDE.md that works](#7-writing-a-claudemd-that-works). Everything else is setup.

---

## Contents

| | |
|---|---|
| [1. What you actually get](#1-what-you-actually-get) | and what you don't |
| [2. Prerequisites](#2-prerequisites) | including the licence trap |
| [3. Install](#3-install) | `setupAgenticToolkit` |
| [4. Configure `.mcp.json`](#4-configure-mcpjson) | every flag, and why |
| [5. `startup.m`](#5-startupm--the-single-most-common-failure) | the #1 first-time failure |
| [6. Verify, and know your tools](#6-verify-and-know-your-tools) | |
| [7. Writing a CLAUDE.md that works](#7-writing-a-claudemd-that-works) | **the important part** |
| [8. Skills — layout and reality](#8-skills--layout-and-reality) | Windows symlinks, skill groups |
| [9. Lessons learned](#9-lessons-learned) | **the expensive part** |
| [10. Git hygiene for Simulink](#10-git-hygiene-for-simulink) | binary models, MATLAB projects |
| [11. Troubleshooting](#11-troubleshooting) | combined vendor + field |
| [12. Templates](#12-templates) | copy-paste starting points |

---

## Verified on

| | |
|---|---|
| **MATLAB** | R2026a (Update 5) on Windows 11 |
| **Toolkit** | matlab `2026.08.27`, simulink `2026.09.a` (re-verified 2026-10-13) |
| **MCP server** | `0.13.0` (MATLAB MCP Server Toolbox `0.4.0`) |
| **Skills** | 177 in the catalog — 147 MATLAB + 30 Simulink |
| **Licensed** | Base MATLAB + Simulink, plus MATLAB Coder and Simulink Coder (added later). Nothing else |

That last row is the point of §2, and it is the ordinary case rather than an unlucky one. Most of
what makes this setup frustrating is not the MCP wiring; it is discovering which of the 177 skills
your licence can actually run. Check yours with `detect_matlab_toolboxes` before assuming any of the
compliance, test or architecture skills will work.

Version numbers here are what was current at the time of writing. Read your own with
`cat ~/.matlab/agentic-toolkits/config.json`.

---

## 1. What you actually get

**Working:**

- Claude reads, edits, builds, validates and simulates Simulink models directly — no pasting block
  diagrams into chat.
- Claude runs MATLAB code and test files and gets real command-window output back.
- A catalog of 177 MathWorks-authored procedures the agent consults *before* improvising, so it
  follows the vendor's pattern for e.g. building a model programmatically instead of guessing at
  `add_block` calls.

**Not working, and worth knowing up front:**

- **This is not CI.** The MCP server drives a MATLAB desktop session on your machine. There is no
  headless runner and no server-side licence. If you want a pre-merge gate, you write a script and
  run it locally — see [§10](#10-git-hygiene-for-simulink).
- **`model_edit` cannot be undone.** `.slx` is binary. There is no diff and no partial revert. Your
  only undo button is a Git commit made *before* the edit.
- **Skills degrade silently.** A skill whose toolbox you do not own will not always refuse — some
  fall back to a lesser method, and the agent may not tell you unless instructed to. See §2 and §7.

---

## 2. Prerequisites

- **MATLAB R2023a or later** with Simulink *(Vendor)*. Verified here on R2026a.
- **Claude Code** installed and working.
- **A short, writable, local folder for logs** — e.g. `C:\mcplog`. Create it now; §4 explains why it
  is not optional.
- **Knowledge of which toolboxes you actually have licensed.**

### The licence trap

The toolkit installs happily regardless of what you own. The skills then split three ways:

| | Meaning |
|---|---|
| **Usable** | Runs as documented |
| **Degraded** | Falls back to a lesser method — e.g. no Requirements Toolbox → YAML instead of `.slreqx`; no Simulink Test → `sim` + `assert` instead of `sltest.TestCase` |
| **Blocked** | Cannot run at all — no Simulink Check means no Model Advisor, so *nothing* can produce a compliance result |

Common gaps: **Simulink Test**, **Simulink Check**, **Requirements Toolbox**, **System Composer**.

Settle it in one call before you build anything on top:

```
Ask Claude: "list installed MATLAB toolboxes"
```

That runs `detect_matlab_toolboxes`. Write the result into your `CLAUDE.md` as a status table
(§7) — otherwise the agent will cheerfully attempt a Model Advisor run you cannot license, and the
failure will surface three steps later as something confusing.

> **The rule worth writing down:** when a skill is blocked, the agent should say so and stop — never
> fabricate what Model Advisor or System Composer *would* have said. This does not happen by
> default. You have to ask for it in `CLAUDE.md`.

---

## 3. Install

From inside MATLAB:

```matlab
setupAgenticToolkit("install")
```

It installs the MCP server binary into `~/.matlab/agentic-toolkits/bin/` and the skill catalogs
into `~/.matlab/agentic-toolkits/{matlab,simulink}/skills-catalog/`.

To have it write the Claude Code config for you:

```matlab
setupAgenticToolkit("install", Agents="claude-code")
```

Other actions: `setupAgenticToolkit("update")`, `setupAgenticToolkit("uninstall")` and
`setupAgenticToolkit("status")`.

**From an agent session, always pass `Prompt=false`.** Verified 2026-09-08: without it the call opens a
numbered menu that the MCP channel cannot answer (see [L1](#l1-the-interactive-hang)); with it, it runs
straight through. Full argument list (from the `.m` shipped next to the `.p`):

```matlab
setupAgenticToolkit("install",   Toolkit=["matlab","simulink"], Prompt=false)
setupAgenticToolkit("configure", Scope="global", Agents="claude-code", Prompt=false)
setupAgenticToolkit("update",    Prompt=false)
% Name-value: Toolkit, Agents ("claude-code","copilot","codex","amp","gemini-cli"), Scope ("global"|"project"),
% InstallRoot, Source, SessionMode ("auto"|"existing"|"new"), Prompt, SkillGroups, AgentCLI
```

After any update *(Vendor)*: re-run `satk_initialize` in MATLAB **and** restart your agent session.

> ### ⚠️ Never run `setupAgenticToolkit("configure")` from an agent session
>
> It prompts interactively with `input()`. An agent has no stdin — every MCP call arrives as an
> empty line, producing `Invalid selection`, and it loops forever. The MATLAB session is wedged and
> **no tool call can rescue it**; a human has to press **Ctrl-C** in the MATLAB desktop.
>
> Run it yourself, in MATLAB, with the desktop in front of you — **or add `Prompt=false`**, which
> avoids the menu entirely (verified 2026-09-08; the first version of this guide said this was
> unavoidable, and was wrong). See [L1](#l1-the-interactive-hang).

If the Add-On Manager fails to open the `.mltbx` (`ERR_CERT_AUTHORITY_INVALID`, or "Unable to open
the requested feature" — typically a corporate proxy, antivirus, or headless environment), install
programmatically instead *(Vendor)*:

```matlab
matlab.addons.toolbox.installToolbox("agenticToolkitInstaller.mltbx")
```

### Install only the skill groups you need

The catalog is 177 skills across 28 groups. The vendor's own advice is to install only what you
need — *"Only install skills that you need to allow your agent to reliably trigger the skills."*
A Simulink controls project has no use for the 32-skill RF group, and every irrelevant skill is
another chance for the agent to trigger the wrong one.

| Toolkit | Groups | Skills |
|---|---|---|
| `simulink` | model-based-design-core (11), verification-validation-and-test (4), model-based-system-engineering (1), simulink-simulation (1), code-generation (1) | **18** |
| `matlab` | 24 groups — aerospace, automotive, radar, rf-and-mixed-signal, signal-processing, wireless-communications, robotics, image-processing, matlab-core, … | **151** |

`matlab-core` is mandatory. Everything else is opt-in. The full annotated list is in
**[SKILLS_CATALOG.md](../SKILLS_CATALOG.md)**.

### Optional: toolbox knowledge bases and your own block libraries *(Vendor)*

```matlab
satk.Configuration.setLibrary('all')                         % activate pre-built KBs for every installed toolbox
satk.Configuration.setLibrary({'Aerospace Blockset','Simscape'})   % or specific ones; 'none' deactivates
satk.Configuration.setCustomLibraries("C:\path	o\customLibs")   % your own block libraries (indexed on first use, ~3-5 min)
satk.Configuration.clearConfig()                             % remove all library configuration
```
Custom libraries are then indexed by the `setup-custom-libraries` skill into MATLAB's `prefdir`.

---

## 4. Configure `.mcp.json`

Place it at your project root. This is the **real, working** config from the reference project:

```json
{
  "mcpServers": {
    "matlab": {
      "type": "stdio",
      "command": "C:/Users/<you>/.matlab/agentic-toolkits/bin/matlab-mcp-server.exe",
      "args": [
        "--matlab-root=C:/Program Files/MATLAB/R2026a",
        "--initial-working-folder=C:/path/to/your/project",
        "--matlab-session-mode=auto",
        "--matlab-display-mode=desktop",
        "--extension-file=C:/Users/<you>/.matlab/agentic-toolkits/simulink/tools/tools.json",
        "--log-folder=C:/mcplog",
        "--log-level=info",
        "--disable-telemetry=true"
      ],
      "alwaysLoad": true
    }
  }
}
```

**Restart Claude Code after any edit** — MCP servers load once, at session start.

### What each flag is for

| Flag | Why |
|---|---|
| `--matlab-root` | Pins the release. Essential with multiple MATLAB versions installed. |
| `--initial-working-folder` | Where MATLAB starts — and therefore **which `startup.m` runs** (§5). Point it at your project root. |
| `--matlab-session-mode=auto` | **Deliberate.** See below. |
| `--matlab-display-mode=desktop` | Full MATLAB desktop, so you can watch what the agent does and intervene. `headless` hides it — and hides interactive prompts you may need to answer. |
| `--extension-file` | Registers the Simulink `model_*` tools. Without it you get the five MATLAB tools only. |
| `--log-folder` | **Deliberate, and load-bearing.** See below. |
| `--log-level=info` | The vendor's first troubleshooting step for connection problems is to read these logs. |
| `--disable-telemetry=true` | Usage data is collected **by default**. This opts out — and **must be re-applied after every toolkit update** *(Vendor)*. |
| `alwaysLoad` | Claude Code connects the server at session start rather than on first use. |

### The two flags that are not cosmetic

**`--log-folder` must be short, local and writable.** The server opens a **unix-domain socket**
inside this folder, and those paths have a hard length limit. Observed failures:

- A deeply nested path → `socket path is too long`
- `%TEMP%` → `access denied for socket file`

`C:/mcplog` works. Create it once, never move it. Do not point it at OneDrive or any synced folder.

**`--matlab-session-mode=auto`, not `existing`.** `setupAgenticToolkit` writes `existing` — confirmed
in `~/.matlab/agentic-toolkits/config.json`, which shows `"sessionMode": "existing"`. That mode only
works when a MATLAB session *with `satk_initialize` already run* is sitting there waiting. If not,
every tool call fails. `auto` starts one when needed.

> **Re-running `setupAgenticToolkit("configure")` overwrites `.mcp.json` wholesale** and reinstates
> `existing`. Keep a backup copy of your working config and re-apply after any reconfigure or
> update. Same for `--disable-telemetry`.

---

## 5. `startup.m` — the single most common failure

The server starts MATLAB in `--initial-working-folder`. MATLAB automatically runs a `startup.m`
found there. That file must call `satk_initialize`.

**Without it, every `model_*` tool fails** with `Unrecognized function or variable
'satk_initialize'`. This is the number-one first-time failure and it looks like a broken install
rather than a missing line.

```matlab
% startup.m — runs automatically when MATLAB starts in this folder.
%
% satk_initialize registers the Simulink Agentic Toolkit tool entry points
% (model_overview, model_read, model_edit, ...) and calls shareMATLABSession.
% Without it, those MCP tools fail with "Unrecognized function or variable".
% It must run once per MATLAB session.

try
    addpath(fullfile(getenv('USERPROFILE'), '.matlab', 'agentic-toolkits', 'simulink'));
    evalc('satk_initialize');   % silence the banner; errors still propagate
catch err
    warning('startup:satk', 'satk_initialize failed: %s', err.message);
end

% Your project's own functions
addpath(genpath(fileparts(mfilename('fullpath'))));
```

Three details that matter:

- **The explicit `addpath` first.** `satk_initialize.p` lives in the toolkit's `simulink/` folder,
  which is not on a fresh MATLAB path. Without this line the very next line fails.
- **`evalc` around it** suppresses a noisy banner that otherwise lands in every tool result. Errors
  still propagate.
- **`try`/`catch` with a warning**, not a bare call. If the toolkit is missing you want a readable
  warning, not a `startup.m` that aborts and leaves your project paths unset too.

If you start MATLAB **manually** from another folder and want to attach to it, run
`satk_initialize` yourself in that session first.

---

## 6. Verify, and know your tools

The first tool call in a session takes **~20–30 s** — that is MATLAB booting. Later calls are fast.
Do not mistake the cold start for a hang.

Good smoke test, in order:

1. `"list installed MATLAB toolboxes"` → exercises the transport and answers the licence question.
2. `"give me an overview of <YourModel>.slx"` → proves `satk_initialize` ran and the Simulink
   extension file is registered.

The vendor also ships `validate_installation.p` in `~/.matlab/agentic-toolkits/simulink/`.

### The tools

| Tool | What it does |
|---|---|
| `evaluate_matlab_code` | Run arbitrary MATLAB in the live session; returns command-window output |
| `run_matlab_file` | Execute a `.m` script |
| `run_matlab_test_file` | Run a test file via `runtests` |
| `check_matlab_code` | Static analysis (Code Analyzer) — style, errors, perf |
| `detect_matlab_toolboxes` | Installed products and versions |
| `model_overview` | Model hierarchy: subsystems, interfaces, connections |
| `model_read` | Structure, topology and expressions at a given scope/depth |
| `model_edit` | **Destructive.** Add/connect/configure/delete/replace blocks, create subsystems |
| `model_check` | Unconnected ports/lines, Stateflow lint |
| `model_query_params` | Random-access read of any block/signal/config parameter |
| `model_resolve_params` | Resolve `@Gain(Kp)` → the numeric value of `Kp` |
| `model_read_diagnostics` | Errors/warnings from the latest Diagnostic Viewer stage, with block IDs. Never compiles or simulates itself — trigger an update-diagram/sim first |
| `model_test` | Gherkin behavioural tests — **requires Simulink Test** |

Server `0.11.2` did not expose `model_read_diagnostics`; `0.13.0` does (13 tools in total, 8 of them from
`simulink/tools/tools.json` via `--extension-file`). Check what *your* version exposes rather than
assuming the docs match. The server also publishes two MCP resources, `guidelines://coding` and
`guidelines://plain-text-live-code` (needs R2025a+), which an agent can read for house style.

**Prefer `model_*` over hand-written `set_param`/`get_param`** — the skills are written assuming
those tools, and mixing approaches produces advice that does not match what the agent then does.

---

## 7. Writing a CLAUDE.md that works

This is where most of the value is. The MCP wiring is a one-time cost; `CLAUDE.md` is what decides
whether the agent is useful on day 30. A full template is in
**[`../templates/CLAUDE.md.example`](../templates/CLAUDE.md.example)**.

The principle: **`CLAUDE.md` is not documentation. It is the set of things that are true about this
project and expensive to rediscover.** Anything the agent can learn by reading the code does not
belong there. Anything that cost someone an afternoon does.

### 7.1 Say where the real logic lives

Simulink projects have a discoverability problem: the behaviour is in `.slx` files the agent cannot
read as text. Tell it where the actual code is.

```markdown
| Layer | Path |
|---|---|
| Top-level model | `<TopModel>.slx` |
| Subsystem libraries | `models/*.slx` |
| Algorithm bodies | `functions/<algorithms>/*.m` ← **the real logic lives here** |

The `.slx` files are binary — do not read or edit them as text. To change behaviour, edit the
corresponding `.m` file, which is what the MATLAB Function blocks call.
```

That last paragraph saves the agent from trying to grep a zip archive, and it steers changes toward
files that Git can actually merge.

### 7.2 State the licence reality, and forbid faking

```markdown
| Skill | Status | Blocker |
|---|---|---|
| `building-simulink-models`, `simulating-simulink-models` | Usable | — |
| `generate-requirement-drafts` | Degraded | No Requirements Toolbox → YAML fallback, not `.slreqx` |
| `testing-simulink-models` | Degraded | No Simulink Test → plain `sim` + `assert` |
| `checking-model-compliance` | **Blocked** | No Simulink Check → no Model Advisor |

When a skill is blocked, say so and stop — do not fake Model Advisor output or invent compliance
results. `detect_matlab_toolboxes` settles any doubt in one call.
```

The last line is the one that matters. Without it, a plausible-looking compliance table can appear
in a certification context. Name the tool that settles it so the agent has a cheap alternative to
guessing.

### 7.3 A trigger table, not a skill list

177 skills is too many to choose from reliably. Map *phrasings you actually use* to skill names:

```markdown
| Trigger in the request | Skill |
|---|---|
| "is the model compliant", DO-178C / MISRA / ISO 26262 | `checking-model-compliance` |
| Build or edit a model programmatically | `building-simulink-models` |
| "wrong value at t=X", step through a sim | `simulink-debug-commandline` |
| "simulation is slow", compare two runs | `simulink-profiler-analyzer` |
| Solver errors, step size, algebraic loops | `simulink-solver-profiler-analyzer` |
```

Two jobs: it tells the agent *when to stop and read a skill* instead of improvising, and it doubles
as a live index of what is relevant to your project versus the 150 skills you will never touch.

### 7.4 A "Do not touch" list

Generated files, vendor files, and archives. Without this the agent will helpfully "fix" things that
regenerate, or hand-edit an output whose source is elsewhere.

```markdown
## Do not touch
- `resources/project/**` — MATLAB project metadata (126 generated XML files)
- `docs/diagrams/*.svg` — **generated**. Edit `docs/diagrams/src/*.py` and regenerate
- `skills/**` — vendor-authored. Read and follow; don't edit
- The `archive/pre-git-2026-06` branch — a frozen record. Never merge it
```

### 7.5 Guard the destructive tool explicitly

```markdown
**Before any `model_edit`**, confirm the tree is clean and committed — `model_edit` is destructive
and a binary `.slx` edit cannot be diffed or undone. `git stash`/commit first; never assume a
restore point exists.
```

### 7.6 Encode the idioms that produce working-but-wrong results

Short notes that are cheap to read and expensive to get wrong:

```markdown
- "this block" = `gcb`, "this model" = `bdroot`, "this subsystem" = `gcs`
- Use `add_block` + `Simulink.BlockDiagram.arrangeSystem`; **never** hand-position blocks
- **Always** `out = sim(in)` with a `Simulink.SimulationInput`; never `set_param` for sim
  parameters — that mutates the model file instead of configuring a run
- Capture a baseline **before** modifying any model, then verify against it
```

Keep these as plain `.md` files *without* YAML frontmatter, so Claude Code does not surface them as
invocable skills, and reference them from `CLAUDE.md` as always-read notes.

### 7.7 Make documentation upkeep a rule — with the *why*

The rule that has paid off most:

```markdown
## Maintenance — keep README.md current (mandatory)

Never finish a piece of work without updating `README.md` in the same commit.

### The logbook is not optional
| **YYYY-MM-DD** | **Short title.** What changed and *why*. |

- **Say why, not what.** `git log` already records what. The logbook exists for the reasoning that
  would otherwise evaporate — the constraint discovered, the option rejected, the measurement that
  settled it.
- **Cite evidence** — test counts, spec IDs, measured numbers.
- **Record corrections.** When a documented fact turns out wrong, that is the *most* valuable
  entry. Never silently overwrite a wrong fact.
- **Never record a result you have not run.** If a claim needs MATLAB and MATLAB is unavailable,
  say so instead of assuming.
- Skip trivia. One entry per day per theme, not per commit.
```

Why this works: an agent session has no memory of last week. A logbook that explains *why* a
decision was made is the difference between an agent that reinforces your architecture and one that
relitigates it every session.

### 7.8 Watch where `CLAUDE.md` lives

If `CLAUDE.md` is gitignored (reasonable — it is agent configuration, not product), then **nothing
in it reaches a colleague's clone.** The reference project hit exactly this: a carefully written
`CONTRIBUTING.md` explaining the `.slx` merge rule sat in an untracked folder, invisible to the one
person it was written for.

Decide deliberately:

| | Put it in |
|---|---|
| Agent behaviour, tool quirks, licence status | `CLAUDE.md` (may be untracked) |
| Anything a human collaborator must know | A **tracked** file — `README.md` or `CONTRIBUTING.md` |

Some rules belong in both. Duplication beats a rule nobody receives.

---

## 8. Skills — layout and reality

### How Claude Code finds them

Claude Code auto-discovers skills from `.claude/skills/`. *(Vendor)* Setup registers them via the
`claude plugin` system, and **falls back to symlinks in `~/.claude/skills/` if the `claude` CLI is
not on PATH** — worth knowing, because it changes where you look when skills do not appear.

### Recommended layout

```
your-project/
├── .mcp.json                 # MCP registration (§4)
├── CLAUDE.md                 # project instructions (§7)
├── startup.m                 # satk_initialize (§5)
├── .claude/
│   └── skills/               # AUTO-DISCOVERED — vendor links + your local extras
└── skills/                   # tracked copies of YOUR extras only (see below)
```

Two kinds of entry live in `.claude/skills/`:

1. **Links into `~/.matlab/agentic-toolkits/`** — the vendor catalog. Regenerated by
   `setupAgenticToolkit("update")`. **Never hand-edit**: they are not your files and an update
   overwrites them.
2. **Real local files** — cheat-sheets, custom Model Advisor checks, your modelling conventions.

**Gitignore `.claude/skills/` and keep authoritative copies of your local extras in a tracked
`skills/` folder.** Reason: `.claude/skills/` is a mix of links and real files, and links do not
survive a clone. If your only copy of a custom skill lives there, a fresh clone loses it.

Do not track the vendor skills. The reference project initially committed 10 of them, then removed
them — they are ~9.8 MB of someone else's code that goes stale the moment the catalog updates.

### Prune: load only what this machine can run

`.claude/skills/` descriptions load into **every** session's context. On a machine with only MATLAB +
Simulink, ~120 of the 177 catalog skills describe toolboxes that are not installed (RF, radar, robotics,
bio, finance, 5G…) and can never run. The reference machine went from 179 entries to 66 on 2026-09-08:
the whole Simulink catalog (a skill that says "needs a licence you don't have" beats silence), the
relevant MATLAB groups, and none of the rest. Keep a `RELINK.md` next to the junctions listing what is
kept and the command that restores a dropped group — [`../templates/RELINK.md.example`](../templates/RELINK.md.example).
`install/install.ps1 -Profile core` does this for you (see [`../CLAUDE.md`](../CLAUDE.md) step 6).

### ⚠️ After `setupAgenticToolkit("update")`, rebuild the junctions — do not repair them

Upstream renames and regroups skills between releases. The 2026-09-08 update dangled **18 of 50**
junctions at once (`matlab-debugging` → `matlab-debug-code`, `matlab-testing` → `matlab-write-test`,
`matlab-theming` → `matlab-apply-theme`, nine toolbox skills merged into `matlab-package-toolbox`, the
Simulink catalog regrouped from 5 groups to 9). Delete every junction and recreate from your keep-list,
then **always** check for dangling ones — `mklink` reports success even when the target does not exist:

```bash
for l in $(find .claude/skills -maxdepth 1 -type l -printf '%f\n'); do [ -e ".claude/skills/$l" ] || echo "BROKEN: $l"; done
```

On Git Bash: write the flag as `//J` (a lone `/J` is rewritten into a drive path and `mklink` then blames the
*link name*), and build targets with `cygpath -w`, never by hand-escaping backslashes (a quoted
`"$TW\$g\$s"` yields a literal `$g$s`: 56 junctions created, 56 broken).

### ⚠️ Windows: use junctions, not symlinks

This one costs an afternoon if you get it wrong.

- **`New-Item -ItemType SymbolicLink` requires administrator** and fails with
  *"Cette opération nécessite un privilège d'administrateur"* / *"This operation requires an
  elevated privilege"*.
- **Directory junctions do not.** `mklink /J` works as a normal user.

```bash
cmd //c mklink //J "target-name" "C:\Users\<you>\.matlab\agentic-toolkits\simulink\skills-catalog\<group>\<skill>"
```

And the trap underneath it: **`cp -a` in Git Bash silently dereferences MSYS symlinks.** It looks
like it worked. What you get is 9.8 MB of *copies* that no longer follow vendor updates — a
divergence that surfaces months later as "why is the agent following an old procedure?".

Also note MSYS-style symlinks are **invisible to PowerShell's `LinkType`**, so a PowerShell check
will report them as ordinary directories. Verify with `readlink` in bash, or `fsutil reparsepoint
query`.

---

## 9. Lessons learned

The expensive ones, in rough order of how much time they cost.

### L1. The interactive hang

**`setupAgenticToolkit("configure")` prompts with `input()`.** Run from an agent session, every MCP
call arrives as an empty line → `Invalid selection` → loop. The MATLAB session is wedged and **no
tool call can rescue it** — the agent cannot answer, and cannot cancel. A human must press
**Ctrl-C** in the MATLAB desktop.

Generalisation worth carrying: **any MATLAB function that may prompt is unsafe from an agent
session.** `input`, `keyboard`, `uiwait`, `questdlg`, `pause` with no argument. If you cannot avoid
one, run it yourself with the desktop visible — which is also why `--matlab-display-mode=desktop`
is the right default.

### L2. Model callbacks resolve against the current folder, not the project

A `CloseFcn` on three models cleaned build caches like this:

```matlab
slxcFiles = dir('**/*.slxc');    % resolves against MATLAB's cwd, NOT the project
if exist('slprj', 'dir')         % also searches the MATLAB path
    rmdir('slprj', 's');
end
```

Opening a model from an unrelated folder and closing it **deleted files in that folder**. Demonstrated
by planting a decoy `.slxc` and an `slprj/` in an unrelated tree and closing the model from there:
both destroyed.

The fix — resolve the project root explicitly, and no-op when there is no project:

```matlab
proj = matlab.project.rootProject;
if isempty(proj), return; end     % not in a project → do nothing
root = proj.RootFolder;
recycle('on');                    % recoverable, not permanent
% ... operate only on paths under `root`
```

**Anything an agent might trigger should be scoped to a path it resolves explicitly.** `dir`,
`exist`, `delete` and `rmdir` all silently follow the current folder or the MATLAB path.

### L3. Never put a Git working copy in OneDrive

Four independent failure modes, all real:

1. **`.git` corruption.** Git rewrites `index`, `HEAD` and lock files constantly; OneDrive uploads
   them mid-write and can restore a stale copy over a newer one → `error: index file corrupt`.
2. **Simulink file locks.** Simulink holds an exclusive lock on an open `.slx`. OneDrive fails to
   upload and produces conflict copies — `MyModel-<machine-name>.slx` — sitting untracked beside the
   real model.
3. **Files On-Demand dehydration.** The ~126 XML files under `resources/project/` are exactly the
   profile OneDrive targets. MATLAB then fails to open the project: the files "exist" but have no
   local content.
4. **Two sync systems, one set of bytes**, with no shared notion of a commit.

**Git is the sync.** `git push` is the backup and the transfer to a colleague. If you want a
company-controlled copy in OneDrive, use a **bare mirror** — no working tree, no locks, changes only
when you deliberately push:

```bash
git clone --bare /path/to/repo "/path/to/OneDrive/project-mirror.git"
git remote add backup "/path/to/OneDrive/project-mirror.git"
git push backup --all --tags
```

Also keep an eye on Windows `MAX_PATH` (260). Deep project trees plus a deep repo location will
break tools in ways that look unrelated. The reference project measured a 168-char worst case
before settling on a location.

### L4. Commit `resources/project/` — the project will not open without it

It looks like generated metadata that belongs in `.gitignore`. It is not. Three lines of evidence:

- The vendor skill's recommended `.gitignore` does not list it.
- Grepping it found **zero** absolute paths and zero usernames — it is portable.
- **Empirically: `openProject` fails outright without it** — *"Unable to load the project at: …"*.

Cost of keeping it: 126 files, ~10.7 KB, 0.07 % of the repo.

### L5. MATLAB regexp has no `\b`

Word boundary in MATLAB is `\<` and `\>`. And `^` means start-of-*string* unless you pass
`'lineanchors'`.

```matlab
% WRONG — silently matches nothing, every count reads zero
n = numel(regexp(out, '^\s*PASS\b', 'start'));

% RIGHT
n = numel(regexp(out, '^\s*PASS\>', 'start', 'lineanchors'));
```

This produced a test runner that reported "1 check" for every suite and looked plausible. Nothing
errored. **Verify a counting regex against known input before trusting it** — `(?m)` also silently
does nothing here.

### L6. `run` executes a script in the *caller's* workspace

```matlab
t0 = tic;
run('some_script');       % if the script assigns t0, your timer is gone
toc(t0)                   % → 959579.8 seconds
```

A verification script assigning `t0 = uint64(1000000)` clobbered the caller's `tic` handle. Fix:
time in the caller, and isolate the runner to one deliberately-named local:

```matlab
tStart = tic;
[out, err] = capture_suite(name);
elapsed = toc(tStart);

function [out, err] = capture_suite(RUNALLVERIFY_cmd_)   % unlikely to collide
    err = '';
    try
        out = evalc(sprintf('run(''%s'')', RUNALLVERIFY_cmd_));
    catch ME
        out = ''; err = ME.message;
    end
end
```

### L7. Telemetry is on by default, and resets

`--disable-telemetry=true` opts out, and **must be re-applied after every toolkit update**
*(Vendor)*. Same for every other manual flag — `configure` rewrites the file wholesale.

### L8. The vendor licence is *not* plain BSD-3-Clause

Both `LICENSE.md` files are BSD-3-Clause **plus an added third clause**:

> *"In all cases, the software is, and all modifications and derivatives of the software shall be,
> licensed to you solely for use in conjunction with MathWorks products and service offerings."*

That is a use restriction standard BSD does not have. The toolkit also states that **MCP servers
must not be shared by multiple users** — contact MathWorks for centralised deployment. Relevant if
you were considering a shared build machine.

*(An earlier version of this guide said "BSD-3-Clause". That was wrong, and is corrected here rather
than quietly edited — see §7.7 on recording corrections.)*

---

### L9. Skills and tools shipped by the toolkit disagree with each other — trust the live system

Skill text is written for a *licensed, current* toolkit. Before relying on one, check that the tool it
names is in your session (`model_read_diagnostics` did not exist in server 0.11.2), that the toolbox it
needs is licensed (`detect_matlab_toolboxes`), and that the skill folder still exists after an update.
When docs, skills and the live tool list disagree, the live tool list wins, then say so in `CLAUDE.md`.

### L10. A dictionary's unsaved changes are what a *fresh* MATLAB reads

A scenario run in the agent session left a Simulink data dictionary open with what-if values dirty (the
run restored and measured them; the dirty flag outlived it). A `matlab -batch` started meanwhile read the
dirty in-memory value and every scenario ran wrong. Before any background run:
`Simulink.data.dictionary.open(f).HasUnsavedChanges == 0` in every open MATLAB. Same family: a model left
open on the desktop gets its *view state* saved and dirties the tree with a multi-MB cosmetic `.slx` diff —
see [SIMULINK_TRAPS](SIMULINK_TRAPS.md).

### L11. All agent sessions share ONE desktop MATLAB

With `--matlab-session-mode=auto`, every Claude session's MCP server attaches to the same MATLAB. Never
restart it or re-root its path for another session's sake; run checks on a second source tree in a
separate `matlab -batch` process. Recipe, memory budget and timings: [MULTI_SESSION](MULTI_SESSION.md).

### L12. `genpath` sweeps `.git`, worktrees and archives onto the path

A bare `addpath(genpath(root))` pulls in `.claude/worktrees/*`, `.git` and any reference folder; a stale
worktree copy of a function then **shadows** the real one with errors that point nowhere near the cause.
Use a filtered path helper (skip any path with a dot-folder) and diagnose "undefined variable that should
exist" with `which <fn> -all` then `git worktree list`.

### L13. "My manual edits are gone" is almost never Git

`.slx` is binary, so "is my change in?" cannot be read from a diff. Check, in order: `git status` and the
file mtime against `git log -1 --format=%ci -- <file>` (a desktop save after the last commit sits on disk
in no commit); `git worktree list` / `git stash list` / `git reflog`; then the MATLAB processes — an
instance that loaded the model before the save shows its own stale memory (three were alive once). Before
committing any desktop `.slx` save, unzip both versions, `diff -rq`, and count `<Block ` / `<Line>` /
`<Annotation SID` — a view-state-only change touches `windowsInfo.xml`, `coreProperties.xml` and
`thumbnail.png` and nothing else.

---

## 10. Git hygiene for Simulink

### `.slx` cannot be merged, and that shapes everything

```gitattributes
*.slx  binary
```

`binary` expands to `-diff -merge -text`. Git will refuse to auto-merge, which is what you want —
the alternative is a corrupted model. But it means the only resolution to a conflict is **"pick one
side and redo the other by hand in Simulink."**

The conventions that avoid ever hitting it:

1. **Logic in `.m`, not in the model.** Keep MATLAB Function blocks as thin wrappers around on-file
   `.m` functions. Those merge cleanly; only *wiring* changes touch a `.slx`.
2. **One owner per model at a time.** Use a project board as the lock — moving a card to *In
   progress* claims every model it touches.
3. **Short branches.** One parked branch in the reference project reached 4 ahead / 24 behind, and
   the model it branched from no longer existed on master. Its `.m` files still port; the wiring has
   to be redone by hand.
4. **Squash-merge.** Collapses N intermediate `.slx` blobs into one. Materially slows repo growth —
   each model commit adds megabytes that never compress.

The `binary` marking also protects against **Windows CRLF conversion silently corrupting** the
zip-under-the-hood `.slx` format.

### Cache folders

Route build artefacts somewhere ignorable instead of scattering them:

```matlab
Simulink.fileGenControl('set', ...
    'CacheFolder',   fullfile(projRoot,'work','slprj'), ...
    'CodeGenFolder', fullfile(projRoot,'work','codegen'));
```

```gitignore
work/
slprj/
sccprj/
codegen/
*.slxc
*.autosave
*.asv
*.slx.r*
*.slx.original
```

### A local gate, since there is no CI

No server has a MATLAB licence, so a script you run locally is the only pre-merge check that exists.
Write one runner that executes every verification script and prints a single summary — see
[`../templates/run_all_verify.m.example`](../templates/run_all_verify.m.example), which has L5 and L6
already worked around.

Then require its output in a PR template: pasted results, which `.slx` files were touched, and
confirmation the author held the lock.

---

## 11. Troubleshooting

**F** = observed in the field · **V** = vendor-documented

| Symptom | Cause | Fix | |
|---|---|---|---|
| Every `model_*` fails, "Unrecognized function or variable" | `satk_initialize` never ran | Add it to `startup.m` in the server's working folder (§5) | V·F |
| `socket path is too long` | `--log-folder` too deeply nested | Point it at `C:/mcplog` | F |
| `access denied for socket file` | Log folder not writable, or synced/redirected | Use a plain local folder | F |
| MATLAB wedged, repeating `Invalid selection` | `setupAgenticToolkit("configure")` run from an agent session | **Human presses Ctrl-C in MATLAB.** Never run it from an agent (L1) | F |
| Custom `.mcp.json` flags reverted | `setupAgenticToolkit("configure")` or an update | Restore from backup, re-apply flags including `--disable-telemetry` | V·F |
| First call hangs ~20–30 s | Cold start — MATLAB booting | Normal; once per session | F |
| Agent doesn't list Simulink skills | Skills not registered | Re-run `setupAgenticToolkit("configure")` — **in MATLAB, not from an agent** | V |
| MCP server can't connect to MATLAB | Connector not running, or stale connection | Add `--log-folder` + `--log-level`, re-run `satk_initialize` (it calls `shareMATLABSession`), read the logs | V |
| `rmiml.selectionLinkHelper` error | Path corruption from another toolbox | `restoredefaultpath`, then re-run `satk_initialize` | V |
| Add-On Manager fails on the `.mltbx` | CEF/display issue — proxy, antivirus, headless | `matlab.addons.toolbox.installToolbox("agenticToolkitInstaller.mltbx")` | V |
| macOS blocks the binary | Gatekeeper quarantine | `xattr -d com.apple.quarantine ~/.matlab/agentic-toolkits/bin/matlab-mcp-server` | V |
| `model_test` unavailable | Simulink Test not licensed | Use the other tools; plain `sim` + `assert` for tests | V |
| Symlink creation refused on Windows | Symlinks need admin | Use a junction: `mklink /J` (§8) | F |
| Skill folders became real copies | `cp -a` dereferenced MSYS symlinks | Recreate as junctions; verify with `readlink` | F |
| A skill confidently produces output for an unlicensed toolbox | Silent degradation | `detect_matlab_toolboxes`; add the "say so and stop" rule to `CLAUDE.md` (§7.2) | F |
| `openProject` fails after a clean clone | `resources/project/` was gitignored | Commit it (L4) | F |
| Test counts all read zero | MATLAB regexp has no `\b` | Use `\>` and `'lineanchors'` (L5) | F |

---

## 12. Templates

| File | What |
|---|---|
| [`../templates/.mcp.json.example`](../templates/.mcp.json.example) | Full working MCP registration, every flag annotated |
| [`../templates/startup.m.example`](../templates/startup.m.example) | `satk_initialize` bootstrap with the path fix and error handling |
| [`../templates/CLAUDE.md.example`](../templates/CLAUDE.md.example) | Complete `CLAUDE.md` skeleton — code map, licence table, trigger table, guards, maintenance rule |
| [`../templates/.gitattributes.example`](../templates/.gitattributes.example) | Binary handling for `.slx` and friends |
| [`../templates/.gitignore.example`](../templates/.gitignore.example) | Build artefacts, with `resources/` deliberately **not** ignored |
| [`../templates/run_all_verify.m.example`](../templates/run_all_verify.m.example) | Local pre-merge gate, with the L5/L6 traps already handled |
| [`../SKILLS_CATALOG.md`](../SKILLS_CATALOG.md) | All 177 vendor skills by group, with the descriptions the agent sees (regenerate: `tools/gen_skills_catalog.py`) |
| [`../skills/`](../skills/) | Nine **MathWorks-authored** entries from an earlier distribution, plus one original skill (`simulink-tile-layout`) — see below |

### 12.1 The `skills/` folder

Nine entries kept as a reference point, **unmodified**, authored by The MathWorks: four full skills
with scripts (`simulink-debug-commandline`, `simulink-profiler-analyzer`,
`simulink-profile-initialization`, `simulink-solver-profiler-analyzer`), `check-authoring` — which
is in today's catalog as **`author-modeladvisor-checks`** — and the four frontmatter-less idiom
notes from [§7.6](#76-encode-the-idioms-that-produce-working-but-wrong-results).

They came from a **distribution earlier than the current catalog**, which is why some names do not
resolve against `~/.matlab/agentic-toolkits/*/skills-catalog/` today. Useful when reading an older
setup, or when a name in someone's `CLAUDE.md` does not resolve.

> **If you have MATLAB, install from MATLAB instead.** `setupAgenticToolkit("install")` gets the
> current, maintained versions. A snapshot in Git is stale the day after it lands — the reference
> project committed 10 vendor skills and removed them again for exactly this reason. Do not copy
> this folder wholesale into `.claude/skills/`: you would end up with two copies of
> `check-authoring`/`author-modeladvisor-checks` and an agent unable to tell which to follow.

Details and the name mapping: [`skills/README.md`](../skills/README.md).

### 12.2 What is deliberately *not* here — the server binary

The MCP server executable is **not** redistributed. Get it from MATLAB:

```matlab
setupAgenticToolkit("install")     % installs to ~/.matlab/agentic-toolkits/bin/
setupAgenticToolkit("update")      % keeps it current
```

Three reasons, in order of weight:

1. **The toolkit documentation states MCP servers must not be shared by multiple users**, and
   directs anyone needing centralised deployment to contact MathWorks.
2. **A committed binary is instantly stale.** The reference machine had two on disk — a `0.11.1`
   copy from an earlier install and the `0.11.2` the toolkit actually runs. Different MD5, three
   weeks apart. Anyone downloading the committed one would silently get the old server.
3. **Git history is permanent.** Removing a ~19 MB blob later means rewriting history and
   force-pushing over everyone's clone.

**To check which version you have:**

```bash
cat ~/.matlab/agentic-toolkits/config.json
```

It reports `mcpServerVersion`, the per-toolkit versions, your MATLAB root, and `lastUpdated` — and
it is also where you can confirm whether `sessionMode` has been reset to `existing` behind your back
([§4](#4-configure-mcpjson)).

---

## License

**This guide and its templates:** MIT.

**The `skills/` folder:** MathWorks-authored, redistributed in source form. BSD-3-Clause **plus a
third clause** restricting use to "in conjunction with MathWorks products and service offerings"
(see [L8](#l8-the-vendor-licence-is-not-plain-bsd-3-clause)). Full licence text, reproduced as
clauses 1 and 2 require: [**`NOTICE`**](../NOTICE). **If you do not hold a MATLAB/Simulink licence,
clause 3 applies to you and that folder is not licensed for your use.**

**The Agentic Toolkit and MCP server binary:** not redistributed here — see §12.2.

**Upstream:** [matlab/simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit) ·
[matlab/matlab-mcp-core-server](https://github.com/matlab/matlab-mcp-core-server)
