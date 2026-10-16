# MATLAB: override with `make MATLAB=/path/to/matlab test`. Windows: run the matlab -batch lines from CLAUDE.md.
MATLAB ?= $(shell command -v matlab 2>/dev/null || ls -d /Applications/MATLAB_R20*.app/bin/matlab /usr/local/MATLAB/R20*/bin/matlab 2>/dev/null | tail -1)
ML = "$(MATLAB)" -batch

.PHONY: all test sims paper clean overleaf-zip

all: sims paper

test:
	$(ML) "addpath('matlab'); setupPaths; r = runtests('matlab/tests'); disp(table(r)); assert(all([r.Passed]), 'tests failed')"

sims:
	$(ML) "addpath('matlab'); setupPaths; runAllSims"

paper:
	cd paper && tectonic -X compile main.tex

# Self-contained zip for Overleaf upload: results/ copied in, \resdir rewritten to "."
overleaf-zip:
	@tmp=$$(mktemp -d) && cp -R paper/ $$tmp/ && rm -f $$tmp/main.pdf && \
	cp -R results/figures results/tables $$tmp/ && \
	sed -i.bak 's|\\newcommand{\\resdir}{../results}|\\newcommand{\\resdir}{.}|' $$tmp/main.tex && rm -f $$tmp/main.tex.bak && \
	rm -f overleaf.zip && (cd $$tmp && zip -qr $(CURDIR)/overleaf.zip . -x '.*') && rm -rf $$tmp && \
	echo "wrote overleaf.zip"

clean:
	rm -f paper/*.aux paper/*.log paper/*.out paper/*.bbl paper/*.blg paper/main.pdf overleaf.zip
