#!/usr/bin/env bash
# Bootstraps this dotfiles repo onto a new machine via GNU Stow.
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(bash bat fd firefox fish foot git hidden-apps kde kitty lazydocker lazygit nvim quickshell ripgrep satty scripts sway tmux yazi)
BOOTSTRAP_DIR="$DOTS_DIR/.bootstrap"
RICE_DIR="$HOME/.rice"
RICE_REPO="git@github.com:piarn/.rice.git"

# A few packages install a binary whose name doesn't match the package
# name, so a plain `command -v <package>` never finds them and they'd get
# re-installed (harmlessly, but noisily prompting for sudo) on every run.
declare -A PACKAGE_BIN_OVERRIDES=(
    [fd-find]=fd               # Fedora: package fd-find installs binary fd (Debian/Ubuntu: fdfind — see below)
    [wl-clipboard]=wl-copy
    [pulseaudio-utils]=pactl
    [ripgrep]=rg
    [neovim]=nvim
)

# apt sometimes uses a differently-cased/named package than dnf's
# packages.txt name — add an entry here when that happens.
declare -A APT_NAME_OVERRIDES=()

# Installs everything listed in .bootstrap/packages.txt (one binary/package
# name per line, matching dnf naming — see the override maps above for the
# handful that need translating) that isn't already on PATH.
install_packages() {
    local pkgs=() pkg missing=() probe
    while IFS= read -r pkg; do
        case "$pkg" in ''|'#'*) continue ;; esac
        pkgs+=("$pkg")
    done <"$BOOTSTRAP_DIR/packages.txt"

    for pkg in "${pkgs[@]}"; do
        probe="${PACKAGE_BIN_OVERRIDES[$pkg]:-$pkg}"
        command -v "$probe" >/dev/null 2>&1 || missing+=("$pkg")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "==> packages already installed, nothing to do"
        return
    fi

    echo "==> installing packages: ${missing[*]}"
    if command -v apt >/dev/null 2>&1; then
        local apt_pkgs=()
        for pkg in "${missing[@]}"; do
            apt_pkgs+=("${APT_NAME_OVERRIDES[$pkg]:-$pkg}")
        done
        sudo apt update && sudo apt install -y "${apt_pkgs[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "${missing[@]}"
    else
        echo "error: no supported package manager (apt/dnf) detected; install manually: ${missing[*]}" >&2
        exit 1
    fi
}

# Several Mason-managed LSP servers (json-lsp, bash-language-server,
# yaml-language-server, ...) are npm packages, so npm must exist before
# nvim can install them.
install_node() {
    if command -v npm >/dev/null 2>&1; then
        return
    fi
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y nodejs npm
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y nodejs npm
    else
        echo "warning: npm not found and no supported package manager (apt/dnf) detected;" >&2
        echo "         npm-based LSP servers will fail to install until it's on PATH" >&2
    fi
}

# Installs the Mason packages declared in nvim/.config/nvim/lua/plugins/lsp.lua's
# ensure_installed (as mason package names, which differ from the lspconfig
# server names used there), so the first interactive launch isn't stuck
# waiting on installs. Only installs what's actually missing, so this is
# fast and safe to re-run any time (e.g. after adding a language above).
MASON_PACKAGES=(
    gopls
    basedpyright
    ruff
    lua-language-server
    clangd
    bash-language-server
    yaml-language-server
    json-lsp
    rust-analyzer
    nimlangserver
)

install_lsp_servers() {
    if ! command -v nvim >/dev/null 2>&1; then
        return
    fi

    local missing=()
    for pkg in "${MASON_PACKAGES[@]}"; do
        if ! nvim --headless -c "lua if require('mason-registry').is_installed('$pkg') then os.exit(0) else os.exit(1) end" 2>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "==> LSP servers already installed, nothing to do"
        return
    fi

    echo "==> installing LSP servers via Mason: ${missing[*]}"
    local pkg_list
    pkg_list=$(printf "'%s'," "${missing[@]}")
    nvim --headless "+MasonInstall ${missing[*]}" \
        "+lua vim.wait(180000, function() local r = require('mason-registry'); for _, n in ipairs({${pkg_list}}) do if not r.is_installed(n) then return false end end; return true end, 500)" \
        +qa 2>&1 | grep -Ev '^\[[a-zA-Z0-9._-]+\] +(log|fetch|status|checkout)' || true
}

# .dots owns configs; .rice owns the styling layer they include/symlink
# from (sway gaps/colors/screen-layout, tmux/nvim/fish accents,
# yazi/lazygit/lazydocker/firefox theme files, ...). Clone it if
# it's not already there, then render the current theme and — if sway is
# actually running — apply the screen layout that matches what's connected.
install_rice() {
    if [ ! -d "$RICE_DIR/.git" ]; then
        echo "==> cloning .rice"
        git clone "$RICE_REPO" "$RICE_DIR"
    fi
    "$RICE_DIR/bin/apply-theme"
    if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
        "$RICE_DIR/bin/apply-layout" --auto
    fi
}

# yazi, lazygit and lazydocker aren't packaged for apt/dnf, so they're
# installed straight from each project's GitHub release binaries instead.
LOCAL_BIN="$HOME/.local/bin"

case "$(uname -m)" in
    x86_64) RELEASE_ARCH=x86_64; YAZI_ARCH=x86_64-unknown-linux-gnu ;;
    aarch64) RELEASE_ARCH=arm64; YAZI_ARCH=aarch64-unknown-linux-gnu ;;
    *) RELEASE_ARCH=""; YAZI_ARCH="" ;;
esac

# Installs $bin_name from the latest GitHub release of $repo whose asset
# filename contains $asset_pattern: downloads it, extracts it (.tar.gz or
# .zip), and copies every binary named in $bin_names (may be more than
# one, e.g. yazi ships a "ya" companion binary) into ~/.local/bin. A no-op
# if $bin_name is already on PATH, so safe to re-run any time.
install_from_github_release() {
    local bin_name="$1" repo="$2" asset_pattern="$3"
    shift 3
    local bin_names=("$@")

    if command -v "$bin_name" >/dev/null 2>&1; then
        return
    fi
    if [ -z "$asset_pattern" ]; then
        echo "warning: unsupported CPU architecture ($(uname -m)) for $bin_name; install manually from https://github.com/$repo/releases" >&2
        return
    fi

    echo "==> installing $bin_name from github.com/$repo (latest release)"
    local url
    url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -o "\"browser_download_url\": *\"[^\"]*${asset_pattern}[^\"]*\"" \
        | head -1 \
        | sed -E 's/.*"(https[^"]+)"/\1/')
    if [ -z "$url" ]; then
        echo "warning: no $bin_name release asset matching '$asset_pattern' found; install manually from https://github.com/$repo/releases" >&2
        return
    fi

    local tmp
    tmp=$(mktemp -d)
    curl -fsSL "$url" -o "$tmp/asset"
    case "$url" in
        *.tar.gz|*.tgz) tar -xzf "$tmp/asset" -C "$tmp" ;;
        *.zip) unzip -q "$tmp/asset" -d "$tmp" ;;
        *) echo "warning: unrecognized archive format for $bin_name: $url" >&2; rm -rf "$tmp"; return ;;
    esac

    mkdir -p "$LOCAL_BIN"
    local name found=0
    for name in "${bin_names[@]}"; do
        local match
        match=$(find "$tmp" -type f -name "$name" | head -1)
        if [ -n "$match" ]; then
            install -m755 "$match" "$LOCAL_BIN/$name"
            found=1
        fi
    done
    rm -rf "$tmp"

    if [ "$found" -eq 0 ]; then
        echo "warning: downloaded $bin_name release but found none of: ${bin_names[*]}" >&2
    fi
}

install_yazi() {
    install_from_github_release yazi sxyazi/yazi "${YAZI_ARCH}.zip" yazi ya
}

# No apt/dnf package on Fedora or Debian/Ubuntu; ships a prebuilt glibc
# binary using the same target-triple naming as yazi's release assets, so
# $YAZI_ARCH (e.g. "x86_64-unknown-linux-gnu") doubles as satty's too.
install_satty() {
    install_from_github_release satty Satty-org/Satty "${YAZI_ARCH}.tar.gz" satty
}

# quickshell's bar uses a couple of Nerd Font icon glyphs (bluetooth on/off)
# that no packaged font on Fedora/apt actually ships — "monospace" resolves
# to a font with none of them. Nerd Fonts' own "symbols only" release is
# just the icon glyphs, meant to be layered as a fallback alongside any
# regular font (its bundled fontconfig snippet does that), rather than
# replacing the whole terminal/UI font like a full patched font would.
install_nerd_font_symbols() {
    if fc-list 2>/dev/null | grep -q "Symbols Nerd Font Mono"; then
        return
    fi
    echo "==> installing Symbols Nerd Font Mono (icons for quickshell's bar)"
    local tmp font_dir="$HOME/.local/share/fonts/NerdFontSymbols"
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/symbols.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
    unzip -q "$tmp/symbols.zip" -d "$tmp"
    mkdir -p "$font_dir" "$HOME/.config/fontconfig/conf.d"
    install -m644 "$tmp/SymbolsNerdFont-Regular.ttf" "$tmp/SymbolsNerdFontMono-Regular.ttf" "$font_dir/"
    install -m644 "$tmp/10-nerd-font-symbols.conf" "$HOME/.config/fontconfig/conf.d/"
    rm -rf "$tmp"
    fc-cache -f "$font_dir" >/dev/null 2>&1
}

# quickshell's lock screen (~/.dots/quickshell/.config/quickshell/popups/LockScreen.qml)
# authenticates via PamContext against its own PAM service rather than
# reusing "login"'s (heavier than needed — session/selinux rules meant for
# actual logins, not a screen unlock) or swaylock's (a package this repo no
# longer installs). `auth include login` mirrors what swaylock's own
# /etc/pam.d/swaylock did: reuse the distro's normal auth stack (so e.g.
# fprintd fallback still works if system-auth is set up for it) without
# pulling in login's non-auth rules. A system file, so this needs sudo;
# idempotent and safe to re-run.
install_pam_lock_config() {
    local pam_file="/etc/pam.d/quickshell-lock"
    local content='auth include login'
    if [ -f "$pam_file" ] && [ "$(cat "$pam_file" 2>/dev/null)" = "$content" ]; then
        return
    fi
    echo "==> installing $pam_file"
    echo "$content" | sudo tee "$pam_file" >/dev/null
}

# The KDE flatpaks (Dolphin, Gwenview, Ark) already read the host's
# ~/.config/kdeglobals (stowed from ./kde, a symlink into ~/.rice), but
# outside a Plasma session Qt never loads KDE's platform theme, so they
# ignore its colors and fall back to stock Breeze Dark. Forcing it per app
# makes them follow the rice palette. Apps that aren't installed are skipped.
KDE_FLATPAKS=(org.kde.dolphin org.kde.gwenview org.kde.ark)

install_kde_flatpak_theme() {
    command -v flatpak >/dev/null 2>&1 || return
    local app
    for app in "${KDE_FLATPAKS[@]}"; do
        flatpak info "$app" >/dev/null 2>&1 || continue
        flatpak override --user --env=QT_QPA_PLATFORMTHEME=kde "$app"
    done
}

install_lazygit() {
    install_from_github_release lazygit jesseduffield/lazygit "linux_${RELEASE_ARCH}.tar.gz" lazygit
}

install_lazydocker() {
    install_from_github_release lazydocker jesseduffield/lazydocker "Linux_${RELEASE_ARCH}.tar.gz" lazydocker
}

install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [ -d "$tpm_dir" ]; then
        return
    fi
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
}

# fisher.fish and bass's function files are committed under fish/.config/fish
# already (stow drops them straight in), so this is normally a no-op. It
# only does real work — via the scripts in .bootstrap/fish — the first time
# fish itself is set up on a machine, or if those tracked files are missing.
install_fish_plugins() {
    if ! command -v fish >/dev/null 2>&1; then
        return
    fi
    if fish -c 'type -q fisher' >/dev/null 2>&1; then
        return
    fi
    echo "==> bootstrapping fisher + plugins via .bootstrap/fish"
    fish -c "source $BOOTSTRAP_DIR/fish/install_fisher.sh"
    fish -c "source $BOOTSTRAP_DIR/fish/install_bass.sh"
}

install_packages
install_node
install_rice
install_nerd_font_symbols
install_pam_lock_config
install_yazi
install_satty
install_lazygit
install_lazydocker
cd "$DOTS_DIR"

for pkg in "${PACKAGES[@]}"; do
    echo "==> stowing $pkg"
    stow -v --no-folding --adopt -t "$HOME" "$pkg"
done

install_fish_plugins
install_kde_flatpak_theme
install_tpm
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true

install_lsp_servers

echo
echo "Done. Review 'git status' / 'git diff' in $DOTS_DIR — --adopt pulls any"
echo "pre-existing files at the target paths into the repo, which may have"
echo "overwritten tracked content with your local version. Discard with"
echo "'git checkout -- <file>' if the repo version should win instead."
