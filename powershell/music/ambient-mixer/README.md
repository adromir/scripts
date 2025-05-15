# 💾 Ambient Mixer Downloader PowerShell Script

A user-friendly PowerShell script with a WPF GUI to download complete ambient sound mixes (XML configuration, audio files, preview image) from [ambient-mixer.com](https://ambient-mixer.com/).

---

## 📜 Description

This script provides a graphical interface for users to easily back up their favorite ambient mixes from ambient-mixer.com. Simply provide the URL of the mix page and select a destination folder. The script intelligently extracts the mix details, downloads all necessary components, and organizes them locally for offline use or integration with other projects.

It automatically determines the mix's name and description, creates a dedicated folder, downloads the core XML configuration, the preview image, and all associated audio tracks. It then cleans up the XML file, updates audio paths to point to the local files, and adds useful metadata like the mix title and description directly into the XML.

---

## ✨ Features

* **🖥️ Graphical User Interface (WPF):** Easy-to-use interface for entering the URL and selecting the destination.
* **🏷️ Smart Name & Description Extraction:** Automatically fetches the mix title (from H1/Title tags) and description (from `og:description` meta tag).
* **📁 Organized Output:** Creates a dedicated subfolder for each mix, named after the mix title (sanitized).
* **🎵 Audio Downloading:** Downloads all 8 audio tracks associated with the mix into a structured `audio` subfolder.
* **🖼️ Image Downloading:** Downloads the mix's preview/cover image (from `og:image` meta tag) as `cover.jpg` (or other extension).
* **📝 XML Processing:**
    * Downloads the core XML configuration file.
    * **Renames XML:** Saves the XML file using the sanitized mix title (e.g., `the-shire.xml`).
    * **Cleans XML:** Removes unnecessary session/template ID tags (`<id_template>`, `<id_session_user>`, `<id_session_player>`).
    * **Adds Metadata:** Inserts `<title>` and `<description>` tags into the XML.
    * **Updates Paths:** Modifies audio file paths (`<url_audio>`) within the XML to point to the locally downloaded files (e.g., `audio/rain.mp3`).
* **⚙️ Default Folder Configuration:** Remembers your last used download folder via a `config.json` file stored alongside the script.
* **🔒 TLS 1.2 Enabled:** Includes necessary configuration to work with modern web security protocols.
* **⚠️ Enhanced Error Reporting:** Provides more detailed feedback if downloads fail (e.g., HTTP status codes).
* **✅ Input Validation:** Checks for valid URL format and destination folder selection.

---

## ⚙️ Requirements

* **Operating System:** Windows (tested on Windows 10/11)
* **.NET Framework:** Version 4.5 or later (usually included with modern Windows versions).
* **PowerShell:** Version 3.0 or later (for `ConvertTo-Json`/`ConvertFrom-Json`). Usually included with modern Windows versions.
* **Internet Connection:** Required to download the mix data from ambient-mixer.com.

---

## 🚀 Installation & Setup

1.  **Save the Script:** Save the PowerShell script code to a file named `AmbientDownloader.ps1` (or any name you prefer with a `.ps1` extension).
2.  **Unblock (If Necessary):** Depending on your system's execution policy, you might need to unblock the script file.
    * Right-click the `.ps1` file.
    * Select "Properties".
    * On the "General" tab, if you see an "Unblock" checkbox or button near the bottom, check it or click it, then click "Apply" and "OK".
3.  **Execution Policy (If Necessary):** You might need to adjust PowerShell's execution policy to run local scripts. You can do this temporarily for the current session:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    ```
    Or, for the current user (less secure, use with caution):
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
    *Run PowerShell as Administrator if changing policies outside the `Process` scope.*

---

## 🖱️ Usage

1.  **Run the Script:**
    * Open PowerShell.
    * Navigate to the directory where you saved `AmbientDownloader.ps1` using the `cd` command (e.g., `cd C:\Scripts`).
    * Run the script by typing `.\AmbientDownloader.ps1` and pressing Enter.
    * Alternatively, right-click the `.ps1` file and choose "Run with PowerShell".

2.  **Enter Mix URL:** The "Ambient Mixer Downloader" window will appear. Paste the full URL of the *mix page* you want to download into the "Ambient Mix URL" text box.
    * Example: `https://ambient-mixer.com/s/the-shire`
    * *(Do not use the direct XML URL, as the script needs the page URL to fetch the name, description, and image).*

3.  **Select Destination Folder:**
    * Click the "Browse..." button.
    * Navigate to the main folder where you want the mix's subfolder to be created (e.g., `D:\MyMixes`).
    * Click "OK" in the folder browser dialog.
    * The selected path will appear in the "Destination Folder" text box.

4.  **Set Default Folder (Optional):**
    * If you want the script to remember the selected "Destination Folder" for the next time you run it, check the "Set as Default Folder" checkbox.

5.  **Start Download:** Click the "OK" button.

6.  **Monitor Progress:** The script will output progress messages to the PowerShell console window behind the GUI. The GUI window will close once you click "OK".

7.  **Completion:** Once finished, you'll see "Script finished." in the console. Check your selected destination folder for the newly created mix subfolder.

---

## 💾 Configuration (`config.json`)

* When you check the "Set as Default Folder" box and click "OK", the script creates (or updates) a file named `config.json` in the *same directory* as the `AmbientDownloader.ps1` script.
* This file stores the path you selected, so it's automatically filled in the next time you run the script.
* **Example `config.json` content:**
    ```json
    {
      "defaultFolderPath": "D:\\MyMixes"
    }
    ```
* You can manually edit this file or delete it to remove the default setting. Ensure the path uses double backslashes (`\\`) if editing manually.

---

## 📁 Output Structure

For a mix named "The Shire" downloaded to `D:\MyMixes`, the output will be structured like this:

D:\MyMixes└── The-Shire\              <-- Folder named after sanitized mix title├── audio\              <-- Subfolder for audio files│   ├── birds-chirping.mp3│   ├── gentle-stream.ogg│   ├── distant-laughter.wav│   └── ... (other audio files, named after sanitized <name_audio>)├── cover.jpg           <-- Preview image (or .png, etc.)└── the-shire.xml       <-- XML configuration file, named after sanitized mix title
**The `the-shire.xml` file will contain:**
* Updated `<url_audio>` tags pointing to files in the `audio/` folder (e.g., `<url_audio>audio/birds-chirping.mp3</url_audio>`).
* A `<title>The Shire</title>` tag.
* A `<description>...</description>` tag with the fetched description.
* No `<id_template>`, `<id_session_user>`, or `<id_session_player>` tags.

---

## ❓ Troubleshooting

* **Download Failures / TLS Errors:**
    * The script attempts to force TLS 1.2. If downloads still fail, ensure your Windows version has up-to-date .NET Framework components and Windows updates installed, as these provide the underlying TLS support.
    * Check the console output for specific error messages (e.g., HTTP 404 Not Found, 403 Forbidden, connection errors). A 404 might mean the audio file URL in the XML is broken on the website itself.
* **Script Won't Run / Execution Policy Errors:** See the "Installation & Setup" section regarding `Set-ExecutionPolicy` and unblocking the file.
* **GUI Doesn't Appear:** Ensure you have .NET Framework installed. Check the console for errors related to `PresentationFramework` or `XamlReader`.
* **Incorrect Mix Name/Description/Image:** The script relies on the structure of the ambient-mixer.com page (H1, title, meta tags). If the website changes its structure significantly, the script might need updating. It uses fallbacks (like using the template ID for the name) if primary methods fail.
* **Invalid Characters in Filenames:** The script sanitizes folder and file names, replacing invalid characters. If you encounter issues, check the sanitized names created by the script. `Sanitize-FolderName` replaces invalid chars with `_`, while `Sanitize-XmlFilename` replaces spaces with `-` and removes most other invalid chars.
* **Partial Downloads:** The script attempts to remove partially downloaded files on error, but manual cleanup might occasionally be needed if the script is interrupted abruptly.

---

Happy Mixing! 🎉
