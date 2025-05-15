# ExifTool Metadata Checker Script (PowerShell with WPF GUI)

## 1. Synopsis

This PowerShell script scans a selected folder (optionally including subdirectories) for common **image** file types. It utilizes the powerful ExifTool by Phil Harvey to check each image file for metadata errors and warnings. The script provides a graphical user interface (GUI) for initial setup and for displaying the final results, which include a list of image files with their specific issues. It also offers an option to save this report to a log file.

## 2. Features

* **GUI-Driven Setup:** Uses standard Windows dialogs for selecting the target folder and a WPF dialog for confirming subdirectory inclusion.
* **ExifTool Integration:** Leverages `exiftool.exe` with recommended validation flags (`-validate -warning -a`) to perform metadata checks on image files.
* **Console Progress:** Displays real-time progress updates in the PowerShell console using `Write-Progress`.
* **Verbose Console Output:** Prints immediate warnings to the console when a file with relevant issues is detected during the scan.
* **Targeted File Discovery:** Correctly finds specified image files in the target folder, whether or not recursion is enabled. Includes hidden files (`-Force`).
* **Specific Warning Filtering:**
    * Ignores the specific warning message containing `Not decoding some large array(s). Ignore minor errors to decode`.
    * Files that *only* contain this specific warning are excluded entirely from the final report.
    * Other errors or warnings for a file (even if the ignored warning is also present) will still be reported.
* **WPF Results Window:** Displays a detailed list of image files with their corresponding (filtered) errors/warnings in a modern WPF window with scrollable text.
* **Save Report Option:** Includes a "Save Log..." button in the results window, allowing the user to save the detailed report (including full file paths and errors) as `exif_errors.log` to a user-selected folder via a standard folder browser dialog.

## 3. Requirements

* **PowerShell:** Version 5.1 or later.
* **.NET Framework:** Version 3.0 or later (for WPF components, usually included with modern Windows versions).
* **ExifTool:** `exiftool.exe` by Phil Harvey must be installed. Download from [https://exiftool.org/](https://exiftool.org/). The script needs to be able to find `exiftool.exe`.

## 4. Configuration

Before running the script, you might need to configure the following variables near the top:

1.  **`$exiftoolPath`**:
    * If `exiftool.exe` is in your system's PATH environment variable (recommended), you can leave this as `'exiftool.exe'`.
    * Otherwise, you **must** provide the full path to the executable, for example: `'C:\Tools\ExifTool\exiftool.exe'`.
2.  **`$imageExtensions`**:
    * This array defines which image file types the script will scan.
    * You can add or remove extensions (including the leading dot, e.g., `.cr3`) as needed based on the image file types you want to check.

## 5. Usage

1.  **Save:** Save the script code to a file named, for example, `Check-Metadata.ps1`.
2.  **Configure:** Edit the script file in a text editor (like VS Code, Notepad++, or ISE) and adjust `$exiftoolPath` if necessary (see Configuration section). Review the `$imageExtensions` list.
3.  **Run:**
    * Open PowerShell.
    * Navigate to the directory where you saved the script using the `cd` command (e.g., `cd C:\Scripts`).
    * Execute the script by typing its name: `.\Check-Metadata.ps1` and pressing Enter.
4.  **Execution Policy:** If you encounter an error related to script execution being disabled, you may need to adjust PowerShell's execution policy. For a single session, you can often bypass it by running:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    .\Check-Metadata.ps1
    ```
    Alternatively, consult `Get-Help about_Execution_Policies` for more persistent options (use with caution).

## 6. Workflow

1.  **Select Folder:** A standard Windows folder browser dialog will appear. Choose the main folder containing the image files you want to scan.
2.  **Include Subdirectories?:** A WPF dialog box will ask if you want to scan folders within the selected folder. Click "Yes" or "No".
3.  **Scanning & Progress:** The script will scan for image files based on your selections and configured extensions. Progress will be shown in the PowerShell console window (`Write-Progress`). If any files are found to have relevant errors/warnings (after filtering), a `WARNING:` message indicating the filename will appear immediately in the console.
4.  **Results Window:** Once the scan is complete, if relevant errors/warnings were found, a WPF window will appear displaying:
    * A list of all image files that had relevant issues.
    * Under each filename, a list of the specific errors/warnings found for that file (excluding the filtered 'large array' warning).
5.  **Save Report (Optional):** Click the "Save Log..." button in the results window. A folder browser dialog will appear. Select the folder where you want to save the report. A file named `exif_errors.log` containing the full report details will be saved there.
6.  **Close:** Click the "Close" button in the results window or press Enter/Esc.
7.  **Finish:** The script will print a final message in the console, and you can press Enter to exit.

## 7. Output

* **Console:** Shows initial setup messages, real-time progress, immediate warnings for files with issues, and a final summary message indicating the number of image files found with relevant issues.
* **Results GUI Window:** Provides a scrollable view of the full image file paths and their associated, filtered error/warning messages.
* **Saved Log File (`exif_errors.log`):** If saved, this text file contains:
    * A header with the report title (indicating Images Only), timestamp, scanned folder, and recursion status.
    * A note about the specific warning pattern that was filtered out.
    * A list of image files (full path) with issues.
    * Under each file, the specific (filtered) errors/warnings found, indented with ` - `.

## 8. Filtering Logic

The script is configured to ignore one specific, often benign, warning from ExifTool related to large data arrays within metadata profiles:

* **Ignored Pattern:** `*Not decoding some large array(s). Ignore minor errors to decode*`

This means:
* If an image file's *only* reported issue matches this pattern (including variations like `[Minor]` prefix or `[xN]` suffix), the file will **not** be included in the final report or the GUI window.
* If an image file has this warning *plus* other errors or warnings, the file **will** be included in the report, but this specific warning message will be filtered out from the list shown for that file.

## 9. Troubleshooting

* **"ExifTool not found" error:** Ensure the `$exiftoolPath` variable in the script points to the correct location of `exiftool.exe` or that the directory containing `exiftool.exe` is in your system's PATH environment variable.
* **"No image files found" warning:**
    * Verify that the image files exist directly in the selected folder (if not recursing).
    * Ensure the file extensions (e.g., `.dng`, `.cr2`) are correctly listed (including the dot) in the `$imageExtensions` array in the script configuration.
    * Check folder permissions if PowerShell might be blocked from reading the contents.
* **GUI Errors:** Ensure you have .NET Framework 3.0 or later installed (usually standard on modern Windows).

## 10. Disclaimer

This script is provided as-is. While designed to help identify potential metadata issues in image files, it relies on ExifTool's output and interpretation. Always back up important files before performing any metadata modifications.
