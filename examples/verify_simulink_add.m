function y = verify_simulink_add(outDir)
%VERIFY_SIMULINK_ADD Five-second proof that Simulink builds and simulates: a = 5, b = 7, expects 12.
%   Builds a throwaway model in OUTDIR (default: a fresh temp folder), sets a and b through
%   Simulink.SimulationInput (never set_param on the model), simulates, checks, and removes the files.
%
%   matlab -batch "addpath('examples'); verify_simulink_add"
arguments
    outDir (1,1) string = string(tempname)
end
if ~isfolder(outDir), mkdir(outDir); end
mdl = 'add_test';
oldDir = cd(outDir);
cleanup = onCleanup(@() tidy(mdl, oldDir, outDir));   % one handler: fixed order, runs on error too

new_system(mdl);
add_block('simulink/Sources/Constant', [mdl '/a'], 'Value', 'a');
add_block('simulink/Sources/Constant', [mdl '/b'], 'Value', 'b');
add_block('simulink/Math Operations/Sum', [mdl '/Sum'], 'Inputs', '++');
add_block('simulink/Sinks/Out1', [mdl '/y']);
add_line(mdl, 'a/1', 'Sum/1'); add_line(mdl, 'b/1', 'Sum/2'); add_line(mdl, 'Sum/1', 'y/1');
Simulink.BlockDiagram.arrangeSystem(mdl);
save_system(mdl, fullfile(outDir, [mdl '.slx']));

in = Simulink.SimulationInput(mdl);
in = in.setVariable('a', 5).setVariable('b', 7).setModelParameter('StopTime', '1');
out = sim(in);
y = out.yout{1}.Values.Data(end);
assert(y == 12, 'expected a + b = 12, got %g', y);
fprintf('Simulink %s OK: a = 5, b = 7 -> a + b = %g\n', version('-release'), y);
end

function tidy(mdl, oldDir, outDir)
if bdIsLoaded(mdl), close_system(mdl, 0); end
cd(oldDir);
if isfolder(outDir), rmdir(outDir, 's'); end
end
