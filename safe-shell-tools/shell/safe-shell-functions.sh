#!/usr/bin/env bash
#
# safe-shell-functions.sh - cd (with history) and mkdir (prompt to enter directory)
#
# *** IMPORTANT - THIS FILE IS NOT EXECUTED DIRECTLY; IT IS SOURCED ***
#
# Unlike rm/ls, cd is a Bash BUILTIN, and mkdir's "enter the newly created
# directory" feature must change the current working directory of the
# existing shell.
# A child process (that is, a separate script) can never change the working
# directory of its parent shell - this is a fundamental Unix rule, not a
# limitation of our script. Therefore, cd and mkdir must be implemented as
# BASH FUNCTIONS directly inside your interactive shell, rather than as
# executable files placed in PATH.
#
# INSTALLATION
#   1) Put this file somewhere permanent, for example:
#        mkdir -p ~/.local/share/safe-shell-tools
#        cp safe-shell-functions.sh ~/.local/share/safe-shell-tools/
#
#   2) Add the following line to the END of your ~/.bashrc:
#        source ~/.local/share/safe-shell-tools/safe-shell-functions.sh
#
#   3) Open a new terminal or run:
#        source ~/.bashrc
#
#   4) Verify with:
#        type cd
#      You should see "cd is a function"
#      (not a file path).
#
# USAGE
#   cd some/path              -> normal cd; ALL real cd behavior is preserved
#                               (cd, cd -, cd ~, cd -L/-P, etc. all work as usual)
#
#   cd -h   or   cd --history -> lists all directories visited so far, numbered
#
#   cd 3!                     -> changes to the directory stored as history entry 3
#
#   mkdir newdir               -> creates the directory; when exactly ONE
#                               directory is specified, asks:
#                               "Enter the directory? (y/n)"
#
#   mkdir -p a/b/c             -> works the same way; creates a/b/c and,
#                               if requested, enters c
#
#   mkdir a b c                -> when multiple directories are specified,
#                               does NOT ask (the intended directory would be
#                               ambiguous).
#
# KNOWN LIMITATIONS
#   - The cd history grows in ~/.local/share/safecd_history. You can remove
#     it manually with:
#        rm -f ~/.local/share/safecd_history
#     (using the real rm, or saferm if you have it installed).
#
#   - The mkdir "enter the directory?" prompt is shown only when input is
#     coming from a terminal (TTY). When called from a script, it stays silent
#     and only creates the directory, so automation is not blocked. This is
#     intentional.

_safecd_hist_file() {
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}"

    # 'command' is used to invoke the real system mkdir rather than our
    # mkdir function below. Otherwise, it would call itself recursively and
    # unnecessarily display the "enter the directory?" prompt.
    command mkdir -p "$dir"

    echo "$dir/safecd_history"
}

cd() {
    local hist_file
    hist_file="$(_safecd_hist_file)"
    touch "$hist_file"

    # -h / --history : display history with line numbers
    if [[ "${1:-}" == "-h" || "${1:-}" == "--history" ]]; then
        if [[ ! -s "$hist_file" ]]; then
            echo "(cd history is empty)"
            return 0
        fi

        nl -ba -w4 -s'  ' "$hist_file"
        return 0
    fi

    # N! : jump to history entry N
    if [[ "${1:-}" =~ ^[0-9]+!$ ]]; then
        local num="${1%!}"
        local target

        target=$(sed -n "${num}p" "$hist_file")

        if [[ -z "$target" ]]; then
            echo "cd: no history entry numbered $num" >&2
            return 1
        fi

        builtin cd -- "$target" || return $?
        [[ "$PWD" != "$(tail -n1 "$hist_file" 2>/dev/null)" ]] && echo "$PWD" >> "$hist_file"
        return 0
    fi

    # Normal usage: delegate everything to the real cd builtin unchanged.
    builtin cd "$@"
    local rc=$?

    if (( rc == 0 )); then
        [[ "$PWD" != "$(tail -n1 "$hist_file" 2>/dev/null)" ]] && echo "$PWD" >> "$hist_file"
    fi

    return $rc
}

mkdir() {
    # Call the real mkdir command - all flags and behavior are preserved exactly.
    command mkdir "$@"
    local rc=$?

    (( rc == 0 )) || return $rc

    # Continue only when running interactively in a terminal,
    # so automation is never blocked by a prompt.
    [[ -t 0 ]] || return 0

    # Count arguments that do not begin with '-'.
    # Skip the value following -m/--mode.
    local -a dirs=()
    local skip_next=0 arg

    for arg in "$@"; do
        if (( skip_next )); then
            skip_next=0
            continue
        fi

        case "$arg" in
            -m|--mode) skip_next=1 ;;
            -*) ;;
            *) dirs+=("$arg") ;;
        esac
    done

    # Ask only when exactly ONE directory was created.
    if (( ${#dirs[@]} == 1 )); then
        local target="${dirs[0]}"
        local reply

        read -r -p "Enter the directory? ($target) (y/n) " reply

        case "$reply" in
            y|Y|e|E) builtin cd -- "$target" ;;
            *) : ;;
        esac
    fi
}
