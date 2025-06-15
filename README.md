# clivm

**clivm** is a lightweight tool to locally create containers for multiple Linux distributions.

## Supported Distributions

- Debian  
- Arch  
- Alpine  
- Gentoo  
- Ubuntu

## Dependencies
clivm's dependencies include:
- debootstrap (for Debian/Ubuntu)
- pacstrap (part of the arch-install-scripts package, used for Arch)
- wget
- git

**Note:** If not using Arch/Arch-based, you can't use pacstrap.

## Installation

Install from the AUR:

```bash
yay -S clivm
```

Or use git:

```bash
git clone https://github.com/AruAVI/clivm-git.git
cd clivm-git
sudo make install
```

## Uninstallation

To uninstall the AUR version:

```bash
yay -R clivm
sudo rm -rf ~/clivm
```
Or if the repository was cloned:

```bash
cd clivm-git
sudo make clean
```

## Usage

After installation, run "clivm" in your terminal to open the launcher.
