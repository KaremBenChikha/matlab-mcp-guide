classdef SmokeTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(~)
            setupPaths();
        end
    end
    methods (Test)
        function rootHasClaudeMd(tc)
            tc.verifyTrue(isfile(fullfile(projectRoot(), 'CLAUDE.md')));
        end
        function startupPutsProjectOnPath(tc)
            run(fullfile(projectRoot(), 'startup.m'));
            tc.verifyNotEmpty(which('saveFigure'));
            entries = strsplit(path, pathsep);
            tc.verifyFalse(any(contains(entries, {'/inbox', '/.claude', '/.git'})), ...
                'inbox/, .claude/ and .git/ must never be on the path');
        end
        function startupWiresAgenticToolkit(tc)
            tk = fullfile(getenv('HOME'), '.matlab', 'agentic-toolkits');
            tc.assumeTrue(isfolder(tk), 'Agentic Toolkit not installed on this machine');
            run(fullfile(projectRoot(), 'startup.m'));
            tc.verifyNotEmpty(which('satk_initialize'));
            tc.verifyNotEmpty(which('shareMATLABSession'));
        end
        function smokeSimWritesFigure(tc)
            f = fullfile(projectRoot(), 'results', 'figures', 'sim_00_smoke.pdf');
            if isfile(f), delete(f); end
            sim_00_smoke();
            tc.verifyTrue(isfile(f));
        end
    end
end
