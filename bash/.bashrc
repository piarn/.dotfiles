if [[ $- == *i* ]] && [[ -z "$FISH_VERSION" ]] && command -v fish >/dev/null 2>&1
then
    shell_name=$(ps -p $$ -o comm=)
    if [[ "$shell_name" != "fish" ]]
    then
        exec fish
    fi
fi
