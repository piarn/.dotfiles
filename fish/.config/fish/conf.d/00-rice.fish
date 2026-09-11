if test -f ~/.rice/fish/colors.fish
    source ~/.rice/fish/colors.fish
end

set -q rice_color_dir; or set -g rice_color_dir cyan

if test -f ~/.rice/eza/colors.fish
    source ~/.rice/eza/colors.fish
end
