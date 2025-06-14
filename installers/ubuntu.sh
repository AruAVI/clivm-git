#!/usr/bin/env bash
set -euo pipefail

USER_HOME="${HOME}"
TARGET="$USER_HOME/clivm/.ubuntu"
UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"

echo_info()   { echo -e "\033[1;32m[INFO]\033[0m $*"; }
echo_error()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Fetch LTS metadata from Ubuntu
echo_info "Fetching latest Ubuntu LTS metadata..."
data=$(curl -s https://changelogs.ubuntu.com/meta-release-lts)

codename=$(grep "^Name:" <<< "$data" | tail -n1 | cut -d':' -f2 | xargs)
version=$(grep "^Version:" <<< "$data" | tail -n1 | cut -d':' -f2 | xargs)
dist=$(grep "^Dist:" <<< "$data" | tail -n1 | cut -d':' -f2 | xargs)

if [[ -z "$dist" ]]; then
    echo_error "Failed to extract LTS codename"
    exit 1
fi

echo_info "Latest LTS is $version ($codename), codename: $dist"

if [ -d "$TARGET" ]; then
    echo_error "Target $TARGET already exists. Remove it first."
    exit 1
fi

sudo mkdir -p "$TARGET"

echo_info "Bootstrapping Ubuntu $dist into $TARGET..."
sudo unshare --mount --fork --pid -- bash -c "
    mount --make-rprivate /
    sudo debootstrap --variant=minbase $dist $TARGET $UBUNTU_MIRROR
" || {
    echo_error "Debootstrap failed."
    exit 1
}

echo_info "Copying DNS config..."
sudo cp /etc/resolv.conf "$TARGET/etc/resolv.conf"

echo_info "Configuring APT..."

sudo tee "$TARGET/etc/apt/sources.list" > /dev/null <<EOF
deb $UBUNTU_MIRROR $dist main restricted universe multiverse
deb $UBUNTU_MIRROR $dist-updates main restricted universe multiverse
deb $UBUNTU_MIRROR $dist-security main restricted universe multiverse
EOF

echo_info "Mounting /dev, /proc, /sys, and /dev/pts in chroot..."

sudo mount --bind /dev "$TARGET/dev"
sudo mount --bind /dev/pts "$TARGET/dev/pts"
sudo mount -t proc proc "$TARGET/proc"
sudo mount -t sysfs sys "$TARGET/sys"

cleanup() {
    echo_info "Unmounting /dev, /proc, /sys, and /dev/pts..."
    sudo umount -lf "$TARGET/dev/pts" || true
    sudo umount -lf "$TARGET/dev" || true
    sudo umount -lf "$TARGET/proc" || true
    sudo umount -lf "$TARGET/sys" || true
}
trap cleanup EXIT

echo_info "Installing useful packages inside chroot..."

sudo chroot "$TARGET" /bin/bash -c "
    apt-get update &&
    apt-get install -y --no-install-recommends \
        curl wget vim git htop nano net-tools \
        iputils-ping ca-certificates unzip build-essential \
        software-properties-common lsb-release sudo coreutils
"

echo_info "Ensuring standard paths are in /etc/profile..."

sudo tee -a "$TARGET/etc/profile" > /dev/null << 'EOF'

# Ensure standard system paths are in PATH
case ":$PATH:" in
  *:/sbin:* ) :;;        *) PATH="/sbin:$PATH";;
esac
case ":$PATH:" in
  *:/usr/sbin:* ) :;;    *) PATH="/usr/sbin:$PATH";;
esac
case ":$PATH:" in
  *:/usr/local/sbin:* ) :;; *) PATH="/usr/local/sbin:$PATH";;
esac

export PATH
EOF

echo_info "Success!"
