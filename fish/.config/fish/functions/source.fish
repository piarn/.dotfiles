# Fish files, piped stdin and bass's own generated script go to the builtin
# (fish itself and plugins rely on it); anything else is run through bass.
function source --wraps source --description 'source fish files natively, bash files via bass'
    if test (count $argv) -eq 0; or string match -q -- '-' $argv[1]; or string match -q -- '*.fish' $argv[1]
        or status stack-trace | string match -q "*in function 'bass'*"
        builtin source $argv
    else
        bass source $argv
    end
end
