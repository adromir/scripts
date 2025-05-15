# PowerShell XMP Sidecar Creator

## Overview

This PowerShell script provides a graphical user interface (GUI) built with Windows Presentation Foundation (WPF) to automate the creation of XMP sidecar files for various media files (images, RAW images, videos) located within a specified folder. It leverages the powerful `ExifTool` by Phil Harvey to extract metadata from the source media file and write it into a corresponding `.xmp` file.

The script is designed to be user-friendly, offering features like subfolder scanning and automatic checking for the required `ExifTool` dependency, even offering to install it via `winget` if it's missing.

## Features

* **Graphical User Interface (WPF):** Easy-to-use interface for selecting folders and options.
* **Folder Selection:** Browse and select the target folder containing media files.
* **Recursive Scan:** Option to include subfolders in the scan.
* **ExifTool Dependency Check:** Automatically checks if `ExifTool` is installed and accessible in the system's PATH.
* **Automatic ExifTool Installation (Optional):** Prompts the user to install `ExifTool` using `winget` if it's not found.
* **Existing XMP Handling:** Automatically deletes any pre-existing `.xmp` file for a media file before generating a new one, ensuring fresh metadata extraction.
* **Broad Media Support:** Processes common image, RAW, and video file formats (configurable in the script).
* **Status Logging:** Displays real-time progress and status messages within the GUI.
* **Error Handling:** Reports errors during file processing or ExifTool execution.

## Requirements

* **Operating System:** Windows (tested on Windows 10/11)
* **PowerShell:** Version 5.1 or later (usually included with modern Windows).
* **.NET Framework:** Version 4.5 or later (required for WPF).
* **ExifTool:** Must be installed and accessible via the system's PATH environment variable. The script can attempt to install it using `winget` if missing.
    * You can download ExifTool manually from: [https://exiftool.org/](https://exiftool.org/)
* **Winget:** Required if you want the script to automatically install ExifTool. (Included in modern Windows versions).

## Installation / Setup

1.  **Save the Script:** Download or save the script code as a `.ps1` file (e.g., `Create-XMP.ps1`).
2.  **Ensure ExifTool is Installed:**
    * Run the script. It will automatically check for `ExifTool`.
    * If `ExifTool` is not found, the script will prompt you to install it via `winget`. Click **Yes** to attempt installation (requires `winget` and potentially Administrator privileges). You will need to restart the script after a successful installation.
    * Alternatively, download `ExifTool` from [https://exiftool.org/](https://exiftool.org/), extract it, and rename `exiftool(-k).exe` to `exiftool.exe`. Ensure the directory containing `exiftool.exe` is added to your system's PATH environment variable.

## Usage

1.  **Run the Script:**
    * Open PowerShell.
    * Navigate to the directory where you saved the script.
    * Execute the script: `.\Create-XMP.ps1`
    * *Note:* If you encounter PowerShell execution policy restrictions, you might need to temporarily bypass it for the current process by running: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` before executing the script.

2.  **Select Folder:**
    * The script's GUI window will appear.
    * Click the **Browse...** button.
    * Navigate to and select the root folder containing the media files you want to process.

3.  **Choose Options:**
    * Check the **Include Subfolders** box if you want the script to process files in all subdirectories within the selected folder.

4.  **Start Processing:**
    * Click the **Create XMP Files** button.

5.  **Monitor Progress:**
    * The text box at the bottom of the window will display status messages, including which files are being processed, any existing XMP files being deleted, and the results of the ExifTool operation for each file.
    * Any errors encountered during the process will also be logged here.

6.  **Completion:**
    * Once the script has processed all found media files, a summary message indicating the total files processed and any errors will be displayed in the status box.
    * The `.xmp` sidecar files will be created in the same directories as their corresponding media files.

## Supported File Types

By default, the script looks for files with the following extensions:

* **Images:** `.jpg`, `.jpeg`, `.png`, `.gif`, `.tiff`, `.tif`
* **RAW Images:** `.cr2`, `.cr3`, `.nef`, `.arw`, `.orf`, `.rw2`, `.raf`, `.dng`
* **Videos:** `.mov`, `.mp4`, `.avi`, `.mkv`, `.mts`, `.m2ts`

This list can be modified by editing the `$mediaExtensions` array within the script file itself.

## Notes

* The script uses the command `exiftool -o <XMP_File_Path> <Media_File_Path>` to generate the XMP file. This command instructs ExifTool to create a new output file (`-o`) containing the metadata from the source media file, formatted as XMP.
* Ensure you have sufficient permissions to read the media files and write `.xmp` files in the target directories.
* Processing a large number of files or very large files may take a significant amount of time.
* If ExifTool fails for a specific file, an error message will be logged, and the script will attempt to continue with the next file.

## License

This script is provided as-is. Please review the code and test it in a non-critical environment before using it on valuable data. (Author information can be found in the script's notes section).
