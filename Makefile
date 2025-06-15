# Get real user’s home directory, falling back to $HOME if not using sudo
REAL_HOME := $(shell if [ -n "$$SUDO_USER" ]; then echo /home/$$SUDO_USER; else echo $$HOME; fi)

INSTALL_DIR := $(REAL_HOME)/clivm
BIN_DEST := $(INSTALL_DIR)/binaries
INSTALLER_DEST := $(INSTALL_DIR)/installers
LAUNCHER_SRC := clivm.py
LAUNCHER_TARGET := /usr/bin/clivm


# Colors for fancy output
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
RESET := \033[0m

.PHONY: install clean

install:
	@echo -e "$(BLUE)==> Creating directories in $(INSTALL_DIR)...$(RESET)"
	mkdir -p $(BIN_DEST) $(INSTALLER_DEST)
	@echo -e "$(GREEN)==> Copying binaries...$(RESET)"
	cp -r binaries/* $(BIN_DEST)/
	@echo -e "$(GREEN)==> Copying installers...$(RESET)"
	cp -r installers/* $(INSTALLER_DEST)/
	@echo -e "$(GREEN)==> Copying clivm.py to /usr/bin/clivm...$(RESET)"
	cp $(LAUNCHER_SRC) $(LAUNCHER_TARGET)
	@echo -e "$(YELLOW)==> Making /usr/bin/clivm executable...$(RESET)"
	chmod +x $(LAUNCHER_TARGET)
	@echo -e "$(GREEN)Installation complete!$(RESET)"

clean:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo -e "$(RED)==> ERROR: make clean must be run as root! Use sudo make clean.$(RESET)"; \
		exit 1; \
	fi
	@echo -e "$(YELLOW)==> Removing installed files from $(INSTALL_DIR)...$(RESET)"
	rm -rf $(INSTALL_DIR)
	@echo -e "$(YELLOW)==> Removing /usr/bin/clivm...$(RESET)"
	rm -f $(LAUNCHER_TARGET)
	@echo -e "$(GREEN)==> Clean complete. All installed files removed.$(RESET)"
