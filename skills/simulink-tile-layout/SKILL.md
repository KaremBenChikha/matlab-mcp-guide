---
name: simulink-tile-layout
description: Cosmetic cleanup of a flat Simulink subsystem whose structure is N parallel hub-and-spoke flows (repeated container subsystems, each with its own sources and sinks). Produces short wires, aligned blocks, and per-channel grouping. Use when asked to organize, clean, tidy, or "make neat" such a diagram.
---

# Simulink Tile Layout

Deterministic cosmetic layout for diagrams like a multi-channel parse/dedup/anti-replay level:
several structurally identical container subsystems, each fed by a few sources and fanning out
to a column of bus-element outports / terminators. First applied to a
104-block, 4-channel receive-chain level of a real model (2026-09-03).

## Why not `arrangeSystem`

The usual rule "never hand-position blocks; use `Simulink.BlockDiagram.arrangeSystem`" exists
to stop *eyeballed* coordinates. `arrangeSystem` layers the whole diagram by dataflow depth, so
on N *parallel* independent flows it interleaves the channels into one wide sprawl and ignores
area annotations - the opposite of "good grouping". This skill is the sanctioned alternative for
that case: every coordinate is **computed from the container's actual port positions** (via
`PortHandles`/`PortConnectivity`), not eyeballed, so alignment is exact and reproducible. For a
diagram with genuinely irregular dataflow, still use `arrangeSystem`.

## What the script guarantees

`scripts/layout_tiles.m` moves and resizes blocks ONLY - it never adds, deletes, or rewires
anything. Zero structural risk by construction. It ends with an integrity summary (line count
unchanged, 0 broken lines, 0 unconnected ports) and warns loudly if that fails.

## Workflow

1. **Clean tree first.** `model_edit`-class rules apply even to cosmetic edits: `git status`
   must be clean for the model; commit a checkpoint if not. Also confirm the loaded model is
   the right file - `get_param(mdl,'FileName')` - before trusting anything (a same-named model
   loaded from another tree shadows silently).
2. **Capture BEFORE:** `print(['-s' sys], '-dpng', '-r72', beforePng)` with the subsystem open.
3. **Identify the tiles.** List the container subsystem names at that level, in the tile order
   you want (row-major, 2 columns). Check one container's `PortConnectivity` to confirm the
   hub-and-spoke assumption: inputs come from dedicated source blocks, outputs go to
   outports/terminators (branches to a debug Display chain are handled automatically).
4. **Run:** with `scripts/` on the path (or `run` the file's folder):
   ```matlab
   layout_tiles('MODEL/Path/To/Subsystem', ...
       {'Container A','Container B','Container C','Container D'}, ...
       {'A','B','C','D'})   % optional: substrings matching the area annotations
   ```
5. **Gate on the summary line.** All of: lines N -> N, 0 broken, 0 unconnected. If the warning
   fires, do NOT save - `close_system(mdl, 0)` and reload.
6. **Save, capture AFTER, show both images to the user, commit.** Commit message should say
   "cosmetic only - moves/resizes, no add/delete/rewire" with the verified counts. A pure
   layout tidy-up needs no README logbook entry (a common convention: do not log layout
   tidy-ups), but the commit itself is mandatory - `.slx` is binary and un-diffable, so the
   checkpoint is the only undo.

## Layout produced

- One tile per container, 2 columns, row-major; tile size derived from the tallest container.
- Container resized to ~30 px per port so labels are readable.
- Sources right-aligned into a column, each centered exactly on its container inport's y.
- Destinations in a column at each outport's y; a branched port's extra destinations offset
  +170 px right; Inport/Outport blocks normalized to 30x14.
- Non-sink destinations (e.g. ASCII→String → Display debug taps) parked above the tile.
- Area annotations (when tokens are given) resized to wrap their tile.
- Every line rerouted with `Simulink.BlockDiagram.routeLine`.

## Limits

- One hierarchy level per run; it does not descend into the containers.
- Assumes each source/destination block belongs to one tile. A block shared between two
  containers is placed once (first tile that reaches it) and left there - check the AFTER
  image for any long wire that reveals sharing, and place that block by hand judgment.
- Tune `TILE_W` / `DST_XL` in the script if long bus-element labels overflow the tile.
