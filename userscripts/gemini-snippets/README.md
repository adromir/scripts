# Google Gemini Mod (Toolbar, Folders & Download) - UserScript 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Greasy Fork](https://img.shields.io/badge/Greasy%20Fork-Install-brightgreen)](https://greasyfork.org/scripts/536192-google-gemini-mod-toolbar-download) [![OpenUserJS](https://img.shields.io/badge/OpenUserJS-Install-blue)](https://openuserjs.org/scripts/Adromir/Google_Gemini_Mod_(Toolbar_Download))


This UserScript enhances the Google Gemini web interface (`gemini.google.com`) by adding a customizable toolbar and a folder system in the sidebar to organize your conversations.

## ✨ Features

* **📌 Fixed, Centered Toolbar:** Adds a persistent toolbar at the top-center of the Google Gemini interface.
* **📂 Sidebar Folders:** Organize your conversations into collapsible, color-coded folders directly in the sidebar.
    * **Drag & Drop:** Easily move conversations into folders or between them.
    * **Customization:** Rename folders, change their colors, and delete them via a simple context menu.
    * **Persistent:** Your folder structure and conversation assignments are saved locally.
* **⚙️ On-Page Configuration:** No more code editing! A new settings panel allows you to add, edit, and remove buttons and dropdowns directly in the Gemini interface. Your configuration is saved locally in your browser. UPDATE: Now you can change the Order of Dropdown and Buttons as you wish.
* **⚡ Quick Snippets:** Define buttons for frequently used phrases or commands. Click a button to instantly append its text to the Gemini input field.
* **📚 Dropdown Menus:** Organize snippets into multiple dropdown menus for better categorization (e.g., Actions, Translations, Custom Prompts).
* **📋 Paste from Clipboard:** A dedicated button in the toolbar to paste content from your system clipboard directly into the Gemini input field.
* **💾 Download Canvas Content:** A button in the toolbar that allows you to download the content of the currently active/visible Gemini "Canvas" (works for both code and document views).
    * **Text Download**: Saves as a plain text/code file.
    * **PDF Export**: Saves as a formatted PDF file (A4 format, Courier font).
    * The filename is automatically derived from the Canvas title.
    * Intelligently preserves file extensions for code (e.g., `script.js`).
* **🖱️ Smart Insertion (for Snippets/Paste):** Automatically appends text to the input field, placing the cursor correctly.
* **🌓 Dark Mode Aware:** The toolbar and settings panel are styled with a dark theme, fitting well with Gemini's dark mode.

## 🛠️ Installation Guide

1.  **Install a Userscript Manager:**
    Ensure you have a userscript manager browser extension installed. Popular choices include:
    * [Tampermonkey](https://www.tampermonkey.net/) (Recommended; available for Chrome, Firefox, Edge, Safari, Opera)
    * [Violentmonkey](https://violentmonkey.github.io/) (Available for Chrome, Firefox, Edge, Opera)
    * [Greasemonkey](https://www.greasespot.net/) (Firefox only)

2.  **Install the Script:**
    * Navigate to the script's installation URL (e.g., from Greasy Fork, OpenUserJS, or the raw GitHub link if provided).
        * **Direct Install from GitHub:** [Click here to install from GitHub](https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js)
    * Your userscript manager should automatically detect the script and prompt you to install it.
    * Review the script's permissions and details, then click "Install".

3.  **Verify Installation:**
    * Click the Tampermonkey (or your chosen manager's) icon in your browser toolbar.
    * Go to the "Dashboard" or "Manage Scripts" section.
    * You should see "Google Gemini Mod (Toolbar, Folders & Download)" listed and enabled.

4.  **Visit Gemini:**
    * Navigate to or refresh `https://gemini.google.com/`. The toolbar should appear at the top, and folder controls will be in the sidebar. 🎉

## ⚙️ Configuration & Customization

This script features a user-friendly settings panel for the toolbar and intuitive controls for folders.

### Managing Toolbar Items

1.  Click the **⚙️ Settings** button on the far right of the toolbar.
2.  The settings panel will appear, allowing you to manage your buttons and dropdowns.

* **Add:** Click **Add Toolbar Item** and choose 'Button' or 'Dropdown' to create a new entry.
* **Edit:** Change the text in the "Button Label", "Snippet Text", or "Dropdown Placeholder" fields for any item.
* **Reorder:** Simply drag and drop the items within the settings panel to change their order on the toolbar.
* **Remove:** Click the **Remove** button next to any item you want to delete.

3.  Once you're done, click **Save & Close**. The toolbar will instantly update with your new configuration.

### Managing Folders

Folder management happens directly in the sidebar.

* **Create Folder:** Click the **＋ New Folder** button at the top of the sidebar's conversation list.
* **Move Conversations:** Drag any conversation from the list and drop it into a folder.
* **Open/Close Folder:** Click on a folder's header to toggle its visibility.
* **Folder Options:** Click the **⋮** icon on a folder to open a context menu where you can:
    * **Rename:** Change the folder's name.
    * **Change Color:** Select a new color from a predefined palette or enter a custom hex code.
    * **Delete Folder:** Remove the folder (conversations inside will be moved back to the main list).

Your folder setup is saved automatically and will persist across sessions.

---

## Disclaimer

This script is provided "as is" without warranty of any kind. The author, Adromir, is not responsible for any damage or data loss that may result from its use. Use at your own risk. This script is not affiliated with or endorsed by Google.

## License

This project is licensed under the MIT License.

Copyright (c) 2025 Adromir

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