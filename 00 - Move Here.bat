@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "MODE=MOVE"
set "ALWAYS_PAUSE=0"

rem Destination detection: the batch file's directory is always the destination.
set "DESTINATION=%~dp0"
set "DESTINATION_PATH=%~dp0."
set "SCRIPT_PATH=%~f0"
set "RD_DEST=%DESTINATION_PATH%"

rem Filesystem detection: unknown filesystems use conservative non-NTFS flags.
set "FILESYSTEM="
for /f "delims=" %%F in ('powershell.exe -NoProfile -NonInteractive -Command "try { $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($env:RD_DEST)); [IO.DriveInfo]::new($root).DriveFormat } catch { }" 2^>nul') do if not defined FILESYSTEM set "FILESYSTEM=%%F"
if not defined FILESYSTEM set "FILESYSTEM=Unknown"
if /I "%FILESYSTEM%"=="NTFS" set "FILESYSTEM=NTFS"
if /I "%FILESYSTEM%"=="exFAT" set "FILESYSTEM=exFAT"
if /I "%FILESYSTEM%"=="FAT32" set "FILESYSTEM=FAT32"

rem Filesystem-specific copy flags: do not copy ACLs, ownership, or auditing data.
set "COPY_FLAGS=/COPY:DATX"
if /I "%FILESYSTEM%"=="NTFS" set "COPY_FLAGS=/COPY:DAT"

rem Count arguments without consuming the main batch file's argument list.
set "ITEM_COUNT=0"
call :CountArguments %*
if "%ITEM_COUNT%"=="0" goto NoArguments

echo ==================================================
echo Destination: "%DESTINATION%"
echo Filesystem: %FILESYSTEM%
echo Mode: %MODE%
echo Items: %ITEM_COUNT%
echo ==================================================
if /I "%MODE%"=="MIRROR" echo WARNING: MIRROR can delete extra files from each corresponding destination folder.
echo.

set "PROCESSED=0"
set "SUCCEEDED=0"
set "FAILED=0"

rem Argument processing: process each dropped item and continue after failures.
:ProcessNext
if "%~1"=="" goto Summary
set /a PROCESSED+=1
set "SOURCE=%~f1"
set "SOURCE_NAME=%~nx1"

if not exist "%SOURCE%" goto ItemMissing
if exist "%SOURCE%\" goto PrepareFolder
goto PrepareFile

rem Folder handling: every folder gets a child destination of the same name.
:PrepareFolder
if "%SOURCE_NAME%"=="" goto FolderHasNoName
set "TARGET=%DESTINATION%%SOURCE_NAME%"
if /I "%TARGET%"=="%SCRIPT_PATH%" goto ScriptTargetRejected

rem Relationship and mirror safeguards are shared by all folder operations.
set "RD_SOURCE=%SOURCE%"
set "RD_TARGET=%TARGET%"
call :CheckDirectoryRelationship
set "RELATION_CODE=%ERRORLEVEL%"
if not "%RELATION_CODE%"=="0" goto RelationshipRejected

echo --------------------------------------------------
echo %MODE% FOLDER
echo.
echo Source:
echo "%SOURCE%"
echo.
echo Destination:
echo "%TARGET%"
echo --------------------------------------------------

if /I "%MODE%"=="COPY" goto RunCopyFolder
if /I "%MODE%"=="MOVE" goto RunMoveFolder
goto RunMirrorFolder

rem Robocopy invocation for directory trees, including empty directories.
:RunCopyFolder
robocopy "%SOURCE%" "%TARGET%" /E %COPY_FLAGS% /DCOPY:DAT /R:2 /W:1
set "ROBOCOPY_CODE=%ERRORLEVEL%"
goto EvaluateRobocopy

:RunMoveFolder
robocopy "%SOURCE%" "%TARGET%" /E /MOVE %COPY_FLAGS% /DCOPY:DAT /R:2 /W:1
set "ROBOCOPY_CODE=%ERRORLEVEL%"
goto EvaluateRobocopy

:RunMirrorFolder
robocopy "%SOURCE%" "%TARGET%" /MIR %COPY_FLAGS% /DCOPY:DAT /R:2 /W:1
set "ROBOCOPY_CODE=%ERRORLEVEL%"
goto EvaluateRobocopy

rem File handling: copy one named file into the batch file's directory.
:PrepareFile
set "SOURCE_PARENT=%~dp1."
set "TARGET=%DESTINATION%%SOURCE_NAME%"
if /I "%SOURCE%"=="%TARGET%" goto FileIsDestination
if /I "%TARGET%"=="%SCRIPT_PATH%" goto ScriptTargetRejected

echo --------------------------------------------------
echo %MODE% FILE
echo.
echo Source:
echo "%SOURCE%"
echo.
echo Destination:
echo "%TARGET%"
echo --------------------------------------------------

if /I "%MODE%"=="MIRROR" echo Individual file supplied. Synchronizing file without directory mirror.
if /I "%MODE%"=="COPY" goto RunCopyFile
if /I "%MODE%"=="MOVE" goto RunMoveFile
goto RunMirrorFile

rem Robocopy invocation for individual files. /MOV is used instead of /MOVE.
:RunCopyFile
robocopy "%SOURCE_PARENT%" "%DESTINATION_PATH%" "%SOURCE_NAME%" %COPY_FLAGS% /DCOPY:DAT /R:2 /W:1
set "ROBOCOPY_CODE=%ERRORLEVEL%"
goto EvaluateRobocopy

:RunMoveFile
robocopy "%SOURCE_PARENT%" "%DESTINATION_PATH%" "%SOURCE_NAME%" /MOV %COPY_FLAGS% /DCOPY:DAT /R:2 /W:1
set "ROBOCOPY_CODE=%ERRORLEVEL%"
goto EvaluateRobocopy

:RunMirrorFile
robocopy "%SOURCE_PARENT%" "%DESTINATION_PATH%" "%SOURCE_NAME%" %COPY_FLAGS% /DCOPY:DAT /R:2 /W:1
set "ROBOCOPY_CODE=%ERRORLEVEL%"
goto EvaluateRobocopy

rem Robocopy return-code interpretation: codes 0-7 are nonfatal; 8+ fail.
:EvaluateRobocopy
echo.
echo Robocopy exit code: %ROBOCOPY_CODE%
if %ROBOCOPY_CODE% GEQ 8 goto RobocopyFailed
echo Result: SUCCEEDED
set /a SUCCEEDED+=1
goto AdvanceArgument

:RobocopyFailed
echo Result: FAILED
echo Failed source: "%SOURCE%"
set /a FAILED+=1
goto AdvanceArgument

:ItemMissing
echo --------------------------------------------------
echo ERROR: Source does not exist.
echo Failed source: "%SOURCE%"
echo --------------------------------------------------
set /a FAILED+=1
goto AdvanceArgument

:FolderHasNoName
echo --------------------------------------------------
echo ERROR: A filesystem root cannot be used as a dropped folder.
echo Failed source: "%SOURCE%"
echo --------------------------------------------------
set /a FAILED+=1
goto AdvanceArgument

:FileIsDestination
echo --------------------------------------------------
echo ERROR: Source file and destination file are the same.
echo Failed source: "%SOURCE%"
echo --------------------------------------------------
set /a FAILED+=1
goto AdvanceArgument

:ScriptTargetRejected
echo --------------------------------------------------
echo ERROR: This operation would overwrite the running batch file.
echo Failed source: "%SOURCE%"
echo --------------------------------------------------
set /a FAILED+=1
goto AdvanceArgument

:RelationshipRejected
echo --------------------------------------------------
if "%RELATION_CODE%"=="10" echo ERROR: Source folder and destination folder are the same.
if "%RELATION_CODE%"=="11" echo ERROR: Destination is inside the source tree and would recurse.
if "%RELATION_CODE%"=="12" echo ERROR: Source is inside the destination tree and is unsafe.
if not "%RELATION_CODE%"=="10" if not "%RELATION_CODE%"=="11" if not "%RELATION_CODE%"=="12" echo ERROR: Unable to validate the source and destination relationship safely.
echo Failed source: "%SOURCE%"
echo Intended destination: "%TARGET%"
echo --------------------------------------------------
set /a FAILED+=1
goto AdvanceArgument

:AdvanceArgument
echo.
shift
goto ProcessNext

rem Final result accounting.
:Summary
echo ==================================================
echo Transfer complete.
echo.
echo Mode: %MODE%
echo Processed: %PROCESSED%
echo Succeeded: %SUCCEEDED%
echo Failed: %FAILED%
if not "%FAILED%"=="0" echo Failed sources are identified in the output above.
echo ==================================================

set "FINAL_EXIT=0"
if not "%FAILED%"=="0" set "FINAL_EXIT=1"
if "%ALWAYS_PAUSE%"=="1" goto PauseAndExit
if not "%FAILED%"=="0" goto PauseAndExit
goto ExitBatch

:NoArguments
echo ==================================================
echo Destination: "%DESTINATION%"
echo Filesystem: %FILESYSTEM%
echo Mode: %MODE%
echo Items: 0
echo ==================================================
echo.
echo ERROR: No source items were supplied.
echo Drag one or more files or folders onto this batch file.
set "FINAL_EXIT=1"
goto PauseAndExit

:PauseAndExit
echo.
pause

:ExitBatch
endlocal & exit /b %FINAL_EXIT%

:CountArguments
if "%~1"=="" exit /b 0
set /a ITEM_COUNT+=1
shift
goto CountArguments

:CheckDirectoryRelationship
powershell.exe -NoProfile -NonInteractive -Command "$comparison = [StringComparison]::OrdinalIgnoreCase; $source = [IO.Path]::GetFullPath($env:RD_SOURCE).TrimEnd([IO.Path]::DirectorySeparatorChar); $target = [IO.Path]::GetFullPath($env:RD_TARGET).TrimEnd([IO.Path]::DirectorySeparatorChar); if ([string]::Equals($source, $target, $comparison)) { exit 10 }; if ($target.StartsWith($source + [IO.Path]::DirectorySeparatorChar, $comparison)) { exit 11 }; if ($source.StartsWith($target + [IO.Path]::DirectorySeparatorChar, $comparison)) { exit 12 }; exit 0" >nul 2>&1
set "CHECK_CODE=%ERRORLEVEL%"
exit /b %CHECK_CODE%
