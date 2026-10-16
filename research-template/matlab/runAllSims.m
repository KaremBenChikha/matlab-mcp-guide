function runAllSims()
%RUNALLSIMS Run every matlab/sims/sim_*.m in order and regenerate results/.
root = projectRoot();
files = dir(fullfile(root, 'matlab', 'sims', 'sim_*.m'));
for k = 1:numel(files)
    [~, name] = fileparts(files(k).name);
    fprintf('== %s\n', name);
    t = tic;
    feval(name);
    fprintf('   done in %.1f s\n', toc(t));
end
end
