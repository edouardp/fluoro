# Makefile for fluoro.vim
#
# Usage:
#   make              Show all available targets
#   make <target>     Run a specific target

VIM       ?= vim
CTAGS     ?= ctags
VIM_PACK_DIR ?= $(HOME)/.vim/pack/plugins/start
INSTALL_DIR  := $(VIM_PACK_DIR)/fluoro
ARGS      ?=

.PHONY: help
help: ## Show this help message, grouped by section
	@if [ -t 1 ]; then color=1; else color=0; fi; \
		awk -v color="$$color" 'BEGIN{FS=":.*?## "; t="General"; max=0; c=(color=="1")?"\033[36m":""; b=(color=="1")?"\033[1m":""; r=(color=="1")?"\033[0m":""} \
		/^# =+$$/{s=1; next} s==1{if($$0 ~ /^# [^=]/){t=substr($$0,3); sub(/[ \t]+$$/,"",t); next} s=0} \
		/^[a-zA-Z0-9_-]+:.*## /{n++; name[n]=$$1; desc[n]=$$2; sect[n]=t; if(length($$1)>max)max=length($$1)} \
		END{last=""; for(i=1;i<=n;i++){if(sect[i]!=last){printf "\n  %s%s%s\n",b,sect[i],r; last=sect[i]} printf "  %s%-*s%s %s\n",c,max+2,name[i],r,desc[i]}}' $(MAKEFILE_LIST)

# ============================================================================
# Setup
# ============================================================================

.PHONY: install
install: ## Symlink this checkout into Vim's package directory
	@mkdir -p "$(VIM_PACK_DIR)"
	@ln -sfn "$(CURDIR)" "$(INSTALL_DIR)"
	@echo "Installed $(INSTALL_DIR) -> $(CURDIR)"

.PHONY: uninstall
uninstall: ## Remove the package symlink
	@rm -f "$(INSTALL_DIR)"
	@echo "Removed $(INSTALL_DIR)"

.PHONY: dev
dev: ## Open Vim with this checkout on 'runtimepath' (ARGS="file ...")
	@$(VIM) --cmd 'set runtimepath^=.' \
		-c 'runtime plugin/fluoro.vim' $(ARGS)

# ============================================================================
# Development
# ============================================================================

.PHONY: tags
tags: ## Generate ctags for Vimscript navigation (requires Universal Ctags)
	@if ! $(CTAGS) --version >/dev/null 2>&1 \
		|| ! $(CTAGS) --version | grep -qi universal; then \
		echo "Universal Ctags not found; install with: brew install universal-ctags"; \
	else \
		$(CTAGS) -R --exclude=.git --exclude=test/tmp .; \
		echo "Generated tags"; \
	fi

.PHONY: doc
doc: ## Generate doc/tags for :help fluoro
	@$(VIM) -Nu NONE -es -c 'helptags doc' -c 'qa!'
	@echo "Generated doc/tags"

.PHONY: lint
lint: ## Load the plugin cleanly and validate the help tags
	@$(VIM) -Nu NONE -es --cmd 'set runtimepath^=.' \
		-c 'runtime plugin/fluoro.vim' -c 'qa!'
	@$(VIM) -Nu NONE -es -c 'helptags doc' -c 'qa!'
	@rm -f doc/tags
	@echo "lint: ok"

# ============================================================================
# Testing
# ============================================================================

.PHONY: test
test: test-unit test-mappings ## Run the full test suite

.PHONY: test-unit
test-unit: ## Run the headless unit tests
	@$(VIM) -Nu NONE -es -S test/run.vim; \
		status=$$?; \
		cat test/results.txt 2>/dev/null || true; \
		rm -f test/results.txt; \
		rm -rf test/tmp; \
		exit $$status

.PHONY: test-mappings
test-mappings: ## Run the default-mapping tests
	@$(VIM) -Nu NONE -es -S test/mappings.vim; \
		status=$$?; \
		cat test/results-mappings.txt 2>/dev/null || true; \
		rm -f test/results-mappings.txt; \
		rm -rf test/tmp; \
		exit $$status

.PHONY: check
check: lint test ## Run lint and the full test suite

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean
clean: ## Remove generated tags, test output, and swap files
	@rm -f doc/tags tags test/results.txt test/results-mappings.txt
	@rm -f *.swp *.swo .swp .swo
	@rm -rf test/tmp
	@echo "Cleaned"

.DEFAULT_GOAL := help
