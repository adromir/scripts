// ==UserScript==
// @name          Google Gemini Mod (Toolbar & Download)
// @namespace     http://tampermonkey.net/
// @version       0.0.8
// @description   Enhances Google Gemini with a configurable toolbar for snippets and canvas content download.
// @description[de] Verbessert Google Gemini mit einer konfigurierbaren Symbolleiste für Snippets und dem Herunterladen von Canvas-Inhalten.
// @author        Adromir
// @match         https://gemini.google.com/*
// @icon          https://www.google.com/s2/favicons?sz=64&domain=gemini.google.com
// @license       MIT
// @licenseURL    https://opensource.org/licenses/MIT
// @homepageURL   https://github.com/adromir/scripts/tree/main/userscripts/gemini-snippets
// @supportURL    https://github.com/adromir/scripts/issues
// @grant         GM_addStyle
// @grant         GM_setValue
// @grant         GM_getValue
// @downloadURL https://update.greasyfork.org/scripts/536192/Google%20Gemini%20Mod%20%28Toolbar%20%20Download%29.user.js
// @updateURL https://update.greasyfork.org/scripts/536192/Google%20Gemini%20Mod%20%28Toolbar%20%20Download%29.meta.js
// ==/UserScript==

(function() {
    'use strict';

    // ===================================================================================
    // I. CONFIGURATION SECTION
    // ===================================================================================

    const STORAGE_KEY_BUTTONS = "geminiModButtons";
    const STORAGE_KEY_DROPDOWNS = "geminiModDropdowns";

    // --- Customizable Labels for Toolbar Buttons ---
    const PASTE_BUTTON_LABEL = "📋 Paste";
    const DOWNLOAD_BUTTON_LABEL = "💾 Download Canvas";
    const SETTINGS_BUTTON_LABEL = "⚙️ Settings";

    // --- CSS Selectors for DOM Elements ---
    const GEMINI_CANVAS_TITLE_TEXT_SELECTOR = "code-immersive-panel > toolbar > div > div.left-panel > h2.title-text.gds-title-s.ng-star-inserted";
    const GEMINI_CANVAS_SHARE_BUTTON_SELECTOR = "toolbar div.action-buttons share-button > button";
    const GEMINI_CANVAS_COPY_BUTTON_SELECTOR = "copy-button[data-test-id='copy-button'] > button.copy-button";
    const GEMINI_INPUT_FIELD_SELECTORS = ['.ql-editor p', '.ql-editor', 'div[contenteditable="true"]'];

    // --- Download Feature Configuration ---
    const DEFAULT_DOWNLOAD_EXTENSION = "txt";

    // --- Regular Expressions for Filename Sanitization ---
    // eslint-disable-next-line no-control-regex
    const INVALID_FILENAME_CHARS_REGEX = /[<>:"/\\|?*\x00-\x1F]/g;
    const RESERVED_WINDOWS_NAMES_REGEX = /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i;
    const FILENAME_WITH_EXT_REGEX = /^(.+)\.([a-zA-Z0-9]{1,8})$/;
    const SUBSTRING_FILENAME_REGEX = /([\w\s.,\-()[\\]{}'!~@#$%^&+=]+?\.([a-zA-Z0-9]{1,8}))(?=\s|$|[,.;:!?])/g;

    // ===================================================================================
    // II. DEFAULT TOOLBAR DEFINITIONS (Used if no custom config is saved)
    // ===================================================================================

    const defaultButtonSnippets = [
        { label: "Greeting", text: "Hello Gemini!" },
        { label: "Explain", text: "Could you please explain ... in more detail?" },
    ];

    const defaultDropdownConfigurations = [
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

    // ===================================================================================
    // III. SCRIPT LOGIC
    // ===================================================================================

    let currentButtonSnippets = [];
    let currentDropdownConfigurations = [];

    const embeddedCSS = `
        /* --- Toolbar Styles --- */
        #gemini-snippet-toolbar-userscript {
            position: fixed !important; top: 0 !important; left: 50% !important;
            transform: translateX(-50%) !important;
            width: auto !important; max-width: 80% !important;
            padding: 10px 15px !important; z-index: 999999 !important;
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
            padding-right: 25px !important; appearance: none !important;
            background-image: url('data:image/svg+xml;charset=US-ASCII,<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="%23e3e3e3" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z"/></svg>') !important;
            background-repeat: no-repeat !important; background-position: right 8px center !important; background-size: 12px 12px !important;
        }
        #gemini-snippet-toolbar-userscript option {
            background-color: #2a2a2a !important; color: #e3e3e3 !important;
            font-weight: normal !important; padding: 5px 10px !important;
        }
        #gemini-snippet-toolbar-userscript button:hover,
        #gemini-snippet-toolbar-userscript select:hover { background-color: #4a4e51 !important; }
        #gemini-snippet-toolbar-userscript button:active { background-color: #5f6368 !important; transform: scale(0.98) !important; }
        .userscript-toolbar-spacer { margin-left: auto !important; }

        /* --- Settings Panel Styles --- */
        #gemini-mod-settings-panel {
            display: none; position: fixed; top: 50%; left: 50%;
            transform: translate(-50%, -50%); z-index: 1000000;
            background-color: #282a2c; color: #e3e3e3; border-radius: 16px;
            padding: 20px; box-shadow: 0 8px 24px rgba(0,0,0,0.5);
            width: 90vw; max-width: 800px; max-height: 80vh; overflow-y: auto;
            font-family: 'Roboto', 'Arial', sans-serif !important;
        }
        #gemini-mod-settings-panel h2 { margin-top: 0; border-bottom: 1px solid #444; padding-bottom: 10px; }
        #gemini-mod-settings-panel .settings-section { margin-bottom: 20px; }
        #gemini-mod-settings-panel label { display: block; margin: 10px 0 5px; font-weight: 500; }
        #gemini-mod-settings-panel input[type="text"], #gemini-mod-settings-panel textarea {
            width: 100%; padding: 8px; border-radius: 8px; border: 1px solid #5f6368;
            background-color: #202122; color: #e3e3e3; box-sizing: border-box;
        }
        #gemini-mod-settings-panel textarea { min-height: 80px; resize: vertical; }
        #gemini-mod-settings-panel .item-group {
            border: 1px solid #444; border-radius: 8px; padding: 15px; margin-bottom: 10px;
            display: grid; grid-template-columns: 1fr 1fr auto; gap: 10px; align-items: center;
        }
         #gemini-mod-settings-panel .dropdown-item-group {
            border: 1px solid #444; border-radius: 8px; padding: 15px; margin-bottom: 10px;
        }
        #gemini-mod-settings-panel .dropdown-options-container { margin-left: 20px; margin-top: 10px; }
        #gemini-mod-settings-panel .option-item { display: grid; grid-template-columns: 1fr 1fr auto; gap: 10px; align-items: center; margin-bottom: 5px; }
        #gemini-mod-settings-panel button {
             padding: 4px 10px !important; cursor: pointer !important; background-color: #3c4043 !important;
             color: #e3e3e3 !important; border-radius: 16px !important; font-size: 13px !important;
             border: none !important; transition: background-color 0.2s ease;
        }
        #gemini-mod-settings-panel button:hover { background-color: #4a4e51 !important; }
        #gemini-mod-settings-panel .remove-btn { background-color: #5c2b2b !important; }
        #gemini-mod-settings-panel .remove-btn:hover { background-color: #7d3a3a !important; }
        #gemini-mod-settings-panel .settings-actions { text-align: right; margin-top: 20px; }
    `;

    // --- Core Functions ---

    function injectCustomCSS() {
        try {
            GM_addStyle(embeddedCSS);
        } catch (error) {
            console.error("Gemini Mod Userscript: Failed to inject custom CSS:", error);
            const style = document.createElement('style');
            style.textContent = embeddedCSS;
            document.head.appendChild(style);
        }
    }

    function displayUserscriptMessage(message, isError = true) {
        const prefix = "Gemini Mod Userscript: ";
        if (isError) console.error(prefix + message);
        else console.log(prefix + message);
        alert(prefix + message);
    }

    // --- Text Insertion Logic ---

    function findTargetInputElement() {
        for (const selector of GEMINI_INPUT_FIELD_SELECTORS) {
            const element = document.querySelector(selector);
            if (element) {
                if (element.classList.contains('ql-editor')) {
                    return element.querySelector('p') || element;
                }
                return element;
            }
        }
        return null;
    }

    function insertSnippetText(textToInsert) {
        const target = findTargetInputElement();
        if (!target) {
            displayUserscriptMessage("Could not find Gemini input field.");
            return;
        }
        target.focus();
        setTimeout(() => {
            try {
                document.execCommand('insertText', false, textToInsert);
            } catch (e) {
                console.warn("Gemini Mod: execCommand failed, falling back to textContent.", e);
                target.textContent += textToInsert;
            }
            target.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }));
        }, 50);
    }


    // --- Configuration Management ---

    async function loadConfiguration() {
        try {
            const savedButtons = await GM_getValue(STORAGE_KEY_BUTTONS);
            const savedDropdowns = await GM_getValue(STORAGE_KEY_DROPDOWNS);

            currentButtonSnippets = savedButtons ? JSON.parse(savedButtons) : defaultButtonSnippets;
            currentDropdownConfigurations = savedDropdowns ? JSON.parse(savedDropdowns) : defaultDropdownConfigurations;
        } catch (e) {
            console.error("Gemini Mod: Error loading configuration, using defaults.", e);
            currentButtonSnippets = defaultButtonSnippets;
            currentDropdownConfigurations = defaultDropdownConfigurations;
        }
    }

    async function saveConfiguration() {
        const settingsPanel = document.getElementById('gemini-mod-settings-panel');
        if (!settingsPanel) return;

        // Save Buttons
        const newButtons = [];
        settingsPanel.querySelectorAll('#settings-buttons .item-group').forEach(group => {
            const label = group.querySelector('.label-input').value.trim();
            const text = group.querySelector('.text-input').value;
            if (label) newButtons.push({ label, text });
        });

        // Save Dropdowns
        const newDropdowns = [];
        settingsPanel.querySelectorAll('#settings-dropdowns .dropdown-item-group').forEach(group => {
            const placeholder = group.querySelector('.placeholder-input').value.trim();
            const options = [];
            group.querySelectorAll('.option-item').forEach(opt => {
                const label = opt.querySelector('.label-input').value.trim();
                const text = opt.querySelector('.text-input').value;
                if (label) options.push({ label, text });
            });
            if (placeholder && options.length > 0) {
                newDropdowns.push({ placeholder, options });
            }
        });

        try {
            await GM_setValue(STORAGE_KEY_BUTTONS, JSON.stringify(newButtons));
            await GM_setValue(STORAGE_KEY_DROPDOWNS, JSON.stringify(newDropdowns));
            await loadConfiguration(); // Reload current config from storage
            rebuildToolbar();
            toggleSettingsPanel(false);
            console.log("Gemini Mod: Settings saved.");
        } catch (e) {
            displayUserscriptMessage("Failed to save settings. See console for details.");
            console.error("Gemini Mod: Error saving settings:", e);
        }
    }

    // --- Toolbar Creation ---

    function createToolbar() {
        const toolbarId = 'gemini-snippet-toolbar-userscript';
        let toolbar = document.getElementById(toolbarId);
        if (toolbar) toolbar.innerHTML = ''; // Clear existing toolbar if rebuilding
        else {
            toolbar = document.createElement('div');
            toolbar.id = toolbarId;
            document.body.insertBefore(toolbar, document.body.firstChild);
        }

        // Snippet Buttons
        currentButtonSnippets.forEach(snippet => {
            const button = document.createElement('button');
            button.textContent = snippet.label;
            button.title = snippet.text;
            button.addEventListener('click', () => insertSnippetText(snippet.text));
            toolbar.appendChild(button);
        });

        // Dropdowns
        currentDropdownConfigurations.forEach(config => {
            const select = document.createElement('select');
            select.title = config.placeholder;
            const defaultOption = new Option(config.placeholder, "", true, true);
            defaultOption.disabled = true;
            select.appendChild(defaultOption);
            config.options.forEach(opt => select.appendChild(new Option(opt.label, opt.text)));
            select.addEventListener('change', (e) => {
                if (e.target.value) {
                    insertSnippetText(e.target.value);
                    e.target.selectedIndex = 0;
                }
            });
            toolbar.appendChild(select);
        });

        // Spacer & Action Buttons
        const spacer = document.createElement('div');
        spacer.className = 'userscript-toolbar-spacer';
        toolbar.appendChild(spacer);

        const pasteButton = document.createElement('button');
        pasteButton.textContent = PASTE_BUTTON_LABEL;
        pasteButton.title = "Paste from Clipboard";
        pasteButton.addEventListener('click', async () => {
             try {
                const text = await navigator.clipboard.readText();
                if (text) insertSnippetText(text);
            } catch (err) {
                displayUserscriptMessage('Failed to read clipboard: ' + err.message);
            }
        });
        toolbar.appendChild(pasteButton);

        const downloadButton = document.createElement('button');
        downloadButton.textContent = DOWNLOAD_BUTTON_LABEL;
        downloadButton.title = "Download active canvas content";
        downloadButton.addEventListener('click', handleGlobalCanvasDownload);
        toolbar.appendChild(downloadButton);

        const settingsButton = document.createElement('button');
        settingsButton.textContent = SETTINGS_BUTTON_LABEL;
        settingsButton.title = "Open Userscript Settings";
        settingsButton.addEventListener('click', () => toggleSettingsPanel());
        toolbar.appendChild(settingsButton);

        console.log("Gemini Mod: Toolbar created/updated.");
    }

    function rebuildToolbar() {
        const toolbar = document.getElementById('gemini-snippet-toolbar-userscript');
        if (toolbar) createToolbar();
    }


    // --- Settings Panel UI ---

    function createSettingsPanel() {
        if (document.getElementById('gemini-mod-settings-panel')) return;

        const panel = document.createElement('div');
        panel.id = 'gemini-mod-settings-panel';
        panel.innerHTML = `
            <h2>Gemini Mod Settings</h2>
            <div class="settings-section" id="settings-buttons">
                <h3>Buttons</h3>
                <div id="buttons-container"></div>
                <button id="add-button-btn">Add Button</button>
            </div>
            <div class="settings-section" id="settings-dropdowns">
                <h3>Dropdowns</h3>
                <div id="dropdowns-container"></div>
                <button id="add-dropdown-btn">Add Dropdown</button>
            </div>
            <div class="settings-actions">
                <button id="settings-save-btn">Save & Close</button>
                <button id="settings-cancel-btn">Cancel</button>
            </div>
        `;
        document.body.appendChild(panel);

        // Event Listeners
        document.getElementById('settings-save-btn').addEventListener('click', saveConfiguration);
        document.getElementById('settings-cancel-btn').addEventListener('click', () => toggleSettingsPanel(false));
        document.getElementById('add-button-btn').addEventListener('click', () => addButtonToPanel());
        document.getElementById('add-dropdown-btn').addEventListener('click', () => addDropdownToPanel());
    }

    function populateSettingsPanel() {
        const buttonsContainer = document.getElementById('buttons-container');
        const dropdownsContainer = document.getElementById('dropdowns-container');
        buttonsContainer.innerHTML = '';
        dropdownsContainer.innerHTML = '';

        currentButtonSnippets.forEach(btn => addButtonToPanel(btn));
        currentDropdownConfigurations.forEach(dd => addDropdownToPanel(dd));
    }

    function addButtonToPanel(button = { label: '', text: '' }) {
        const container = document.getElementById('buttons-container');
        const group = document.createElement('div');
        group.className = 'item-group';
        group.innerHTML = `
            <div>
                <label>Button Label</label>
                <input type="text" class="label-input" value="${button.label}">
            </div>
            <div>
                <label>Snippet Text</label>
                <textarea class="text-input">${button.text}</textarea>
            </div>
            <button class="remove-btn">Remove</button>
        `;
        group.querySelector('.remove-btn').addEventListener('click', () => group.remove());
        container.appendChild(group);
    }

    function addDropdownToPanel(dropdown = { placeholder: '', options: [] }) {
        const container = document.getElementById('dropdowns-container');
        const group = document.createElement('div');
        group.className = 'dropdown-item-group';
        group.innerHTML = `
            <div>
                <label>Dropdown Placeholder</label>
                <input type="text" class="placeholder-input" value="${dropdown.placeholder}">
                <button class="remove-btn" style="float: right;">Remove Dropdown</button>
            </div>
            <div class="dropdown-options-container">
                <label>Options</label>
            </div>
            <button class="add-option-btn">Add Option</button>
        `;
        group.querySelector('.remove-btn').addEventListener('click', () => group.remove());
        group.querySelector('.add-option-btn').addEventListener('click', (e) => {
            const optionsContainer = e.target.previousElementSibling;
            addOptionToDropdownPanel(optionsContainer);
        });

        const optionsContainer = group.querySelector('.dropdown-options-container');
        if (dropdown.options.length > 0) {
            dropdown.options.forEach(opt => addOptionToDropdownPanel(optionsContainer, opt));
        } else {
             addOptionToDropdownPanel(optionsContainer); // Add one empty option by default
        }

        container.appendChild(group);
    }

    function addOptionToDropdownPanel(container, option = { label: '', text: '' }) {
        const item = document.createElement('div');
        item.className = 'option-item';
        item.innerHTML = `
            <input type="text" class="label-input" placeholder="Option Label" value="${option.label}">
            <textarea class="text-input" placeholder="Snippet Text">${option.text}</textarea>
            <button class="remove-btn">X</button>
        `;
        item.querySelector('.remove-btn').addEventListener('click', () => item.remove());
        container.appendChild(item);
    }


    function toggleSettingsPanel(forceState) {
        const panel = document.getElementById('gemini-mod-settings-panel');
        if (!panel) return;
        const isVisible = panel.style.display === 'block';
        const show = typeof forceState === 'boolean' ? forceState : !isVisible;

        if (show) {
            populateSettingsPanel();
            panel.style.display = 'block';
        } else {
            panel.style.display = 'none';
        }
    }


    // --- Download Logic ---
    // (This section remains largely unchanged)

    function sanitizeBasename(baseName) {
        if (typeof baseName !== 'string' || baseName.trim() === "") return "downloaded_document";
        let sanitized = baseName.trim()
            .replace(INVALID_FILENAME_CHARS_REGEX, '_')
            .replace(/\s+/g, '_')
            .replace(/__+/g, '_')
            .replace(/^[_.-]+|[_.-]+$/g, '');
        if (!sanitized || RESERVED_WINDOWS_NAMES_REGEX.test(sanitized)) {
            sanitized = `_${sanitized || "file"}_`;
        }
        return sanitized || "downloaded_document";
    }

    function determineFilename(title) {
        if (!title || typeof title !== 'string' || title.trim() === "") {
            return `downloaded_document.${DEFAULT_DOWNLOAD_EXTENSION}`;
        }
        const match = title.trim().match(FILENAME_WITH_EXT_REGEX);
        if (match) {
            const base = sanitizeBasename(match[1]);
            const ext = match[2].toLowerCase();
            return `${base}.${ext}`;
        }
        return `${sanitizeBasename(title)}.${DEFAULT_DOWNLOAD_EXTENSION}`;
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
        } catch (error) {
            displayUserscriptMessage(`Failed to download: ${error.message}`);
        }
    }

    async function handleGlobalCanvasDownload() {
        const titleEl = document.querySelector(GEMINI_CANVAS_TITLE_TEXT_SELECTOR);
        if (!titleEl) return displayUserscriptMessage("No active canvas found to download.");

        const panelEl = titleEl.closest('code-immersive-panel');
        const shareButton = panelEl?.querySelector(GEMINI_CANVAS_SHARE_BUTTON_SELECTOR);
        if (!shareButton) return displayUserscriptMessage("Could not find the 'Share' button.");

        shareButton.click();

        setTimeout(() => {
            const copyButton = document.querySelector(GEMINI_CANVAS_COPY_BUTTON_SELECTOR);
            if (!copyButton) return displayUserscriptMessage("Could not find the 'Copy' button after sharing.");

            copyButton.click();

            setTimeout(async () => {
                try {
                    const content = await navigator.clipboard.readText();
                    if (!content) return displayUserscriptMessage("Clipboard empty. Nothing to download.");
                    const filename = determineFilename(titleEl.textContent);
                    triggerDownload(filename, content);
                } catch (err) {
                    displayUserscriptMessage('Clipboard permission denied or failed to read.');
                }
            }, 300);
        }, 500);
    }

    // --- Initialization ---

    async function init() {
        console.log("Gemini Mod Userscript: Initializing...");
        injectCustomCSS();
        await loadConfiguration();
        // Delay initialization to ensure Gemini UI is loaded
        setTimeout(() => {
            try {
                createToolbar();
                createSettingsPanel();
                console.log("Gemini Mod Userscript: Fully initialized.");
            } catch (e) {
                console.error("Gemini Mod: Error during delayed initialization:", e);
                displayUserscriptMessage("Error initializing toolbar. See console.");
            }
        }, 1500);
    }

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
