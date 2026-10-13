# Several Claude sessions, one MATLAB

Measured with three sessions open on a 16 GB Windows machine (2026-10-02).

## Facts

- With `--matlab-session-mode=auto`, **every Claude session's MCP server attaches to the SAME desktop MATLAB**
  (one MATLAB process pair; six `matlab-mcp-server` processes for three sessions). `satk_initialize` calls
  `shareMATLABSession`, which is what exposes it.
- So: never restart that MATLAB, never re-root its path, never run a project init in it "on another session's
  behalf", never leave a dialog or `input()` open in it (it blocks every session).
- A model loaded in an older MATLAB instance shows stale memory after someone saves the file elsewhere.
- Budget: ~4 GB free with the desktop MATLAB up → **one extra `matlab -batch` at a time** (~2.3 GB each).

## Running checks on another source tree without touching the shared MATLAB

1. Put the second tree in a **worktree OUTSIDE the repo folder and not on any MATLAB path**, same path depth,
   e.g. `C:\Users\<you>\Documents\MATLAB\proj-wt\<name>`. A worktree under `.claude/worktrees/` breaks any
   path helper that skips dot-folders (you get an EMPTY path list).
2. Start a separate process from a scratch folder, so the repo's `startup.m` (and `satk_initialize`) never run:

```bash
"/c/Program Files/MATLAB/R2026a/bin/matlab.exe" -wait -sd <scratch-dir> -logfile <log> -batch "run('<script>.m')"
```

   The script begins `cd(wt); addpath(wt); <your_filtered_addpath>(wt)`.
3. Print `which -all` of the key functions first, to prove nothing shadows.
4. `load_system(name)` before reading config you need at init.
5. Before any background capture, check dictionaries: `HasUnsavedChanges == 0` in every open MATLAB.

## Rules

- Branch per session; never two sessions editing the same `.slx`.
- Do not let two sessions run dictionary-injecting scenarios at once.
- After a sync/merge touching generated models: regenerate them, run the project's checks in a **fresh**
  MATLAB, compare the nominal run to the other line's.
