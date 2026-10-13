function layout_tiles(sys, tiles, areaTokens)
%LAYOUT_TILES Deterministic cosmetic layout for hub-and-spoke Simulink subsystems.
%
%   layout_tiles(SYS, CONTAINERS)
%   layout_tiles(SYS, CONTAINERS, AREATOKENS)
%
% SYS        - full path of the subsystem level to lay out, e.g.
%              'MyModel/Receiver/Parse'
% CONTAINERS - cell array of container block NAMES at that level, one per
%              tile, in tile order (row-major, 2 columns), e.g.
%              {'Parse LTE','Parse SATCOM','Parse RF','Parse STARLINK'}
% AREATOKENS - optional cell array, same length: for each tile, a substring
%              of the area annotation that should wrap it (e.g. channel
%              name). Omit or pass {} to leave annotations alone.
%
% What it does (MOVES AND RESIZES ONLY - never adds, deletes, or rewires):
%   * one tile per container, 2 columns, row-major
%   * container resized so every port gets ~30 px spacing
%   * each input source right-aligned at its container inport's exact y
%   * each output destination in a column at its outport's exact y;
%     extra destinations on a branched port offset right by 170 px
%   * pass-through destinations (anything that is not an Inport, Outport,
%     or Terminator - e.g. an ASCII->Display debug chain) parked above the
%     tile, their immediate downstream blocks placed to their right
%   * Inport/Outport blocks normalized to 30x14; other blocks keep size
%   * area annotations (if AREATOKENS given) resized to wrap their tile
%   * every line at this level rerouted (Simulink.BlockDiagram.routeLine)
%   * prints an integrity summary: broken lines / unconnected ports must
%     both be 0 and the line count must match the pre-layout count
%
% It does NOT save. Caller verifies the summary, then save_system.

if nargin < 3, areaTokens = {}; end

% ---- pre-layout integrity baseline
nLines0 = numel(find_system(sys,'FindAll','on','SearchDepth',1,'Type','line'));

% ---- geometry
NCOLS  = 2;
CONT_W = 220;                 % container width
CONT_X = 420; CONT_Y = 80;    % container top-left inside the tile
SRC_XR = 340;                 % source column right edge (tile-relative)
DST_XL = 860;                 % destination column left edge (tile-relative)
TILE_W = 1650;
PORT_WH = [30 14];            % normalized Inport/Outport size
X0 = 100; Y0 = 100;

% tile height from the tallest container in the set
maxPorts = 0;
for k = 1:numel(tiles)
    ph = get_param([sys '/' tiles{k}], 'PortHandles');
    maxPorts = max([maxPorts, numel(ph.Inport), numel(ph.Outport)]);
end
contHmax = max(120, 30*maxPorts);
TILE_H = CONT_Y + contHmax + 250;

placed = containers.Map('KeyType','double','ValueType','logical');

for k = 1:numel(tiles)
    r  = floor((k-1)/NCOLS); c = mod(k-1, NCOLS);
    ox = X0 + c*TILE_W; oy = Y0 + r*TILE_H;
    cont = [sys '/' tiles{k}];

    ph = get_param(cont,'PortHandles');
    contH = max(120, 30*max(numel(ph.Inport), numel(ph.Outport)));
    set_param(cont,'Position',[ox+CONT_X, oy+CONT_Y, ox+CONT_X+CONT_W, oy+CONT_Y+contH]);
    ph = get_param(cont,'PortHandles');           % refresh after resize
    pc = get_param(cont,'PortConnectivity');

    for i = 1:numel(pc)
        s = pc(i); pn = str2double(s.Type);
        if isnan(pn), continue; end               % enable/trigger/etc: skip
        if ~isempty(s.SrcBlock) && s.SrcBlock > 0
            % ---- input source: right-align at the inport's y
            py = get_param(ph.Inport(pn),'Position');
            moveTo(s.SrcBlock, ox+SRC_XR, py(2), 'right', PORT_WH, placed);
        elseif ~isempty(s.DstBlock)
            % ---- output destinations: column at the outport's y
            py = get_param(ph.Outport(pn),'Position');
            colUsed = 0;
            for d = s.DstBlock(:)'
                bt = get_param(d,'BlockType');
                if any(strcmp(bt,{'Inport','Outport','Terminator','ToWorkspace','Scope','Display'}))
                    x = ox+DST_XL + 170*colUsed; colUsed = colUsed+1;
                    moveTo(d, x, py(2), 'left', PORT_WH, placed);
                else
                    % pass-through chain (debug tap): park above the tile
                    p0 = get_param(d,'Position'); w = p0(3)-p0(1); h = p0(4)-p0(2);
                    set_param(d,'Position',[ox+DST_XL, oy-10, ox+DST_XL+w, oy-10+h]);
                    placed(double(d)) = true;
                    dh = get_param(d,'PortHandles');
                    for op = dh.Outport(:)'
                        dl = get_param(op,'Line');
                        if dl > 0
                            for dd = get_param(dl,'DstBlockHandle')'
                                p1 = get_param(dd,'Position'); w1=p1(3)-p1(1); h1=p1(4)-p1(2);
                                set_param(dd,'Position',[ox+DST_XL+w+60, oy-8, ox+DST_XL+w+60+w1, oy-8+h1]);
                                placed(double(dd)) = true;
                            end
                        end
                    end
                end
            end
        end
    end

    % ---- wrap the matching area annotation around the tile
    if ~isempty(areaTokens)
        ann = find_system(sys,'FindAll','on','SearchDepth',1,'Type','annotation');
        for a = ann(:)'
            if strcmp(get_param(a,'AnnotationType'),'area_annotation') ...
                    && contains(get_param(a,'Name'), areaTokens{k})
                set_param(a,'Position',[ox-60, oy-70, ox+TILE_W-320, oy+CONT_Y+contH+90]);
            end
        end
    end
end

% ---- reroute every line at this level
lines = find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
try
    Simulink.BlockDiagram.routeLine(lines);
catch e
    fprintf('routeLine: %s\n', e.message);
end

% ---- integrity summary (all three numbers must be clean before saving)
% routeLine can recreate lines - re-fetch handles before inspecting them
lines = find_system(sys,'FindAll','on','SearchDepth',1,'Type','line');
bad = 0;
for l = lines(:)'
    if get_param(l,'SrcPortHandle') < 0 || any(get_param(l,'DstPortHandle') < 0)
        bad = bad + 1;
    end
end
ports  = find_system(sys,'FindAll','on','SearchDepth',1,'Type','port');
unconn = sum(arrayfun(@(p) get_param(p,'Line') < 0, ports));
fprintf('layout_tiles: %d tiles | lines %d -> %d (%d broken) | %d ports (%d unconnected)\n', ...
    numel(tiles), nLines0, numel(lines), bad, numel(ports), unconn);
if bad > 0 || unconn > 0 || numel(lines) ~= nLines0
    warning('layout_tiles:integrity', 'integrity check FAILED - do not save; revert the model.');
end
end

function moveTo(h, x, portY, alignEdge, portWH, placed)
% center block vertically on portY; align its left or right edge on x
if isKey(placed, double(h)), return; end
placed(double(h)) = true;
bt = get_param(h,'BlockType');
if any(strcmp(bt,{'Inport','Outport'}))
    w = portWH(1); hh = portWH(2);
else
    p = get_param(h,'Position'); w = p(3)-p(1); hh = p(4)-p(2);
end
y = round(portY - hh/2);
if strcmp(alignEdge,'right'), x1 = x - w; else, x1 = x; end
set_param(h, 'Position', [x1, y, x1+w, y+hh]);
end

