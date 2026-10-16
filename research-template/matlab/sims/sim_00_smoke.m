function sim_00_smoke()
%SIM_00_SMOKE Placeholder sim proving the pipeline (MATLAB -> results -> paper). Delete once real sims exist.
rng(0);
t = linspace(0, 1, 200);
y = sin(2*pi*5*t) + 0.1*randn(size(t));
fig = figure('Visible', 'off');
plot(t, y); xlabel('t (s)'); ylabel('y'); grid on;
saveFigure(fig, 'sim_00_smoke');
close(fig);
end
