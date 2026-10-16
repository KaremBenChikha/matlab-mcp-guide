function setupPaths()
%SETUPPATHS Add project MATLAB folders to the path.
root = projectRoot();
addpath(fullfile(root, 'matlab'), fullfile(root, 'matlab', 'src'), fullfile(root, 'matlab', 'sims'));
end
