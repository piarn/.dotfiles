if status is-interactive
    set -g fish_greeting
end

fish_add_path ~/.local/bin
fish_add_path ~/bin

if test -f ~/.config/fish/local.fish
    source ~/.config/fish/local.fish
end
