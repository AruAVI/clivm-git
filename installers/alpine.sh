#!/bin/bash
set -e

# Use the invoking user's home directory explicitly
USER_HOME="${HOME}"
TARGET_DIR="$USER_HOME/clivm/.alpine"
TMP_DIR="/tmp/alpine-setup"
ARCH="x86_64"
MIRROR="https://dl-cdn.alpinelinux.org/alpine"

echo_info() {
    echo -e "\033[1;34m[INFO]\033[0m $*"
}

echo_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $*"
}

echo_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*"
}

# Step 1: Fetch latest Alpine version
echo_info "Fetching latest Alpine version..."
ALPINE_BRANCH=$(wget -qO- "$MIRROR/latest-stable/releases/$ARCH/latest-releases.yaml" | grep 'version:' | head -n1 | awk '{print $2}')
ROOTFS="alpine-minirootfs-${ALPINE_BRANCH}-${ARCH}.tar.gz"
ROOTFS_URL="$MIRROR/latest-stable/releases/$ARCH/$ROOTFS"

# Step 2: Prepare directories
echo_info "Creating target directory..."
sudo mkdir -p "$TARGET_DIR"
mkdir -p "$TMP_DIR"

# Step 3: Download and extract minirootfs
echo_info "Downloading Alpine minirootfs ($ALPINE_BRANCH)..."
wget -q --show-progress "$ROOTFS_URL" -O "$TMP_DIR/$ROOTFS"

echo_info "Extracting rootfs into $TARGET_DIR..."
sudo tar -xzf "$TMP_DIR/$ROOTFS" -C "$TARGET_DIR"

# Step 4: Setup PATH fix to persist across logins
echo_info "Setting up permanent PATH fix..."
echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' | sudo tee "$TARGET_DIR/etc/profile.d/00-path.sh" > /dev/null
sudo chmod +x "$TARGET_DIR/etc/profile.d/00-path.sh"

# Step 5: Provide default /etc/resolv.conf if missing
echo_info "Ensuring resolv.conf exists..."
if ! sudo test -f "$TARGET_DIR/etc/resolv.conf"; then
    echo "nameserver 1.1.1.1" | sudo tee "$TARGET_DIR/etc/resolv.conf" > /dev/null
fi

# Step 6: Enter chroot using unshare, mount special filesystems, and install shadow with suid
echo_info "Entering chroot with unshare and installing shadow package..."
sudo unshare --mount --uts --ipc --pid --fork bash -c "\
  mount -t proc proc $TARGET_DIR/proc && \
  mount -t sysfs sysfs $TARGET_DIR/sys && \
  mount --rbind /dev $TARGET_DIR/dev && \
  mount --make-rslave $TARGET_DIR/dev && \
  chroot $TARGET_DIR /bin/sh -l -c '\
    apk update && \
    apk add shadow && \
    chmod u+s /bin/su'"

echo_success "Alpine setup complete."
