# PowerShell EXIF/MP4 Rotator 🖼️ 📹

## 🌟 Overview

This PowerShell script provides a user-friendly graphical interface (GUI) built with Windows Presentation Foundation (WPF) to help you visually inspect and correct the orientation of your image files and MP4 video files. It achieves this by modifying their metadata using the powerful, free, and open-source `exiftool` by Phil Harvey.

Whether your photos are sideways or your videos upside down, this tool aims to make the correction process straightforward. You can select multiple files, preview them, apply rotations, and save the changes back to the files' metadata, ensuring that other software displays them correctly.

## ✨ Features

* **🖥️ Graphical User Interface:** Easy-to-use WPF interface.
* **📂 Batch Processing:** Select and process multiple files at once.
* **👁️ Visual Preview:**
    * Displays image thumbnails based on their current EXIF `Orientation` tag.
    * Attempts to display the first frame of MP4 videos based on their `Rotation` metadata tag (requires system codecs).
* **🔄 Interactive Rotation:** Simple buttons (↶ CCW, ↷ CW) to rotate each preview.
* **🏷️ Metadata-Based Rotation:** Changes are saved by modifying:
    * `EXIF:Orientation` tag for images.
    * `QuickTime:Rotation` (or similar) tag for MP4 videos.
* **🖱️ Drag & Drop:** Easily add files by dragging them onto the application window.
* **🗂️ Wide Format Support:**
    * **Images:** JPG, PNG, TIFF, GIF, BMP.
    * **RAW Images:** CR2, NEF, ARW, DNG, ORF, RAF, PEF, RW2, and more (thanks to `exiftool`).
    * **Videos:** MP4.
* **💾 Overwrite Control:**
    * **Safe Default:** Creates backups of original files (e.g., `filename.ext_original`).
    * **Optional Overwrite:** Choose to overwrite original files directly (no backup).

## ⚙️ Requirements

1.  **OS:** Windows Operating System (tested on Windows 10/11).
2.  **PowerShell:** Version 5.1 or later (check with `$PSVersionTable.PSVersion`).
3.  **.NET Framework:** Required for WPF (usually included with Windows).
4.  **ExifTool:** The core utility for metadata operations.
    * **MUST be installed and accessible.** The script will check if `exiftool.exe` is in your system's PATH.
5.  **Video Codecs (for MP4 Preview):** For MP4 previews to work, your system needs appropriate video codecs that WPF's `MediaElement` can use (e.g., standard Windows codecs or K-Lite Codec Pack).

## 🛠️ Installation

1.  **Download ExifTool:**
    * Go to the official ExifTool website: [https://exiftool.org/](https://exiftool.org/)
    * Download the **Windows Executable** version (e.g., `exiftool(-k).exe`).
2.  **Make ExifTool Accessible:**
    * Rename the downloaded file from `exiftool(-k).exe` to `exiftool.exe`.
    * **Option A (Recommended - Add to PATH):**
        1.  Place `exiftool.exe` in a dedicated folder (e.g., `C:\Tools\ExifTool`).
        2.  Add this folder to your system's PATH environment variable.
            * Search for "Edit the system environment variables" in Windows Search.
            * Click "Environment Variables...".
            * Under "System variables" (or "User variables" for just your account), find and select "Path", then click "Edit...".
            * Click "New" and add the full path to your `exiftool.exe` directory (e.g., `C:\Tools\ExifTool`).
            * Click OK on all dialogs. You might need to restart PowerShell or your computer for the change to take effect.
    * **Option B (Place in Script Directory):**
        * Place the renamed `exiftool.exe` in the *exact same directory* where you save the `MediaRotator.ps1` script file.
3.  **Save the Script:**
    * Copy the PowerShell script code.
    * Save it as a `.ps1` file (e.g., `MediaRotator.ps1`) in a location of your choice.

## 🚀 Usage

1.  **Run the Script:**
    * Open PowerShell.
    * Navigate to the directory where you saved `MediaRotator.ps1` (e.g., `cd C:\Path\To\Script`).
    * **Execution Policy (One-Time Setup):** If you haven't run PowerShell scripts before or encounter an execution policy error, run this command in PowerShell (you might need administrator rights):
        ```powershell
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        ```
    * Execute the script:
        ```powershell
        .\MediaRotator.ps1
        ```
2.  **Select Files:**
    * **Button:** Click the "Select Image/Video Files..." button. A dialog will appear. Select your files and click "Open".
    * **Drag & Drop:** Drag files directly from Windows Explorer onto the application window.
3.  **Preview and Rotate:**
    * The script loads supported files, reads their current orientation, and displays previews.
    * ⚠️ **Note on Previews:** For some RAW images or MP4 videos, if necessary system codecs are missing, a "[Preview N/A]" message will appear. Rotation based on metadata should still function.
    * Use the `↶` (Counter-Clockwise) and `↷` (Clockwise) buttons below each preview to adjust orientation. The preview updates instantly.
4.  **Choose Overwrite Option:**
    * At the bottom right, find the "Overwrite original files (no backup)" checkbox.
    * **Unchecked (Default & Safer):** `exiftool` creates a backup of the original file (e.g., `image.jpg` becomes `image.jpg_original`) before saving changes to a new file with the original name.
    * **Checked:** `exiftool` modifies the original file directly. **No backup is made.** Use with caution!
5.  **Save Changes:**
    * Click the "Save Changes" button.
    * The script instructs `exiftool` to write the new orientation to the metadata of modified files.
    * A confirmation message will show the results. Check the PowerShell console for detailed logs or warnings from `exiftool`.
6.  **Close:** Click the "Close" button to exit.

## 💡 How It Works

* **WPF Interface:** The GUI is defined using XAML (embedded as an XML string) and managed via PowerShell's .NET integration.
* **ExifTool Core:** The script calls `exiftool.exe` as an external command-line tool for all metadata reading and writing.
* **Preview Generation:**
    * Images: `System.Windows.Media.Imaging.BitmapImage` loads previews. `CacheOption = OnLoad` is used to release file locks.
    * MP4 Videos: `System.Windows.Controls.MediaElement` attempts to load the first frame. Success depends on system codecs.
* **State Management:** A PowerShell hashtable (`$itemData`) tracks each file's path, WPF control, current and original orientation (internally mapped to EXIF 1-8 values for consistency), and type (image/video).
* **Rotation Logic:**
    * Internal calculations use EXIF orientation values (1-8).
    * For MP4s, these are converted to/from standard rotation degrees (0, 90, 180, 270) when interacting with `exiftool`.
    * WPF `RotateTransform` and `ScaleTransform` update visual previews.

## ⚠️ Troubleshooting

* **`exiftool.exe not found`:**
    * Ensure `exiftool.exe` (renamed from `exiftool(-k).exe`) is correctly installed and either in your PATH or the script's directory.
    * Restart PowerShell or your PC after PATH modifications.
* **`Exiftool error getting/setting orientation...: Error: File not found`:**
    * Usually an issue with how the path was passed to `exiftool`. Ensure you are using a recent version of this script.
    * Verify the file path in the error message is correct and accessible.
* **Previews Not Showing / "[Preview N/A]":**
    * **RAW Images:** Likely missing Windows Imaging Component (WIC) codecs for that specific RAW format. Rotation should still work.
    * **MP4 Videos:** Likely missing DirectShow/Media Foundation codecs usable by `MediaElement`. Installing a reputable codec pack (e.g., K-Lite Codec Pack - Standard) might help. Metadata rotation via `exiftool` might still work even if the preview fails.
* **Access Denied / File In Use Errors During Save:**
    * Ensure you have write permissions for the files and their folders.
    * Make sure the files are not locked open by another application.
* **XAML Parsing Errors on Startup:**
    * Ensure the XAML block at the beginning of the script has not been accidentally modified in a way that breaks XML rules (e.t., unescaped special characters like `&` in text attributes, which should be `&amp;`).

---

## 📜 Liability Disclaimer

**This software is provided "AS IS" without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.**

**Use this script at your own risk.** It modifies file metadata, and while it includes options for backups, data loss is always a possibility with any file modification tool if not used carefully or if unexpected errors occur. **It is strongly recommended to test the script on copies of unimportant files first to understand its behavior before using it on valuable data.** The author(s) are not responsible for any loss or damage of data.

---

## ©️ MIT License

Copyright (c) 2025 Adromir (via Gemini)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
