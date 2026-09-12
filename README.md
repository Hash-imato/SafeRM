# SafeRM
SafeRM- A Safer Undoable Replacement for rm

 saferm - A safe deletion utility that mimics rm with a 5-minute undo window.

# HOW IT WORKS
   Every file/directory deleted with "rm" is actually MOVED to its own unique
   subdirectory under $TRASH_ROOT. After 300 seconds, it is permanently
   deleted automatically in the background. During this period, "undelete"
   can restore the file to EXACTLY its original location.

   Name collisions are not a problem: each deletion gets its own unique
   directory (timestamp + PID + random number), while the original path is
   stored separately in a metadata file.

# INSTALLATION
##   1) Make this file executable and place it somewhere permanent:
        mkdir -p ~/.local/bin
        cp saferm.sh ~/.local/bin/saferm
        chmod +x ~/.local/bin/saferm

##   2) Create symbolic links so it can be called using two different names
      (rm and undelete):
        ln -sf ~/.local/bin/saferm ~/.local/bin/rm
        ln -sf ~/.local/bin/saferm ~/.local/bin/undelete

##   3) Make sure ~/.local/bin appears BEFORE /usr/bin in your PATH.
      Add the following to the END of your ~/.bashrc:
        export PATH="$HOME/.local/bin:$PATH"

##   4) source ~/.bashrc

##   5) Verify: `which rm` should output ~/.local/bin/rm.

# USAGE
   rm file.txt                   -> behaves like normal rm, but actually
                                    moves the file to the trash
   rm -rf directory/             -> same syntax and behavior as rm -rf
   rm -i -v file1 file2          -> supports -i (prompt) and -v (verbose)
   undelete                      -> lists unexpired items in the trash
   undelete <id>                 -> restores the specified entry to its
                                    original location
   undelete file.txt             -> restores the matching entry by name/path
   undelete last                 -> restores the most recently deleted item
   undelete --all                -> restores everything currently in the trash

 IMPORTANT LIMITATIONS
   **- This protection only applies when the "rm" command is invoked by its
     plain name through PATH. A program that directly calls /usr/bin/rm is
     NOT affected (this is intentional, to avoid breaking system scripts).**

   **- When the script cleans up the trash, it calls the REAL rm/mv commands
     using `command -p`, which uses the system's default PATH rather than the
     user's PATH. This prevents the script from calling itself recursively
     and entering an infinite loop.**

   **- Moving very large files to a different filesystem (e.g. another
     disk/partition) may cause `mv` to perform a copy+delete operation,
     which can be slower than normal. For deletions within the home directory
     (~/.local/share), this is not an issue because the move is performed as
     a fast filesystem-level rename.**

   - The -d (remove empty directories) option is not supported. Use -r/-R
#     to remove directories.
```
