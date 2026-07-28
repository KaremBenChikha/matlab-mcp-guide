## Simulating Simulink Models
- Always use `out = sim(in)` where `in` is a `Simulink.SimulationInput` object
- Never use `set_param` for simulation parameters; use `in.setModelParameter(...)` instead
- Never call `load_system` or `open_system` before sim — the sim command loads automatically
- Input signals go through Inport blocks as `timeseries`, combined in `Simulink.SimulationData.Dataset`
- Log signals using dataset format; access via `out.logsout.get('signalName').Values`
- Plot with: `plot(out.logsout.get('signalName').Values)`
