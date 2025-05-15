# PowerShell RAW Preview Updater Script

## Overview

This PowerShell script provides a graphical user interface (GUI) to process RAW image files within a selected folder (and optionally subfolders). Its primary goal is to ensure RAW files have an appropriate, up-to-date preview image embedded.

The script employs different strategies based on the file type:

* **For `.DNG` files:** It utilizes the **Adobe DNG Converter** to re-save the file. This process inherently updates the preview according to the specified settings (uncompressed, Camera Raw 16.0+ compatibility, full-size preview).
* **For other supported RAW files (e.g., `.CR2`, `.NEF`, `.ARW`):** It uses **ImageMagick** (which often relies on **dcraw** or **LibRaw**) to generate a new, full-size JPEG preview directly from the RAW data. Basic enhancements (`-normalize`, `-sharpen`) are applied during generation. This generated JPEG is then embedded back into the original RAW file using the `PreviewImage` tag via **ExifTool**.

## Features

* **GUI:** User-friendly WPF interface for selecting the target folder and options.
* **Subfolder Processing:** Option to include files in subdirectories.
* **Backup Option:** Choice to create backups (`.original` for ExifTool, `_1.dng` for DNG Converter) or overwrite original files.
* **Conditional Processing:** Automatically uses the appropriate tool based on file type (`.DNG` vs. other RAW).
* **Preview Generation:** Creates new, enhanced JPEG previews for non-DNG RAW files using ImageMagick.
* **DNG Re-saving:** Updates DNG files using Adobe DNG Converter with specific compatibility and preview settings.
* **Dependency Management:**
    * Checks for required external tools (ExifTool, ImageMagick, dcraw, Adobe DNG Converter).
    * Loads/saves tool paths from/to a `tool_paths.json` configuration file in the script's directory for persistence.
    * Provides a validation GUI to confirm/locate tool paths manually.
    * Offers to install missing tools automatically using `winget` (requires winget to be installed and functional).
* **Configurable:** Tool paths and RAW extensions can be adjusted within the script or via the `tool_paths.json` file.
* **Progress & Logging:** Displays progress in the console and shows output/errors from external tools.

## Prerequisites

1.  **PowerShell:** Version 3.0 or higher.
2.  **Winget:** Required if you want the script to attempt automatic installation of missing dependencies.
3.  **ExifTool:** (`exiftool.exe`) Required for embedding previews in non-DNG files.
    * *Installation:* Can be installed manually from the [ExifTool website](https://exiftool.org/) or via `winget` (the script will prompt if missing). Ensure it's accessible via the system PATH or specify the full path in the validation dialog/config file.
4.  **ImageMagick:** (`magick.exe`) Required for generating previews for non-DNG files.
    * *Installation:* Can be installed manually from the [ImageMagick website](https://imagemagick.org/) or via `winget` (the script will prompt if missing).
    * **Important:** Your ImageMagick installation **must include RAW delegates** (like `dcraw` or `LibRaw`) to decode your specific RAW file formats. The winget installation might *not* include these by default. Verify by running `magick -list format` or test converting a RAW file manually. Ensure `magick.exe` is accessible via the system PATH or specify the full path.
5.  **dcraw:** (`dcraw.exe`) Often required by ImageMagick as a RAW delegate.
    * *Installation:* Can be installed manually or via `winget` (the script will prompt if missing). Ensure it's accessible via the system PATH or specify the full path.
6.  **Adobe DNG Converter:** Required *only* if processing `.DNG` files.
    * *Installation:* Can be installed manually from the [Adobe website](https://helpx.adobe.com/camera-raw/using/adobe-dng-converter.html) or via `winget` (the script will prompt if missing *when a .DNG file is encountered*). The script checks the default installation path (`C:\Program Files\Adobe\Adobe DNG Converter\Adobe DNG Converter.exe`) but allows specifying a different path in the validation dialog/config file.

## How to Use

1.  **Save:** Save the script to a file (e.g., `update-previews.ps1`).
2.  **Run:** Open PowerShell, navigate to the directory where you saved the file, and execute it:
    ```powershell
    .\update-previews.ps1
    ```
    * Optionally, run with `-Verbose` for more detailed output:
        ```powershell
        .\update-previews.ps1 -Verbose
        ```
3.  **Validate Tool Paths:**
    * A dialog will appear showing the detected/configured paths for the required tools (ExifTool, ImageMagick, dcraw, DNG Converter).
    * It will indicate if each tool is "Found" or "Not Found".
    * **Browse:** Use the "..." buttons to manually locate any executables if the automatically detected/configured path is incorrect.
    * **Check All Paths:** Click this to re-validate all paths entered in the text boxes.
    * **Install Missing (Winget):** Click this to attempt installing any tools marked as "Not Found" using `winget`. After installation attempts, click "Check All Paths" again.
    * **Save Configuration:** Click this to save the currently displayed paths to `tool_paths.json` in the script's directory for future use.
    * **Continue:** This button is enabled only when ExifTool, ImageMagick, and dcraw are found. Click it to proceed. (DNG Converter is only strictly required if a `.DNG` file is later encountered).
    * **Cancel:** Exit the script.
4.  **Select Folder & Options:**
    * The main GUI appears. Click "Browse..." to select the root folder containing your RAW files.
    * Check "Include Subfolders" if desired.
    * Check "Create Backups" if you want the script to preserve original files (`_1.dng` for DNG conversions, `.original` for ExifTool operations). Leave unchecked to modify files in place.
    * Click "OK".
5.  **Processing:** The script will iterate through the files:
    * `.DNG` files will be processed by Adobe DNG Converter.
    * Other RAW files will have previews generated by ImageMagick and embedded by ExifTool.
    * Progress and tool output will be displayed in the PowerShell console.

## Configuration File (`tool_paths.json`)

The script automatically creates/uses a `tool_paths.json` file in the same directory as the script itself. This file stores the paths to the external tools. You can manually edit this file or use the "Save Configuration" button in the validation dialog.

Example `tool_paths.json`:

```json
{
  "ExifTool": "exiftool.exe",
  "ImageMagick": "C:\\Program Files\\ImageMagick-7.1.0-Q16-HDRI\\magick.exe",
  "Dcraw": "dcraw.exe",
  "DngConverter": "C:\\Program Files\\Adobe\\Adobe DNG Converter\\Adobe DNG Converter.exe"
}
If a tool is expected to be found in the system PATH, just list its executable name (e.g., exiftool.exe). Otherwise, provide the full path.Notes & TroubleshootingImageMagick RAW Delegates: The most common issue with the ImageMagick step is missing RAW delegates. Ensure your ImageMagick installation can actually decode the RAW formats you need. You might need to install dcraw separately or reinstall ImageMagick with delegate libraries included.Execution Policy: You may need to adjust your PowerShell execution policy to run scripts (e.g., Set-ExecutionPolicy RemoteSigned). Run PowerShell as Administrator to change the policy.Winget: The winget installation requires an internet connection and appropriate permissions.Paths with Spaces: The script attempts to handle tool paths containing spaces correctly, but ensure paths saved in