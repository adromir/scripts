# ExifTool Error Fixer PowerShell Script

## Overview

This PowerShell script provides a graphical user interface (GUI) to help identify and attempt to fix metadata errors in image files using the powerful ExifTool command-line utility by Phil Harvey. It offers two main modes of operation:

1.  **Log File Mode:** Parses a pre-generated ExifTool validation report (`exif_errors.log` or similar) and attempts to fix the files listed with errors in that report, using specific strategies based on the error types found.
2.  **Folder Scan Mode:** Scans a selected folder (optionally including subfolders) for common image types, runs an ExifTool validation check (`exiftool -m -validate -warning -error -a FILE`) on each file, parses the output for errors/warnings, and attempts to fix files where issues are detected.

The script aims to correct common issues like misplaced tags (`Wrong IFD` errors), problematic MakerNotes, outdated IPTC digests, malformed values (like incorrect boolean capitalization), and missing required tags by applying targeted ExifTool commands sequentially when necessary.

## Features

* **GUI Prompts:** User-friendly dialog boxes for selecting input method, files/folders, and processing options.
* **Two Input Modes:** Process based on a detailed error log or scan folders directly.
* **Selective Processing (Folder Scan):** Validates files before attempting fixes, avoiding unnecessary processing of healthy files.
* **Sophisticated Fix Strategies:**
    * Identifies specific error categories: MakerNotes, IPTC Digest, Missing Required Tags, and Other Structural/Format errors (like `Wrong IFD`, boolean capitalization, bad offsets).
    * Applies fixes in a logical sequence for maximum effectiveness:
        1.  **General Rebuild (`-all= -tagsfromfile @ -all -unsafe`):** Performed FIRST if "Other Structural" errors exist OR if *only* "Missing Required Tag" errors exist.
        2.  **MakerNote Removal (`-makernotes:all=`):** Performed SECOND only if MakerNote errors exist (depends on the success of the General Rebuild step, if it ran).
        3.  **IPTCDigest Update (`-IPTCDigest=new`):** Performed LAST only if IPTCDigest errors exist (depends on the success of the preceding step, if any).
    * If a step in the sequence fails, subsequent steps for that file are skipped.
* **Flexible Fixing Options:**
    * Choose automatic fixing for all applicable files.
    * Choose per-file confirmation before applying fixes.
* **Backup Control:**
    * Option to overwrite original files (use with caution!).
    * Option to let ExifTool create backups (default behavior, adds `_original` suffix).
* **Progress Reporting:** Displays a progress bar and console output showing the current file and action (validation or fixing steps).
* **Detailed Summary:** Provides a summary of processed files, successes, failures, and skipped files (including reasons like passing validation or user skips).

## Requirements

* **Windows Operating System:** With PowerShell 5.1 or later.
* **.NET Framework:** Required for the GUI elements (`System.Windows.Forms`). Usually included with Windows.
* **ExifTool:** The command-line utility by Phil Harvey must be installed.
    * Download from the [Official ExifTool Website](https://exiftool.org/).
    * The script assumes `exiftool.exe` (or the renamed `exiftool`) is accessible via the system's `PATH` environment variable. Alternatively, modify the `$ExifToolPath` variable within the script.

## Installation

1.  **Install ExifTool:** Download ExifTool for Windows. It's often recommended to rename the downloaded `exiftool(-k).exe` to `exiftool.exe` and place it in a directory included in your system's `PATH` (like `C:\Windows`) or a dedicated tools directory that you add to the `PATH`.
2.  **Save the Script:** Save the PowerShell script code to a file named `FixExifErrors.ps1` (or any other `.ps1` name) on your computer.

## Usage

1.  **Open PowerShell:** You can right-click in the folder where you saved the script and choose "Open PowerShell window here" or "Open in Windows Terminal".
2.  **Execution Policy:** If you haven't run PowerShell scripts before, you might need to adjust the execution policy. You can check with `Get-ExecutionPolicy`. If it's `Restricted`, you may need to set it to `RemoteSigned` or `Unrestricted` to run local scripts. Run PowerShell as Administrator and execute:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
    (Using `CurrentUser` scope is often safer than `LocalMachine`). Answer 'Y' if prompted. **Understand the security implications before changing the execution policy.**
3.  **Run the Script:** Navigate to the directory containing the script (if not already there) using the `cd` command. Then run the script:
    ```powershell
    .\FixExifErrors.ps1
    ```
4.  **Follow GUI Prompts:**
    * **Select Input Method:**
        * Choose **Yes** to load an existing ExifTool error log file. You will be prompted to select the `.log` file.
        * Choose **No** to scan a folder. You will be prompted to select the folder.
    * **Folder Scan Options (if No chosen above):**
        * **Select Folder:** Choose the parent folder containing the images.
        * **Include Subfolders?:** Choose **Yes** to process images in subdirectories, **No** to only process images directly within the selected folder.
    * **Fixing Mode:**
        * Choose **Yes** to automatically attempt fixes on all files identified as needing them (based on log errors or validation results).
        * Choose **No** to be prompted with a Yes/No dialog for *each* file before the script attempts a fix.
    * **Backup Options:**
        * Choose **Yes** to add the `-overwrite_original` flag to ExifTool commands. **This permanently modifies your original files with NO backup created by ExifTool.** Use with extreme caution and only if you have other backups.
        * Choose **No** (Recommended) to let ExifTool perform its default backup behavior (creating a copy of the original file with `_original` appended to the filename) before modifying the file.
        * Choose **Cancel** to abort the script.

5.  **Monitor Progress:** The script will output progress and status updates to the PowerShell console window. If scanning a folder, the validation step will run first. The fixing phase will show which steps (General Rebuild, MakerNote Removal, IPTCDigest Update) are being attempted for each file based on the detected errors.
6.  **Review Summary:** Once finished, a detailed summary of actions taken, successes, failures, and skipped files (with reasons) will be displayed in the console.

## Input Methods & Logic Details

### Log File Mode

* Reads the specified log file (typically generated by `exiftool -m -validate -warning -error -a DIR > exif_errors.log`).
* Parses lines starting with `File:` to get file paths and subsequent lines starting with ` - ` as error descriptions for that file.
* Identifies files that have *any* errors listed.
* For each file with errors, it classifies the errors into "MakerNote Issues", "IPTCDigest Issues", "Missing Required Tags", and "Other Structural Errors".
* Applies the specific fix strategy sequentially:
    1.  General Rebuild (if Other Structural errors OR *only* Missing Required errors exist).
    2.  MakerNote Removal (if MakerNote errors exist, depends on step 1 success).
    3.  IPTCDigest Update (if IPTC Digest errors exist, depends on step 2/1 success).

### Folder Scan Mode

* Gets a list of image files based on `$ImageExtensions` in the selected folder (and subfolders if chosen).
* For *each* found file, it runs `exiftool -m -validate -warning -error -a FILE`.
* It parses the output of the validation command, looking for lines starting with `Warning:` or `Error:`.
* If any such lines are found, the file is initially flagged, and the extracted error messages are stored.
* Files passing validation with no warnings/errors are added to a "Skipped (Validation OK)" list.
* For files that had validation warnings/errors, it classifies the errors just like in Log File Mode ("MakerNote Issues", "IPTCDigest Issues", "Missing Required Tags", "Other Structural Errors").
* The script then proceeds to the fixing phase (`Process-Files`) using the list of files that had errors and their collected error messages, applying the *same* sequential fixing logic as in Log File Mode.

## Configuration Variables

These variables are located near the top of the script and can be adjusted if needed:

* `$ExifToolPath`: Path to the `exiftool` executable. Defaults to `"exiftool"`, assuming it's in the system PATH. Change to the full path (e.g., `"C:\Tools\exiftool.exe"`) if necessary.
* `$ImageExtensions`: An array of file extensions (with wildcards) used when scanning folders. Add or remove types as needed.
* `$MakerNoteErrorPatterns`: An array of string patterns (using `-like` wildcards) used to identify MakerNote-related errors.
* `$IPTCDigestErrorPattern`: String pattern for the IPTC Digest error.
* `$MissingRequiredPatterns`: Array of patterns for "Missing required tag" errors. These *will* trigger a general rebuild if they are the *only* errors found.
* `$OtherStructuralErrorPatterns`: Array of patterns for errors that trigger the general metadata rebuild (`-all=...`) as the first step.

## Output

* **Console:** Provides real-time feedback on the current operation (parsing, validating, fixing), file being processed, ExifTool commands being executed, and success/failure status for each step. Warnings and errors are highlighted.
* **Progress Bar:** Shows the progress through the current major phase (validation or fixing).
* **Final Summary:** Reports:
    * Input source (log file path or folder scan details).
    * Total files identified/scanned.
    * Number of files skipped due to passing validation (in Folder Scan mode).
    * Number of files identified with errors/warnings.
    * Number of files where fixes were attempted (i.e., had actionable errors).
    * Number of files skipped by the user during the fixing phase.
    * Number of successful file-level fix operations (meaning all required steps for that file succeeded).
    * Number of failed file-level fix operations (with details about the failing step).
    * A combined list of all skipped files with reasons (Validation OK, User Skip, No Actionable Errors Found, etc.).
    * The chosen backup option.

## Important Notes & Warnings

* **BACKUP YOUR FILES!** Before running this script, especially if choosing the "Overwrite originals" option, ensure you have reliable backups of your photos. Metadata operations can sometimes have unintended consequences. The default behavior (creating `_original` files) is safer.
* **Test on Copies:** It is highly recommended to test the script on a *copy* of a small subset of your files first to ensure it behaves as expected.
* **ExifTool Complexity:** ExifTool is extremely powerful but complex. This script uses common commands for fixing typical structural issues, MakerNote problems, IPTC digest mismatches, and missing tags. It may not fix *all* possible types of metadata corruption. Some errors might require manual intervention or different ExifTool commands.
* **Review Results:** After running the script, check the processed files and the console output, especially any reported failures or warnings, to verify the results. Check the `_original` backup files if created.
* **Performance:** Validating and fixing many large image files can take a significant amount of time. Be patient.

## Disclaimer

This script is provided "as is" without warranty of any kind. The user assumes all risk associated with using this script. Always back up your data before running tools that modify files.
