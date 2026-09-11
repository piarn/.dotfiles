#!/usr/bin/env bash
# Bootstraps this dotfiles repo onto a new machine via GNU Stow.
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(bash bat fd fish ghostty git lazydocker lazygit nvim ripgrep tmux waybar yazi)
BOOTSTRAP_DIR="$DOTS_DIR/.bootstrap"

# Installs everything listed in .bootstrap/packages.txt (one binary/package
# name per line, matching apt/dnf naming) that isn't already on PATH.
install_packages() {
    local pkgs=() pkg missing=()
    while IFS= read -r pkg; do
        case "$pkg" in ''|'#'*) continue ;; esac
        pkgs+=("$pkg")
    done <"$BOOTSTRAP_DIR/packages.txt"

    for pkg in "${pkgs[@]}"; do
        command -v "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "==> packages already installed, nothing to do"
        return
    fi

    echo "==> installing packages: ${missing[*]}"
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y "${missing[@]}"
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
cd "$DOTS_DIR"

for pkg in "${PACKAGES[@]}"; do
    echo "==> stowing $pkg"
    stow -v --no-folding --adopt -t "$HOME" "$pkg"
done

install_fish_plugins
install_tpm
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true

install_lsp_servers

echo
echo "Done. Review 'git status' / 'git diff' in $DOTS_DIR — --adopt pulls any"
echo "pre-existing files at the target paths into the repo, which may have"
echo "overwritten tracked content with your local version. Discard with"
echo "'git checkout -- <file>' if the repo version should win instead."
