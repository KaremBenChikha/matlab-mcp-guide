% startup.m - runs when MATLAB starts in this folder (the MCP server starts it here).
% 1. satk_initialize registers the Simulink Agentic Toolkit model_* tools; without it they all fail with
%    "Unrecognized function or variable 'satk_initialize'". Warns (does not abort) if the toolkit is missing.
% 2. The MCP Server Toolbox (shareMATLABSession) is an add-on; some sessions (seen with `matlab -batch` on
%    macOS R2026b) do not load it from the add-on registry, so add it explicitly when missing.
% 3. Project paths via setupPaths. Never genpath the root: it pulls inbox/ and .claude/ onto the path and a
%    stale copy then shadows the real function.
try
    if ispc, home = getenv('USERPROFILE'); else, home = getenv('HOME'); end
    if isempty(which('shareMATLABSession'))
        roots = {};
        try, roots{end+1} = matlab.internal.addons.util.retrieveAddOnsInstallationFolder; catch, end %#ok<AGROW>
        roots = [roots, {fullfile(home, 'Library', 'Application Support', 'MathWorks', 'MATLAB Add-Ons'), ... % macOS
                         fullfile(getenv('APPDATA'), 'MathWorks', 'MATLAB Add-Ons'), ...                 % Windows
                         fullfile(home, 'Documents', 'MATLAB', 'Add-Ons')}];                              % Linux default
        for k = 1:numel(roots)
            d = dir(fullfile(roots{k}, 'MATLAB_MCP_Server_Toolbox@*'));
            if ~isempty(d), addpath(fullfile(d(end).folder, d(end).name)); break; end
        end
    end
    addpath(fullfile(home, '.matlab', 'agentic-toolkits', 'simulink'));
    evalc('satk_initialize');
catch err
    warning('startup:satk', 'satk_initialize failed: %s', err.message);
end
addpath(fullfile(fileparts(mfilename('fullpath')), 'matlab'));
setupPaths();
