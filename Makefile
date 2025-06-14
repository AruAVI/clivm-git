# Get real user’s home directory, falling back to $HOME if not using sudo
REAL_HOME := $(shell if [ -n "$$SUDO_USER" ]; then echo /home/$$SUDO_USER; else echo $$HOME; fi)

INSTALL_DIR := $(REAL_HOME)/clivm
BIN_DEST := $(INSTALL_DIR)/binaries
INSTALLER_DEST := $(INSTALL_DIR)/installers
LOCAL_BIN := $(REAL_HOME)/bin
LAUNCHER_SRC := launcher.py
LAUNCHER_TARGET := $(LOCAL_BIN)/launcher

# Colors for fancy output
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
RESET := \033[0m

.PHONY: install clean

install:
	@echo -e "$(BLUE)==> Creating directories in $(INSTALL_DIR)...$(RESET)"
	mkdir -p $(BIN_DEST) $(INSTALLER_DEST) $(LOCAL_BIN)

	@echo -e "$(GREEN)==> Copying binaries...$(RESET)"
	@if [ "$$(readlink -f binaries)" != "$$(readlink -f $(BIN_DEST))" ]; then \
		cp -r binaries/* $(BIN_DEST)/; \
	else \
		echo -e "$(YELLOW)==> Skipping binaries copy (source and destination are the same).$(RESET)"; \
	fi

	@echo -e "$(GREEN)==> Copying installers...$(RESET)"
	cp -r installers/* $(INSTALLER_DEST)/

	@echo -e "$(GREEN)==> Copying launcher and removing .py extension...$(RESET)"
	@if [ "$$(readlink -f $(LAUNCHER_SRC))" != "$$(readlink -f $(LAUNCHER_TARGET))" ]; then \
		cp $(LAUNCHER_SRC) $(LAUNCHER_TARGET); \
	else \
		echo -e "$(YELLOW)==> Skipping launcher copy (source and destination are the same).$(RESET)"; \
	fi

	@echo -e "$(YELLOW)==> Making launcher executable...$(RESET)"
	chmod +x $(LAUNCHER_TARGET)

	@echo -e "$(GREEN)Installation complete!$(RESET)"

clean:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo -e "$(RED)==> ERROR: make clean must be run as root! Use sudo make clean.$(RESET)"; \
		exit 1; \
	fi
	@echo -e "$(YELLOW)==> Removing installed files from $(INSTALL_DIR)...$(RESET)"
	rm -rf $(INSTALL_DIR)
	@echo -e "$(YELLOW)==> Removing launcher executable from $(LAUNCHER_TARGET)...$(RESET)"
	rm -f $(LAUNCHER_TARGET)
	@echo -e "$(GREEN)==> Clean complete. All installed files removed.$(RESET)"
