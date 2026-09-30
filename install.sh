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
    [git-delta]=delta
)

# apt sometimes uses a differently-cased/named package than dnf's
# packages.txt name — add an entry here when that happens.
declare -A APT_NAME_OVERRIDES=()

# Same idea for pacman — Arch mostly matches dnf's naming (it's the
# outlier that needs translating, not the rule), so this only needs
# entries for the packages that actually differ.
declare -A ARCH_NAME_OVERRIDES=(
    [fd-find]=fd              # Arch just calls it fd, no split like Fedora/Debian
    [pulseaudio-utils]=libpulse   # pactl ships in libpulse, pulled in either by pipewire-pulse or pulseaudio
)

# Installs everything listed in .bootstrap/packages.txt (one binary/package
# name per line, matching dnf naming — see the override maps above for the
# handful that need translating on apt/pacman) that isn't already on PATH.
# Prints (one per line) the packages.txt entries not already on PATH.
missing_packages() {
    local pkg probe
    while IFS= read -r pkg; do
        case "$pkg" in ''|'#'*) continue ;; esac
        probe="${PACKAGE_BIN_OVERRIDES[$pkg]:-$pkg}"
        command -v "$probe" >/dev/null 2>&1 || echo "$pkg"
    done <"$BOOTSTRAP_DIR/packages.txt"
}

install_packages() {
    local pkg missing=()
    mapfile -t missing < <(missing_packages)

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
    elif command -v pacman >/dev/null 2>&1; then
        local pacman_pkgs=()
        for pkg in "${missing[@]}"; do
            pacman_pkgs+=("${ARCH_NAME_OVERRIDES[$pkg]:-$pkg}")
        done
        sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
    else
        echo "error: no supported package manager (apt/dnf/pacman) detected; install manually: ${missing[*]}" >&2
        exit 1
    fi
}

# Installs every app in .bootstrap/flatpaks.txt (one Flathub app id per
# line) that isn't installed yet, system-wide like Fedora's own flatpak
# setup, adding the Flathub remote first if it's missing. Runs before
# stowing so install_kde_flatpak_theme finds the KDE apps it themes.
install_flatpaks() {
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "warning: flatpak not found; skipping .bootstrap/flatpaks.txt" >&2
        return
    fi

    local apps=() app missing=()
    while IFS= read -r app; do
        case "$app" in ''|'#'*) continue ;; esac
        apps+=("$app")
    done <"$BOOTSTRAP_DIR/flatpaks.txt"

    for app in "${apps[@]}"; do
        flatpak info "$app" >/dev/null 2>&1 || missing+=("$app")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "==> flatpaks already installed, nothing to do"
        return
    fi

    echo "==> installing flatpaks: ${missing[*]}"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y --noninteractive flathub "${missing[@]}"
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
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm nodejs npm
    else
        echo "warning: npm not found and no supported package manager (apt/dnf/pacman) detected;" >&2
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
    else
        # Keep .rice in step with .dots: fast-forward only, and a failure
        # (local edits in the way, diverged history, offline) never blocks the install.
        echo "==> updating .rice"
        # sway/outputs.conf used to be tracked and is gitignored now: a
        # clone from before that has it both tracked and locally modified,
        # which makes the pull that untracks it refuse to run (and one that
        # did run would delete it). Keep this machine's copy across the pull.
        local outputs="$RICE_DIR/sway/outputs.conf" outputs_copy=""
        if [ -f "$outputs" ]; then
            outputs_copy=$(mktemp)
            cp "$outputs" "$outputs_copy"
            git -C "$RICE_DIR" checkout -q -- sway/outputs.conf 2>/dev/null || true
        fi
        git -C "$RICE_DIR" pull --ff-only \
            || echo "warning: couldn't fast-forward $RICE_DIR; continuing with what's there" >&2
        if [ -n "$outputs_copy" ]; then
            mkdir -p "$(dirname "$outputs")"   # the pull may have removed sway/ with it
            cp "$outputs_copy" "$outputs"
            rm -f "$outputs_copy"
        fi
    fi
    # sway/outputs.conf is per-machine (gitignored) and normally written by
    # apply-layout, which needs a running sway. Seed the laptop profile —
    # it has no explicit resolution, so it suits any machine — so sway's
    # `include` doesn't dangle on a fresh clone; --auto replaces it later.
    if [ ! -e "$RICE_DIR/sway/outputs.conf" ] && [ -f "$RICE_DIR/layouts/laptop.conf" ]; then
        echo "==> seeding sway/outputs.conf from the laptop layout"
        mkdir -p "$RICE_DIR/sway"
        { echo "# generated by install.sh from $RICE_DIR/layouts/laptop.conf"
          cat "$RICE_DIR/layouts/laptop.conf"; } >"$RICE_DIR/sway/outputs.conf"
    fi
    "$RICE_DIR/bin/apply-theme"
    if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
        "$RICE_DIR/bin/apply-layout" --auto
    fi
}

# yazi, lazygit and lazydocker aren't packaged for apt/dnf, so they're
# installed straight from each project's GitHub release binaries instead.
LOCAL_BIN="$HOME/.local/bin"

# Quickshell ships no prebuilt binary (no AppImage, no GitHub release
# tarball like yazi/lazygit get) and Fedora/Debian/Arch each package
# their own point release, sometimes months apart — risky for something
# this repo's entire desktop is built against the QML API of (quickshell
# itself warns it can break across Qt updates). Built from source instead,
# pinned to one tag, identical on every distro, rather than trusting
# whatever each one happens to have packaged. Installs to ~/.local (no
# sudo needed for the build itself, just for its distro build deps);
# `qs` is a convenience symlink distro packages add that upstream's own
# build doesn't produce, so this makes one too.
QUICKSHELL_VERSION=v0.3.1
QUICKSHELL_VERSION_FILE="$HOME/.local/share/dots-quickshell-version"
QT_FALLBACK_VERSION=6.8.3

install_quickshell() {
    if [ -x "$LOCAL_BIN/quickshell" ] \
        && [ "$(cat "$QUICKSHELL_VERSION_FILE" 2>/dev/null)" = "$QUICKSHELL_VERSION" ]; then
        return
    fi

    echo "==> installing quickshell $QUICKSHELL_VERSION's build dependencies"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y cmake ninja-build pkgconf-pkg-config gcc-c++ \
            qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtwayland-devel \
            qt6-qt5compat-devel qt6-qtimageformats qt6-qtshadertools-devel \
            libdrm-devel wayland-devel wayland-protocols-devel mesa-libgbm-devel \
            vulkan-headers spirv-tools-devel cli11-devel pipewire-devel \
            pam-devel polkit-devel jemalloc-devel libunwind-devel python3
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y cmake ninja-build pkgconf g++ \
            qt6-base-dev qt6-declarative-dev qt6-wayland-dev qt6-shadertools-dev \
            qt6-base-private-dev qt6-declarative-private-dev qt6-wayland-private-dev \
            libcli11-dev libwayland-dev wayland-protocols libpipewire-0.3-dev \
            libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev libglib2.0-dev \
            libdrm-dev libgbm-dev libjemalloc-dev libegl-dev libgles-dev libvulkan-dev \
            libxcb1-dev spirv-tools libunwind-dev python3-venv
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm base-devel cmake ninja pkgconf \
            cli11 qt6-shadertools spirv-tools vulkan-headers wayland-protocols \
            qt6-base qt6-declarative qt6-wayland wayland libdrm libpipewire pam \
            polkit mesa libxcb libunwind jemalloc python
    else
        echo "error: no supported package manager (apt/dnf/pacman) for quickshell's build deps" >&2
        exit 1
    fi

    # quickshell needs Qt >= 6.6; Ubuntu 24.04 ships 6.4. Fall back to an
    # upstream Qt build (aqtinstall) in ~/.local/qt, rpath'd into the binary
    # so nothing needs LD_LIBRARY_PATH at runtime.
    local qt_ver qt_args=()
    qt_ver=$(pkg-config --modversion Qt6Core 2>/dev/null || echo 0)
    if [ "$(printf '%s\n6.6.0\n' "$qt_ver" | sort -V | head -1)" != "6.6.0" ]; then
        local qt_root="$HOME/.local/qt" qt_dir
        qt_dir="$qt_root/$QT_FALLBACK_VERSION/gcc_64"
        if [ ! -d "$qt_dir/lib/cmake/Qt6" ]; then
            if [ "$(uname -m)" != x86_64 ]; then
                echo "error: system Qt $qt_ver is too old for quickshell and no fallback Qt exists for $(uname -m)" >&2
                exit 1
            fi
            echo "==> system Qt is $qt_ver (< 6.6); installing Qt $QT_FALLBACK_VERSION via aqtinstall"
            local venv
            venv=$(mktemp -d)
            python3 -m venv "$venv"
            "$venv/bin/pip" install -q aqtinstall
            "$venv/bin/aqt" install-qt linux desktop "$QT_FALLBACK_VERSION" linux_gcc_64 \
                -m qt5compat qtshadertools qtimageformats -O "$qt_root"
            rm -rf "$venv"
        fi
        qt_args=(-DCMAKE_PREFIX_PATH="$qt_dir" -DCMAKE_INSTALL_RPATH="$qt_dir/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON)
    fi

    echo "==> building quickshell $QUICKSHELL_VERSION from source (a few minutes)"
    local tmp
    tmp=$(mktemp -d)
    git clone --branch "$QUICKSHELL_VERSION" --depth 1 \
        https://git.outfoxxed.me/outfoxxed/quickshell "$tmp/quickshell"
    (
        cd "$tmp/quickshell"
        # cpptrace (crash handler) has no Ubuntu/Fedora package; let quickshell fetch it
        cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DVENDOR_CPPTRACE=ON -DCMAKE_INSTALL_PREFIX="$HOME/.local" "${qt_args[@]}"
        cmake --build build
        cmake --install build
    )
    rm -rf "$tmp"

    ln -sf "$LOCAL_BIN/quickshell" "$LOCAL_BIN/qs"
    mkdir -p "$(dirname "$QUICKSHELL_VERSION_FILE")"
    echo "$QUICKSHELL_VERSION" >"$QUICKSHELL_VERSION_FILE"
}

# The session's polkit agent (password prompts for privileged actions,
# run by polkit-agent.service): mate-polkit, the one agent packaged under
# the same name on Fedora, Debian/Ubuntu and Arch — Fedora no longer ships
# polkit-gnome. Its binary is never on PATH (a different libexec dir per
# distro), so it can't go through packages.txt's `command -v` check;
# scripts/.local/bin/polkit-agent holds the list of places it can be.
. "$DOTS_DIR/extras/lib.sh"

polkit_agent_installed() {
    grep -o '/usr/lib[a-z]*/[^ ]*-authentication-agent-1' "$DOTS_DIR/scripts/.local/bin/polkit-agent" \
        | while IFS= read -r agent; do [ -x "$agent" ] && echo "$agent"; done | grep -q .
}

install_polkit_agent() {
    polkit_agent_installed && return
    echo "==> installing a polkit agent (mate-polkit)"
    pkg_install mate-polkit -- mate-polkit -- mate-polkit
}

# Stowing new or changed unit files (sway/.config/systemd/user) doesn't
# tell a running systemd --user about them.
reload_user_units() {
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}

case "$(uname -m)" in
    x86_64) RELEASE_ARCH=x86_64; YAZI_ARCH=x86_64-unknown-linux-gnu; MISE_ARCH=x64 ;;
    aarch64) RELEASE_ARCH=arm64; YAZI_ARCH=aarch64-unknown-linux-gnu; MISE_ARCH=arm64 ;;
    *) RELEASE_ARCH=""; YAZI_ARCH=""; MISE_ARCH="" ;;
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
    # CI runners share IPs, so unauthenticated API calls hit GitHub's rate
    # limit there; use its token when there is one.
    local url auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    url=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" \
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
# to a font with none of them. Material Symbols Outlined is Google's
# variable icon font (consistent stroke weight/style across every glyph,
# unlike Nerd Font Symbols which stitches together many unrelated icon
# sets) — quickshell/components/Icon.qml pins it to its "Regular" named
# instance so weight/fill don't drift to an arbitrary axis position.
install_material_symbols() {
    if fc-list 2>/dev/null | grep "Material Symbols Outlined" >/dev/null; then
        return
    fi
    echo "==> installing Material Symbols Outlined (icons for quickshell)"
    local font_dir="$HOME/.local/share/fonts/MaterialSymbols"
    mkdir -p "$font_dir"
    curl -fsSL -o "$font_dir/MaterialSymbolsOutlined.ttf" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
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

# mise: per-project language toolchains (go, node, python, flutter, ...)
# pinned in each project's mise.toml / .tool-versions, activated by
# fish/conf.d/mise.fish. Only Arch packages it, so it comes from GitHub
# releases like lazygit. The asset pattern matches just the glibc tarball
# (not -musl, .tar.zst or .sig).
install_mise() {
    install_from_github_release mise jdx/mise "linux-${MISE_ARCH}.tar.gz" mise
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

# Read-only preflight: verifies everything the install will need is
# obtainable *before* anything is installed, removed or modified. No sudo,
# no package-index refresh, no writes — it only inspects and reports, and
# aborts with the full list of problems if any are found.
preflight() {
    local problems=() pkg name

    echo "==> preflight: checking dependencies (read-only)"

    local pm=""
    for name in apt dnf pacman; do
        command -v "$name" >/dev/null 2>&1 && { pm=$name; break; }
    done
    [ -n "$pm" ] || problems+=("no supported package manager (apt/dnf/pacman)")

    # Only what can't be bootstrapped by the installer itself.
    for name in sudo git python3; do
        command -v "$name" >/dev/null 2>&1 || problems+=("'$name' is required to run the installer but is not on PATH")
    done

    # Every package the install would fetch must exist in the configured repos.
    local missing=() avail
    mapfile -t missing < <(missing_packages)
    [ "$(uname -m)" = x86_64 ] || [ "$(uname -m)" = aarch64 ] \
        || problems+=("unsupported CPU architecture $(uname -m) (yazi/lazygit/lazydocker/satty release binaries)")
    command -v npm >/dev/null 2>&1 || missing+=(nodejs npm)
    polkit_agent_installed || missing+=(mate-polkit)
    if [ "$pm" = apt ] && ! python3 -c 'import venv, ensurepip' >/dev/null 2>&1; then
        missing+=(python3-venv)
    fi
    for pkg in "${missing[@]}"; do
        case "$pm" in
            apt)
                name="${APT_NAME_OVERRIDES[$pkg]:-$pkg}"
                avail=$(apt-cache policy "$name" 2>/dev/null | awk '/Candidate:/ {print $2}')
                [ -n "$avail" ] && [ "$avail" != "(none)" ] ;;
            dnf)
                dnf -q list --available "$pkg" >/dev/null 2>&1 ;;
            pacman)
                name="${ARCH_NAME_OVERRIDES[$pkg]:-$pkg}"
                pacman -Si "$name" >/dev/null 2>&1 ;;
            *) true ;;
        esac || problems+=("package '$pkg' not available from $pm repos (if the index is stale, refresh it and retry)")
    done

    # Remote hosts the installer pulls from.
    local host
    for host in github.com git.outfoxxed.me dl.flathub.org; do
        # curl itself gets installed from packages.txt if absent
        command -v curl >/dev/null 2>&1 || break
        curl -fsS --head --max-time 10 "https://$host" >/dev/null 2>&1 \
            || problems+=("cannot reach https://$host")
    done

    # .rice is cloned over ssh, so a working key matters up front.
    if [ ! -d "$RICE_DIR/.git" ] && [ "$MODE" != ci ]; then
        GIT_TERMINAL_PROMPT=0 git ls-remote "$RICE_REPO" HEAD >/dev/null 2>&1 \
            || problems+=("cannot read $RICE_REPO (ssh key for github.com set up?)")
    fi

    if [ ${#problems[@]} -gt 0 ]; then
        echo "error: preflight failed, nothing was changed:" >&2
        printf '  - %s\n' "${problems[@]}" >&2
        exit 1
    fi
    echo "==> preflight OK"
}


# Symlinks in $HOME that point into ~/.dots or ~/.rice at a file that no
# longer exists — left behind whenever a file is deleted or renamed in a
# package, since stow only ever adds links. One "link -> target" per line.
dangling_links() {
    { find "$HOME" -maxdepth 1 -xtype l -printf '%p -> %l\n'
      find "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/applications" -xtype l -printf '%p -> %l\n'
    } 2>/dev/null | grep -E '\.(dots|rice)/' || true
}

prune_dangling_links() {
    local line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        echo "==> removing dangling link ${line}"
        rm -f -- "${line%% -> *}"
    done < <(dangling_links)
}

# Read-only health check of an installed machine (`./install.sh --doctor`):
# what install.sh would still change, plus the session pieces that can
# break quietly after it ran (a service that died, a link that dangles).
# Never installs, links or restarts anything; exits 1 if anything failed.
doctor() {
    local fails=0 warns=0 pkg name out missing=()
    local g="" r="" y="" n=""
    [ -t 1 ] && { g=$'\033[32m'; r=$'\033[31m'; y=$'\033[33m'; n=$'\033[0m'; }
    ok() { printf '  %sok%s    %s\n' "$g" "$n" "$*"; }
    bad() { printf '  %sFAIL%s  %s\n' "$r" "$n" "$*"; fails=$((fails + 1)); }
    warn() { printf '  %swarn%s  %s\n' "$y" "$n" "$*"; warns=$((warns + 1)); }

    echo "packages"
    mapfile -t missing < <(missing_packages)
    if [ ${#missing[@]} -eq 0 ]; then ok "packages.txt"; else bad "not installed: ${missing[*]}"; fi
    polkit_agent_installed && ok "polkit agent" || bad "no polkit agent (mate-polkit)"
    for name in yazi satty lazygit lazydocker mise; do
        command -v "$name" >/dev/null 2>&1 && ok "$name" || bad "$name not on PATH"
    done
    if [ "$(cat "$QUICKSHELL_VERSION_FILE" 2>/dev/null)" = "$QUICKSHELL_VERSION" ] && [ -x "$LOCAL_BIN/quickshell" ]; then
        ok "quickshell $QUICKSHELL_VERSION"
    else
        bad "quickshell isn't the pinned $QUICKSHELL_VERSION build"
    fi
    if command -v flatpak >/dev/null 2>&1; then
        missing=()
        while IFS= read -r name; do
            case "$name" in ''|'#'*) continue ;; esac
            flatpak info "$name" >/dev/null 2>&1 || missing+=("$name")
        done <"$BOOTSTRAP_DIR/flatpaks.txt"
        if [ ${#missing[@]} -eq 0 ]; then ok "flatpaks.txt"; else bad "flatpaks not installed: ${missing[*]}"; fi
    fi
    fc-list 2>/dev/null | grep "Material Symbols Outlined" >/dev/null && ok "Material Symbols font" || bad "Material Symbols font missing"
    [ -f /etc/pam.d/quickshell-lock ] && ok "lock screen PAM service" || bad "/etc/pam.d/quickshell-lock missing (lock screen can't unlock)"

    echo "links"
    local fails_before=$fails
    # stow's dry run lists exactly the links a real run would still make
    # (LINK:) and the files it would refuse to replace (* cannot stow ...)
    local stow_dirs=() dir
    for pkg in "${PACKAGES[@]}"; do stow_dirs+=("$DOTS_DIR:$pkg"); done
    while IFS= read -r name; do
        [ -d "$DOTS_DIR/extras/$name/home" ] && stow_dirs+=("$DOTS_DIR/extras/$name:home")
    done < <(grep -v '^\s*$' "$DOTS_DIR/.extras-enabled" 2>/dev/null)
    for dir in "${stow_dirs[@]}"; do
        pkg=${dir##*:}; dir=${dir%:*}
        out=$(stow -n -v --no-folding -d "$dir" -t "$HOME" "$pkg" 2>&1 || true)
        name=${dir#"$DOTS_DIR"}; name=${name#/}; name=${name:+$name/}$pkg
        if grep -q '^LINK:' <<<"$out"; then
            bad "$name: not linked: $(sed -n 's/^LINK: \([^ ]*\) =>.*/~\/\1/p' <<<"$out" | tr '\n' ' ')(run install.sh)"
        elif grep -q 'cannot stow' <<<"$out"; then
            bad "$name: conflicts: $(sed -n 's/.*over existing target \([^ ]*\).*/~\/\1/p' <<<"$out" | tr '\n' ' ')"
        fi
    done
    local dangling
    dangling=$(dangling_links)
    if [ -n "$dangling" ]; then
        bad "dangling links into ~/.dots or ~/.rice (install.sh removes them):"
        sed 's/^/          /' <<<"$dangling"
    fi
    [ "$fails" -gt "$fails_before" ] || ok "every package and enabled extra is linked"

    echo "rice"
    if [ -d "$RICE_DIR/.git" ]; then
        ok "$RICE_DIR"
        [ -e "$RICE_DIR/sway/outputs.conf" ] && ok "sway/outputs.conf" || bad "$RICE_DIR/sway/outputs.conf missing (sway's include dangles)"
    else
        bad "$RICE_DIR not cloned"
    fi

    echo "session"
    if swaymsg -t get_version >/dev/null 2>&1; then
        pgrep -x quickshell >/dev/null && ok "quickshell running" || bad "quickshell not running"
        local units
        units=$(systemctl --user show -p Wants --value dots-session.target 2>/dev/null)
        if ! systemctl --user -q is-active dots-session.target; then
            bad "dots-session.target not active (log out and back in, or: systemctl --user restart dots-session.target)"
        fi
        for name in $units; do
            if systemctl --user -q is-active "$name"; then
                ok "$name"
            else
                bad "$name $(systemctl --user show -p ActiveState --value "$name") (journalctl --user -u $name)"
            fi
        done
    else
        warn "not inside sway; skipped the session services"
    fi

    echo "repos"
    for dir in "$DOTS_DIR" "$RICE_DIR"; do
        [ -d "$dir/.git" ] || continue
        if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
            warn "$dir has uncommitted changes"
        else
            ok "$dir clean"
        fi
    done

    echo
    if [ "$fails" -gt 0 ]; then
        echo "$fails problem(s), $warns warning(s)"
        return 1
    fi
    echo "all good ($warns warning(s))"
}

# --ci (.github/workflows/ci.yml, as root in a fresh distro container):
# everything that installs from a package manager or a download, so a
# renamed/dropped package or a broken quickshell build fails there first.
# Skips what needs a real user session or credentials: the ssh-cloned
# .rice, flatpaks (system flatpak doesn't run in a container), PAM, and
# the stow/tmux/LSP steps that depend on .rice being present.
ci() {
    preflight
    install_packages
    install_polkit_agent
    install_quickshell
    install_node
    install_yazi
    install_satty
    install_lazygit
    install_lazydocker
    install_mise
    "$LOCAL_BIN/quickshell" --version
    polkit_agent_installed
}

MODE=install
case "${1:-}" in
    --doctor) doctor; exit ;;
    --ci) MODE=ci; ci; exit ;;
    '') ;;
    *) echo "usage: $0 [--doctor | --ci]" >&2; exit 1 ;;
esac

preflight
install_packages
install_polkit_agent
install_quickshell
install_flatpaks
install_node
install_rice
install_material_symbols
install_pam_lock_config
install_yazi
install_satty
install_lazygit
install_lazydocker
install_mise
cd "$DOTS_DIR"

for pkg in "${PACKAGES[@]}"; do
    echo "==> stowing $pkg"
    stow -v --no-folding --adopt -t "$HOME" "$pkg"
done

# Opt-in extras (extras/extras.sh) stay out of PACKAGES; this only re-links
# the ones already enabled on this machine, so new files in them land too.
"$DOTS_DIR/extras/extras.sh" restow
prune_dangling_links

reload_user_units
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
