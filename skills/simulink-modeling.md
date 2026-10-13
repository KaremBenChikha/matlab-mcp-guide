## Building Simulink/Simscape Models Programmatically
- Add blocks: `add_block('libraryPath/BlockName', 'modelName/BlockName')`
- Simscape libraries: fl_lib, sdl_lib, SimscapeFluids_lib, nesl_utility
- Do NOT set block positions manually — use auto-arrange: `Simulink.BlockDiagram.arrangeSystem('systemName')`
- Connect Simscape ports: `simscape.addConnection(block1, port1, block2, port2)`
- Only connect ports with matching `ConnectionType`
- Enable variable logging: get default table with `simscape.instrumentation.defaultVariableTable(...)`, set Logging=true, apply with `simscape.instrumentation.setVariableTable(...)`
