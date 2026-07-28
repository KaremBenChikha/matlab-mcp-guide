## Baseline Testing Pattern
- Capture baseline before modifying any model
- Use `Simulink.SimulationInput` with `setVariable` for variant parameters
- Save baseline with `save('baseline.mat', 'logsout')`
- Use `sltest.TestCase` with `verifySignalsMatch` for validation
- Use `testCase.setUp`/`tearDown` to load/close models cleanly
