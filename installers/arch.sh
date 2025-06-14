#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$(realpath "$HOME/clivm/.arch")"
HOST_LOCALE=$(locale | grep LANG= | cut -d= -f2 || true)
[ -z "$HOST_LOCALE" ] && HOST_LOCALE="en_US.UTF-8"

# Colored echo helpers
function echo_info() {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}
function echo_success() {
  echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}
function echo_error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
}

function ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo_error "$1 is required but not installed."; exit 1; }
}

function do_uninstall() {
  echo_info "Unmounting chroot mounts (if any)..."
  for mnt in dev/pts dev proc sys; do
    mountpoint -q "$TARGET_DIR/$mnt" && sudo umount -lf "$TARGET_DIR/$mnt" || true
  done
  echo_info "Removing target directory..."
  sudo rm -rf "$TARGET_DIR"
  echo_success "Uninstallation complete."
  exit 0
}

if [[ "${1:-}" == "-u" ]]; then
  do_uninstall
fi

ensure_cmd pacstrap
ensure_cmd arch-chroot
ensure_cmd mount
ensure_cmd umount
ensure_cmd git

export TARGET_DIR
sudo mkdir -p "$TARGET_DIR"

# Dummy bind mount to satisfy pacstrap
echo_info "Creating dummy bind mount for $TARGET_DIR"
sudo mount --bind "$TARGET_DIR" "$TARGET_DIR"

# Write static mirrorlist
echo_info "Creating static mirrorlist..."
sudo mkdir -p "$TARGET_DIR/etc/pacman.d"
sudo tee "$TARGET_DIR/etc/pacman.d/mirrorlist" > /dev/null <<EOF
##
## Arch Linux repository mirrorlist
## Generated on $(date +%Y-%m-%d)
##
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://ftpmirror.infania.net/mirror/archlinux/\$repo/os/\$arch
Server = http://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
EOF

# Launch isolated mount namespace
sudo unshare --mount --pid --fork -- bash -c "
set -e
TARGET_DIR=\"$TARGET_DIR\"
HOST_LOCALE=\"$HOST_LOCALE\"

mount --make-rprivate /
mkdir -p \"\$TARGET_DIR/dev\" \"\$TARGET_DIR/dev/pts\" \"\$TARGET_DIR/proc\" \"\$TARGET_DIR/sys\"
mount --bind /dev \"\$TARGET_DIR/dev\"
mount --bind /dev/pts \"\$TARGET_DIR/dev/pts\"
mount --bind /proc \"\$TARGET_DIR/proc\"
mount --bind /sys \"\$TARGET_DIR/sys\"

# Bootstrap Arch
if ! pacstrap -K \"\$TARGET_DIR\" base base-devel bash vim sudo --config /etc/pacman.conf --disable-download-timeout --noconfirm; then
  echo \"[ERROR] pacstrap failed. Check disk space or mirror issues.\"
  exit 1
fi

# Disable CheckSpace in pacman.conf
sed -i \"s/^CheckSpace/#CheckSpace/\" \"\$TARGET_DIR/etc/pacman.conf\"

# Locale setup
echo \"\$HOST_LOCALE UTF-8\" > \"\$TARGET_DIR/etc/locale.gen\"
echo \"LANG=\$HOST_LOCALE\" > \"\$TARGET_DIR/etc/locale.conf\"
arch-chroot \"\$TARGET_DIR\" locale-gen

# Hostname
echo \"arch-chroot\" > \"\$TARGET_DIR/etc/hostname\"

# Root password
echo \"[INFO] Set root password:\"
arch-chroot \"\$TARGET_DIR\" /bin/bash -c \"passwd\"

# Optional user
read -rp \"Create a non-root user? (y/N): \" create_user
if [[ \$create_user =~ ^[Yy]\$ ]]; then
  read -rp \"Enter username: \" username
  read -rp \"Should this user have sudo (admin) access? (y/N): \" sudo_user

  if [[ \$sudo_user =~ ^[Yy]\$ ]]; then
    echo \"[INFO] Enabling sudo access for wheel group...\"
    arch-chroot \"\$TARGET_DIR\" /bin/bash -c \"sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers\"
    arch-chroot \"\$TARGET_DIR\" /bin/bash -c \"useradd -m -G wheel -s /bin/bash \$username && passwd \$username\"
  else
    arch-chroot \"\$TARGET_DIR\" /bin/bash -c \"useradd -m -s /bin/bash \$username && passwd \$username\"
  fi
fi

# Patch Kitty terminfo
TMP_KITTY_REPO=\"/tmp/kitty-term\"
rm -rf \"\$TMP_KITTY_REPO\"
echo \"[INFO] Cloning Kitty terminal repo...\"
git clone https://github.com/kovidgoyal/kitty.git \"\$TMP_KITTY_REPO\"
KITTY_TERMINFO_SRC=\"\$TMP_KITTY_REPO/terminfo/x/xterm-kitty\"
KITTY_TERMINFO_DEST=\"\$TARGET_DIR/usr/share/terminfo/x\"
if [[ -f \"\$KITTY_TERMINFO_SRC\" ]]; then
  echo \"[INFO] Copying Kitty terminfo...\"
  mkdir -p \"\$KITTY_TERMINFO_DEST\"
  cp \"\$KITTY_TERMINFO_SRC\" \"\$KITTY_TERMINFO_DEST/\"
else
  echo \"[WARNING] Kitty terminfo not found, skipping.\"
fi
rm -rf \"\$TMP_KITTY_REPO\"

echo \"[SUCCESS] Arch chroot setup complete.\"
"

# Final cleanup
sudo umount -lf "$TARGET_DIR" || true
echo_success "Done. You can now run: sudo arch-chroot $TARGET_DIR"
