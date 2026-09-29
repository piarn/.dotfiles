# Sourced by extras' setup.sh scripts that need an AUR-only package on
# Arch (mullvad, netbird, protonvpn, ssh-vpn — none of them ship an
# official Arch repo, only a community AUR package). We deliberately
# don't auto-install a helper the way install_packages() auto-installs
# from apt/dnf/pacman: building and installing yay/paru means running
# makepkg with your privileges, unprompted, on a package this repo didn't
# write — more trust than a dotfiles installer should take without
# asking. Install yay or paru yourself first; this just fails with
# instructions if neither is on PATH yet.
aur_install() {
    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm "$@"
    elif command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm "$@"
    else
        echo "error: no AUR helper (yay/paru) found; install one first, e.g.:" >&2
        echo "  git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si" >&2
        echo "then re-run this script" >&2
        exit 1
    fi
}
