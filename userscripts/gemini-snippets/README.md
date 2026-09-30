# Google Gemini Mod (Toolbar, Folders & Download) - UserScript 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Author](https://img.shields.io/badge/Creator-Adromir-blue.svg?style=flat-square)](https://github.com/adromir)
[![GitHub issues](https://img.shields.io/github/issues/adromir/scripts.svg?style=flat-square)](https://github.com/adromir/scripts/issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/adromir/scripts.svg?style=flat-square)](https://github.com/adromir/scripts)
[![Greasy Fork](https://img.shields.io/badge/Greasy%20Fork-Install-brightgreen.svg?style=flat-square)](https://greasyfork.org/scripts/536192-google-gemini-mod-toolbar-download)
[![OpenUserJS](https://img.shields.io/badge/OpenUserJS-Install-blue.svg?style=flat-square)](https://openuserjs.org/scripts/Adromir/Google_Gemini_Mod_(Toolbar_Download))
[![Install Size](https://img.shields.io/badge/Install%20Size-Small-success.svg?style=flat-square)]()

This UserScript enhances the Google Gemini web interface (`gemini.google.com`) by adding a customizable toolbar, a folder system in the sidebar, and powerful backup options.

## ✨ Features

* **📌 Fixed, Centered Toolbar:** Persistent access to your tools at the top-center of the interface.
* **📂 Sidebar Folders:** Organize conversations into collapsible, color-coded folders via Drag & Drop.
* **☁️ Cloud Sync (Supabase):** Seamlessly synchronize your settings, snippets, folders, and conversation mappings across browsers and between the Userscript and the Ferdium Recipe with hardened multi-user authentication.
* **💾 Manual Backup:** Export your configuration to a `.json` file and restore it anywhere, anytime.
* **⚙️ Tabbed Settings Panel:** intuitive interface to manage Toolbar items, Cloud Sync, and Danger Zone reset options.
* **⚡ Quick Snippets:** Define buttons for frequent prompts.
* **📚 Dropdown Menus:** Categorize snippets (e.g., "Coding", "Writing").
* **📋 Clipboard Integration:** Paste clipboard content instantly.
* **📥 Canvas Download:** Download code or text from Gemini's canvas as `.txt` or `.pdf` (A4 formatted).
* **🌓 Dark Mode:** Fully themed to match Gemini's aesthetic.

---

## 🛠️ Installation Guide

1.  **Install a Userscript Manager:**
    *   [Tampermonkey](https://www.tampermonkey.net/) (Recommended)
    *   [Violentmonkey](https://violentmonkey.github.io/)

2.  **Install the Script:**
    *   [**Click here to install directly from GitHub**](https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js)
    *   Or install from Greasy Fork / OpenUserJS.

3.  **Permissions:**
    *   The script requires `GM_xmlhttpRequest` for Cloud Synchronization.
    *   It requires access to `gemini.google.com`.

4.  **Refresh Gemini:**
    *   Reload `https://gemini.google.com/` to see the improvements!

---

## ⚙️ Configuration

Open the **⚙️ Settings** from the toolbar to access the tabbed capabilities:

### 🛠️ Toolbar Tab
*   **Add/Edit/Remove:** Manage buttons and dropdowns.
*   **Reorder:** Drag and drop items to arrange them.
*   **Visibility:** Toggle items on or off without deleting them.

### ☁️ Cloud Sync Tab
*   **Secure Supabase Synchronization:**
    *   **Multi-User Protection:** Individual user accounts powered by Supabase Auth with Row-Level Security (RLS). Anonymous users have 0 access; your configuration is strictly isolated.
    *   **Instant Sign Up & Log In:** Enter your email and password to create an account or sign in directly from the settings panel.
    *   **Cross-App Sync:** Log in with the same credentials in both your Browser Userscript and the Ferdium Recipe (`google-gemini-mod`) to keep folders, toolbars, and chats in sync.
    *   **☁️ Upload to Cloud:** Push your current toolbar items and folders to Supabase.
    *   **☁️ Download from Cloud:** Pull settings and apply them with one click.
*   **Manual Backup:**
    *   **⬇️ Export to File:** Save your complete configuration to a local `.json` file.
    *   **⬆️ Import from File:** Restore settings from a local `.json` file instantly.

### ⚠️ Reset Tab
*   **Reset Folders:** Clear folder structure only.
*   **Factory Reset:** Wipe all data and return to default state.

---

## 📂 Folder Management

*   **Create:** Click `+ New Folder` in the sidebar.
*   **Organize:** Drag conversations into folders.
*   **Customize:** Click `⋮` on a folder to **Rename**, **Change Color**, or **Delete**.

---

## 📜 Disclaimer

This script is provided "as is" without warranty of any kind. The creator, **Adromir**, is not responsible for any damage or data loss resulting from its use. This project is not affiliated with, endorsed by, or connected to Google LLC.

## ⚖️ License

This project is licensed under the **MIT License**.

Copyright (c) 2025 **Adromir** ([https://github.com/adromir](https://github.com/adromir))

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.