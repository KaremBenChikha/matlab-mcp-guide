# <paper-title>

Research paper project: MATLAB/Simulink does the code and simulations, LaTeX holds the paper.
Generated from the research template of sim2paper. Fill the <placeholders>, delete what doesn't apply.

## Layout

- `inbox/` : original material, **read-only**. Never edit, rename or delete anything here.
  `thesis/` report/thesis, `draft/` paper draft, `comments/` reviewer/supervisor comments,
  `matlab-legacy/` old code as found, `refs/` cited papers.
- `matlab/src/` reusable functions (models, solvers, metrics). Pure functions, no plotting, no globals.
- `matlab/sims/` one script per experiment, `sim_<nn>_<what>.m`. Each sets its own parameters and seed
  (`rng(<seed>)`), calls `src/`, saves to `results/`, exports its figures with `saveFigure`.
- `matlab/tests/` `matlab.unittest` tests for everything in `src/` (plus a smoke test per sim).
- `results/figures/` generated vector PDFs used by the paper; `results/tables/` generated LaTeX tables;
  `results/cache/` .mat outputs (gitignored, reproducible).
- `paper/` LaTeX: `main.tex`, `sections/*.tex`, `refs.bib`. Figures come from `\resdir/figures` via
  `\graphicspath`; never copy figures by hand.
- `notes/` `plan.md` (roadmap), `comments-tracker.md` (comment -> status -> where fixed),
  `legacy-map.md` (old code -> new code, what changed, does it reproduce).

## Rules

- Legacy code is ported, not edited in place. First reproduce the original numbers/figures, then change.
- Every number, figure and table in the paper comes from a script in `matlab/sims/`. No hand-edited values;
  the caption or a `% source: sim_xx` comment names the script.
- Every `src/` function gets a test; `make test` passes before any commit touching `matlab/`.
- Fixed seeds; no absolute paths (use `projectRoot()`).
- Never invent results, citations or data. Unverifiable reference -> `\todo{verify}`.
- Each comment in `inbox/comments/` gets a row in `notes/comments-tracker.md`; close it only when the fix
  is in the .tex and the PDF builds.

## Commands

    make test      # MATLAB unit tests (headless)
    make sims      # run all sims, regenerate results/
    make paper     # build paper/main.pdf (tectonic)
    make overleaf-zip  # self-contained zip to upload to Overleaf

Windows without make:
`matlab -batch "addpath('matlab'); setupPaths; runtests('matlab/tests')"` and
`matlab -batch "addpath('matlab'); setupPaths; runAllSims"`.
MATLAB `<release>` at `<root>`. Cold start ~30 s: batch work into one call.

## Overleaf

The git repo is the source of truth. Overleaf's free plan has no git sync: `make overleaf-zip`, upload as a
new project, bring co-author edits back by diffing the downloaded zip against `paper/`.

<!-- Append templates/CLAUDE.matlab-rules.md from sim2paper here (MATLAB/Simulink rules for agents). -->
