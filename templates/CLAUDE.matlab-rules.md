<!--
APPEND THIS BLOCK TO THE PROJECT'S CLAUDE.md (the installing agent does it in step 8 of the repo's CLAUDE.md).
It is the distilled, always-loaded part of the knowledge in sim2paper. Replace the <placeholders>.
Keep the "why" fragments: they are what stops a later session from "improving" a rule away.
Source & depth: https://github.com/KaremBenChikha/sim2paper  (docs/SIMULINK_TRAPS.md, docs/GUIDE.md)
-->

## MATLAB / Simulink - rules for every session (from sim2paper)

**Environment.** MATLAB `<R20xx>` at `<root>`; MCP server `matlab` in `.mcp.json` (stdio); MATLAB starts in this
folder, so `startup.m` runs `satk_initialize`. Licensed products (from `detect_matlab_toolboxes`, <date>):
`<list>`. Restart Claude Code after any `.mcp.json` / skills change - both load at session start. First tool
call takes ~20–30 s (MATLAB boot); that is not a hang.

**Tools.** Prefer `model_overview` → `model_read` → `model_query_params` / `model_resolve_params` to look,
`model_edit` to change, `model_check` + `model_read_diagnostics` to validate. `model_edit` does **not save**,
**cannot be undone** and a binary `.slx` cannot be diffed: **commit first, save explicitly, check after.**
`model_test` needs Simulink Test.

**Never, from an agent session:**
- run `setupAgenticToolkit("configure")` or `("update")` without `Prompt=false` - it prompts with `input()`,
  wedges MATLAB, and only a human pressing Ctrl-C at the desktop recovers it. Same for any `input`,
  `keyboard`, `uiwait`, `questdlg`, bare `pause`.
- `restoredefaultpath` (removes the MCP server's functions from the path) or restart the shared MATLAB.
- read or edit `.slx`/`.sldd` as text; `cp -a` symlinked skills (it dereferences them silently).
- hand-position blocks (use `Simulink.BlockDiagram.arrangeSystem`; exception: the `simulink-tile-layout` skill).
- `set_param` simulation settings on the model for a run: use `out = sim(in)` with a `Simulink.SimulationInput`.
- use a bare `addpath(genpath(root))` - it pulls `.git` and worktrees onto the path and a stale copy shadows the
  real function. Use a filtered helper; diagnose with `which <fn> -all` + `git worktree list`.
- fake output: **if a skill/tool needs a product that `detect_matlab_toolboxes` does not list, say so and stop.**
  No invented Model Advisor, coverage, System Composer or compliance results. No test counts you did not run.

**Always:**
- Baseline before changing a model (`save('baseline.mat','out')`), and prove cosmetic/routing changes
  **bit-identical** (`isequal`, dimensions included; read "moved" lines before deciding a value moved).
- `ToWorkspace`: `MaxDataPoints='inf'`, `SampleTime='-1'`; census every parameter your script sets and read it
  back (`model_edit` once flipped `>=` to `<=` silently).
- After any bus-element / port / line deletion: reconnect explicitly, sweep dangling stubs (`DstPortHandle -1`),
  `model_check`.
- Branch → PR; one owner per `.slx`; `.gitattributes` marks `*.slx binary`; commit `resources/project/`.
- Close models you opened on the desktop; zip-diff any unexplained `.slx` change against HEAD before touching it
  (view-state-only changes touch just `windowsInfo.xml`, `coreProperties.xml`, `thumbnail.png`).
- Treat a spec/document as the requirement and code as the implementation; flag mismatches.
- Log bug + fix in `<issues file>` and the README logbook in the same commit; say *why*; record corrections.

**Several Claude sessions share ONE desktop MATLAB** (`--matlab-session-mode=auto`). Run checks on another tree in
a separate `matlab -batch` from a worktree outside the repo (not under `.claude/`). One extra batch at a time
(~2.3 GB each). A dictionary with `HasUnsavedChanges` is what a fresh MATLAB reads.

**Skills.** Check before improvising: `building-simulink-models`, `simulating-simulink-models`,
`managing-simulink-projects`, `simulink-debug-commandline`, `simulink-profiler-analyzer`,
`simulink-profile-initialization`, `simulink-solver-profiler-analyzer`, `simulink-tile-layout`,
`matlab-debug-code`, `matlab-write-test`, `matlab-review-code`, `matlab-modernize-code`. Read the four plain
notes `.claude/skills/simulink-{interaction,modeling,simulation,baseline-test}.md` before any model-touching MATLAB.
Blocked here (no licence): `<e.g. checking-model-compliance, building-architecture-models, testing-simulink-models (degraded), ...>`.

**Do not touch:** `resources/project/**` (generated, but required), `<generated diagrams>`, vendor skills
(read, don't edit), `<archive branches>`.
