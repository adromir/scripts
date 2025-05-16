# Google Gemini Mod (Toolbar & Download) - UserScript 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Greasy Fork](https://img.shields.io/badge/Greasy%20Fork-Install-brightgreen)](https://greasyfork.org/scripts/YOUR_SCRIPT_ID_HERE) [![OpenUserJS](https://img.shields.io/badge/OpenUserJS-Install-blue)](https://openuserjs.org/scripts/YOUR_USERNAME/YOUR_SCRIPT_NAME) This UserScript enhances the Google Gemini web interface (`gemini.google.com`) by adding a customizable toolbar near the top of the page. This toolbar provides quick access to predefined text snippets, a paste button, and a feature to download the content of an active Gemini "Canvas".

![](https://raw.githubusercontent.com/adromir/assets/refs/heads/main/screenshot-gemeni-mod.png)
*(A screenshot of the toolbar being on the upper border)*

## ✨ Features

* **📌 Fixed, Centered Toolbar:** Adds a persistent, customizable toolbar at the top-center of the Google Gemini interface.
* **⚡ Quick Snippets:** Define buttons for frequently used phrases or commands. Click a button to instantly append its text to the Gemini input field.
* **📚 Dropdown Menus:** Organize snippets into multiple dropdown menus for better categorization (e.g., Actions, Translations, Custom Prompts).
* **📋 Paste from Clipboard:** A dedicated button in the toolbar to paste content from your system clipboard directly into the Gemini input field.
* **💾 Download Canvas Content:** A button in the toolbar that allows you to download the content of the currently active/visible Gemini "Canvas".
    * It cleverly uses the Canvas's own "Copy to Clipboard" functionality.
    * The filename is automatically derived from the Canvas title.
    * It intelligently attempts to preserve existing file extensions from the Canvas title (e.g., `myScript.js` will be saved as `myScript.js`). If no extension is found, `.txt` is used as a default.
* **🖱️ Smart Insertion (for Snippets/Paste):** Automatically appends text to the input field, placing the cursor correctly.
* **🎨 Customizable:** Easily modify the buttons, dropdowns, and snippet text directly within the userscript's code.
* **🌓 Dark Mode Aware:** The toolbar is styled with a dark theme by default, fitting well with Gemini's dark mode.

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
    * You should see "Google Gemini Mod (Toolbar & Download)" listed and enabled.

4.  **Visit Gemini:**
    * Navigate to or refresh `https://gemini.google.com/`. The toolbar should now appear at the top-center of the page. 🎉

## ⚙️ Customization

You can easily tailor the toolbar buttons and dropdowns to your needs by editing the userscript's code.

1.  Click the Tampermonkey (or your manager's) icon in your browser.
2.  Go to the "Dashboard".
3.  Find "Google Gemini Mod (Toolbar & Download)" in the list and click the "Edit" (pencil) icon.
4.  Modify the configuration sections as described below.

**1. Customizing Buttons:**

    Find the `buttonSnippets` array:
    ```javascript
    const buttonSnippets = [
      { label: "Greeting", text: "Hello Gemini!" },
      { label: "Explain", text: "Could you please explain ... in more detail?" },
      // Add more button snippets here
      // Example: { label: "My Button", text: "My snippet text..." }
    ];
    ```
    * **Edit:** Change the `label` (what appears on the button) and `text` (what gets inserted).
    * **Add:** Copy an existing line `{ label: "...", text: "..." },` and modify it.
    * **Remove:** Delete the line corresponding to the button you want to remove.

**2. Customizing Dropdowns:**

    Find the `dropdownConfigurations` array:
    ```javascript
    const dropdownConfigurations = [
      {
        placeholder: "Actions...", // Text shown before selection
        options: [
          { label: "Summarize", text: "Please summarize the following text:\n" },
          { label: "Ideas", text: "Give me 5 ideas for ..." },
          // Add more options here: { label: "Option Name", text: "Snippet..." }
        ]
      },
      // Add more dropdown objects here
    ];
    ```
    * **Edit Options:** Modify the `label` and `text` within the `options` array of a specific dropdown.
    * **Add Options:** Add more `{ label: "...", text: "..." }` objects to an existing `options` array.
    * **Edit Placeholder:** Change the `placeholder` text for a dropdown.
    * **Add Dropdowns:** Copy an entire dropdown object `{ placeholder: "...", options: [...] },` and customize it.
    * **Remove Dropdowns/Options:** Delete the relevant lines or objects.

**3. Customizing Download Behavior (Advanced):**

    The download functionality relies on specific CSS selectors to find the active Gemini "Canvas" title and its internal "Copy to Clipboard" button. These are defined as constants near the top of the script:
    ```javascript
    const GEMINI_CANVAS_TITLE_TEXT_SELECTOR = "..."; // Identifies the title element of the canvas
    const GEMINI_COPY_BUTTON_IN_TOOLBAR_SELECTOR = "..."; // Finds the "Copy" button within the canvas's toolbar
    ```
    If the download feature stops working after a Gemini UI update, these selectors might need to be updated by inspecting the Gemini webpage elements with browser developer tools.

**Important:** After saving changes to the script in the Tampermonkey editor, you usually need to **refresh the Gemini page** for the changes to take effect.

## 📡 Auto-Updates

This script includes `@downloadURL` and `@updateURL` metadata pointing to its GitHub location. Userscript managers like Tampermonkey will periodically check for updates. If a new version is found (based on the `@version` number), you will be prompted to update (or it may update automatically, depending on your manager's settings).

To ensure you get updates:
1.  Make sure you installed the script from the `@downloadURL` provided in the metadata.
2.  Keep your userscript manager's update checks enabled.

If you modify the script yourself and want to manage your own updates via GitHub:
1.  **Fork** the repository: [https://github.com/adromir/scripts](https://github.com/adromir/scripts)
2.  Upload your modified script to your fork.
3.  Update the `@version`, `@downloadURL`, and `@updateURL` in your script's metadata to point to the raw file URL in *your* forked repository.
4.  Each time you update your forked script, increment the `@version` number.

## 📝 Notes
* The CSS styles are embedded directly in the script using `GM_addStyle` for compatibility.
* The download feature relies on programmatic clicking of the canvas's "Copy" button and then reading from the clipboard. This requires clipboard permissions to be granted to the browser for the Gemini site.
* If the toolbar doesn't appear or features don't work:
    * Ensure Tampermonkey (or your manager) is enabled.
    * Ensure the script is enabled in the Tampermonkey dashboard.
    * Check the browser's developer console (usually F12, then click the "Console" tab) for any error messages related to "Gemini Mod Userscript".
    * Google Gemini might have updated its website structure, breaking the script's CSS selectors. The script might need adjustments.

## 📜 Disclaimer

This userscript is a community-driven effort and is not officially supported by Google. It modifies the Gemini web interface, and future updates to Gemini might break its functionality. Use at your own risk.

The author, Adromir, and contributors are not responsible for any issues or data loss that may arise from using this script.

## 📄 License

This project is licensed under the MIT License.

Copyright (c) 2024 Adromir - <https://github.com/adromir>

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
