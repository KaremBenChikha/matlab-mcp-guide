# skills/ - one original skill, four cheat-sheets, and MathWorks entries from an earlier toolkit distribution

> **`simulink-tile-layout/` is original work (MIT)** - a computed, integrity-gated layout for hub-and-spoke
> subsystems with N parallel flows, where `arrangeSystem` interleaves everything. Everything else in this
> folder is MathWorks-authored, as described below. `install/install.ps1` copies all of it (except
> `check-authoring`, which duplicates the catalog's `author-modeladvisor-checks`) into a project's `.claude/skills/`.

> **Authored by The MathWorks, Inc. Not original work of this repository.**
> Redistributed in source form under BSD-3-Clause **plus a third clause** restricting use to
> "in conjunction with MathWorks products and service offerings". Full licence text: [`../NOTICE`](../NOTICE).
>
> **If you have MATLAB, install these from MATLAB instead** - `setupAgenticToolkit("install")`
> gets the current, maintained versions. This folder is a snapshot, and snapshots go stale.

## Why these are here at all

They predate the current catalog. When the reference project was set up, these nine came from an
earlier Agentic Toolkit distribution and did **not** appear in
`~/.matlab/agentic-toolkits/*/skills-catalog/` under these names. They are included as a reference
point - useful if you are looking at an older setup, or if a name in someone's `CLAUDE.md` does not
resolve against today's catalog.

They are **unmodified**. Nothing here has been edited.

## What is in here, and what replaced it

| Entry | Kind | In today's catalog as |
|---|---|---|
| `check-authoring/` | Full skill - 13 files, custom Model Advisor checks: DetailStyle callbacks, ResultDetail reporting, `sl_customization` registration, edit-time check classes | **`author-modeladvisor-checks`** - renamed. Prefer the catalog copy. |
| `simulink-debug-commandline/` | Full skill - `sldebug`, the method-level simulation debugger. Step through Outputs / Update / Derivatives / Enable / Disable at a specific block and time step | Not present under this name |
| `simulink-profiler-analyzer/` | Full skill + 9 scripts - analyse Simulink Profiler results, find bottlenecks, compare two sessions for regressions | Not present under this name |
| `simulink-profile-initialization/` | Full skill + 12 scripts - profile the *initialization/compile* phase; diagnose slow model loading, generate flamegraphs | Not present under this name |
| `simulink-solver-profiler-analyzer/` | Full skill + 17 scripts - Solver Profiler: step size, zero-crossings, algebraic loops, solver resets | Not present under this name |
| `simulink-interaction.md` | Plain note, no frontmatter | - |
| `simulink-modeling.md` | Plain note, no frontmatter | - |
| `simulink-simulation.md` | Plain note, no frontmatter | - |
| `simulink-baseline-test.md` | Plain note, no frontmatter | - |

## The four `.md` files are notes, not skills

They have **no YAML frontmatter**, so Claude Code will not surface them as invocable skills and they
never auto-load. That is deliberate and worth copying as a pattern: they hold idioms that produce
**working-but-wrong** results if skipped, so you want them read *before* any model-touching MATLAB -
not offered as one option among 169.

Reference them explicitly from your `CLAUDE.md` as always-read notes. What they encode:

- **`simulink-interaction.md`** - "this block" = `gcb`, "this model" = `bdroot`, "this subsystem" = `gcs`
- **`simulink-modeling.md`** - use `add_block` + `Simulink.BlockDiagram.arrangeSystem`; **never**
  hand-position blocks with pixel coordinates
- **`simulink-simulation.md`** - **always** `out = sim(in)` with a `Simulink.SimulationInput`;
  **never** `set_param` for simulation parameters, because that mutates the model file instead of
  configuring a run
- **`simulink-baseline-test.md`** - capture a baseline *before* modifying any model, then verify
  against it. Without a Simulink Test licence this degrades to `sim` + `assert` rather than
  `sltest.TestCase` - degraded, not blocked

## How to use these

Do **not** copy this folder into `.claude/skills/` alongside the catalog - you would end up with two
copies of `check-authoring`/`author-modeladvisor-checks` and an agent that cannot tell which to
follow.

If you want one of the profiler/debugger skills and it is genuinely absent from your catalog, link
that single entry. On Windows use a **junction**, not a symlink - symlinks need administrator,
junctions do not:

```bash
cmd //c mklink //J ".claude\skills\simulink-profiler-analyzer" "<path-to-this-repo>\skills\simulink-profiler-analyzer"
```

Check your own catalog first:

```bash
ls ~/.matlab/agentic-toolkits/simulink/skills-catalog/*/
ls ~/.matlab/agentic-toolkits/matlab/skills-catalog/*/
```

The full current catalog - 169 skills with their trigger descriptions - is in
[`../SKILLS_CATALOG.md`](../SKILLS_CATALOG.md).

## What is *not* here

The **MCP server binary** is deliberately not redistributed. Get it with
`setupAgenticToolkit("install")` from inside MATLAB: that fetches the current version, installs it
to `~/.matlab/agentic-toolkits/bin/`, and `setupAgenticToolkit("update")` keeps it current. A binary
committed to Git is stale the day after it lands, and the toolkit documentation states that MCP
servers must not be shared by multiple users. See section 3 of the [main README](../README.md).
