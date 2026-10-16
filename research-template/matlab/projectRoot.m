function root = projectRoot()
%PROJECTROOT Absolute path of the repo root (folder holding CLAUDE.md).
root = fileparts(fileparts(mfilename('fullpath')));
end
