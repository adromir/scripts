// ==UserScript==
// @name         Google Gemini Mod (Toolbar & Download)
// @namespace    http://tampermonkey.net/
// @version      0.0.1
// @description  Enhances Google Gemini with a toolbar for snippets and canvas content download.
// @author       Adromir
// @match        https://gemini.google.com/*
// @grant        GM_addStyle
// @grant        GM_setClipboard
// @grant        GM_getClipboard
// ==/UserScript==

(function() {
    'use strict';

    // --- Customizable Elements ---
    const PASTE_BUTTON_LABEL = "📋 Paste";
    const DOWNLOAD_BUTTON_LABEL = "💾 Download Canvas as File";

    // --- Embedded CSS ---
    // Note: GM_addStyle will be used to inject this CSS.
    const embeddedCSS = `
        #gemini-snippet-toolbar-userscript { /* Changed ID to avoid potential conflicts */
          position: fixed !important; top: 0 !important; left: 50% !important; /* Centered */
          transform: translateX(-50%) !important; /* Centering trick */
          width: auto !important; /* Auto width based on content */
          max-width: 80% !important; /* Max width to prevent overflow on small screens */
          padding: 10px 15px !important; 
          z-index: 999999 !important; /* Higher z-index */
          display: flex !important; flex-wrap: wrap !important;
          gap: 8px !important; align-items: center !important; font-family: 'Roboto', 'Arial', sans-serif !important;
          box-sizing: border-box !important; background-color: rgba(40, 42, 44, 0.95) !important;
          border-radius: 0 0 16px 16px !important; /* Rounded bottom corners */
          box-shadow: 0 4px 12px rgba(0,0,0,0.25);
        }
        #gemini-snippet-toolbar-userscript button, 
        #gemini-snippet-toolbar-userscript select {
          padding: 4px 10px !important; cursor: pointer !important; background-color: #202122 !important;
          color: #e3e3e3 !important; border-radius: 16px !important; font-size: 13px !important;
          font-family: inherit !important; font-weight: 500 !important; height: 28px !important;
          box-sizing: border-box !important; vertical-align: middle !important;
          transition: background-color 0.2s ease, transform 0.1s ease !important;
          border: none !important; flex-shrink: 0;
        }
        #gemini-snippet-toolbar-userscript select {
          padding-right: 25px !important;
          appearance: none !important;
          background-image: url('data:image/svg+xml;charset=US-ASCII,<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="%23e3e3e3" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z"/></svg>') !important;
          background-repeat: no-repeat !important;
          background-position: right 8px center !important;
          background-size: 12px 12px !important;
        }
        #gemini-snippet-toolbar-userscript option {
          background-color: #2a2a2a !important;
          color: #e3e3e3 !important;
          font-weight: normal !important;
          padding: 5px 10px !important;
        }
        #gemini-snippet-toolbar-userscript button:hover,
        #gemini-snippet-toolbar-userscript select:hover {
          background-color: #4a4e51 !important;
        }
        #gemini-snippet-toolbar-userscript button:active {
          background-color: #5f6368 !important;
          transform: scale(0.98) !important;
        }
        .userscript-toolbar-spacer { /* Renamed spacer class */
            margin-left: auto !important;
        }
    `;

    /**
     * Injects the embedded CSS using GM_addStyle.
     */
    function injectCustomCSS() {
        try {
            GM_addStyle(embeddedCSS);
            console.log("Gemini Mod Userscript: Custom CSS injected successfully.");
        } catch (error) {
            console.error("Gemini Mod Userscript: Failed to inject custom CSS:", error);
            // Fallback if GM_addStyle is not available or fails
            const styleId = 'gemini-mod-userscript-styles';
            if (document.getElementById(styleId)) return;
            const style = document.createElement('style');
            style.id = styleId;
            style.textContent = embeddedCSS;
            document.head.appendChild(style);
        }
    }

    // --- Snippet Definitions ---
    const buttonSnippets = [
        { label: "Greeting", text: "Hello Gemini!" },
        { label: "Explain", text: "Could you please explain ... in more detail?" },
    ];

    const dropdownConfigurations = [
        {
            placeholder: "Actions...",
            options: [
                { label: "Summarize", text: "Please summarize the following text:\n" },
                { label: "Ideas", text: "Give me 5 ideas for ..." },
                { label: "Code (JS)", text: "Give me a JavaScript code example for ..." },
            ]
        },
        {
            placeholder: "Translations",
            options: [
                { label: "DE -> EN", text: "Translate the following into English:\n" },
                { label: "EN -> DE", text: "Translate the following into German:\n" },
                { label: "Correct Text", text: "Please correct the grammar and spelling in the following text:\n" }
            ]
        },
    ];

    // --- Helper Functions ---

    /**
     * Displays a message to the user (console and alert).
     * @param {string} message - The message to display.
     * @param {boolean} isError - True if it's an error message.
     */
    function displayUserscriptMessage(message, isError = true) {
        const prefix = "Gemini Mod Userscript: ";
        if (isError) {
            console.error(prefix + message);
        } else {
            console.log(prefix + message);
        }
        alert(prefix + message); // Simple alert for now
    }

    /**
     * Moves the cursor to the end of the provided element's content.
     * @param {Element} element - The contenteditable element or paragraph within it.
     */
    function moveCursorToEnd(element) {
        try {
            const range = document.createRange();
            const sel = window.getSelection();
            range.selectNodeContents(element);
            range.collapse(false); // false collapses to the end
            sel.removeAllRanges();
            sel.addRange(range);
            element.focus();
        } catch (e) {
            console.error("Gemini Mod Userscript: Error setting cursor position:", e);
        }
    }

    /**
     * Finds the target Gemini input element.
     * @returns {Element | null} The found input element or null.
     */
    function findTargetInputElement() {
        const selectorsToTry = [
            '.ql-editor p',
            '.ql-editor',
            'div[contenteditable="true"]'
        ];
        for (const selector of selectorsToTry) {
            const element = document.querySelector(selector);
            if (element) {
                if (element.classList.contains('ql-editor')) {
                    const pInEditor = element.querySelector('p');
                    return pInEditor || element;
                }
                return element;
            }
        }
        return null;
    }

    /**
     * Inserts text into the Gemini input field, always appending.
     * @param {string} textToInsert - The text snippet to insert.
     */
    function insertSnippetText(textToInsert) {
        let targetInputElement = findTargetInputElement();
        if (!targetInputElement) {
            console.error("Gemini Mod Userscript: Could not find the Gemini input field for snippet insertion.");
            displayUserscriptMessage("Could not find Gemini input field.");
            return;
        }

        let actualInsertionPoint = targetInputElement;
        if (targetInputElement.classList.contains('ql-editor')) {
            let p = targetInputElement.querySelector('p');
            if (!p) {
                p = document.createElement('p');
                targetInputElement.appendChild(p);
            }
            actualInsertionPoint = p;
        }

        actualInsertionPoint.focus();
        setTimeout(() => {
            moveCursorToEnd(actualInsertionPoint);
            let insertedViaExec = false;
            try {
                insertedViaExec = document.execCommand('insertText', false, textToInsert);
            } catch (e) {
                console.warn("Gemini Mod Userscript: execCommand('insertText') threw an error:", e);
            }

            if (!insertedViaExec) {
                console.warn("Gemini Mod Userscript: execCommand('insertText') failed. Using fallback append.");
                if (actualInsertionPoint.innerHTML === '<br>') {
                    actualInsertionPoint.innerHTML = '';
                }
                actualInsertionPoint.textContent += textToInsert;
                moveCursorToEnd(actualInsertionPoint);
            }

            const editorToDispatchOn = document.querySelector('.ql-editor') || targetInputElement;
            if (editorToDispatchOn) {
                editorToDispatchOn.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }));
                editorToDispatchOn.dispatchEvent(new Event('change', { bubbles: true, cancelable: true }));
            }
            console.log("Gemini Mod Userscript: Snippet inserted.");
        }, 50);
    }

    /**
     * Handles the paste button click. Reads from clipboard and inserts text.
     */
    async function handlePasteButtonClick() {
        try {
            if (!navigator.clipboard || !navigator.clipboard.readText) {
                console.warn("Gemini Mod Userscript: Clipboard API not available or readText not supported.");
                displayUserscriptMessage("Clipboard access is not available or not permitted.");
                return;
            }
            const text = await navigator.clipboard.readText();
            if (text) {
                insertSnippetText(text);
            } else {
                console.log("Gemini Mod Userscript: Clipboard is empty.");
            }
        } catch (err) {
            console.error('Gemini Mod Userscript: Failed to read clipboard contents: ', err);
            if (err.name === 'NotAllowedError') {
                displayUserscriptMessage('Permission to read clipboard was denied.');
            } else {
                displayUserscriptMessage('Failed to paste from clipboard. See console.');
            }
        }
    }

    // --- Canvas Download Feature ---
    const DEFAULT_DOWNLOAD_EXTENSION = "txt";
    const GEMINI_CANVAS_WRAPPER_SELECTOR = "immersive-panel.ng-tns-c1436378242-1.ng-trigger.ng-trigger-immersivePanelTransitions.ng-star-inserted";
    const GEMINI_CANVAS_TITLE_TEXT_SELECTOR = "h2.title-text.gds-title-s";
    const GEMINI_CANVAS_TITLE_BAR_SELECTOR = "div.toolbar.has-title";
    const GEMINI_CANVAS_COPY_BUTTON_SELECTOR = "code-immersive-panel.ng-star-inserted copy-button.ng-star-inserted button.copy-button";

    /**
     * Sanitizes a string to be used as a valid filename.
     * @param {string} name - The original filename string.
     * @param {string} defaultExtension - The default extension if none is found.
     * @returns {string} A sanitized filename.
     */
    function sanitizeFilename(name, defaultExtension = "txt") {
        if (!name || typeof name !== 'string') name = 'downloaded_content';
        let baseName = name;
        let extension = defaultExtension;
        const commonExtensionsRegex = /\.(js|html|css|py|md|txt|json|xml|yaml|sh|bat|ps1|java|c|cpp|h|hpp|cs|go|rb|php|swift|kt|kts|dart|rs|lua|pl|sql|r|ipynb)$/i;
        const match = name.match(commonExtensionsRegex);
        if (match && match[1]) {
            extension = match[1].toLowerCase();
            baseName = name.substring(0, name.lastIndexOf(match[0]));
        }
        let sanitizedBase = baseName.replace(/[<>:"/\\|?*~]+/g, '_')
                                   .replace(/\s+/g, '_')
                                   .replace(/__+/g, '_')
                                   .replace(/^_+|_+$/g, '')
                                   .replace(/^\.+|\.+$/g, '')
                                   .trim();
        if (!sanitizedBase) sanitizedBase = 'downloaded_content';
        return `${sanitizedBase}.${extension}`;
    }

    /**
     * Creates and triggers a download for the given text content.
     * @param {string} filename - The desired filename.
     * @param {string} content - The text content to download.
     */
    function triggerDownload(filename, content) {
        try {
            const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            console.log(`Gemini Mod Userscript: Download triggered for "${filename}".`);
        } catch (error) {
            console.error(`Gemini Mod Userscript: Failed to trigger download for "${filename}":`, error);
            displayUserscriptMessage(`Failed to download: ${error.message}`);
        }
    }

    /**
     * Handles the click of the global canvas download button.
     */
    async function handleGlobalCanvasDownload() {
        const canvasElement = document.querySelector(GEMINI_CANVAS_WRAPPER_SELECTOR);
        if (!canvasElement) {
            displayUserscriptMessage("No active canvas found to download.");
            return;
        }
        const copyButton = canvasElement.querySelector(GEMINI_CANVAS_COPY_BUTTON_SELECTOR);
        if (!copyButton) {
            displayUserscriptMessage("Could not find 'Copy to Clipboard' button in canvas.");
            return;
        }
        copyButton.click();
        setTimeout(async () => {
            try {
                if (!navigator.clipboard || !navigator.clipboard.readText) {
                    displayUserscriptMessage("Clipboard access not available.");
                    return;
                }
                const clipboardContent = await navigator.clipboard.readText();
                if (!clipboardContent || clipboardContent.trim() === "") {
                    displayUserscriptMessage("Clipboard empty after copy. Nothing to download.");
                    return;
                }
                let titleTextElement = canvasElement.querySelector(GEMINI_CANVAS_TITLE_TEXT_SELECTOR);
                if (!titleTextElement) {
                    const titleBar = canvasElement.querySelector(GEMINI_CANVAS_TITLE_BAR_SELECTOR);
                    if (titleBar) titleTextElement = titleBar.querySelector(GEMINI_CANVAS_TITLE_TEXT_SELECTOR);
                }
                const canvasTitle = titleTextElement ? (titleTextElement.textContent || "Untitled Canvas").trim() : "Untitled Canvas";
                const filename = sanitizeFilename(canvasTitle);
                triggerDownload(filename, clipboardContent);
            } catch (err) {
                console.error('Gemini Mod Userscript: Error reading from clipboard:', err);
                displayUserscriptMessage(err.name === 'NotAllowedError' ? 'Clipboard permission denied.' : 'Failed to read clipboard.');
            }
        }, 300);
    }

    /**
     * Creates the snippet toolbar and adds it to the page.
     */
    function createToolbar() {
        const toolbarId = 'gemini-snippet-toolbar-userscript'; // Use userscript-specific ID
        if (document.getElementById(toolbarId)) {
            console.log("Gemini Mod Userscript: Toolbar already exists.");
            return;
        }
        console.log("Gemini Mod Userscript: Initializing toolbar...");
        const toolbar = document.createElement('div');
        toolbar.id = toolbarId;

        buttonSnippets.forEach(snippet => {
            const button = document.createElement('button');
            button.textContent = snippet.label;
            button.title = snippet.text;
            button.addEventListener('click', () => insertSnippetText(snippet.text));
            toolbar.appendChild(button);
        });

        dropdownConfigurations.forEach(config => {
            if (config.options && config.options.length > 0) {
                const select = document.createElement('select');
                select.title = config.placeholder || "Select snippet";
                const defaultOption = document.createElement('option');
                defaultOption.textContent = config.placeholder || "Select...";
                defaultOption.value = "";
                defaultOption.disabled = true;
                defaultOption.selected = true;
                select.appendChild(defaultOption);
                config.options.forEach(snippet => {
                    const option = document.createElement('option');
                    option.textContent = snippet.label;
                    option.value = snippet.text;
                    select.appendChild(option);
                });
                select.addEventListener('change', (event) => {
                    const selectedText = event.target.value;
                    if (selectedText) {
                        insertSnippetText(selectedText);
                        event.target.selectedIndex = 0;
                    }
                });
                toolbar.appendChild(select);
            }
        });

        const spacer = document.createElement('div');
        spacer.className = 'userscript-toolbar-spacer'; // Use renamed class
        toolbar.appendChild(spacer);

        const pasteButton = document.createElement('button');
        pasteButton.textContent = PASTE_BUTTON_LABEL;
        pasteButton.title = "Paste from Clipboard";
        pasteButton.addEventListener('click', handlePasteButtonClick);
        toolbar.appendChild(pasteButton);

        const globalDownloadButton = document.createElement('button');
        globalDownloadButton.textContent = DOWNLOAD_BUTTON_LABEL;
        globalDownloadButton.title = "Download active canvas content (uses canvas's copy button)";
        globalDownloadButton.addEventListener('click', handleGlobalCanvasDownload);
        toolbar.appendChild(globalDownloadButton);

        document.body.insertBefore(toolbar, document.body.firstChild);
        console.log("Gemini Mod Userscript: Toolbar inserted.");
    }

    /**
     * Handles dark mode. For a userscript, this is mostly about adapting to the site's
     * existing dark mode, if necessary for the toolbar.
     * The current toolbar CSS is dark-themed by default.
     */
    function handleDarkModeForUserscript() {
        // Gemini handles its own dark mode. Our toolbar is styled with a dark theme.
        // If specific adjustments were needed based on Gemini's dark mode class on <body>,
        // one could use a MutationObserver to watch document.body.classList.
        console.log("Gemini Mod Userscript: Dark mode handling is passive (toolbar is dark by default).");
        // Example: Check if Gemini uses a specific class for dark mode on the body
        // if (document.body.classList.contains('gemini-dark-mode-class')) {
        //    // Potentially apply additional styles to the toolbar if needed
        // }
    }

    // --- Initialization Logic ---
    function init() {
        console.log("Gemini Mod Userscript: Initializing...");
        injectCustomCSS();
        // Wait for the page to be more likely settled before adding the toolbar
        // Especially since Gemini is a complex web application.
        const M_INITIALIZATION_DELAY = 1500; // Increased delay
        setTimeout(() => {
            try {
                createToolbar();
                handleDarkModeForUserscript();
                 console.log("Gemini Mod Userscript: Fully initialized.");
            } catch(e) {
                console.error("Gemini Mod Userscript: Error during delayed initialization:", e);
                displayUserscriptMessage("Error initializing toolbar. See console.");
            }
        }, M_INITIALIZATION_DELAY);
    }

    // Run the script after the DOM is fully loaded or if it's already loaded.
    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
