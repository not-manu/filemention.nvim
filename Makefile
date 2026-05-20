.PHONY: test deps clean

PLENARY_DIR := .tests/site/pack/deps/start/plenary.nvim

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

deps:
	@mkdir -p .tests/site/pack/deps/start
	@if [ ! -d "$(PLENARY_DIR)" ]; then \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$(PLENARY_DIR)"; \
	fi

clean:
	rm -rf .tests
