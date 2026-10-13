# Working agreement for an agent on a MATLAB/Simulink project

Distilled from several weeks of daily use. Copy what fits into the project's own `CLAUDE.md`.

## Order of work

1. Read `CLAUDE.md` and recalled memory. `git status`, current branch. **Never work on the default branch.**
2. If a model is involved: read the project's traps file and the relevant skill / cheat-sheet.
3. Prefer **`.m` first**, `.slx` only when structure must change (binary, unmergeable, no undo).
4. Sanity-check what you changed *directly*: a short `sim`, `model_check`, `check_matlab_code`. Report what you
   actually ran.
5. Log the bug and the fix in the project's issues file **and** the README logbook, same commit.
6. Commit on the branch; open a PR only when asked.

## Rules of conduct that paid off

- **Say it's blocked, then stop.** If a skill needs a toolbox that `detect_matlab_toolboxes` does not list,
  say so. Never invent Model Advisor, System Composer, coverage or compliance output.
- **Never quote a number you did not produce in this session** (test counts, gate results, timings).
- **Verification gates are the owner's call.** A 30-minute regression suite can be right for a release and
  wrong for a bug-fixing week. Record the owner's standing decision in `CLAUDE.md` ("do not run the
  `verify_*` gate unless asked") and obey it; do not gate PRs on it unprompted.
- **Branch → PR, even solo.** `.slx` cannot be merged; branches are the only undo. Short branches; one owner
  per model at a time; merge with a merge commit if branches are stacked.
- **Commit before `model_edit`, every time.** Tag a restore point before risky work.
- **Push, tag and merge only when the owner asks.** Uncommitted artefacts (office docs, evidence) are not
  committed without asking.
- **Documents beat code for requirements.** If a spec and the code disagree, flag the mismatch; do not
  silently trust either.
- **Record corrections, not just facts.** When something documented was wrong, the correction is the most
  valuable log entry. Never silently overwrite.
- **An agent has no memory of last week.** Put the *why* of decisions where the next session will read it,
  otherwise it relitigates them.
- **Production hardware is read-only.** If a bench or target unit belongs to someone else, only read-only
  `ssh host '…'` commands; leave nothing behind except an owner-approved folder.

## The "my edits are gone" triage

`git status` + file mtime vs `git log -1 --format=%ci -- <file>` → `git worktree list` / `stash list` /
`reflog` → list MATLAB processes (a stale instance shows its own memory). Before committing a desktop `.slx`
save: zip-diff vs HEAD, count blocks/lines/annotations. See guide L13.

## Memory hygiene for long engagements

One memory file per fact, with the *why* and *how to apply*. Retire per-PR logs into the README logbook once
merged; keep only durable lessons, standing decisions and open parked items. Verify a remembered path or flag
still exists before recommending it.

## Document upkeep rule (put it in `CLAUDE.md`)

Never finish work without updating `README.md` in the same commit: a logbook row (**say why, cite evidence**),
and any of Layout / Conventions / Open threads / Restore points that went stale. Never write a result you did
not run — "MATLAB was unavailable" is a valid entry; an invented count is not.
