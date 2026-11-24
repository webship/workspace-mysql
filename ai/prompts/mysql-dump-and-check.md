Export the MySQL database of a Webship Workspace project into the backups folder, and check that the dump is whole.

```
claude --permission-mode bypassPermissions """
# A Webship Workspace, container-based (DDEV by default), at ~/workspace/<folder>: the project <project>.
# The MySQL plugin placed cmd-tools-mysql.sh in that folder: every step below is that tool or a read of its dump.

1. Run `bash cmd-tools-mysql.sh <project> --info` and say the MySQL version, the runtime and the size.
   Stop there if it answers that the project is stopped, has another engine or has no database.
2. Run `bash cmd-tools-mysql.sh <project> --tables` and keep the number of tables.
3. Run `bash cmd-tools-mysql.sh <project> --export`, and take the path of the dump from what it prints.
4. Check the dump: `gunzip -t <file>`, then count `^CREATE TABLE` in `gunzip -c <file>` (the same number as step 2),
   and read its last line (a whole dump ends with "-- Dump completed").
5. Say where the dump is, its size, and whether each check passed. Import nothing, change nothing else.
"""
```

The text between the triple quotes is plain: it can be given to another AI command-line assistant as it is.
