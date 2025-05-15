# PowerShell XMP Cleaner Script (`CleanXMP.ps1`)

## Purpose

This PowerShell script is designed to recursively search through a specified folder and its subfolders for Adobe Extensible Metadata Platform (XMP) files (`.xmp`). It then reads each XMP file, removes all occurrences of a specific predefined string (default: `st|`), and saves the modified content back to the original file using UTF-8 encoding.

This is particularly useful for cleaning up hierarchical keywords or other metadata entries in XMP sidecar files exported from software like Adobe Lightroom where unwanted prefixes might be present.

## Features

* **Graphical Folder Selection:** Uses a standard Windows dialog to easily select the target root folder.
* **Recursive Search:** Processes XMP files in the selected folder and all nested subfolders.
* **String Removal:** Removes all instances of a specific target string (`st|` by default) within the content of each XMP file.
* **In-Place Modification:** Overwrites the original XMP files with the cleaned content.
* **Progress Bar:** Displays a progress bar in the PowerShell console showing the status of the file processing.
* **Verbose Output:** Prints the full path of each file being processed and indicates whether it was modified.
* **UTF-8 Encoding:** Reads and writes files using UTF-8 encoding, which is standard for XMP.
* **Error Handling:** Includes basic error handling for file access and processing issues.

## Requirements

* **Operating System:** Windows
* **PowerShell Version:** 5.1 or later (usually included in Windows 10 and later). You can check your version by running `$PSVersionTable.PSVersion` in PowerShell.
* **.NET Framework:** Required for the `System.Windows.Forms` assembly used by the folder browser dialog. This is typically pre-installed on modern Windows systems.

## How to Use

1.  **Save the Script:** Save the PowerShell script code (provided separately) to a file with a `.ps1` extension (e.g., `CleanXMP.ps1`).
2.  **Run the Script:** You have a few options:
    * **Easiest:** Right-click the `CleanXMP.ps1` file in Windows Explorer and select "Run with PowerShell".
    * **Via PowerShell Console:**
        * Open PowerShell (you might need to "Run as Administrator" depending on your system's execution policy and file permissions).
        * Navigate to the directory where you saved the script using the `cd` command (e.g., `cd C:\Users\YourUser\Scripts`).
        * Execute the script by typing `.\CleanXMP.ps1` and pressing Enter.
3.  **Select Folder:** A dialog box titled "Select the root folder containing your XMP files" will appear. Browse to the parent folder containing the XMP files you want to process and click "OK".
4.  **Monitor Progress:** The script will start scanning the selected folder and its subfolders. The PowerShell console will display:
    * The full path of each `.xmp` file being processed.
    * A message indicating if the file was modified.
    * A progress bar showing the overall completion percentage.
5.  **Completion:** Once all files are processed, a summary message will show the total number of files scanned and modified. If running in a standard console, you may be prompted to "Press Enter to exit".

## Configuration

You can modify the following variables at the beginning of the script if needed:

* `$StringToReplace = 'st|'`: Change `'st|'` to the exact string you want to remove from the XMP files.
* `$ReplacementString = ''`: This is what `$StringToReplace` will be replaced with. An empty string (`''`) effectively deletes the target string. You could change this if you wanted to replace `st|` with something else instead of removing it.
* `$FileFilter = '*.xmp'`: Defines the file pattern to search for. Keep as `'*.xmp'` unless you need to target different file types.
* `$Encoding = [System.Text.Encoding]::UTF8`: Specifies the character encoding for reading and writing files. UTF-8 is generally recommended for XMP.

## Important Notes

* **BACKUP YOUR FILES!** This script modifies files *in-place*. It is **strongly recommended** to create a backup of your XMP files or the entire folder structure *before* running the script. There is no undo function.
* **PowerShell Execution Policy:** If you encounter an error stating that scripts are disabled on your system, you may need to adjust your PowerShell execution policy.
    * Check the current policy: `Get-ExecutionPolicy -List`
    * To allow locally saved scripts to run for the current user, you can use: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`. You may need to run PowerShell as Administrator to change policies. Understand the security implications before changing execution policies.
* **Case Sensitivity:** The string replacement performed by `-replace` is case-insensitive by default in PowerShell. If you need case-sensitive replacement, the script would need modification. However, for the specific `st|` case, this is unlikely to be an issue.

## Troubleshooting

* **"Scripts are disabled" Error:** See the "PowerShell Execution Policy" note above.
* **Access Denied Errors:** Ensure you have read and write permissions for the folder and files you are trying to process. You might need to run PowerShell as Administrator.
* **Dialog Box Doesn't Appear:** Ensure `.NET Framework` is properly installed and the `System.Windows.Forms` assembly can be loaded. This is rare on modern systems.
* **Incorrect Encoding:** If files appear corrupted after processing, double-check if your original XMP files use an encoding other than UTF-8 and adjust the `$Encoding` variable accordingly (e.g., `[System.Text.Encoding]::Default` for the system's ANSI encoding, but UTF-8 is strongly preferred for XMP).

## License

This script is provided as-is. Use at your own risk. The author(s) are not responsible for any data loss or damage resulting from its use. Always back up your data before running scripts that modify files.
