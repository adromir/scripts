// ==UserScript==
// @name         Google Gemini Mod (Toolbar & Download)
// @namespace    http://tampermonkey.net/
// @version      0.0.4
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
        #gemini-snippet-toolbar-userscript { 
          position: fixed !important; top: 0 !important; left: 50% !important; 
          transform: translateX(-50%) !important; 
          width: auto !important; 
          max-width: 80% !important; 
          padding: 10px 15px !important; 
          z-index: 999999 !important; 
          display: flex !important; flex-wrap: wrap !important;
          gap: 8px !important; align-items: center !important; font-family: 'Roboto', 'Arial', sans-serif !important;
          box-sizing: border-box !important; background-color: rgba(40, 42, 44, 0.95) !important;
          border-radius: 0 0 16px 16px !important; 
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
        .userscript-toolbar-spacer { 
            margin-left: auto !important;
        }
    `;

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
    // This selector now directly targets the title h2 element within an active immersive panel.
    const GEMINI_CANVAS_TITLE_TEXT_SELECTOR = "immersive-panel.ng-tns-c1436378242-1.ng-trigger.ng-trigger-immersivePanelTransitions.ng-star-inserted code-immersive-panel > toolbar > div > div:nth-child(1) > h2.title-text.gds-title-s.ng-star-inserted"; 
    
    // This selector is now relative to the toolbar element that will be found via the titleTextElement.
    const GEMINI_COPY_BUTTON_IN_TOOLBAR_SELECTOR = "copy-button.ng-star-inserted button.copy-button.icon-button";
    
    // eslint-disable-next-line no-control-regex
    const INVALID_FILENAME_CHARS_REGEX = /[<>:"/\\|?*\x00-\x1F]/g;
    const RESERVED_WINDOWS_NAMES_REGEX = /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i;
    const FILENAME_WITH_EXT_REGEX = /^(.+)\.([a-zA-Z0-9]{1,8})$/;
    const SUBSTRING_FILENAME_REGEX = /([\w\s.,\-()[\\]{}'!~@#$%^&+=]+?\.([a-zA-Z0-9]{1,8}))(?=\s|$|[,.;:!?])/g;

    function ensureLength(filename, maxLength = 255) {
        if (filename.length <= maxLength) {
            return filename;
        }
        const dotIndex = filename.lastIndexOf('.');
        if (dotIndex === -1 || dotIndex < filename.length - 10 ) { 
            return filename.substring(0, maxLength);
        }
        const base = filename.substring(0, dotIndex);
        const ext = filename.substring(dotIndex);
        const maxBaseLength = maxLength - ext.length;
        if (maxBaseLength <= 0) {
            return filename.substring(0, maxLength);
        }
        return base.substring(0, maxBaseLength) + ext;
    }

    function sanitizeBasename(baseName) {
        if (typeof baseName !== 'string' || baseName.trim() === "") return "downloaded_document";
        let sanitized = baseName.trim()
            .replace(INVALID_FILENAME_CHARS_REGEX, '_')
            .replace(/\s+/g, '_')
            .replace(/__+/g, '_')
            .replace(/^[_.-]+|[_.-]+$/g, '');
        if (!sanitized || RESERVED_WINDOWS_NAMES_REGEX.test(sanitized)) {
            sanitized = `_${sanitized || "file"}_`;
            sanitized = sanitized.replace(INVALID_FILENAME_CHARS_REGEX, '_').replace(/\s+/g, '_').replace(/__+/g, '_').replace(/^[_.-]+|[_.-]+$/g, '');
        }
        return sanitized || "downloaded_document";
    }

    function determineFilename(title, defaultExtension = "txt") {
        const logPrefix = "Gemini Mod Userscript: determineFilename - ";
        if (!title || typeof title !== 'string' || title.trim() === "") {
            console.log(`${logPrefix}Input title invalid or empty, defaulting to "downloaded_document.${defaultExtension}".`);
            return ensureLength(`downloaded_document.${defaultExtension}`);
        }
        let trimmedTitle = title.trim();
        let baseNamePart = "";
        let extensionPart = "";
        const fullTitleMatch = trimmedTitle.match(FILENAME_WITH_EXT_REGEX);
        if (fullTitleMatch) {
            const potentialBase = fullTitleMatch[1];
            const potentialExt = fullTitleMatch[2].toLowerCase();
            if (!INVALID_FILENAME_CHARS_REGEX.test(potentialBase.replace(/\s/g, '_'))) {
                baseNamePart = potentialBase;
                extensionPart = potentialExt;
                console.log(`${logPrefix}Entire title "${trimmedTitle}" matches basename.ext. Base: "${baseNamePart}", Ext: "${extensionPart}"`);
            }
        }
        if (!extensionPart) { 
            let lastMatch = null;
            let currentMatch;
            SUBSTRING_FILENAME_REGEX.lastIndex = 0; 
            while ((currentMatch = SUBSTRING_FILENAME_REGEX.exec(trimmedTitle)) !== null) {
                lastMatch = currentMatch;
            }
            if (lastMatch) {
                const substringExtMatch = lastMatch[1].match(FILENAME_WITH_EXT_REGEX);
                if (substringExtMatch) {
                    baseNamePart = substringExtMatch[1];
                    extensionPart = substringExtMatch[2].toLowerCase();
                    console.log(`${logPrefix}Found substring "${lastMatch[1]}" matching basename.ext. Base: "${baseNamePart}", Ext: "${extensionPart}"`);
                }
            }
        }
        if (extensionPart) { 
            const sanitizedBase = sanitizeBasename(baseNamePart);
            return ensureLength(`${sanitizedBase}.${extensionPart}`);
        } else {
            console.log(`${logPrefix}No basename.ext pattern found. Sanitizing full title "${trimmedTitle}" with default extension "${defaultExtension}".`);
            const sanitizedTitleBase = sanitizeBasename(trimmedTitle);
            return ensureLength(`${sanitizedTitleBase}.${defaultExtension}`);
        }
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
        const titleTextElement = document.querySelector(GEMINI_CANVAS_TITLE_TEXT_SELECTOR);
        if (!titleTextElement) {
            console.warn("Gemini Mod Userscript: No active canvas title found. Selector:", GEMINI_CANVAS_TITLE_TEXT_SELECTOR);
            displayUserscriptMessage("No active canvas found to download.");
            return;
        }
        console.log("Gemini Mod Userscript: Found canvas title element:", titleTextElement);

        const toolbarElement = titleTextElement.closest('code-immersive-panel > toolbar'); 
        if (!toolbarElement) {
            console.warn("Gemini Mod Userscript: Could not find parent toolbar for the title element.");
            displayUserscriptMessage("Could not locate the toolbar for the active canvas.");
            return;
        }
        console.log("Gemini Mod Userscript: Found toolbar element relative to title:", toolbarElement);

        const copyButton = toolbarElement.querySelector(GEMINI_COPY_BUTTON_IN_TOOLBAR_SELECTOR);
        if (!copyButton) {
            console.warn("Gemini Mod Userscript: 'Copy to Clipboard' button not found within the identified toolbar. Selector used:", GEMINI_COPY_BUTTON_IN_TOOLBAR_SELECTOR);
            displayUserscriptMessage("Could not find the 'Copy to Clipboard' button in the active canvas's toolbar.");
            return;
        }
        console.log("Gemini Mod Userscript: Found 'Copy to Clipboard' button:", copyButton);
        copyButton.click();
        console.log("Gemini Mod Userscript: Programmatically clicked 'Copy to Clipboard' button.");

        setTimeout(async () => {
            try {
                if (!navigator.clipboard || !navigator.clipboard.readText) {
                    displayUserscriptMessage("Clipboard access not available.");
                    return;
                }
                const clipboardContent = await navigator.clipboard.readText();
                console.log("Gemini Mod Userscript: Successfully read from clipboard.");
                if (!clipboardContent || clipboardContent.trim() === "") {
                    displayUserscriptMessage("Clipboard empty after copy. Nothing to download.");
                    return;
                }
                
                const canvasTitle = (titleTextElement.textContent || "Untitled Canvas").trim();
                const filename = determineFilename(canvasTitle); 
                triggerDownload(filename, clipboardContent);
                console.log("Gemini Mod Userscript: Global download initiated for canvas title:", canvasTitle, "using clipboard content. Filename:", filename);
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
