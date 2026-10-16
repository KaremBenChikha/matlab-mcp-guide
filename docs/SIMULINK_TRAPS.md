# Simulink & tooling traps (field-tested)

Every item below was met the hard way on a large, scripted, bus-heavy fixed-step model (roughly 80
logged signals, a dozen shared Subsystem References, a data dictionary, binary `.slx` under Git) and
cost at least one wrong answer before it was written down. They are generic: names of the original
project are removed, the mechanism is kept. **An agent should read this before editing any model through
`model_edit` or a script.**

Format: **bold = the trap**, then why it bites, then what to do. Verified on R2026a unless stated.

Contents: [A. Editing & tooling](#a-editing--tooling) · [B. Buses & ports](#b-buses--ports) ·
[C. Lines](#c-lines) · [D. Types, rates & blocks](#d-types-rates--blocks) ·
[E. Subsystem References & variants](#e-subsystem-references--variants) · [F. Logging](#f-logging) ·
[G. Paths, dictionaries & sessions](#g-paths-dictionaries--sessions) · [H. Model Advisor without Simulink Check](#h-model-advisor-without-simulink-check) ·
[I. Regression discipline](#i-regression-discipline)

---

## A. Editing & tooling

- **`model_edit` does NOT save.** A probe that starts with `bdclose('all')` throws away every pending
  edit. Save first, check second. And since a binary `.slx` edit cannot be diffed or undone, confirm the
  tree is clean and committed *before* any `model_edit`.
- **`model_edit` can silently rewrite parameter text.** It turned a Relational Operator's `>=` into `<=`
  and nothing warned; it also added a To Workspace block with `SampleTime = 0` (base rate) instead of `-1`
  (inherit), so a 1 Hz signal logged at the base rate. Put a **census of every parameter your script set**
  (read back with `get_param`) in each pass and *read it*; prefer `set_param` for any value containing `<`
  or `>`; set To Workspace `SampleTime` explicitly.
- **`model_edit` cannot address a block whose name equals its parent's** (block `Clock` inside subsystem
  `Clock`): it fails *after* disconnecting lines. Use MATLAB's own `replace_block` matched on `BlockType`.
- **`model_edit` `incremental` layout keeps old blocks where they are and packs new ones around them** -
  on a level that `arrangeSystem` had laid out, 18 new blocks crossed every new wire over the old and
  stacked two labels. After the edit run `Simulink.BlockDiagram.arrangeSystem`, `print(['-s' sys],'-dpng')`
  and **look**, then save.
- **`model_overview` / `model_read` can refuse a subsystem scope with `SCOPE_INVALID` ("content not
  present") right after a compile/term in the same session.** Fall back to `find_system` + `PortConnectivity`
  or reload the model.
- **`arrangeSystem` can decline** ("Automated layout might not improve upon original layout") and leave a
  pile exactly as it was. It is a *warning*, so a script that trusts the call saves the pile.
  `Simulink.BlockDiagram.arrangeSystem(sys,'FullLayout','true')` forces it (string `'true'`, not a
  logical). Forced is not always better: on a level of a few big hub subsystems with 20–90 ports each it
  scatters blocks and routes through them. Judge with a census (diagonal segments, overlapping pairs,
  segments through a block, **line crossings**, total length) and keep the layout with fewer crossings.
- **`arrangeSystem` interleaves N parallel independent flows into one sprawl.** For repeated
  hub-and-spoke tiles use the computed-layout skill [`skills/simulink-tile-layout`](../skills/simulink-tile-layout/SKILL.md),
  the sanctioned exception to "never hand-position blocks": every coordinate derives from actual port
  positions and the script ends with an integrity gate (line count unchanged, 0 broken, 0 unconnected).
- **A model left open on the visible desktop gets its view state saved**, dirtying the tree with a
  ~4 MB cosmetic diff. Close loaded models when done. Zip-diff any unexplained `.slx` change against HEAD
  before touching it: view state only touches `windowsInfo.xml`, `coreProperties.xml`, `thumbnail.png`;
  anything that moves a `<Block ` or `<Line>` count is real work - never discard it.
- **A manual tidy-up from the desktop sweeps wide annotations.** Selecting blocks with a rubber band takes
  a wide note with them and deleting/moving drops it (this happened six times in one project). Before
  committing a desktop save: `unzip` both versions, `diff -rq`, count `<Annotation SID`; keep a script
  that restores the notes idempotently.
- **A compile left open, then `bdclose('all')`, fires any lingering `onCleanup('term')`** with a loud
  "must be compiled before it can be accessed" error. Harmless; it means an earlier script already
  terminated the model. Pair every `compile` with its own `term` in the same script.
- **A demo or harness that calls its own builder SAVES the model it builds** and leaves a tracked `.slx`
  modified after every run. Run `git status` after running any demo/generator.
- **`Commented` on/off round-trips leave the model Dirty** though nothing changed - close without saving.
- **Full Model Advisor audit takes 30+ min and outlives the MCP idle timeout.** It completes on the MATLAB
  side: read output file timestamps instead of re-running.
- **MATLAB regexp has no `\b`** (use `\<` `\>`), and `^` is start-of-string unless `'lineanchors'`; `(?m)`
  silently does nothing. A counting regex that matches nothing reads as "0 checks" with no error - test it
  on known input.
- **`run('script')` executes in the caller's workspace** - a script that assigns `t0` destroys your `tic`
  handle. Time in the caller; isolate runners behind a function with an unlikely local name.
- **MATLAB integer division rounds to nearest; a block with `RndMeth = Floor` truncates.** An
  `uint16(a / uint64(2^32))` is one too high for any value ≥ 2^31 - invisible while test values are small.
  When a `.m` and a block must agree, integer `/` is a parity question: use `idivide(...,'floor')`, a shift,
  or keep the pair.
- **A Bash heredoc eats `\n`.** When writing MATLAB through a shell, write the file with the editor tool,
  not `echo`/heredoc, if the code contains escape sequences.

## B. Buses & ports

- **Bus-element inports share ONE physical port.** Deleting one element block drops the port's *incoming
  line* and orphans the survivors - invisible in the diagram (two "dead" taps removed silently disconnected
  a live signal). After any such edit: reconnect the port explicitly, then `model_check`.
- **Setting `Element` on an Out Bus Element RENAMES that element for every downstream reader.** A "park
  the outports on placeholder names first" pass retargeted 24 readers. Never re-purpose an outport for
  another field: find it by the element it carries and rename the block; do a deliberate element rename
  **once, at the source**. Companion: `set_param(blk,'Name',…)` invalidates any path string you hold -
  hold handles.
- **A fresh Out Bus Element names its element `signal1` and NESTS the bus.** `add_block` + `PortName` on a
  block meant to export a *whole* bus yields `Element='signal1'` from the unnamed line; readers are
  silently *remapped* ("Remapping selected signal…", a warning on every compile). A whole-bus element is
  `Element=''`, set and asserted.
- **Join an existing bus-element port by COPYING a block already on the port** (`add_block(existing,new)`),
  then set `Element`. Setting `PortName` on a fresh block *renames its own port* and collides; setting
  `Port` to an existing number *inserts* a port there and shifts the rest. That is also how to reorder:
  `Port = N` on any one block of a shared port moves the whole port, lines intact.
- **Port blocks cannot be commented.** `Commented='on'` on In/Out Bus Element is refused. A parked layer's
  *unread* port elements must be deleted (with re-creation recorded in a swap note); a *read* element must
  be fed by the replacement.
- **Deleting a subsystem's port blocks leaves the EXTERNAL line hanging** (source `-1`); the next port made
  at that number re-attaches to whatever line is left ("destination port already has a line connection").
  Detach every line on the block's ports first, record readers of an output before its last element block
  goes, delete the reader-side stub, then re-add and assert. Deleting an Outport leaves a line at the parent
  with both ends gone (`model_check`: *Connected off*) - delete it outright.
- **Port names and block names share one namespace in a subsystem.** A block cannot be called `LTE` beside a
  port `LTE`; use `ibe_`/`obe_` prefixes on port blocks.
- **`get_param(portHandle,'Name')` is the SIGNAL name, not the port name.** To find a bus port by name read
  `get_param([sys '/ibe_X'],'Port')` on the In Bus Element that declares it.
- **A MATLAB Function's vector output is 1-D even if the `.m` returns a column.** A rebuild with an honest
  `Reshape` to a column logged `24x1xN` instead of `Nx24` and cost a bit-identity compare - `isequal`
  compares dimensions. Match what the logs showed before; a 2-D scalar beside 1-D scalars is a latent flip
  (Logic block output dimensionality follows whichever input propagates first) - Reshape to 1-D at the source.
- **Relational Operator and Switch do not expand a scalar against a *matrix*** (`[4 1]`); a 1-D vector
  would expand. Expand the scalar first (vertical Concatenate of copies) or keep it 1-D.

## C. Lines

- **A wire has no colour of its own - it takes its SOURCE block's `ForegroundColor`.** Colour layers by
  colouring *sources*. A multi-class source gets its dominant class; per-signal colour needs a Goto/From pair.
- **`delete_line(handle)` on a branched line removes every branch.** To drop one consumer use the port-pair
  form `delete_line(sys, srcPort, dstPort)` - **but it leaves a dangling stub** (`DstPortHandle -1`, dashed
  red) invisible to `model_check` and to a capture that skips `SrcPortHandle<0`. Sweep after any port-pair
  delete, or rebuild the source line outright (delete from the source, add every real destination back).
- **`find_system(...,'FindAll','on','Type','line')` returns branch segments as well as trunks**, each
  reporting the trunk's `SrcPortHandle`; a trunk's `DstPortHandle` lists every leaf with dangling ones as
  `-1`. Filter `LineParent < 0` for trunks and collect handles **before** any `delete_line` - deleting a
  trunk invalidates its branches ("Invalid Simulink object handle").
- **`find_system(sys,'SearchDepth',1,'Type','block')` returns `sys` itself first only when `sys` is a
  subsystem.** A model root is not a block, so the `b(2:end)` idiom drops the first real block. Strip the
  first element only when it equals `sys`.
- **An area annotation's name is a path** - no `/` in an area or note title.
- **`add_block(existingMatlabFunctionBlock,newPath)` copies the chart with its script** - the way to move a
  MATLAB Function block up a level. Reconnect by port number; the copy has no lines.

## D. Types, rates & blocks

- **A Constant's `OutDataTypeStr` wins over its typed `Value`.** `Value=uint8(0)` with `OutDataTypeStr=double`
  outputs a double; a Switch with that on one leg resolves to double downstream. A typed literal wants
  `Inherit: Inherit from 'Constant value'`. Census `OutDataTypeStr` on every new Constant.
- **A Logical Operator refuses a non-boolean input while `BooleanDataType` is on.** On uint8/32/64 the
  "nonzero" test is a **Data Type Conversion to boolean**, and `x==0` is that followed by a one-input NOT.
- **A Multiport Switch with a default port still ERRORS on an unlisted control value** unless
  `DiagnosticForDefault='None'` (that exact name).
- **Chart data renamed by position keeps its old type.** Reordering a MATLAB Function's inputs left the data
  object typed `uint8`, and a Unit Delay types itself from its IC → *"Inferred type … does not match back
  propagated type"* on the block **upstream**. Pin chart data and ICs when a wrapper's I/O changes.
- **A MATLAB Function wrapper can hide a dead input behind a literal.** A wrapper passed `time=uint64(0)` and
  `reset=uint8(0)` to its core function for three weeks, so every timeout inside was structurally dead.
  Read the *wrapper script* (`sfroot.find(...,'Path',blk).Script`), not just the `.m` it calls.
- **A stateful component that runs every step diverges from a `.m` that guards on `valid`.** The block
  evicted a live entry on idle steps that the `.m` ignored. Gate the *write* of every store on the `.m`'s
  guard, apply `reset` to the previous state before the write, and check idle/eviction/reset cases with a
  scripted mini oracle - a stimulus that never reaches a threshold can never pin it.
- **Algebraic loops through a feedback path** (a controller's own outputs fed back through a peer or a
  parse chain) are not broken by a Rate Transition; a **Unit Delay read** is (one step of lag). Know the
  lag you are buying.
- **A request into a void waits the whole timeout.** At a faster step a boot request reached a handshake
  emulator one step before the observer had seen a frame; it committed to "never answers" and cost the full
  timeout. Gate any consumer of a request on the producer having seen its inputs.
- **Constants dimensioned in STEPS, not time, change physical meaning silently when the step changes.**
  Keep a helper that prints what each step-valued constant becomes; re-scale by hand before any step change.
- **Multi-rate hides in "inherit".** Check `CompiledSampleTime` rather than assuming a rate; keep a script
  that compiles and lists every block off the base rate (it must list nothing). A `Delay` of length 1 on a
  slow signal feeding a fast consumer is refused ("performs rate transition").
- **A harness of a component whose Unit Delays carry an explicit sample time must step at that time**; a
  `FromWorkspace` driving a matrix port needs the `struct('time',…,'signals',struct('values',V,'dimensions',[n 1]))`
  form with `V` sized `n×1×N` - `timeseries` is for scalars.
- **One time base:** feed a component's time through a port from one clock; never add a
  second `DigitalClock` (rounding `Floor` vs `Nearest` differs at another step).
- **A state machine without Stateflow is blocks, and the pattern is fixed:** one subsystem per `case`
  computing its candidate from the *previous* state; a Multiport Switch on the previous state
  (`DataPortOrder='Specify indices'`, default port) picks it; each store is a Unit Delay whose previous
  value passes a reset Switch *before* the logic reads it; first-step detection via a Unit Delay of `true`
  with IC `false`. Verify against the `.m` step by step before swapping.

## E. Subsystem References & variants

- **Variant Subsystems map choice ports to container ports BY NAME, not by position.** Two sources wired to
  the wrong ports hid for weeks with only a data type as symptom. Compare mirrored copies **by port
  number** as well - the compiled positional signature is what a harness or `model_edit` by index sees.
- **A Subsystem Reference is ONE file, N instances.** An edit made through one instance fails on the other
  with "locked by …". Edit the referenced file once (`load_system('x_subsystem')`, edit, `save_system`).
  A sweep with `find_system(...,'LookUnderMasks','all')` descends into nested references and locks on the
  first instance - filter hits to the model's own blocks and edit nested files as their own models.
- **A variant flag's justification can outlive its reason.** A comment said the block choice lacked a port;
  it had it, wired. Read the choice's ports before trusting a comment about them.
- **A new declared variant pair is several edits** (a table of pairs, the standard's table, and a test with
  its own hard-coded list). Search for the pair name's siblings before declaring done.
- **A parked (Commented) block is in the file but out of the compile** - it keeps parameters and interior,
  counts in zip-diff block counts, but types nothing, logs nothing, takes no port slot. A parked
  `ToWorkspace` and a live replacement on the same variable name collide when uncommented.

## F. Logging

- **`ToWorkspace` keeps 1000 samples by default.** Set `MaxDataPoints='inf'` on every sink, including those
  a scratch harness adds - otherwise the last 1000 samples are logged and a "pass" compares only the tail.
  A report must say what window it covered.
- **A tap's name is not evidence of where it lives.** `_B` taps sat inside the `A` side on the `A` signals;
  `find_system` the tap and read its `Parent`. A logged flag can be wired from the wrong source for weeks -
  check logging against the thing it claims to log.
- **Every negative scenario needs a vacuity guard** - an assertion that the injection actually happened
  (`all()` over an empty selection is true).
- **Some variables can only be set with `setappdata`**: a `setVariable` value reaches the blocks but
  `exist()` inside an `InitFcn` returns 0. Document which injection route each knob takes.

## G. Paths, dictionaries & sessions

- **Never a bare `addpath(genpath(root))`** - see L12 in the [guide](GUIDE.md#l12-genpath-sweeps-git-worktrees-and-archives-onto-the-path).
  Use one filtered helper everywhere. Diagnose with `which <fn> -all`, then `git worktree list`.
- **A dictionary's UNSAVED changes in one MATLAB are what a fresh MATLAB reads** (L10). Check
  `HasUnsavedChanges==0` in every open MATLAB before a background capture, and never run a
  dictionary-injecting scenario in parallel with one.
- **Defining a dictionary name in the base workspace at a different value makes Simulink refuse to run**
  ("Symbol … has multiple inconsistent definitions"). That is the point. Read values via a helper; never
  retype one into a `.m`. Generate the dictionary from a script and edit the script, not the `.sldd`.
- **A run of the article may have a minimum `StopTime`** enforced by a guard in the init - a demo can be
  silently broken for a month by a shorter default. Put such guards in `CLAUDE.md`.
- **Do not `set_param` a `StopFcn` on the article** - blank it on the `SimulationInput`
  (`in.setModelParameter('StopFcn','')`) when a run must not draw.
- **Model callbacks resolve against the current folder, not the project** (guide L2): any `dir`, `exist`,
  `delete`, `rmdir` in a Close/Stop/Init callback follows the cwd or the path. Resolve the project root
  explicitly and no-op if there is no project.
- **A first compile can be slow** (~140 s cold on a large model with a crypto/bootstrap InitFcn). Do not
  mistake it for a hang; do not run two at once on a 16 GB machine.

## H. Model Advisor without Simulink Check

The `Simulink.ModelAdvisor` **object API** runs with only Simulink (108 checks here). Gated on Simulink
Check: batch `ModelAdvisor.run`, the `hisl_*` / MAB / JMAAB / DO-178C groups, and custom checks. No output
may be called a DO-178C compliance report. Two traps: **do not pre-compile** (every PostCompile check then
fails *inside the result payload* as a `Warn`), and `getCheckResultStatus == false` means *not run* until
`getCheckResult(id)` is non-empty. A model-standard checker you write yourself must treat **NOTRUN as not a
pass**.

## I. Regression discipline

- **Definition of done for a cosmetic or routing change = bit-identical nominal run.** Capture a baseline
  of every logged variable first, re-run, compare with `isequal` (dimensions included), and read the
  "moved" lines before deciding a value moved. A functional change says which variables moved and why.
- **Write the oracle check BEFORE rebuilding.** Converting MATLAB Function blocks to drawn blocks with the
  `.m` as oracle found real defects in the original `.m` code on the first mini-check.
- **A suite that errors at the end records nothing.** If a runner ends with `error('FAILURES')` the
  artifact may show `passed 0 / failed 1` with no text - run the suite directly to see which line failed.
- **Generated docs/maps of a model must be regenerated with every model change**, in the same commit.
- **Ordering of port numbers is an interface.** Treat a port-order change as a breaking change for every
  harness, mirror and script that indexes by number.
