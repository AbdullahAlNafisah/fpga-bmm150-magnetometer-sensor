SIM ?= verilator
WAVES ?= 1

TOPLEVEL_LANG = verilog

VERILOG_SOURCES = ../spi_master_bmm150.sv
TOPLEVEL = spi_master_bmm150

MODULE = test_spi_master_bmm150

EXTRA_ARGS += --coverage
EXTRA_ARGS += --trace --trace-fst --trace-structs

VERILATOR_TRACE = 1
export VERILATOR_TRACE_FILE = dump.fst

include $(shell cocotb-config --makefiles)/Makefile.sim

# Directory for HTML report
COVERAGE_HTML_DIR = coverage_html

.PHONY: runwave
runwave:
	@if [ -f waveform.gtkw ]; then \
		echo "Launching GTKWave with saved layout..."; \
		gtkwave dump.fst waveform.gtkw & \
	else \
		echo "No waveform.gtkw found, launching GTKWave without layout..."; \
		gtkwave dump.fst & \
	fi

.PHONY: coverage
coverage:
	@if [ -f coverage.dat ]; then \
		echo "Generating HTML coverage report..."; \
		mkdir -p $(COVERAGE_HTML_DIR); \
		verilator_coverage --write-info coverage.info coverage.dat; \
		genhtml coverage.info --output-directory $(COVERAGE_HTML_DIR) > /dev/null; \
		echo "HTML coverage report generated: $(COVERAGE_HTML_DIR)/index.html"; \
		( \
			if command -v xdg-open >/dev/null 2>&1; then xdg-open $(COVERAGE_HTML_DIR)/index.html & \
			elif command -v open >/dev/null 2>&1; then open $(COVERAGE_HTML_DIR)/index.html & \
			elif command -v start >/dev/null 2>&1; then start $(COVERAGE_HTML_DIR)/index.html & \
			else echo "Cannot auto-open HTML report. Please open $(COVERAGE_HTML_DIR)/index.html manually."; \
			fi \
		); \
	else \
		echo "No coverage.dat found, skipping coverage report."; \
	fi

.PHONY: runall
runall:
	@echo "==== Cleaning build directory ===="
	$(MAKE) clean
	@echo "==== Building and running simulation ===="
	$(MAKE) all
	@echo "==== Generating coverage report ===="
	$(MAKE) coverage
	@echo "==== Launching GTKWave ===="
	$(MAKE) runwave
