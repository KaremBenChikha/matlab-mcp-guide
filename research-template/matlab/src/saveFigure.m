function out = saveFigure(fig, name)
%SAVEFIGURE Export a figure as vector PDF to results/figures/<name>.pdf.
arguments
    fig (1,1) matlab.ui.Figure
    name (1,1) string
end
outDir = fullfile(projectRoot(), 'results', 'figures');
if ~isfolder(outDir), mkdir(outDir); end
out = fullfile(outDir, name + ".pdf");
exportgraphics(fig, out, 'ContentType', 'vector');
end
