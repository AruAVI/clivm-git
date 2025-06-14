#!/usr/bin/env bash

set -e

# Resolve the actual home directory for the user running the script,
# not root's home directory when sudo is used
USER_HOME=$(eval echo "~$SUDO_USER")
if [[ -z "$USER_HOME" ]]; then
    # Not running with sudo, just normal user
    USER_HOME="$HOME"
fi

CLIVM_DIR="$USER_HOME/clivm"
CLIVM_DEBIAN_DIR="$CLIVM_DIR/.debian"

# Pretty printing functions
echo_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
echo_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
echo_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
echo_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

HOST_LOCALE=$(locale | grep LANG= | cut -d= -f2)

# Uninstall logic
if [[ "$1" == "-u" ]]; then
    echo_warning "Uninstalling CLIvm environment..."
    sudo umount -l "$CLIVM_DEBIAN_DIR/dev/pts" 2>/dev/null || true
    sudo umount -l "$CLIVM_DEBIAN_DIR/dev" 2>/dev/null || true
    sudo umount -l "$CLIVM_DEBIAN_DIR/proc" 2>/dev/null || true
    sudo umount -l "$CLIVM_DEBIAN_DIR/sys" 2>/dev/null || true
    sudo rm -rf "$CLIVM_DEBIAN_DIR"
    sudo rm -rf "$CLIVM_DIR"
    echo_success "CLIvm environment fully uninstalled."
    exit 0
fi

# Dependency checks
for dep in debootstrap git; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo_error "$dep not found. Install with: sudo apt install $dep"
        exit 1
    fi
done

# Check if environment exists
if [[ -d "$CLIVM_DEBIAN_DIR" ]]; then
    echo_warning "CLIvm already exists at $CLIVM_DEBIAN_DIR. Remove it with -u before reinstalling."
    exit 1
fi

echo_info "Creating CLIvm Debian environment..."
sudo mkdir -p "$CLIVM_DEBIAN_DIR"
sudo debootstrap --arch=amd64 bookworm "$CLIVM_DEBIAN_DIR" http://deb.debian.org/debian

# Patch Kitty terminfo
TMP_KITTY_REPO="/tmp/kitty-term"
rm -rf "$TMP_KITTY_REPO"
echo_info "Cloning Kitty terminal repo for terminfo patch..."
git clone https://github.com/kovidgoyal/kitty.git "$TMP_KITTY_REPO"
KITTY_TERMINFO_SRC="$TMP_KITTY_REPO/terminfo/x/xterm-kitty"
KITTY_TERMINFO_DEST="$CLIVM_DEBIAN_DIR/usr/share/terminfo/x"
if [[ -f "$KITTY_TERMINFO_SRC" ]]; then
    echo_info "Copying Kitty terminfo into chroot..."
    sudo mkdir -p "$KITTY_TERMINFO_DEST"
    sudo cp "$KITTY_TERMINFO_SRC" "$KITTY_TERMINFO_DEST/"
else
    echo_warning "Kitty terminfo not found, skipping."
fi
rm -rf "$TMP_KITTY_REPO"

# Mount required filesystems
echo_info "Making virtual filesystems..."
sudo mkdir -p "$CLIVM_DEBIAN_DIR/dev/pts"

# DNS
sudo cp /etc/resolv.conf "$CLIVM_DEBIAN_DIR/etc/resolv.conf"

# Install essential packages
echo_info "Installing core packages inside chroot..."
sudo chroot "$CLIVM_DEBIAN_DIR" apt update
sudo chroot "$CLIVM_DEBIAN_DIR" apt install -y locales hostname sudo passwd adduser

# Set hostname and hosts
echo_info "Setting hostname to 'debian' inside chroot..."
echo "debian" | sudo tee "$CLIVM_DEBIAN_DIR/etc/hostname" > /dev/null
echo "127.0.1.1 debian" | sudo tee -a "$CLIVM_DEBIAN_DIR/etc/hosts" > /dev/null

# Locale setup
echo_info "Generating locale $HOST_LOCALE..."
echo "$HOST_LOCALE UTF-8" | sudo tee "$CLIVM_DEBIAN_DIR/etc/locale.gen" > /dev/null
echo "LANG=$HOST_LOCALE" | sudo tee "$CLIVM_DEBIAN_DIR/etc/default/locale" > /dev/null
sudo chroot "$CLIVM_DEBIAN_DIR" /usr/bin/env /usr/sbin/locale-gen

# Patch prompt to show hostname
echo_info "Patching .bashrc to show hostname in prompt..."
echo 'export PS1="\u@debian:\w\$ "' | sudo tee "$CLIVM_DEBIAN_DIR/etc/bash.bashrc" > /dev/null
echo 'export PS1="\u@debian:\w\$ "' | sudo tee "$CLIVM_DEBIAN_DIR/etc/skel/.bashrc" > /dev/null

# Set root password
echo_info "Please set a password for root inside chroot:"
sudo chroot "$CLIVM_DEBIAN_DIR" passwd

# Optional non-root user
read -p "$(echo -e '\033[1;34m[INFO]\033[0m Would you like to add a non-root user? (y/n): ')" ADD_USER_CHOICE
if [[ "$ADD_USER_CHOICE" =~ ^[Yy]$ ]]; then
    read -p "Enter username for the new user: " NEW_USER

    echo_info "Creating user '$NEW_USER' inside chroot..."
    sudo chroot "$CLIVM_DEBIAN_DIR" /usr/sbin/adduser "$NEW_USER"

    echo_info "Adding '$NEW_USER' to sudo group..."
    sudo chroot "$CLIVM_DEBIAN_DIR" /usr/sbin/usermod -aG sudo "$NEW_USER"

    echo_success "User '$NEW_USER' added and granted sudo access."
    echo_info "They can become root using the 'sudo' command."
else
    echo_info "Skipping non-root user creation."
fi

echo_success "CLIvm Debian environment is ready!"
