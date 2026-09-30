function tmux --wraps tmux --description 'tmux, but new sessions always get a name'
    set -l new 0
    if test (count $argv) -eq 0
        set new 1
    else if contains -- $argv[1] new new-session
        set new 1
        contains -- -s $argv; and set new 0
        contains -- -t $argv; and set new 0
    end

    if test $new -eq 1
        set -l name
        while test -z "$name"
            read -P 'tmux session name: ' name; or return 1
            set name (string replace -ar '[.:]' _ -- (string trim -- $name))
        end
        if test (count $argv) -eq 0
            command tmux new-session -A -s $name
        else
            command tmux $argv -s $name
        end
    else
        command tmux $argv
    end
end
