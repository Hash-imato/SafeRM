# safe-shell-tools

A small collection of tools that make four commonly used Bash commands (`rm`, `cd`, `mkdir`, and `ls`) a little safer and more convenient while preserving their original behavior as closely as possible.

* **`rm`** → everything you "delete" gets a 5-minute recovery window instead of being permanently deleted immediately
* **`undelete`** → restores files to their original locations while they are still within the recovery window
* **`cd`** → keeps a numbered history of every directory you visit, allowing you to jump back to previous locations by number
* **`mkdir`** → asks whether you want to enter the directory you just created
* **`ls`** → adds `--tree` (tree view) and `--age` (file age) options

Everything else in normal usage (options, multiple files, etc.) works as closely as possible to the original commands.

## Why are some commands scripts and others functions?

This is an important architectural distinction that should not be overlooked:

| Command       | Implementation                                 | Why                                                                                         |
| ------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `rm`, `ls`    | Real executable files placed in `~/.local/bin` | They only need to read/write files and do not need to modify the state of the current shell |
| `cd`, `mkdir` | Bash functions **sourced** from `~/.bashrc`    | They need to modify the current working directory of the shell                              |

`cd` is a **builtin** defined inside Bash itself because a child process (that is, a separate program/script) can never change the working directory of its parent shell. This is not a limitation of our script; it is a fundamental rule of Unix processes.

For the same reason, `mkdir`'s "enter the directory you just created" feature must also be implemented as a function. Therefore, `cd` and `mkdir` are not executable files placed in `PATH` like `rm`/`ls`; instead, they are functions defined directly inside your interactive terminal session.

The practical result is that `rm`/`ls` can take effect anywhere (including other scripts, provided those scripts use the same `PATH`), while `cd`/`mkdir` affect **only your interactive terminal session after `~/.bashrc` has been sourced**. A `mkdir`/`cd` invoked from another script is not affected.

## Installation

### Automatic (recommended)

```bash
git clone <this-repo-url> safe-shell-tools
cd safe-shell-tools
./install.sh
source ~/.bashrc
```

### Manual

```bash
# rm and ls
mkdir -p ~/.local/bin
cp bin/saferm ~/.local/bin/saferm
cp bin/safels ~/.local/bin/safels
chmod +x ~/.local/bin/saferm ~/.local/bin/safels
ln -sf ~/.local/bin/saferm ~/.local/bin/rm
ln -sf ~/.local/bin/saferm ~/.local/bin/undelete
ln -sf ~/.local/bin/safels ~/.local/bin/ls

# cd and mkdir
mkdir -p ~/.local/share/safe-shell-tools
cp shell/safe-shell-functions.sh ~/.local/share/safe-shell-tools/

# Add to the END of ~/.bashrc:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'source "$HOME/.local/share/safe-shell-tools/safe-shell-functions.sh"' >> ~/.bashrc

source ~/.bashrc
```

### Verification

```bash
which rm     # should show ~/.local/bin/rm, NOT /usr/bin/rm
which ls     # should show ~/.local/bin/ls
type cd      # should show "cd is a function"
type mkdir   # should show "mkdir is a function"
```

## Usage

### rm / undelete

```bash
rm file.txt                # behaves like normal rm, but moves the file to the trash
rm -rf directory/          # -r, -f, -v, and -i are all supported
rm -s file1 file2          # TEST MODE - deletes nothing, only previews:
                           #   file1
                           #   file2
                           #   Total: 2 files
                           #   No actual operation was performed

undelete                   # lists the trash (including remaining recovery time)
undelete last              # restores the most recently deleted item
undelete <id>              # restores a specific entry
undelete file.txt          # restores the matching entry by name
undelete --all             # restores everything currently in the trash
```

The recovery window is **5 minutes**. Once the time expires, the item is permanently deleted automatically in the background.

If the same name is deleted multiple times, this is not a problem. When restoring an item, if the original path is already occupied, it is restored as `name.restored-<timestamp>` instead — existing data is never overwritten.

### cd

```bash
cd some/path        # normal cd - nothing changes
cd -                # normal cd - (go back to the previous directory), works as usual
cd -h               # or: cd --history
                    #    1  /home/user/projects
                    #    2  /home/user/projects/api
                    #    3  /tmp
cd 2!               # jumps to directory #2 in the history
```

### mkdir

```bash
mkdir new-project
# output: Enter the directory? (new-project) (y/n)
# y -> enters it, n -> stays where you are

mkdir -p a/b/c       # works with -p as well; the prompt refers to the deepest directory (c)
mkdir a b c          # if multiple directories are specified, there is NO prompt
                     # (to avoid ambiguity)
```

### ls

```bash
ls --tree            # displays the current directory as a tree
ls --tree -a         # includes hidden files
ls --tree some/path  # displays the specified directory as a tree

ls --age             # shows file ages in a human-readable format such as "3 days ago"

ls -la               # EVERYTHING else works like normal ls
```

## Known limitations

* The `rm`/`ls` protection only applies when the command is invoked by its plain name through `PATH`. A program that directly calls `/usr/bin/rm` is not affected (this is intentional, so system scripts are not broken).
* The `cd` history grows indefinitely in `~/.local/share/safecd_history`. You can remove it manually if needed.
* The `mkdir` "enter the directory?" prompt is only shown when called from a terminal (TTY). When called from a script, it is silently skipped (intentionally, so automation is not blocked).
* When very large files are moved to a different filesystem (for example, a separate disk), `rm` may take longer than usual when moving them to the trash. `mv` can perform an instant `rename` on the same filesystem, but must perform a copy+delete operation across different filesystems.
* `ls --tree` and `ls --age` cannot currently be used together (one overrides the other; `--tree` takes precedence).
