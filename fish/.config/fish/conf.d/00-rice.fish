if test -f ~/.rice/fish/colors.fish
    source ~/.rice/fish/colors.fish
end

set -q rice_color_dir; or set -g rice_color_dir cyan
set -q rice_color_branch; or set -g rice_color_branch yellow
set -q rice_color_error; or set -g rice_color_error red
