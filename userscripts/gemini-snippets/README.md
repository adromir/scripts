# Gemini Snippet Toolbar (Tampermonkey UserScript)

## Overview

This Tampermonkey UserScript enhances the Google Gemini web interface (`gemini.google.com`) by adding a customizable toolbar near the top of the page. This toolbar provides quick access to predefined text snippets via buttons and dropdown menus, allowing you to insert frequently used prompts or text fragments into the Gemini chat input field with a single click or selection.

The script is designed to be easily configurable, allowing users to define their own buttons and multiple dropdown menus with custom options.

## Features

* **Customizable Buttons:** Add buttons that insert specific text snippets on click.
* **Multiple Customizable Dropdowns:** Configure several dropdown menus, each with its own set of snippet options.
* **Easy Configuration:** Snippets for both buttons and dropdowns are defined directly within the script's configuration sections.
* **Simple Insertion:** Automatically inserts the selected snippet text into the Gemini chat input field.
* **User-Defined Styling & Positioning:** The script includes CSS which can be modified by the user (as you have already done).

## Installation

1.  **Install Tampermonkey:** Ensure you have the Tampermonkey browser extension (or a compatible userscript manager like Greasemonkey or Violentmonkey) installed for your browser (Chrome, Firefox, Edge, Safari, etc.). You can usually find it in your browser's extension store.
2.  **Create New Script:**
    * Click the Tampermonkey icon in your browser toolbar.
    * Select "Create a new script...".
3.  **Paste Code:** Delete the default template code provided and paste the entire code of the `gemini-snippet-toolbar.user.js` script into the editor.
4.  **Save:** Go to "File" -> "Save" (or click the floppy disk icon).
5.  **Enable:** Make sure the script is enabled in the Tampermonkey dashboard.
6.  **Visit Gemini:** Navigate to or refresh `https://gemini.google.com/app`. The toolbar should now appear.

## Configuration

You can easily customize the buttons and dropdown menus by editing the JavaScript code within the Tampermonkey editor.

### Adding/Modifying Buttons

Locate the `buttonSnippets` array within the script's code:

```javascript
    // --- CONFIGURE BUTTON SNIPPETS HERE ---
    const buttonSnippets = [
        { label: "Greeting", text: "Hello Gemini!" },
        { label: "Explain", text: "Could you please explain ... in more detail?" },
        // Add more button snippets here
    ];
    // ------------------------------------
To add a new button: Add a new object { label: "Your Button Name", text: "Text to insert" } to the array, separated by a comma.label: This is the text that will appear on the button itself. Keep it concise.text: This is the full text snippet that will be inserted into the Gemini chat box when the button is clicked. You can use \n for line breaks if needed.To modify an existing button: Change the label or text values for that button's object.To remove a button: Delete the entire object {...} for that button from the array (and make sure the commas between remaining objects are correct).Example: Adding a button to ask for a Python example:    // --- CONFIGURE BUTTON SNIPPETS HERE ---
    const buttonSnippets = [
        { label: "Greeting", text: "Hello Gemini!" },
        { label: "Explain", text: "Could you please explain ... in more detail?" },
        { label: "Code (Py)", text: "Give me a Python code example for ..." } // New button added
    ];
    // ------------------------------------
Adding/Modifying DropdownsLocate the dropdownConfigurations array within the script's code:    // --- CONFIGURE MULTIPLE DROPDOWNS HERE ---
    // Each object in the array represents a dropdown menu.
    // 'placeholder': The text displayed before anything is selected.
    // 'options': An array of snippets for this specific dropdown.
    const dropdownConfigurations = [
        {
            placeholder: "Actions...", // Placeholder for the first dropdown
            options: [
                { label: "Summarize", text: "Please summarize the following text:\n" },
                { label: "Ideas", text: "Give me 5 ideas for ..." },
                { label: "Code (JS)", text: "Give me a JavaScript code example for ..." },
            ]
        },
        {
            placeholder: "Translations", // Placeholder for the second dropdown
            options: [
                { label: "DE -> EN", text: "Translate the following into English:\n" },
                { label: "EN -> DE", text: "Translate the following into German:\n" },
                { label: "Correct Text", text: "Please correct the grammar and spelling in the following text:\n" }
            ]
        },
        // Add more dropdown objects here
    ];
    // ------------------------------------
To add a new dropdown menu: Add a new object { placeholder: "Dropdown Name", options: [ ... ] } to the dropdownConfigurations array, separated by a comma.placeholder: This text appears in the dropdown when no option is selected.options: This is an array containing the snippet options for this specific dropdown. Each option within this options array is an object { label: "Option Name", text: "Text to insert" }, similar to the button configuration.To add an option to an existing dropdown: Add a new snippet object { label: "New Option", text: "Text for this option" } inside the options array of the desired dropdown configuration object.To modify an existing dropdown or its options: Change the placeholder, or the label / text values within the relevant options array.To remove a dropdown: Delete the entire configuration object {...} for that dropdown from the dropdownConfigurations array.To remove an option from a dropdown: Delete the specific option object {...} from within its parent dropdown's options array.Example: Adding a third dropdown for custom prompts:    // --- CONFIGURE MULTIPLE DROPDOWNS HERE ---
    const dropdownConfigurations = [
        {
            placeholder: "Actions...",
            options: [ /* ... existing options ... */ ]
        },
        {
            placeholder: "Translations",
            options: [ /* ... existing options ... */ ]
        },
        { // New dropdown added
            placeholder: "My Prompts...",
            options: [
                { label: "Blog Post Idea", text: "Generate 5 blog post ideas about..." },
                { label: "Email Draft", text: "Draft a professional email regarding:\n" }
            ]
        }
    ];
    // ------------------------------------
Important: After making any configuration changes, remember to save the script in the Tampermonkey editor. You may need to refresh the Gemini page for the changes to take effect.Hosting on GitHub for Auto-UpdatesYou can host your personalized version of this script on GitHub and configure Tampermonkey to automatically check for and install updates when you modify the script on GitHub.Steps:Create a GitHub Repository:Go to GitHub and create a new repository (it can be public or private, though public is easier for sharing/raw access). Name it something relevant, e.g., tampermonkey-scripts.Upload Your Script:Upload your modified gemini-snippet-toolbar.user.js file (or whatever you named it) to this repository.Add Update Metadata to Your Script:Edit the script in Tampermonkey (or before uploading to GitHub) and add/modify the following lines within the // ==UserScript== ... // ==/UserScript== block:// ==UserScript==
// @name         Gemini Snippet Toolbar
// @namespace    [http://tampermonkey.net/](http://tampermonkey.net/)
// @version      0.1.1 // Increment this version number each time you update!
// @description  Adds a configurable snippet toolbar...
// @author       Adromir
// @match        [https://gemini.google.com/](https://gemini.google.com/)*
// @icon         [https://www.gstatic.com/lamda/images/gemini_favicon_f069958c85030456e93de685481c559f160ea06b.png](https://www.gstatic.com/lamda/images/gemini_favicon_f069958c85030456e93de685481c559f160ea06b.png)
// @updateURL    [https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/gemini-snippet-toolbar.user.js](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/gemini-snippet-toolbar.user.js) // URL to check for updates (points to the script itself)
// @downloadURL  [https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/gemini-snippet-toolbar.user.js](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/gemini-snippet-toolbar.user.js) // URL to download the new version from
// @grant        none
// @license      MIT
// ==/UserScript==
Replace:YOUR_USERNAME with your actual GitHub username.YOUR_REPOSITORY with the name of the repository you created.main with the name of your default branch (usually main or master).gemini-snippet-toolbar.user.js with the exact filename of your script in the repository.@version: Crucially, you MUST increment the @version number (e.g., from 0.1 to 0.1.1 or 0.2) every time you push an updated version of the script to GitHub. Tampermonkey only updates if the version number in the @updateURL location is higher than the currently installed version.@updateURL: This URL tells Tampermonkey where to look for metadata (specifically the @version) to see if an update is available. Often, this points to the same raw script file as @downloadURL.@downloadURL: This URL tells Tampermonkey where to download the actual script file from if an update is detected (based on the version check from @updateURL).URL Format: It's essential to use the raw file URL from GitHub, which typically looks like https://raw.githubusercontent.com/.... Do not use the regular GitHub page URL (https://github.com/...). You can get the raw URL by navigating to the file on GitHub and clicking the "Raw" button.Save and Commit:Save the script with the added metadata lines in Tampermonkey.Commit and push the updated script file (with the new metadata and potentially a new version number) to your GitHub repository.Tampermonkey Auto-Update:By default, Tampermonkey checks for updates periodically (usually daily). You can also manually trigger a check: Tampermonkey Dashboard -> Click the "Last updated" timestamp column header or the "Check for userscript updates" button (location may vary slightly).If you've incremented the @version on GitHub and pushed the changes, Tampermonkey should detect the update and prompt you to install it (or install it automatically, depending on your Tampermonkey settings).Now, whenever you want to update your personal script, simply:a. Edit the script locally or directly on GitHub.b. Increment the @version number in the metadata block.c. Commit and push the changes to GitHub.d. Tampermonkey will handle the update check and installation on your browser(s) where the script is installed.Troubleshooting / NotesToolbar Not Appearing:Ensure Tampermonkey is enabled.Ensure the script is enabled in the Tampermonkey dashboard.Check the browser's developer console (F12) for any error messages related to the script.Google Gemini might have updated its website structure, breaking the script's selectors for inserting text or placing the toolbar. The script might need adjustments (particularly the insertSnippetText function or CSS).Snippets Not Inserting:Check the developer console for errors.The CSS selectors used to find the Gemini input field (.ql-editor p, .ql-editor, etc.) might have changed. You may need to inspect the Gemini page elements and update these selectors in the insertSnippetText function.Auto-Update Not Working:Double-check the @updateURL and @downloadURL in your installed script. Make sure they point to the correct raw GitHub file URL.Verify that you incremented the @version number in the script file on GitHub before pushing the update.Ensure the branch name (main or master) in the URLs is correct.Check your Tampermonkey settings to ensure updates are enabled and the