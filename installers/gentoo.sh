#!/bin/bash
set -e

# Colored output
info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $1"; }

# Configuration
USER_HOME="${HOME}"
GENTOO_DIR="$USER_HOME/clivm/.gentoo"
BASE_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds"
FLAVOR="current-stage3-amd64-openrc"
LATEST_TXT="$BASE_URL/$FLAVOR/latest-stage3-amd64-openrc.txt"

# Step 1: Create target dir
info "Creating root directory..."
sudo mkdir -p "$GENTOO_DIR"

# Step 2: Get latest stage3 tarball name
info "Getting latest stage3 filename..."
STAGE3_FILE=$(wget -qO- "$LATEST_TXT" | grep -o 'stage3-amd64-openrc-[^ ]*\.tar\.xz' | head -n1)

if [ -z "$STAGE3_FILE" ]; then
    error "Could not parse stage3 filename."
    exit 1
fi

STAGE3_URL="$BASE_URL/$FLAVOR/$STAGE3_FILE"
info "Stage3 file: $STAGE3_FILE"

# Step 3: Download and extract
cd /tmp
info "Downloading stage3..."
sudo wget -q --show-progress "$STAGE3_URL"

info "Extracting stage3 to $GENTOO_DIR..."
sudo tar xpf "$STAGE3_FILE" -C "$GENTOO_DIR" --xattrs-include='*.*' --numeric-owner
sudo rm "$STAGE3_FILE"

# Step 4: DNS resolution
info "Copying /etc/resolv.conf..."
sudo cp -L /etc/resolv.conf "$GENTOO_DIR/etc/"

success "Gentoo stage3 extracted to $GENTOO_DIR."
info "You can chroot with: sudo chroot $GENTOO_DIR /bin/bash"
