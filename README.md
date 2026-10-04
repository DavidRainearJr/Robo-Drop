# Robo Drop

Robo Drop is a set of drag-and-drop Windows batch utilities for copying, moving, or mirroring files and folders with the built-in `robocopy.exe` command. It targets Windows 10 and Windows 11 and requires no third-party software.

## Scripts

- `00 - Transfer Here.bat` asks once whether all dropped items should be copied, moved, or mirrored.
- `00 - Copy Here.bat` immediately copies all dropped items.
- `00 - Move Here.bat` immediately moves all dropped items.
- `00 - Mirror Here.bat` immediately mirrors dropped folders. Individual files are synchronized without deleting other destination files.

Every script is completely standalone. This intentionally duplicates the transfer logic so any one `.bat` file continues to work when copied by itself to another drive or folder.

## Use

1. Copy the desired `.bat` file into the destination folder or drive.
2. Select one or more source files and folders in File Explorer.
3. Drag the selection onto the `.bat` file.
4. Review the Robocopy output and final summary.
5. Delete the temporary batch file from the destination when it is no longer needed.

The batch file's actual directory is always the destination. The current command prompt directory does not affect the result. Multiple files, multiple folders, mixed selections, and paths containing spaces are supported. Items are processed sequentially, and a failed item does not prevent later items from being attempted.

## Operations

### Copy

Folders are copied recursively, including empty directories, into a corresponding child folder. Files are copied directly into the batch file's directory. Existing unchanged files may be skipped by Robocopy; new and changed files are copied. Sources remain intact.

Example:

```text
Source:       C:\Source\Project Files
Batch file:   E:\Destination\00 - Copy Here.bat
Destination:  E:\Destination\Project Files
```

### Move

MOVE uses Robocopy's native `/MOVE` behavior for folders and `/MOV` behavior for individual files. Successfully transferred source content is removed by Robocopy. The scripts never perform a separate, unconditional source deletion after Robocopy returns.

If a transfer partially succeeds, Robocopy can remove portions it successfully transferred while leaving failed source content in place. Always review a failed MOVE operation before retrying it.

### Mirror

**MIRROR is destructive.** `00 - Mirror Here.bat` can delete files and folders from the corresponding destination folder when they do not exist in the source.

A dropped folder is always mirrored into a same-named child folder. It is never mirrored directly onto the batch file's destination root:

```text
Source:       C:\Source\Project Files
Batch file:   E:\Destination\00 - Mirror Here.bat
Mirror scope: E:\Destination\Project Files
```

In this example, extra content inside `E:\Destination\Project Files` may be deleted. Unrelated siblings such as `E:\Destination\Other Folder` are outside the mirror scope and remain untouched.

Robocopy `/MIR` applies to directory trees. When an individual file is dropped in MIRROR mode, the script copies or updates that file in the destination root without purging any other destination files.

## Metadata And Filesystems

At startup, each script detects and displays the filesystem containing the destination:

- NTFS destinations use `/COPY:DAT`.
- exFAT, FAT32, unknown, and other non-NTFS destinations use `/COPY:DATX` to exclude alternate data streams.
- Directory metadata uses `/DCOPY:DAT`.

These settings preserve ordinary data, attributes, and timestamps. The scripts do not migrate ACLs, ownership, or auditing information and do not use `/COPYALL` or `/SEC`.

All operations use `/R:2 /W:1`, limiting failed-copy retries to two with a one-second wait rather than Robocopy's very large defaults.

## Safety

The scripts reject missing sources, filesystem roots, a source that is its own destination, and folder relationships that could copy recursively or allow a mirror operation to affect its source. They also prevent an incoming item from overwriting the currently running batch file.

MIRROR deletion is confined to the same-named destination folder for each dropped source folder. `/PURGE` is never used independently; deletion occurs only through the correctly scoped `/MIR` operation.

## Robocopy Results

Robocopy return codes are bitmapped status values, so a nonzero result is not automatically a failure:

- Codes `0` through `7` are successful or nonfatal states.
- Codes `8` and greater indicate at least one copy failure.

Each script reports the Robocopy code for every item, tracks succeeded and failed items, and prints a final summary. Automatic scripts pause when a failure occurs. The interactive script pauses after every run.

See Microsoft's [Robocopy documentation](https://learn.microsoft.com/windows-server/administration/windows-commands/robocopy) for the complete option and return-code reference.
