// ==UserScript==
// @name         Google Gemini Mod (Toolbar & Download)
// @namespace    http://tampermonkey.net/
// @version      0.0.2
// @description  Enhances Google Gemini with a toolbar for snippets and canvas content download.
// @author       Adromir
// @match        https://gemini.google.com/*
// @downloadURL  https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js
// @updateURL    https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js
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

    function displayUserscriptMessage(message, isError = true) {
        const prefix = "Gemini Mod Userscript: ";
        if (isError) console.error(prefix + message);
        else console.log(prefix + message);
        alert(prefix + message);
    }

    function moveCursorToEnd(element) {
        try {
            const range = document.createRange();
            const sel = window.getSelection();
            range.selectNodeContents(element);
            range.collapse(false);
            sel.removeAllRanges();
            sel.addRange(range);
            element.focus();
        } catch (e) {
            console.error("Gemini Mod Userscript: Error setting cursor position:", e);
        }
    }

    function findTargetInputElement() {
        const selectorsToTry = ['.ql-editor p', '.ql-editor', 'div[contenteditable="true"]'];
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

    function insertSnippetText(textToInsert) {
        let targetInputElement = findTargetInputElement();
        if (!targetInputElement) {
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
                if (actualInsertionPoint.innerHTML === '<br>') actualInsertionPoint.innerHTML = '';
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

    async function handlePasteButtonClick() {
        try {
            if (!navigator.clipboard || !navigator.clipboard.readText) {
                displayUserscriptMessage("Clipboard access is not available or not permitted.");
                return;
            }
            const text = await navigator.clipboard.readText();
            if (text) insertSnippetText(text);
            else console.log("Gemini Mod Userscript: Clipboard is empty.");
        } catch (err) {
            console.error('Gemini Mod Userscript: Failed to read clipboard contents: ', err);
            displayUserscriptMessage(err.name === 'NotAllowedError' ? 'Permission to read clipboard was denied.' : 'Failed to paste from clipboard. See console.');
        }
    }

    // --- Canvas Download Feature ---
    const DEFAULT_DOWNLOAD_EXTENSION = "txt";
    const GEMINI_CANVAS_WRAPPER_SELECTOR = "immersive-panel.ng-tns-c1436378242-1.ng-trigger.ng-trigger-immersivePanelTransitions.ng-star-inserted";
    const GEMINI_CANVAS_TITLE_TEXT_SELECTOR = "h2.title-text.gds-title-s";
    const GEMINI_CANVAS_TITLE_BAR_SELECTOR = "div.toolbar.has-title";
    const GEMINI_CANVAS_COPY_BUTTON_SELECTOR = "code-immersive-panel.ng-star-inserted copy-button.ng-star-inserted button.copy-button";
    
    // Regex for common extensions, used in sanitizeFilename
    const COMMON_EXTENSIONS_REGEX = /\.(js|html|css|py|md|txt|json|xml|yaml|sh|bat|ps1|java|c|cpp|h|hpp|cs|go|rb|php|swift|kt|kts|dart|rs|lua|pl|sql|r|ipynb)$/i;


    /**
     * Sanitizes a string to be used as a valid filename.
     * It tries to extract a filename-like part from the input string first.
     * If the extracted part is already a valid filename, it's used directly.
     * Otherwise, the extracted part (or the whole input if no specific part is found) is sanitized.
     * @param {string} name - The original string (e.g., canvas title).
     * @param {string} defaultExtension - The default extension if none is found or extracted.
     * @returns {string} A sanitized filename.
     */
    function sanitizeFilename(name, defaultExtension = "txt") {
        if (!name || typeof name !== 'string' || name.trim() === "") {
            console.log(`Gemini Mod Userscript: Input name invalid or empty, defaulting to "downloaded_content.${defaultExtension}".`);
            return `downloaded_content.${defaultExtension}`;
        }

        let trimmedName = name.trim();
        
        // Regex to find a potential filename pattern (alphanumeric, dots, hyphens, underscores) ending with a known extension.
        // This tries to capture the "most likely" filename if the title contains more text.
        const filenamePatternRegex = /([\w.-]+?\.(?:js|html|css|py|md|txt|json|xml|yaml|sh|bat|ps1|java|c|cpp|h|hpp|cs|go|rb|php|swift|kt|kts|dart|rs|lua|pl|sql|r|ipynb))\b/gi;
        
        let candidateFilename = trimmedName; // Default to the whole trimmed name
        let potentialFilenames = [];
        let match;
        while ((match = filenamePatternRegex.exec(trimmedName)) !== null) {
            potentialFilenames.push(match[1]);
        }

        if (potentialFilenames.length > 0) {
            // If multiple patterns are found (e.g., "file1.js and file2.txt"), use the last one.
            candidateFilename = potentialFilenames[potentialFilenames.length - 1];
            console.log(`Gemini Mod Userscript: Extracted candidate filename: "${candidateFilename}" from title: "${trimmedName}"`);
        } else {
            console.log(`Gemini Mod Userscript: No specific filename pattern with known extension found in title: "${trimmedName}". Using whole title as base.`);
        }

        // Now, check if this candidateFilename is "valid as is".
        // "Valid as is" means: no invalid characters, and if it has an extension, it's a known one.
        // eslint-disable-next-line no-control-regex
        const invalidCharsRegex = /[<>:"/\\|?*\x00-\x1F]/g;
        const hasInvalidChars = invalidCharsRegex.test(candidateFilename);
        
        const extMatch = candidateFilename.match(COMMON_EXTENSIONS_REGEX);

        if (!hasInvalidChars && extMatch) {
            // Candidate has a known extension and no invalid characters.
            // Further check: ensure the base part (before extension) is also clean of invalid chars.
            // This is slightly redundant as we tested candidateFilename, but good for sanity.
            const basePartOfCandidate = candidateFilename.substring(0, candidateFilename.lastIndexOf(extMatch[0]));
            if (!invalidCharsRegex.test(basePartOfCandidate)) {
                 console.log(`Gemini Mod Userscript: Candidate filename "${candidateFilename}" considered valid and used as is.`);
                 return candidateFilename;
            }
        }
        
        // If not returned "as is", proceed to sanitize the candidateFilename (or the original trimmedName if no candidate was extracted)
        console.log(`Gemini Mod Userscript: Candidate filename "${candidateFilename}" requires sanitization or formatting.`);

        let baseToSanitize = candidateFilename;
        let determinedExtension = defaultExtension;

        const currentExtMatch = candidateFilename.match(COMMON_EXTENSIONS_REGEX);
        if (currentExtMatch && currentExtMatch[1]) {
            determinedExtension = currentExtMatch[1].toLowerCase();
            baseToSanitize = candidateFilename.substring(0, candidateFilename.lastIndexOf(currentExtMatch[0]));
        }
        // If baseToSanitize became empty after stripping extension (e.g. candidate was just ".js")
        if (baseToSanitize.trim() === "" && candidateFilename !== "") {
             baseToSanitize = "downloaded_content"; // Or try to derive from original trimmedName's non-ext part
        } else if (baseToSanitize.trim() === "") {
            baseToSanitize = "downloaded_content";
        }


        let sanitizedBase = baseToSanitize
            .replace(invalidCharsRegex, '_') // Remove invalid characters
            .replace(/\s+/g, '_')           // Replace spaces with underscores
            .replace(/__+/g, '_')          // Collapse multiple underscores
            .replace(/^[_.-]+|[_.-]+$/g, '');// Remove leading/trailing underscores, dots, or hyphens

        // If after all this, the base is empty (e.g., title was just "///" or "...")
        if (!sanitizedBase) {
            sanitizedBase = 'downloaded_content';
        }

        // Ensure max length for the base part, leaving room for dot and extension
        const maxBaseLength = 250 - (determinedExtension.length + 1);
        if (sanitizedBase.length > maxBaseLength) {
            sanitizedBase = sanitizedBase.substring(0, maxBaseLength);
            // Clean up again if truncation left a trailing underscore
            sanitizedBase = sanitizedBase.replace(/_+$/, ''); 
        }
         if (!sanitizedBase) { // If truncation made it empty
            sanitizedBase = 'downloaded_content';
        }

        return `${sanitizedBase}.${determinedExtension}`;
    }


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
                const filename = sanitizeFilename(canvasTitle); // Uses the new sanitizeFilename logic
                triggerDownload(filename, clipboardContent);
            } catch (err) {
                console.error('Gemini Mod Userscript: Error reading from clipboard:', err);
                displayUserscriptMessage(err.name === 'NotAllowedError' ? 'Clipboard permission denied.' : 'Failed to read clipboard.');
            }
        }, 300);
    }

    function createToolbar() {
        const toolbarId = 'gemini-snippet-toolbar-userscript';
        if (document.getElementById(toolbarId)) {
            console.log("Gemini Mod Userscript: Toolbar already exists.");
            return;
        }
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
        spacer.className = 'userscript-toolbar-spacer';
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

    function handleDarkModeForUserscript() {
        console.log("Gemini Mod Userscript: Dark mode handling is passive (toolbar is dark by default).");
    }

    // --- Initialization Logic ---
    function init() {
        console.log("Gemini Mod Userscript: Initializing...");
        injectCustomCSS();
        const M_INITIALIZATION_DELAY = 1500;
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

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
