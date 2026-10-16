# Research workflow: from simulation to paper with Claude Code

How to finish (or restart) a MATLAB/Simulink-backed paper with an agent without losing reproducibility.
The skeleton is in [`research-template/`](../research-template); this page explains why it looks like that.

## The pipeline

```
inbox/ (originals, read-only)
   │  port + test
   ▼
matlab/src  ──►  matlab/sims/sim_NN_*.m  ──►  results/figures/*.pdf, results/tables/*.tex
                                                   │  \graphicspath, \inputtable
                                                   ▼
                                             paper/main.tex  ──►  main.pdf  (tectonic)
                                                   │  make overleaf-zip
                                                   ▼
                                               Overleaf (co-authors)
```

One rule holds it together: **every number, figure and table in the paper is produced by a script**.
Nobody (human or agent) pastes a value into the .tex. When a reviewer asks "where does Fig. 4 come from?",
the caption names the script and `make sims` regenerates it.

## Starting

```bash
cp -R research-template ~/my-paper && cd ~/my-paper && git init
install/install.sh --project ~/my-paper --profile core     # from this repo: MCP + skills
make test && make paper                                      # smoke sim -> figure -> PDF
```

Then drop your material into `inbox/`: thesis, draft (docx/tex/pdf), reviewer or supervisor comments, the old
MATLAB code exactly as found, cited papers. The agent treats `inbox/` as read-only evidence.

## Phases (track them in `notes/plan.md`)

1. **Intake.** The agent inventories `inbox/`, summarises the paper (claim, method, experiments, what was
   left unfinished), and turns each comment into a row of `notes/comments-tracker.md`.
2. **Reproduce.** Port legacy code into `matlab/src` + `matlab/sims` with tests, logging every file in
   `notes/legacy-map.md`. Reproduce the original figures and numbers *before* improving anything. Mismatches
   are findings, not things to smooth over.
3. **Finish.** Missing experiments, then the text: port the draft into `paper/sections/`, wire figures to
   `results/`, address every comment (a tracker row closes only when the fix is in the .tex and the PDF builds),
   verify every reference.

## Rules that keep an agent honest

- Never invent results, data or citations. An unverifiable reference becomes `\todo{verify}`.
- Fixed seeds (`rng(seed)`) in every sim; no absolute paths (`projectRoot()`).
- Every `src/` function has a `matlab.unittest` test; `make test` passes before a commit.
- Rewriting a section: show the diff, keep the author's voice.
- Never `genpath` the project root: `inbox/matlab-legacy` would shadow the ported functions.

## Overleaf or local?

Local git is the source of truth; LaTeX builds with [tectonic](https://tectonic-typesetting.github.io)
(`brew install tectonic`, `winget install tectonic`, or your distro's package), which fetches packages on
demand. Overleaf's free plan has no git sync, so `make overleaf-zip` produces a self-contained project
(figures and tables copied in, paths rewritten) to upload for co-authors; bring their edits back by diffing.
If you have Overleaf premium, its git remote works too, but keep `results/` generated, not edited there.

## Windows

`make` is optional. The same targets are two MATLAB calls and one tectonic call:

```powershell
matlab -batch "addpath('matlab'); setupPaths; runtests('matlab/tests')"
matlab -batch "addpath('matlab'); setupPaths; runAllSims"
cd paper; tectonic -X compile main.tex
```
