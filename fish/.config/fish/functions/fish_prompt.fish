function fish_prompt
    set -l last_status $status

    # Directory (shortened)
    set_color $rice_color_dir
    echo -n (prompt_pwd)

    # Git branch, if inside a repo
    set -l branch (git branch --show-current 2>/dev/null)
    if test -n "$branch"
        set_color $rice_color_branch
        echo -n " ($branch)"
    end

    # Status indicator
    if test $last_status -ne 0
        set_color $rice_color_error
        echo -n " [$last_status]"
    end

    set_color normal
    echo -n ' $ '
end
