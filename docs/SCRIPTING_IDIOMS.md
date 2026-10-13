# Scripting idioms — building and editing Simulink by code

Copy-paste patterns that worked. Pair with [SIMULINK_TRAPS](SIMULINK_TRAPS.md) (what goes wrong) and the
four always-read cheat-sheets in [`skills/`](../skills/) (`simulink-interaction.md`, `-modeling.md`,
`-simulation.md`, `-baseline-test.md`).

## Conventions that make a scripted model reviewable

1. **One hue per layer; a wire takes its source block's colour.** Colour blocks, not lines.
   Ports: `ForegroundColor` = `BackgroundColor` = hue. Goto/From/Constant: foreground hue, background white.
   Subsystems: hue + a light tint. Group with `built-in/Area` annotations.
2. **Prefixes tell you what a block is**: `ibe_`/`obe_` bus-element ports, `tw_` To Workspace taps,
   `Goto_`/`From_`, `c_` Constants, `sw_` Switches, `ud_` Unit Delays, `and_`/`or_`/`ge_`/`lt_` logic,
   `term_` terminators (hide the name, label the port).
3. **Buses over scalars.** Whole-bus ports for interfaces; bus elements for fields.
4. **Taps only** — no Scope/Display blocks in a model that is run headless; one diagnostics window is the viewer.
5. **Computed layouts, not eyeballed pixels** (`arrangeSystem`, or the tile-layout skill for parallel tiles).
6. **A constant is not a signal.** No inport named after a constant; a stage owns its own `c_<name>` Constant,
   a tunable value is a dictionary entry read by one Constant per reader.
7. **Group by spec step** inside a component: one subsystem per numbered step of the governing section, named
   after the step.
8. **A component exports the fields something reads**; terminate unread outputs at the block (`term_…`),
   unless a requirement names a future consumer.
9. **A nested repeated design is a Subsystem Reference file** (`models/<name>_subsystem.slx`), registered
   with its harness — never N copies.
10. **A MATLAB Function block in the article needs a written reason on its level.** "It is only a rig" is not
    one. Reasons that hold: a cryptographic primitive verified by known-answer vectors; hardware-in-the-loop glue.

## Snippets

```matlab
% join an existing bus-element port: COPY a block already on it, then set Element
ib = add_block([sys '/ibe_existing'], [sys '/ibe_new']); set_param(ib, 'Element', 'newElement');
% a fresh port: from the library, then name the port
ib = add_block('simulink/Ports & Subsystems/In Bus Element', [sys '/ibe_x']); set_param(ib, 'PortName', 'NewBus');
% whole-bus export: Element must be '' (a fresh Out Bus Element otherwise says 'signal1' and nests)
ob = add_block('simulink/Ports & Subsystems/Out Bus Element', [sys '/obe_Bus']);
set_param(ob, 'PortName', 'Bus', 'Element', '');
% reorder ports: Port = N on ANY block of a shared port moves the whole port, lines intact
set_param([sys '/ibe_RF'], 'Port', '2');
% drop ONE consumer of a branched line (delete_line(handle) kills every branch)
delete_line(sys, srcPortHandle, dstPortHandle);   % then sweep for dangling stubs
% paint
set_param(b, 'ForegroundColor', hue, 'BackgroundColor', hue);            % port
set_param(b, 'ForegroundColor', hue, 'BackgroundColor', 'white');        % Goto/From/Constant
set_param(b, 'ForegroundColor', hue, 'BackgroundColor', tint);           % subsystem
a = add_block('built-in/Area', [sys '/Layer name']); set_param(a, 'Position', bbox, 'BackgroundColor', tint);
% taps that log the whole run
set_param(tw, 'MaxDataPoints', 'inf', 'SampleTime', '-1');
% typed literal Constant
set_param(c, 'Value', 'uint8(0)', 'OutDataTypeStr', 'Inherit: Inherit from ''Constant value''');
% pure-boolean test of a uint signal under BooleanDataType: Data Type Conversion (boolean) -> NOT
% layout that forces itself, then LOOK at it
Simulink.BlockDiagram.arrangeSystem(sys, 'FullLayout', 'true');
print(['-s' sys], '-dpng', '-r72', fullfile(tempdir, 'level.png'));
% find a bus port by name (not get_param(portHandle,'Name'))
p = get_param([sys '/ibe_Peer'], 'Port');
% MATLAB Function blocks: MaskType is empty, use SFBlockType
mf = find_system(sys, 'LookUnderMasks', 'all', 'SFBlockType', 'MATLAB Function');
% a MATLAB Function block's real inputs: read the WRAPPER script, not just the .m it calls
r = sfroot; ch = r.find('-isa', 'Stateflow.EMChart', 'Path', blk); disp(ch.Script)
```

## Simulation, the safe way

```matlab
in  = Simulink.SimulationInput('MyModel');
in  = in.setVariable('Kp', 2.5);                            % variables: no model edit
in  = in.setModelParameter('StopTime', '60', 'StopFcn', '');   % never set_param the model for a run
out = sim(in);                                              % sim() loads the model itself
y   = out.logsout.get('y').Values;
save('baseline.mat', 'out');                                % capture a baseline BEFORE changing the model
```

## Component rebuild recipe (MATLAB Function → blocks)

1. Keep the `.m` as the **oracle**; the blocks are the article. Check which blocks are still MATLAB Function
   (`find_system` above) and read the file's own "ORACLE ONLY" header.
2. Write a **mini oracle check first** (stimulus incl. idle, eviction, reset, boundary values); run it on the
   old implementation; keep it.
3. Build in a Subsystem Reference file by script; census every parameter you set; arrange; look; save.
4. Compile/term clean; mini check passes step by step; baseline compare bit-identical on every logged variable.
5. Bring the oracle in line if the *intended* behaviour changed; record the change and why.
