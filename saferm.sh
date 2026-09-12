#!/usr/bin/env bash
set -u

RETENTION_SECONDS=300
TRASH_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/saferm_trash"
mkdir -p "$TRASH_ROOT"

# ---------- helper functions ----------

now_epoch() { date +%s; }

gen_id() {
    echo "$(date +%Y%m%d%H%M%S%N)_$$_${RANDOM}"
}

abs_path() {
    # Converts a path to an absolute path without resolving symbolic links.
    # When rm deletes a symbolic link, it deletes the link itself, not its target.
    # We preserve this behavior by not using realpath/readlink.
    local p="$1"
    if [[ "$p" = /* ]]; then
        printf '%s\n' "$p"
    else
        printf '%s\n' "$PWD/$p"
    fi
}

purge_expired() {
    local dir meta deleted_at age
    shopt -s nullglob
    for dir in "$TRASH_ROOT"/*/; do
        meta="${dir}meta"
        if [[ ! -f "$meta" ]]; then
            command -p rm -rf -- "$dir"
            continue
        fi
        deleted_at=$(grep -m1 '^deleted_at=' "$meta" | cut -d= -f2)
        if [[ -z "$deleted_at" ]]; then
            command -p rm -rf -- "$dir"
            continue
        fi
        age=$(( $(now_epoch) - deleted_at ))
        if (( age >= RETENTION_SECONDS )); then
            command -p rm -rf -- "$dir"
        fi
    done
    shopt -u nullglob
}

schedule_bg_purge() {
    local entry_dir="$1"
    ( setsid bash -c "sleep $RETENTION_SECONDS; command -p rm -rf -- '$entry_dir'" \
        </dev/null >/dev/null 2>&1 & ) 2>/dev/null
    disown -a 2>/dev/null || true
}

remaining_seconds() {
    local deleted_at="$1"
    local left=$(( deleted_at + RETENTION_SECONDS - $(now_epoch) ))
    (( left < 0 )) && left=0
    echo "$left"
}

# ---------- rm behavior ----------

do_rm() {
    local recursive=0 force=0 interactive=0 verbose=0
    local -a targets=()
    local end_opts=0 arg

    for arg in "$@"; do
        if (( end_opts )); then
            targets+=("$arg")
            continue
        fi
        case "$arg" in
            --) end_opts=1 ;;
            --recursive) recursive=1 ;;
            --force) force=1 ;;
            --interactive) interactive=1 ;;
            --verbose) verbose=1 ;;
            -) targets+=("$arg") ;;
            -*)
                local i c
                for (( i=1; i<${#arg}; i++ )); do
                    c="${arg:$i:1}"
                    case "$c" in
                        r|R) recursive=1 ;;
                        f) force=1 ;;
                        i) interactive=1 ;;
                        v) verbose=1 ;;
                        *)
                            echo "rm: invalid option -- '$c'" >&2
                            return 1
                            ;;
                    esac
                done
                ;;
            *)
                targets+=("$arg")
                ;;
        esac
    done

    if (( ${#targets[@]} == 0 )); then
        if (( force )); then
            return 0
        fi
        echo "rm: missing operand" >&2
        return 1
    fi

    local exit_code=0
    local path abs entry_id entry_dir reply

    for path in "${targets[@]}"; do
        if [[ ! -e "$path" && ! -L "$path" ]]; then
            if (( ! force )); then
                echo "rm: cannot remove '$path': No such file or directory" >&2
                exit_code=1
            fi
            continue
        fi

        if [[ -d "$path" && ! -L "$path" && $recursive -eq 0 ]]; then
            echo "rm: cannot remove '$path': Is a directory (use -r to remove)" >&2
            exit_code=1
            continue
        fi

        if (( interactive )); then
            read -r -p "rm: remove '$path'? (y/n) " reply
            case "$reply" in
                e|E|y|Y) ;;
                *) continue ;;
            esac
        fi

        abs=$(abs_path "$path")
        entry_id=$(gen_id)
        entry_dir="$TRASH_ROOT/$entry_id"
        mkdir -p "$entry_dir"

        if ! command -p mv -- "$path" "$entry_dir/payload" 2>/tmp/.saferm_err; then
            echo "rm: failed to move '$path': $(cat /tmp/.saferm_err 2>/dev/null)" >&2
            command -p rm -rf -- "$entry_dir"
            exit_code=1
            continue
        fi

        {
            printf 'original_path=%s\n' "$abs"
            printf 'deleted_at=%s\n' "$(now_epoch)"
        } > "$entry_dir/meta"

        schedule_bg_purge "$entry_dir"

        if (( verbose )); then
            echo "removed: '$path'  (to restore: undelete $entry_id  |  window: 5 min)"
        fi
    done

    return $exit_code
}

# ---------- undelete behavior ----------

list_trash() {
    purge_expired
    local dir meta original_path deleted_at left found=0
    shopt -s nullglob
    printf '%-24s %-8s %s\n' "ID" "REMAINING" "ORIGINAL LOCATION"
    for dir in "$TRASH_ROOT"/*/; do
        meta="${dir}meta"
        [[ -f "$meta" ]] || continue
        original_path=$(grep -m1 '^original_path=' "$meta" | cut -d= -f2-)
        deleted_at=$(grep -m1 '^deleted_at=' "$meta" | cut -d= -f2)
        left=$(remaining_seconds "$deleted_at")
        printf '%-24s %-8s %s\n' "$(basename "$dir")" "${left}s" "$original_path"
        found=1
    done
    shopt -u nullglob
    (( found )) || echo "(trash is empty)"
}

restore_entry_dir() {
    local entry_dir="$1"
    local meta="${entry_dir}meta"
    if [[ ! -f "$meta" ]]; then
        echo "undelete: invalid entry: $entry_dir" >&2
        return 1
    fi

    local original_path deleted_at left target
    original_path=$(grep -m1 '^original_path=' "$meta" | cut -d= -f2-)
    deleted_at=$(grep -m1 '^deleted_at=' "$meta" | cut -d= -f2)
    left=$(remaining_seconds "$deleted_at")

    if (( left <= 0 )); then
        echo "undelete: restore window for '$original_path' has expired" >&2
        command -p rm -rf -- "$entry_dir"
        return 1
    fi

    target="$original_path"
    if [[ -e "$target" || -L "$target" ]]; then
        target="${original_path}.restored-$(date +%s)"
        echo "undelete: '$original_path' already exists, restoring as '$target' instead" >&2
    fi

    mkdir -p "$(dirname "$target")"
    if command -p mv -- "${entry_dir}payload" "$target"; then
        command -p rm -rf -- "$entry_dir"
        echo "restored: '$target'"
        return 0
    else
        echo "undelete: could not restore to '$target'" >&2
        return 1
    fi
}

do_undelete() {
    purge_expired

    if (( $# == 0 )); then
        list_trash
        return 0
    fi

    case "$1" in
        list|-l)
            list_trash
            return 0
            ;;
        --all)
            local dir any=0
            shopt -s nullglob
            for dir in "$TRASH_ROOT"/*/; do
                restore_entry_dir "$dir"
                any=1
            done
            shopt -u nullglob
            (( any )) || echo "(trash is empty)"
            return 0
            ;;
        last)
            # Entry directory names begin with a fixed-width timestamp
            # (YYYYMMDDHHMMSS + nanoseconds), so the LAST item in alphabetical
            # order is also the most recently deleted item chronologically.
            # Since deleted_at has only second-level precision, it is not enough
            # by itself when multiple deletions occur within the same second.
            local newest="" dir meta
            shopt -s nullglob
            for dir in "$TRASH_ROOT"/*/; do
                meta="${dir}meta"
                [[ -f "$meta" ]] || continue
                newest="$dir"
            done
            shopt -u nullglob
            if [[ -z "$newest" ]]; then
                echo "(trash is empty)"
                return 1
            fi
            restore_entry_dir "$newest"
            return $?
            ;;
        *)
            local exit_code=0 id entry_dir found d meta original_path
            for id in "$@"; do
                entry_dir="$TRASH_ROOT/$id/"
                if [[ -d "$entry_dir" ]]; then
                    restore_entry_dir "$entry_dir" || exit_code=1
                    continue
                fi
                found=0
                shopt -s nullglob
                for d in "$TRASH_ROOT"/*/; do
                    meta="${d}meta"
                    [[ -f "$meta" ]] || continue
                    original_path=$(grep -m1 '^original_path=' "$meta" | cut -d= -f2-)
                    if [[ "$original_path" == "$id" || "$(basename "$original_path")" == "$id" ]]; then
                        restore_entry_dir "$d" || exit_code=1
                        found=1
                    fi
                done
                shopt -u nullglob
                if (( ! found )); then
                    echo "undelete: '$id' not found in trash" >&2
                    exit_code=1
                fi
            done
            return $exit_code
            ;;
    esac
}

# ---------- entry point ----------

prog="$(basename -- "$0")"
purge_expired

case "$prog" in
    undelete)
        do_undelete "$@"
        exit $?
        ;;
    *)
        do_rm "$@"
        exit $?
        ;;
esac
