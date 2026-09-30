// ==UserScript==
// @name          Google Gemini Mod (Toolbar, Folders & Download)
// @namespace     http://tampermonkey.net/
// @version       0.0.30
// @description   Enhances Google Gemini with a configurable toolbar and sidebar folders to organize conversations.
// @description[de] Verbessert Google Gemini mit einer konfigurierbaren Symbolleiste und Ordnern in der Seitenleiste, um Konversationen zu organisieren.
// @author        Adromir
// @license       MIT
// @match         https://gemini.google.com/*
// @icon          https://raw.githubusercontent.com/adromir/google-gemini-mod/refs/heads/main/icon.svg
// @supportURL    https://github.com/adromir/scripts/issues
// @grant         GM_addStyle
// @grant         GM_addElement
// @grant         GM_setValue
// @grant         GM_getValue
// @grant         GM_deleteValue
// @grant         GM_xmlhttpRequest
// @grant         unsafeWindow
// @require       https://cdn.jsdelivr.net/npm/sortablejs@1.15.7/Sortable.min.js
// @require       https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js
// @require       https://update.greasyfork.org/scripts/584958/gemini_mod_styles.js
// @require       https://update.greasyfork.org/scripts/584959/gemini_mod_utils.js
// @require       https://update.greasyfork.org/scripts/584956/gemini_mod_drivejs.js
// @downloadURL   https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js
// @updateURL     https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js
// ==/UserScript==

(function () {
	'use strict';

	// Ensure Namespace exists
	window.GeminiMod = window.GeminiMod || {};

	// Embedded styles to guarantee instant updates and protect against stale CDN caches
	window.GeminiMod.styles = `
    /* --- Toolbar Styles --- */
    #gemini-snippet-toolbar-userscript {
        position: fixed !important; top: 0 !important; left: 50% !important;
        transform: translateX(-50%) !important;
        width: auto !important; max-width: 80% !important;
        padding: 10px 15px !important; z-index: 999998 !important; /* Below settings panel */
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

    /* --- Settings Panel & Modal Styles --- */
    #gemini-mod-settings-overlay, #gemini-mod-type-modal-overlay {
        display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
        background-color: rgba(0,0,0,0.6); z-index: 999999;
    }
    #gemini-mod-settings-panel, #gemini-mod-type-modal {
        position: fixed; top: 50%; left: 50%;
        transform: translate(-50%, -50%);
        background-color: #282a2c; color: #e3e3e3; border-radius: 16px;
        padding: 20px; box-shadow: 0 8px 24px rgba(0,0,0,0.5);
        font-family: 'Roboto', 'Arial', sans-serif !important;
    }
    #gemini-mod-settings-panel {
        width: 90vw; max-width: 800px; max-height: 80vh; overflow-y: auto;
    }
    #gemini-mod-type-modal {
        text-align: center;
    }
    #gemini-mod-type-modal h3 { margin-top: 0; }
    #gemini-mod-type-modal button { margin: 0 10px; }
    #gemini-mod-settings-panel h2 { margin-top: 0; border-bottom: 1px solid #444; padding-bottom: 10px; }
    #gemini-mod-settings-panel h3 { margin-top: 20px; border-bottom: 1px solid #444; padding-bottom: 8px; }
    #gemini-mod-settings-panel label { display: block; margin: 10px 0 5px; font-weight: 500; }
    #gemini-mod-settings-panel input[type="text"], #gemini-mod-settings-panel textarea {
        width: 100%; padding: 8px; border-radius: 8px; border: 1px solid #5f6368;
        background-color: #202122; color: #e3e3e3; box-sizing: border-box;
    }
    #gemini-mod-settings-panel textarea { min-height: 80px; resize: vertical; }
    #gemini-mod-settings-panel .item-group {
        border: 1px solid #444; border-radius: 8px; padding: 15px; margin-bottom: 10px;
        display: flex; gap: 10px; align-items: flex-start;
        cursor: grab;
    }
    #gemini-mod-settings-panel .item-content { flex-grow: 1; }
    #gemini-mod-settings-panel .dropdown-options-container { margin-left: 20px; margin-top: 10px; }
    #gemini-mod-settings-panel .option-item { display: grid; grid-template-columns: 1fr 1fr auto; gap: 10px; align-items: center; margin-bottom: 5px; }
    #gemini-mod-settings-panel button {
            padding: 4px 10px !important; cursor: pointer !important; background-color: #3c4043 !important;
            color: #e3e3e3 !important; border-radius: 16px !important; font-size: 13px !important;
            border: none !important; transition: background-color 0.2s ease;
    }
    #gemini-mod-settings-panel button:hover { background-color: #4a4e51 !important; }
    #gemini-mod-settings-panel .remove-btn, .dialog-btn-delete { background-color: #5c2b2b !important; color: white !important; }
    #gemini-mod-settings-panel .remove-btn:hover, .dialog-btn-delete:hover { background-color: #7d3a3a !important; }
    #gemini-mod-settings-panel .settings-actions {
        margin-top: 20px; display: flex; justify-content: flex-end; gap: 8px;
    }

    /* --- Folder UI Styles --- */
    /* Match Gemini sidebar design: Google Sans font, Material colors, proper spacing */
    #folder-ui-container {
        display: block;
        width: 100%;
        margin: 0 !important;
        padding: 0;
        font-family: "Google Sans Flex","Google Sans Text","Google Sans",sans-serif;
        box-sizing: border-box;
    }

    /* --- Section header: matches "Notebooks" style --- */
    #folder-section-header {
        display: flex;
        flex-direction: row;
        align-items: center;
        justify-content: space-between;
        width: calc(100% - 16px) !important;
        margin: 2px 8px !important;
        box-sizing: border-box !important;
        padding: 0 12px !important;
        min-height: 36px !important;
        background: transparent !important;
        border: none !important;
        border-radius: 9999px !important;
        cursor: pointer;
        text-align: left;
        color: #c4c7c5 !important;
        font-family: inherit;
        gap: 8px;
        transition: background-color 0.15s ease, color 0.15s ease;
        outline: none;
    }
    #folder-section-header:hover {
        background-color: rgba(227, 227, 227, 0.08) !important;
        color: #e3e3e3 !important;
    }
    #folder-section-header .expandable-section-title {
        flex: 1;
        min-width: 0;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        font-size: 0.875rem;
        font-weight: 500;
        line-height: 1.25rem;
    }
    #folder-section-header .toggle-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 20px;
        height: 20px;
        flex-shrink: 0;
        margin-left: auto;
        color: #c4c7c5;
        transition: color 0.15s ease;
    }
    #folder-section-header .toggle-icon svg {
        display: block;
        transition: transform 0.2s ease;
    }
    #folder-section-header.collapsed .toggle-icon svg {
        transform: rotate(-90deg) !important;
    }
    #folder-section-header:not(.collapsed) .toggle-icon svg {
        transform: rotate(0deg) !important;
    }
    #folder-section-header:hover .toggle-icon {
        color: #e3e3e3;
    }
    
    /* Folder Items & Add Button */
    #folder-container { padding-bottom: 4px; }
    
    #add-folder-btn {
        display: flex;
        flex-direction: row;
        align-items: center;
        justify-content: flex-start;
        width: calc(100% - 16px) !important;
        margin: 2px 8px !important;
        box-sizing: border-box !important;
        padding: 0 12px !important;
        min-height: 36px !important;
        background: transparent !important;
        border: none !important;
        color: #c4c7c5 !important;
        border-radius: 9999px !important;
        cursor: pointer;
        text-align: left;
        font-family: "Google Sans Flex","Google Sans Text","Google Sans",sans-serif;
        font-size: 0.875rem;
        font-weight: 400;
        gap: 0 !important;
        transition: background-color 0.15s ease, color 0.15s ease;
        outline: none;
    }
    #add-folder-btn::before { content: none !important; }
    #add-folder-btn:hover {
        background-color: rgba(227, 227, 227, 0.08) !important;
        color: #e3e3e3 !important;
    }
    
    .add-folder-icon, .folder-icon-wrapper { 
        margin-right: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
    }

    /* Folder Specific */
    .folder { margin: 0; padding: 0; overflow: visible; }
    .folder-header {
        display: flex;
        flex-direction: row;
        align-items: center;
        justify-content: flex-start;
        width: calc(100% - 16px) !important;
        margin: 2px 8px !important;
        box-sizing: border-box !important;
        padding: 0 12px !important;
        min-height: 36px !important;
        background: transparent !important;
        border: none !important;
        color: #e3e3e3 !important;
        border-radius: 9999px !important;
        cursor: pointer;
        text-align: left;
        position: relative;
        font-family: "Google Sans Flex","Google Sans Text","Google Sans",sans-serif;
        font-size: 0.875rem;
        transition: background-color 0.15s ease;
        outline: none;
    }
    .folder-header:hover {
        background-color: rgba(227, 227, 227, 0.08) !important;
    }
    .folder-header.folder-drag-over {
        background-color: rgba(227, 227, 227, 0.16) !important;
        outline: 1px dashed #a8c7fa !important;
        outline-offset: -1px;
    }
    .folder-name {
        flex: 1;
        min-width: 0;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        margin-left: 0;
        padding-right: 8px;
        font-size: 0.875rem;
        color: #e3e3e3 !important;
    }

    .folder-controls {
        display: flex !important;
        align-items: center;
        gap: 2px;
        flex-shrink: 0;
        margin-left: auto;
    }
    .folder-options-btn {
        background: none !important;
        border: none !important;
        color: #c4c7c5 !important;
        cursor: pointer;
        padding: 0;
        border-radius: 50% !important;
        width: 24px;
        height: 24px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        font-size: 1.1em;
        line-height: 1;
        opacity: 0;
        transition: opacity 0.15s ease, background-color 0.15s ease, color 0.15s ease;
    }
    .folder-header:hover .folder-options-btn {
        opacity: 1;
    }
    .folder-options-btn:hover {
        background-color: rgba(227, 227, 227, 0.12) !important;
        color: #fff !important;
    }

    .folder-toggle-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 20px;
        height: 20px;
        flex-shrink: 0;
        color: #c4c7c5;
        transition: color 0.15s ease;
        cursor: pointer;
    }
    .folder-toggle-icon svg {
        display: block;
        transition: transform 0.2s ease;
    }
    .folder.closed .folder-toggle-icon svg {
        transform: rotate(-90deg) !important;
    }
    .folder:not(.closed) .folder-toggle-icon svg {
        transform: rotate(0deg) !important;
    }
    .folder-header:hover .folder-toggle-icon {
        color: #e3e3e3;
    }

    /* Folder content area - items inside */
    .folder-content {
        min-height: 0;
        max-height: 2000px;
        overflow: hidden;
        transition: max-height 0.25s ease-in-out;
    }
    .folder.closed .folder-content {
        max-height: 0 !important;
    }

    /* Chat items inside folders - match gem-nav-list-item look */
    .folder-content .conversation-items-container,
    .folder-content gem-nav-list-item {
        display: block;
        border-radius: 9999px !important;
        margin: 2px 8px !important;
        width: calc(100% - 16px) !important;
        box-sizing: border-box !important;
        padding: 0;
        border: none;
        transition: background-color 0.15s;
        position: relative;
    }
    .folder-content .conversation-items-container::before,
    .folder-content gem-nav-list-item::before {
        content: none;
    }
    .folder-content .conversation-items-container:hover,
    .folder-content gem-nav-list-item:hover {
        background-color: rgba(227, 227, 227, 0.08) !important;
    }

    .conversation-items-container, gem-nav-list-item { cursor: grab; }

    .folder-context-menu {
        position: fixed; z-index: 10000;
        background-color: #1e1f20;
        border: 1px solid #444746;
        border-radius: 4px;
        padding: 8px 0;
        box-shadow: 0px 3px 1px -2px rgba(0,0,0,0.2),0px 2px 2px 0px rgba(0,0,0,0.14),0px 1px 5px 0px rgba(0,0,0,0.12);
        display: none;
        min-width: 160px;
    }
    .folder-context-menu-item {
        padding: 8px 12px; cursor: pointer; white-space: nowrap;
        font-family: "Google Sans Flex","Google Sans Text","Google Sans",sans-serif;
        font-size: 0.875rem; font-weight: 500; line-height: 1.25rem;
        color: #e3e3e3;
    }
    .folder-context-menu-item:hover { background-color: rgba(227, 227, 227, 0.08); }
    .folder-context-menu-item.delete { color: #f2b8b5; }
    .folder-context-menu-item.delete:hover { background-color: rgba(242, 184, 181, 0.08); }

    .sortable-ghost { opacity: 0.4; }
    .item-group.sortable-ghost { background-color: #555 !important; }


    /* --- Dialog & Color Picker Styles --- */
    .custom-dialog-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(34, 34, 34, 0.75); z-index: 1000000; display: flex; align-items: center; justify-content: center; }
    .custom-dialog-box { background-color: #333333; padding: 25px; border-radius: 12px; box-shadow: 0 5px 15px rgba(0,0,0,0.3); text-align: center; max-width: 400px; border: 1px solid var(--surface-4); }
    .custom-dialog-box p, .custom-dialog-box h2 { margin: 0 0 20px; font-family: 'Roboto', Arial, sans-serif; color: #FFFFFF; }
    .custom-dialog-btn { border: none; border-radius: 8px; padding: 10px 20px; cursor: pointer; font-weight: 500; margin: 0 10px; }
    .dialog-btn-confirm { background-color: #8ab4f8; color: #202124; }
    .dialog-btn-cancel { background-color: var(--surface-4); color: var(--on-surface); }
    .custom-dialog-input { width: 100%; box-sizing: border-box; padding: 10px; border-radius: 8px; border: 1px solid var(--surface-4); background-color: var(--surface-1); color: var(--on-surface); font-size: 16px; margin-bottom: 20px; }
    .color-picker-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px; margin-bottom: 20px; }
    .color-picker-dialog .color-swatch { width: 32px; height: 32px; border-radius: 50%; cursor: pointer; border: 2px solid transparent; position: relative; }
    .color-picker-dialog .color-swatch:hover { border: 2px solid var(--on-primary-surface); }
    .color-picker-dialog .color-swatch.selected::after { content: ""; position: absolute; inset: 0; border: 3px solid #fff; border-radius: 50%; box-sizing: border-box; pointer-events: none; }

    /* --- Tabbed Settings Styles --- */
    #gemini-mod-settings-panel h2 { margin-top: 0; border-bottom: 1px solid #444; padding-bottom: 15px; margin-bottom: 0; }
    .settings-container { display: flex; height: 500px; min-height: 400px; }
    .settings-sidebar { width: 180px; border-right: 1px solid #444; padding: 15px 10px; display: flex; flex-direction: column; gap: 5px; background-color: #202122; border-bottom-left-radius: 16px; }
    .settings-content { flex-grow: 1; padding: 20px; overflow-y: auto; background-color: #282a2c; border-bottom-right-radius: 16px; }
    .tab-btn {
        text-align: left; padding: 10px 15px; background: none; border: none; color: #aaa;
        cursor: pointer; border-radius: 8px; font-size: 14px; font-weight: 500;
        transition: all 0.2s ease; width: 100%; box-sizing: border-box;
    }
    .tab-btn:hover { background-color: #3c4043; color: #e3e3e3; }
    .tab-btn.active { background-color: #4285f4; color: white; }
    .tab-pane { display: none; animation: fadeIn 0.2s; }
    .tab-pane.active { display: block; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }
    
    /* Help Link */
    .help-link { font-size: 12px; color: #8ab4f8; text-decoration: none; margin-left: 5px; display: inline-flex; align-items: center; }
    .help-link:hover { text-decoration: underline; }
	`;

	// ===================================================================================
	// I. CONFIGURATION SECTION
	// ===================================================================================

	// --- Storage Keys ---
	const STORAGE_KEY_TOOLBAR_ITEMS = "geminiModToolbarItems_v2";
	const STORAGE_KEY_FOLDERS = 'gemini_folders';
	const STORAGE_KEY_CONVO_FOLDERS = 'gemini_convo_folders';

	// --- Toolbar UI Labels ---
	const SETTINGS_BUTTON_LABEL = "⚙️ Settings";

	// --- CSS Selectors ---
	const GEMINI_DOC_CANVAS_EDITOR_SELECTOR = ".ProseMirror";
	const GEMINI_DOC_CANVAS_TITLE_SELECTOR = "h2.title-text";
	const GEMINI_INPUT_FIELD_SELECTORS = ['div[role="textbox"]', '.ql-editor p', '.ql-editor', 'div[contenteditable="true"]'];
	const FOLDER_CHAT_ITEM_SELECTOR = 'gem-nav-list-item, div[data-test-id="conversation"]';
	const FOLDER_CHAT_LIST_CONTAINER_SELECTOR = 'conversations-list mat-nav-list, mat-nav-list, conversations-list .conversations-container';
	const FOLDER_INJECTION_POINT_SELECTOR = '#sidenav-section-content-chats, conversations-list, div.chat-history-list, .conversations-list';

	// --- Download Feature Configuration ---
	const DEFAULT_DOWNLOAD_EXTENSION = "txt";

	// --- Filename Sanitization Regex ---
	// eslint-disable-next-line no-control-regex
	const INVALID_FILENAME_CHARS_REGEX = /[<>:"/\\|?*\x00-\x1F]/g;
	const RESERVED_WINDOWS_NAMES_REGEX = /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i;
	const FILENAME_WITH_EXT_REGEX = /^(.+)\.([a-zA-Z0-9]{1,8})$/;

	// ===================================================================================
	// II. DEFAULT DEFINITIONS (Used if no custom config is saved)
	// ===================================================================================

	const defaultToolbarItems = [
		{ type: 'button', label: "Greeting", text: "Hello Gemini!" },
		{ type: 'button', label: "Explain", text: "Could you please explain ... in more detail?" },
		{
			type: 'dropdown',
			placeholder: "Actions...",
			options: [
				{ label: "Summarize", text: "Please summarize the following text:\n" },
				{ label: "Ideas", text: "Give me 5 ideas for ..." },
			]
		},
		{ type: 'action', action: 'paste', label: "📋 Paste", title: "Paste from Clipboard" },
		{ type: 'action', action: 'copy', label: "📄 Copy", title: "Copy active canvas content" },
		{ type: 'action', action: 'download', label: "💾 Download", title: "Download active canvas content" },
		{ type: 'action', action: 'pdf', label: "📑 PDF", title: "Export active canvas content as PDF" }
	];

	// ===================================================================================
	// III. SCRIPT LOGIC
	// ===================================================================================

	// --- Global State ---
	let toolbarItems = [];
	let folders = [];
	let conversationFolders = {};
	const FOLDER_COLORS = ['#370000', '#0D3800', '#001B38', '#383200', '#380031', '#7DAC89', '#7A82AF', '#AC7D98', '#7AA7AF', '#9CA881'];

	// --- Core Aliases (Helpers) ---
	const displayMessage = GeminiMod.utils.displayUserscriptMessage;
	const clearEl = GeminiMod.utils.clearElement;
	const showConfirm = GeminiMod.utils.showConfirmationDialog;
	const showPrompt = GeminiMod.utils.showCustomPromptDialog;
	const showColorPicker = GeminiMod.utils.showColorPickerDialog;
	const injectCSS = function () {
		try {
			if (typeof GM_addStyle !== 'undefined') {
				GM_addStyle(window.GeminiMod.styles);
			} else {
				const style = document.createElement('style');
				style.textContent = window.GeminiMod.styles;
				document.head.appendChild(style);
			}
		} catch (error) {
			console.error("Gemini Mod Userscript: Failed to inject custom CSS:", error);
			const style = document.createElement('style');
			style.textContent = window.GeminiMod.styles;
			document.head.appendChild(style);
		}
	};

	// --- Text Insertion Logic ---

	function findTargetInputElement() {
		for (const selector of GEMINI_INPUT_FIELD_SELECTORS) {
			const element = document.querySelector(selector);
			if (element) {
				return element.classList.contains('ql-editor') ? (element.querySelector('p') || element) : element;
			}
		}
		return null;
	}

	function insertSnippetText(textToInsert) {
		const target = findTargetInputElement();
		if (!target) {
			displayMessage("Could not find Gemini input field.");
			return;
		}
		target.focus();

		// Force cursor to the end if no valid selection exists within the target
		const selection = window.getSelection();
		if (selection.rangeCount === 0 || !target.contains(selection.anchorNode)) {
			const range = document.createRange();
			range.selectNodeContents(target);
			range.collapse(false); // Collapse to end
			selection.removeAllRanges();
			selection.addRange(range);
		}

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
			// Toolbar items
			const savedToolbarItems = await GM_getValue(STORAGE_KEY_TOOLBAR_ITEMS);
			if (savedToolbarItems) {
				toolbarItems = JSON.parse(savedToolbarItems);
				// Migration: Check if actions are missing and append them if so (for existing users)
				const hasAction = (act) => toolbarItems.some(item => item.type === 'action' && item.action === act);
				if (!hasAction('paste')) toolbarItems.push({ type: 'action', action: 'paste', label: "📋 Paste", title: "Paste from Clipboard" });
				if (!hasAction('copy')) toolbarItems.push({ type: 'action', action: 'copy', label: "📄 Copy", title: "Copy active canvas content" });
				if (!hasAction('download')) toolbarItems.push({ type: 'action', action: 'download', label: "💾 Download", title: "Download active canvas content" });
				if (!hasAction('pdf')) toolbarItems.push({ type: 'action', action: 'pdf', label: "📑 PDF", title: "Export active canvas content as PDF" });
			} else {
				toolbarItems = defaultToolbarItems;
			}
			// Folder items
			folders = await GM_getValue(STORAGE_KEY_FOLDERS, []);
			conversationFolders = await GM_getValue(STORAGE_KEY_CONVO_FOLDERS, {});
		} catch (e) {
			console.error("Gemini Mod: Error loading configuration, using defaults.", e);
			toolbarItems = defaultToolbarItems;
			folders = [];
			conversationFolders = {};
		}
	}

	async function saveToolbarConfiguration() {
		const settingsPanel = document.getElementById('gemini-mod-settings-panel');
		if (!settingsPanel) return;

		const newItems = [];
		settingsPanel.querySelectorAll('#toolbar-items-container > .item-group').forEach(group => {
			const type = group.dataset.type;
			const visible = group.querySelector('.visible-checkbox').checked;

			if (type === 'button') {
				const label = group.querySelector('.label-input').value.trim();
				const text = group.querySelector('.text-input').value;
				if (label) newItems.push({ type, label, text, visible });
			} else if (type === 'dropdown') {
				const placeholder = group.querySelector('.placeholder-input').value.trim();
				const options = [];
				group.querySelectorAll('.option-item').forEach(opt => {
					const label = opt.querySelector('.label-input').value.trim();
					const text = opt.querySelector('.text-input').value;
					if (label) options.push({ label, text });
				});
				if (placeholder && options.length > 0) {
					newItems.push({ type, placeholder, options, visible });
				}
			} else if (type === 'action') {
				const action = group.dataset.action;
				const label = group.querySelector('.label-input').value.trim();
				const title = group.dataset.title;
				if (label) newItems.push({ type, action, label, title, visible });
			}
		});

		try {
			await GM_setValue(STORAGE_KEY_TOOLBAR_ITEMS, JSON.stringify(newItems));
			await loadConfiguration(); // Reload all configs
			rebuildToolbar();
			toggleSettingsPanel(false);
		} catch (e) {
			displayMessage("Failed to save settings. See console for details.");
			console.error("Gemini Mod: Error saving settings:", e);
		}
	}

	async function saveFolderConfiguration() {
		await GM_setValue(STORAGE_KEY_FOLDERS, folders);
		await GM_setValue(STORAGE_KEY_CONVO_FOLDERS, conversationFolders);
	}

	// --- Setup Guide Modal ---


	function showSetupGuide() {
		const overlay = document.createElement('div');
		overlay.className = 'custom-dialog-overlay';
		overlay.id = 'setup-guide-overlay';

		const dialogBox = document.createElement('div');
		dialogBox.className = 'custom-dialog-box';
		dialogBox.style.maxWidth = '600px';

		const h3 = document.createElement('h3');
		h3.textContent = 'Google Drive Sync Setup';
		dialogBox.appendChild(h3);

		const p1 = document.createElement('p');
		p1.textContent = '';
		p1.appendChild(document.createTextNode('To sync explicitly via Google Drive, you need a '));
		const b1 = document.createElement('b');
		b1.textContent = 'Google Cloud Client ID';
		p1.appendChild(b1);
		p1.appendChild(document.createTextNode('. This is required because this script runs privately in your browser.'));
		dialogBox.appendChild(p1);

		const ol = document.createElement('ol');
		const steps = [
			{ html: false, text: 'Go to ', link: { href: 'https://console.cloud.google.com/apis/credentials', text: 'Google Cloud Console' } },
			{ html: false, text: 'Create a new project (or use existing).' },
			{ html: false, parts: [{ text: 'Enable the ' }, { tag: 'b', text: 'Google Drive API' }, { text: '.' }] },
			{ html: false, text: 'Create Credentials -> OAuth client ID.' },
			{ html: false, parts: [{ text: 'Application type: ' }, { tag: 'b', text: 'Web application' }, { text: '.' }] },
			{ html: false, parts: [{ text: 'Add authorized origins: ' }, { tag: 'code', text: 'https://gemini.google.com' }] },
			{ html: false, parts: [{ text: 'Copy the ' }, { tag: 'b', text: 'Client ID' }, { text: ' and paste it in the settings here.' }] }
		];

		const createStep = (step) => {
			const li = document.createElement('li');
			if (step.link) {
				li.appendChild(document.createTextNode(step.text));
				const a = document.createElement('a');
				a.href = step.link.href;
				a.target = '_blank';
				a.textContent = step.link.text;
				li.appendChild(a);
				li.appendChild(document.createTextNode('.'));
			} else if (step.parts) {
				step.parts.forEach(part => {
					if (part.tag) {
						const tag = document.createElement(part.tag);
						tag.textContent = part.text;
						li.appendChild(tag);
					} else {
						li.appendChild(document.createTextNode(part.text));
					}
				});
			} else {
				li.textContent = step.text;
			}
			return li;
		};

		steps.forEach(step => ol.appendChild(createStep(step)));
		dialogBox.appendChild(ol);

		const p2 = document.createElement('p');
		const i = document.createElement('i');
		i.appendChild(document.createTextNode('Alternatively, use the '));
		const b2 = document.createElement('b');
		b2.textContent = 'File Backup';
		i.appendChild(b2);
		i.appendChild(document.createTextNode(' option below to save/restore manually without setup.'));
		p2.appendChild(i);
		dialogBox.appendChild(p2);


		const closeBtn = document.createElement('button');
		closeBtn.className = 'custom-dialog-btn dialog-btn-cancel';
		closeBtn.textContent = 'Close';
		closeBtn.onclick = () => overlay.remove();
		closeBtn.style.marginTop = '20px';

		dialogBox.appendChild(closeBtn);
		overlay.appendChild(dialogBox);
		document.body.appendChild(overlay);
	}

	// --- Toolbar Creation ---

	function createToolbar() {
		const toolbarId = 'gemini-snippet-toolbar-userscript';
		let toolbar = document.getElementById(toolbarId);
		if (toolbar) {
			clearEl(toolbar);
		} else {
			toolbar = document.createElement('div');
			toolbar.id = toolbarId;
			document.body.insertBefore(toolbar, document.body.firstChild);
		}

		toolbarItems.forEach(item => {
			if (item.visible === false) return; // Skip hidden items

			if (item.type === 'button') {
				const button = document.createElement('button');
				button.textContent = item.label;
				button.title = item.text;
				button.addEventListener('click', () => insertSnippetText(item.text));
				toolbar.appendChild(button);
			} else if (item.type === 'dropdown') {
				const select = document.createElement('select');
				select.title = item.placeholder;
				const defaultOption = new Option(item.placeholder, "", true, true);
				defaultOption.disabled = true;
				select.appendChild(defaultOption);
				item.options.forEach(opt => select.appendChild(new Option(opt.label, opt.text)));
				select.addEventListener('change', (e) => {
					if (e.target.value) {
						insertSnippetText(e.target.value);
						e.target.selectedIndex = 0;
					}
				});
				toolbar.appendChild(select);
			} else if (item.type === 'action') {
				const button = document.createElement('button');
				button.textContent = item.label;
				button.title = item.title;
				if (item.action === 'paste') {
					button.addEventListener('click', async () => {
						try {
							const text = await navigator.clipboard.readText();
							if (text) insertSnippetText(text);
						} catch (err) {
							displayMessage('Failed to read clipboard: ' + err.message);
						}
					});
				} else if (item.action === 'download') {
					button.addEventListener('click', handleGlobalCanvasDownload);
				} else if (item.action === 'pdf') {
					button.addEventListener('click', handlePDFExport);
				} else if (item.action === 'copy') {
					button.addEventListener('click', handleCopy);
				}
				toolbar.appendChild(button);
			}
		});

		const spacer = document.createElement('div');
		spacer.className = 'userscript-toolbar-spacer';
		toolbar.appendChild(spacer);

		const settingsButton = document.createElement('button');
		settingsButton.textContent = SETTINGS_BUTTON_LABEL;
		settingsButton.title = "Open Userscript Settings";
		settingsButton.addEventListener('click', () => toggleSettingsPanel());
		toolbar.appendChild(settingsButton);
	}

	function rebuildToolbar() {
		const toolbar = document.getElementById('gemini-snippet-toolbar-userscript');
		if (toolbar) createToolbar();
	}


	// --- Settings Panel ---

	function toggleSettingsPanel(show = true) {
		let overlay = document.getElementById('gemini-mod-settings-overlay');
		let panel = document.getElementById('gemini-mod-settings-panel');

		if (!overlay) {
			createSettingsPanel();
			overlay = document.getElementById('gemini-mod-settings-overlay');
			panel = document.getElementById('gemini-mod-settings-panel');
		}

		if (show) {
			populateSettingsPanel(panel);
			overlay.style.display = 'block';
		} else {
			overlay.style.display = 'none';
		}
	}

	async function updateSettingsPanelDriveStatus() {
		const statusText = document.getElementById('gdrive-status-text');
		const connectBtn = document.getElementById('gdrive-connect-btn');
		const saveBtn = document.getElementById('gdrive-save-btn');
		const loadBtn = document.getElementById('gdrive-load-btn');
		const backupContainer = document.getElementById('gdrive-backup-container');

		if (statusText && connectBtn) {
			const token = await GeminiMod.drive.getGoogleDriveToken();
			if (token) {
				statusText.textContent = "Status: Connected ✅";
				statusText.style.color = "#8ab4f8";
				connectBtn.style.display = 'none';
				backupContainer.style.display = 'block';
			} else {
				statusText.textContent = "Status: Not Connected";
				statusText.style.color = "#aaa";
				connectBtn.style.display = 'inline-block';
				backupContainer.style.display = 'none';
			}
		}
	}

	function createSettingsPanel() {
		if (document.getElementById('gemini-mod-settings-overlay')) return;

		const overlay = document.createElement('div');
		overlay.id = 'gemini-mod-settings-overlay';

		const panel = document.createElement('div');
		panel.id = 'gemini-mod-settings-panel';
		overlay.appendChild(panel);

		panel.appendChild(document.createElement('h2')).textContent = 'Gemini Mod Settings';

		// Create Container for Tabbed Layout
		const container = document.createElement('div');
		container.className = 'settings-container';

		// --- SIDEBAR ---
		const sidebar = document.createElement('div');
		sidebar.className = 'settings-sidebar';

		const tabs = [
			{ id: 'tab-toolbar', label: '🛠️ Toolbar' },
			{ id: 'tab-drive', label: '☁️ Google Drive' },
			{ id: 'tab-reset', label: '⚠️ Danger Zone' }
		];

		tabs.forEach((tab, index) => {
			const btn = document.createElement('button');
			btn.className = 'tab-btn' + (index === 0 ? ' active' : '');
			btn.textContent = tab.label;
			btn.dataset.target = tab.id;
			btn.onclick = () => {
				document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
				document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
				btn.classList.add('active');
				document.getElementById(tab.id).classList.add('active');
			};
			sidebar.appendChild(btn);
		});

		// Footer Buttons Container
		const sidebarFooter = document.createElement('div');
		sidebarFooter.style.marginTop = 'auto'; // Pushes to bottom
		sidebarFooter.style.display = 'flex';
		sidebarFooter.style.flexDirection = 'column';
		sidebarFooter.style.gap = '10px';
		sidebarFooter.style.width = '100%';

		// Close Button
		const closeButton = document.createElement('button');
		closeButton.textContent = 'Close';
		closeButton.className = 'custom-dialog-btn dialog-btn-cancel';
		closeButton.style.width = '100%';
		closeButton.style.boxSizing = 'border-box'; // Ensure padding handles correctly
		closeButton.style.margin = '0'; // Override default class margin
		closeButton.addEventListener('click', () => toggleSettingsPanel(false));
		sidebarFooter.appendChild(closeButton);

		// Save Button
		const saveBtnClose = document.createElement('button');
		saveBtnClose.textContent = 'Save & Close';
		saveBtnClose.className = 'custom-dialog-btn dialog-btn-confirm';
		saveBtnClose.style.width = '100%';
		saveBtnClose.style.boxSizing = 'border-box';
		saveBtnClose.style.margin = '0'; // Override default class margin
		saveBtnClose.addEventListener('click', saveToolbarConfiguration); // Logic handles closing
		sidebarFooter.appendChild(saveBtnClose);

		sidebar.appendChild(sidebarFooter);

		container.appendChild(sidebar);

		// Content Area
		const content = document.createElement('div');
		content.className = 'settings-content';

		// --- TAB 1: TOOLBAR ---
		const tabToolbar = document.createElement('div');
		tabToolbar.id = 'tab-toolbar';
		tabToolbar.className = 'tab-pane active';

		// Add Item Button
		const addItemBtn = document.createElement('button');
		addItemBtn.textContent = '+ Add New Item';
		addItemBtn.className = 'custom-dialog-btn dialog-btn-confirm';
		addItemBtn.style.marginBottom = '20px';
		addItemBtn.addEventListener('click', showAddItemModal);
		tabToolbar.appendChild(addItemBtn);

		const itemsContainer = document.createElement('div');
		itemsContainer.id = 'toolbar-items-container';
		tabToolbar.appendChild(itemsContainer);

		content.appendChild(tabToolbar);


		// --- TAB 2: GOOGLE DRIVE ---
		const tabDrive = document.createElement('div');
		tabDrive.id = 'tab-drive';
		tabDrive.className = 'tab-pane';

		const driveHeader = document.createElement('h3');
		driveHeader.textContent = 'Google Drive Sync';
		driveHeader.style.marginTop = '0';

		// Help Icon/Button
		const helpBtn = document.createElement('button');
		helpBtn.textContent = '📖'; // Book icon
		helpBtn.title = "Show Setup Instructions";
		helpBtn.style.marginLeft = '10px';
		helpBtn.style.background = 'transparent';
		helpBtn.style.border = '1px solid #5f6368';
		helpBtn.onclick = showSetupGuide;
		driveHeader.appendChild(helpBtn);

		tabDrive.appendChild(driveHeader);

		// Client ID Input
		const clientIdLabel = document.createElement('label');
		clientIdLabel.textContent = "Google Cloud Client ID:";
		tabDrive.appendChild(clientIdLabel);

		const clientIdContainer = document.createElement('div');
		clientIdContainer.style.display = 'flex';
		clientIdContainer.style.alignItems = 'center';
		clientIdContainer.style.gap = '5px';

		const clientIdInput = document.createElement('input');
		clientIdInput.id = 'gdrive-client-id-input';
		clientIdInput.type = 'password';
		clientIdInput.placeholder = "Enter your OAuth 2.0 Client ID";
		clientIdInput.style.flexGrow = '1';
		clientIdInput.value = ""; // Will be populated

		// Toggle Visibility
		const toggleVisBtn = document.createElement('button');
		toggleVisBtn.textContent = '👁️';
		toggleVisBtn.title = "Toggle Visibility";
		toggleVisBtn.onclick = () => {
			clientIdInput.type = clientIdInput.type === 'password' ? 'text' : 'password';
		};

		// Help Link
		const helpLink = document.createElement('a');
		helpLink.href = "https://console.cloud.google.com/apis/credentials";
		helpLink.target = "_blank";
		helpLink.textContent = "❓ Get ID";
		helpLink.className = 'help-link';

		clientIdContainer.appendChild(clientIdInput);
		clientIdContainer.appendChild(toggleVisBtn);
		clientIdContainer.appendChild(helpLink);
		tabDrive.appendChild(clientIdContainer);

		const saveClientIdBtn = document.createElement('button');
		saveClientIdBtn.textContent = "Save Client ID";
		saveClientIdBtn.style.marginTop = "10px";
		saveClientIdBtn.addEventListener('click', async () => {
			const val = clientIdInput.value.trim();
			if (val) {
				await GM_setValue(STORAGE_KEY_GDRIVE_CLIENT_ID, val);
				displayMessage("Client ID saved!", false);
				updateSettingsPanelDriveStatus();
			} else {
				displayMessage("Please enter a Client ID.");
			}
		});
		tabDrive.appendChild(saveClientIdBtn);

		// Connection Status
		const statusText = document.createElement('p');
		statusText.id = 'gdrive-status-text';
		statusText.textContent = "Status: Checking...";
		statusText.style.marginTop = "20px";
		statusText.style.fontWeight = "bold";
		tabDrive.appendChild(statusText);

		// Connect Button
		const connectBtn = document.createElement('button');
		connectBtn.id = 'gdrive-connect-btn';
		connectBtn.textContent = "Connect Google Drive";
		connectBtn.className = 'custom-dialog-btn dialog-btn-confirm';
		connectBtn.style.display = 'none';
		connectBtn.addEventListener('click', () => GeminiMod.drive.initiateGoogleDriveAuth());
		tabDrive.appendChild(connectBtn);

		// Backup Controls (Hidden until connected)
		const backupContainer = document.createElement('div');
		backupContainer.id = 'gdrive-backup-container';
		backupContainer.style.display = 'none';
		backupContainer.style.marginTop = '15px';
		backupContainer.style.borderTop = '1px solid #444';
		backupContainer.style.paddingTop = '15px';

		const backupTitle = document.createElement('h4');
		backupTitle.textContent = "Synchronization";
		backupTitle.style.marginTop = '0';
		backupContainer.appendChild(backupTitle);

		const saveBtn = document.createElement('button');
		saveBtn.id = 'gdrive-save-btn';
		saveBtn.textContent = "☁️ Save to Drive";
		saveBtn.className = 'custom-dialog-btn';
		saveBtn.style.marginRight = '10px';
		saveBtn.title = "Overwrite the backup file on Google Drive with current settings";
		saveBtn.onclick = () => {
			GeminiMod.drive.saveToDrive({
				toolbarItems,
				folders,
				conversationFolders
			});
		};
		backupContainer.appendChild(saveBtn);

		const loadBtn = document.createElement('button');
		loadBtn.id = 'gdrive-load-btn';
		loadBtn.textContent = "☁️ Load from Drive";
		loadBtn.className = 'custom-dialog-btn';
		loadBtn.title = "Overwrite local settings with data from Google Drive";
		loadBtn.onclick = () => {
			GeminiMod.drive.loadFromDrive(async (data) => {
				if (data && data.toolbarItems && data.folders) {
					await GM_setValue(STORAGE_KEY_TOOLBAR_ITEMS, JSON.stringify(data.toolbarItems));
					await GM_setValue(STORAGE_KEY_FOLDERS, data.folders);
					await GM_setValue(STORAGE_KEY_CONVO_FOLDERS, data.conversationFolders || {});
					displayMessage("Settings loaded from Drive! Reloading page...", false);
					setTimeout(() => location.reload(), 1500);
				} else {
					displayMessage("Invalid file format downloaded from Drive.");
				}
			});
		};
		backupContainer.appendChild(loadBtn);

		tabDrive.appendChild(backupContainer);

		// --- Manual Backup Section ---
		const manualBackupHeader = document.createElement('h3');
		manualBackupHeader.textContent = 'Manual File Backup';
		tabDrive.appendChild(manualBackupHeader);

		const manualDesc = document.createElement('p');
		manualDesc.textContent = "No setup required. Save your settings to a local file.";
		manualDesc.style.fontSize = '0.9em';
		manualDesc.style.color = '#aaa';
		tabDrive.appendChild(manualDesc);

		const exportBtn = document.createElement('button');
		exportBtn.textContent = "⬇️ Export to File";
		exportBtn.className = 'custom-dialog-btn';
		exportBtn.style.marginRight = '10px';
		exportBtn.onclick = () => GeminiMod.drive.exportSettingsToFile({
			toolbarItems,
			folders,
			conversationFolders
		});
		tabDrive.appendChild(exportBtn);

		const importInput = document.createElement('input');
		importInput.type = 'file';
		importInput.accept = '.json';
		importInput.style.display = 'none';
		importInput.onchange = (e) => {
			if (e.target.files.length > 0) {
				GeminiMod.drive.importSettingsFromFile(e.target.files[0], async (data) => {
					await GM_setValue(STORAGE_KEY_TOOLBAR_ITEMS, JSON.stringify(data.toolbarItems));
					await GM_setValue(STORAGE_KEY_FOLDERS, data.folders);
					await GM_setValue(STORAGE_KEY_CONVO_FOLDERS, data.conversationFolders || {});
					if (data.gdriveClientId) await GM_setValue(STORAGE_KEY_GDRIVE_CLIENT_ID, data.gdriveClientId);

					displayMessage("Settings imported successfully! Reloading...", false);
					setTimeout(() => location.reload(), 1500);
				});
			}
		};

		const importBtn = document.createElement('button');
		importBtn.textContent = "⬆️ Import from File";
		importBtn.className = 'custom-dialog-btn';
		importBtn.onclick = () => importInput.click();
		tabDrive.appendChild(importBtn);
		tabDrive.appendChild(importInput);


		content.appendChild(tabDrive);


		// --- TAB 3: RESET ---
		const tabReset = document.createElement('div');
		tabReset.id = 'tab-reset';
		tabReset.className = 'tab-pane';

		tabReset.appendChild(document.createElement('h3')).textContent = 'Danger Zone';

		const resetFoldersBtn = document.createElement('button');
		resetFoldersBtn.textContent = 'Reset Folders Only';
		resetFoldersBtn.className = 'custom-dialog-btn dialog-btn-delete';
		resetFoldersBtn.style.display = 'block';
		resetFoldersBtn.style.marginBottom = '15px';
		resetFoldersBtn.addEventListener('click', () => {
			showConfirm("Are you sure you want to delete all folders?", async () => {
				await GM_deleteValue(STORAGE_KEY_FOLDERS);
				await GM_deleteValue(STORAGE_KEY_CONVO_FOLDERS);
				location.reload();
			}, "Delete Folders", "dialog-btn-delete");
		});
		tabReset.appendChild(resetFoldersBtn);

		const resetAllBtn = document.createElement('button');
		resetAllBtn.textContent = 'Reset EVERYTHING (Factory Reset)';
		resetAllBtn.className = 'custom-dialog-btn dialog-btn-delete';
		resetAllBtn.style.backgroundColor = '#cc2929'; // Redder
		resetAllBtn.addEventListener('click', () => {
			showConfirm("Are you sure? This will execute a full factory reset of the userscript, including Toolbar items, Folders, and Google Drive connection.", async () => {
				await GM_deleteValue(STORAGE_KEY_TOOLBAR_ITEMS);
				await GM_deleteValue(STORAGE_KEY_FOLDERS);
				await GM_deleteValue(STORAGE_KEY_CONVO_FOLDERS);
				await GM_deleteValue(STORAGE_KEY_GDRIVE_TOKEN);
				await GM_deleteValue(STORAGE_KEY_GDRIVE_CLIENT_ID);
				location.reload();
			}, "FACTORY RESET", "dialog-btn-delete");
		});
		tabReset.appendChild(resetAllBtn);

		content.appendChild(tabReset);

		container.appendChild(content);
		panel.appendChild(container);

		document.body.appendChild(overlay);

		// Initialize Sortable on the items container
		new Sortable(itemsContainer, {
			animation: 150,
			handle: '.item-group',
			ghostClass: 'sortable-ghost'
		});
	}

	function populateSettingsPanel(panel) {
		const container = panel.querySelector('#toolbar-items-container');
		if (!container) return; // Should not happen
		clearEl(container);

		toolbarItems.forEach(item => addItemToPanel(container, item));

		// Populate Client ID if exists
		const clientIdInput = document.getElementById('gdrive-client-id-input');
		if (clientIdInput) {
			GeminiMod.drive.getGoogleDriveClientId().then(id => {
				if (id) clientIdInput.value = id;
			});
		}
		// Update Status
		updateSettingsPanelDriveStatus();
	}

	function addItemToPanel(container, item) {
		const group = document.createElement('div');
		group.className = 'item-group';
		group.dataset.type = item.type;
		if (item.action) group.dataset.action = item.action;
		if (item.title) group.dataset.title = item.title;

		const visibleCheck = document.createElement('input');
		visibleCheck.type = 'checkbox';
		visibleCheck.className = 'visible-checkbox';
		visibleCheck.checked = item.visible !== false;
		visibleCheck.title = 'Show in toolbar';
		group.appendChild(visibleCheck);

		const contentDiv = document.createElement('div');
		contentDiv.className = 'item-content';

		const typeLabel = document.createElement('strong');
		typeLabel.textContent = item.type.toUpperCase() + (item.action ? ` (${item.action})` : '');
		typeLabel.style.display = 'block';
		typeLabel.style.marginBottom = '5px';
		typeLabel.style.fontSize = '0.7em';
		typeLabel.style.color = '#888';
		contentDiv.appendChild(typeLabel);

		// Dynamic fields based on type
		if (item.type === 'button') {
			contentDiv.appendChild(createInputRow("Label:", item.label, "label-input"));
			contentDiv.appendChild(createInputRow("Snippet:", item.text, "text-input", "textarea"));
		} else if (item.type === 'dropdown') {
			contentDiv.appendChild(createInputRow("Placeholder:", item.placeholder, "placeholder-input"));
			const optionsContainer = document.createElement('div');
			optionsContainer.className = 'dropdown-options-container';
			optionsContainer.appendChild(document.createElement('h4')).textContent = "Options:";

			item.options.forEach(opt => addOptionToContainer(optionsContainer, opt));

			const addOptBtn = document.createElement('button');
			addOptBtn.textContent = '+ Add Option';
			addOptBtn.style.marginTop = '5px';
			addOptBtn.addEventListener('click', () => addOptionToContainer(optionsContainer, { label: '', text: '' }));
			optionsContainer.appendChild(addOptBtn);
			contentDiv.appendChild(optionsContainer);
		} else if (item.type === 'action') {
			contentDiv.appendChild(createInputRow("Label:", item.label, "label-input"));
			const descInfo = document.createElement('div');
			descInfo.style.fontSize = '0.8em';
			descInfo.style.color = '#aaa';
			descInfo.textContent = "Functionality is built-in.";
			contentDiv.appendChild(descInfo);
		}

		group.appendChild(contentDiv);

		// Delete Button
		const deleteBtn = document.createElement('button');
		deleteBtn.textContent = '🗑️';
		deleteBtn.className = 'remove-btn';
		deleteBtn.title = 'Remove Item';
		deleteBtn.addEventListener('click', () => group.remove());
		group.appendChild(deleteBtn);

		container.appendChild(group);
	}

	function createInputRow(labelText, value, className, inputType = 'text') {
		const wrapper = document.createElement('div');
		wrapper.style.marginBottom = '5px';
		const label = document.createElement('label');
		label.textContent = labelText;
		let input;
		if (inputType === 'textarea') {
			input = document.createElement('textarea');
		} else {
			input = document.createElement('input');
			input.type = 'text';
		}
		input.value = value || '';
		input.className = className;
		wrapper.appendChild(label);
		wrapper.appendChild(input);
		return wrapper;
	}

	function addOptionToContainer(container, optionData) {
		const row = document.createElement('div');
		row.className = 'option-item';

		const labelInput = document.createElement('input');
		labelInput.type = 'text';
		labelInput.placeholder = 'Label';
		labelInput.value = optionData.label;
		labelInput.className = 'custom-dialog-input label-input';
		labelInput.style.marginBottom = '0';

		const textInput = document.createElement('textarea');
		textInput.placeholder = 'Snippet Text';
		textInput.value = optionData.text;
		textInput.className = 'custom-dialog-input text-input';
		textInput.style.marginBottom = '0';
		textInput.style.minHeight = '40px';


		const delBtn = document.createElement('button');
		delBtn.textContent = 'x';
		delBtn.className = 'remove-btn';
		delBtn.addEventListener('click', () => row.remove());

		row.appendChild(labelInput);
		row.appendChild(textInput);
		row.appendChild(delBtn);

		// Insert before the "Add Option" button
		container.insertBefore(row, container.lastElementChild);
	}

	function showAddItemModal() {
		// reuse existing modal if possible or create simple one
		const overlay = document.createElement('div');
		overlay.className = 'custom-dialog-overlay';
		overlay.id = 'gemini-mod-type-modal-overlay';

		const modal = document.createElement('div');
		modal.id = 'gemini-mod-type-modal';
		modal.className = 'custom-dialog-box';

		const h3 = document.createElement('h3');
		h3.textContent = 'Select Item Type';
		modal.appendChild(h3);

		const createTypeBtn = (type, label) => {
			const btn = document.createElement('button');
			btn.textContent = label;
			btn.className = 'custom-dialog-btn dialog-btn-confirm';
			btn.addEventListener('click', () => {
				let newItem;
				if (type === 'button') newItem = { type: 'button', label: 'New Button', text: '' };
				else if (type === 'dropdown') newItem = { type: 'dropdown', placeholder: 'Select...', options: [] };

				const container = document.getElementById('toolbar-items-container');
				addItemToPanel(container, newItem);
				document.body.removeChild(overlay);
			});
			return btn;
		};

		modal.appendChild(createTypeBtn('button', 'Button'));
		modal.appendChild(createTypeBtn('dropdown', 'Dropdown'));

		const cancelBtn = document.createElement('button');
		cancelBtn.textContent = 'Cancel';
		cancelBtn.className = 'custom-dialog-btn dialog-btn-cancel';
		cancelBtn.style.marginTop = '15px';
		cancelBtn.addEventListener('click', () => document.body.removeChild(overlay));
		modal.appendChild(cancelBtn);

		overlay.appendChild(modal);
		document.body.appendChild(overlay);
	}


	// --- Folder Logic ---

	function findSidebarSections() {
		let notebooksSection = null;

		// 1. Search for Notebooks section container
		const allHeaders = document.querySelectorAll('.expandable-section-header, button[aria-controls], [data-test-id*="section"]');
		for (const h of allHeaders) {
			const text = (h.textContent || '').trim().toLowerCase();
			if (text.includes('notebook') && !h.closest('#folder-ui-container')) {
				notebooksSection = h.closest('expandable-section, .expandable-section') || h.parentElement;
				break;
			}
		}

		if (!notebooksSection) {
			const notebookBtn = document.querySelector('a[href*="notebook"], button[aria-label*="Notebook"], [data-test-id*="notebook"]');
			if (notebookBtn && !notebookBtn.closest('#folder-ui-container')) {
				notebooksSection = notebookBtn.closest('expandable-section, .expandable-section, mat-nav-list, .section') || notebookBtn.parentElement;
			}
		}

		// 2. Search for Recent chats section container
		let recentSection = null;
		const chatHeader = document.querySelector('#sidenav-section-header-chats, [aria-controls="sidenav-section-content-chats"]');
		if (chatHeader) {
			recentSection = chatHeader.closest('expandable-section, .expandable-section') || chatHeader;
		}

		if (!recentSection) {
			const convoList = document.querySelector('conversations-list, #sidenav-section-content-chats');
			if (convoList) {
				recentSection = convoList.closest('expandable-section, .expandable-section') || convoList;
			}
		}

		if (!recentSection) {
			for (const h of allHeaders) {
				const text = (h.textContent || '').trim().toLowerCase();
				if ((text.includes('letzte') || text.includes('recent') || text.includes('unterhaltungen')) && !h.closest('#folder-ui-container')) {
					recentSection = h.closest('expandable-section, .expandable-section') || h;
					break;
				}
			}
		}

		return { notebooksSection, recentSection };
	}

	function positionFolderContainer(container) {
		if (!container) return false;
		const { notebooksSection, recentSection } = findSidebarSections();

		// Priority 1: Insert immediately AFTER the Notebooks section
		if (notebooksSection && notebooksSection.parentNode) {
			const parent = notebooksSection.parentNode;
			const targetNext = notebooksSection.nextSibling;
			if (container.parentNode !== parent || container.previousSibling !== notebooksSection) {
				parent.insertBefore(container, targetNext);
				console.log("Gemini Mod: Positioned folders container after Notebooks section.");
			}
			return true;
		}

		// Priority 2: Insert immediately BEFORE the Recent chats section
		if (recentSection && recentSection.parentNode) {
			const parent = recentSection.parentNode;
			if (container.parentNode !== parent || container.nextSibling !== recentSection) {
				parent.insertBefore(container, recentSection);
				console.log("Gemini Mod: Positioned folders container before Recent section.");
			}
			return true;
		}

		return false;
	}

	function initializeFolders() {
		const foldersContainerId = 'folder-ui-container';
		let container = document.getElementById(foldersContainerId);

		if (!container) {
			container = document.createElement('div');
			container.setAttribute('storagekey', 'folders-mod');
			container.id = foldersContainerId;
		}

		const positioned = positionFolderContainer(container);
		if (!positioned) {
			return false; // Wait until Notebooks or Recent section is available
		}

		if (!container.hasChildNodes()) {
			renderFolders();
		}

		// Observe chat list changes to identify new conversations
		const chatHistoryList = document.querySelector('conversations-list, #sidenav-section-content-chats, mat-nav-list, gem-nav-list, .conversations-list');
		if (chatHistoryList && !chatHistoryList.dataset.geminiModObserved) {
			chatHistoryList.dataset.geminiModObserved = 'true';
			let debounceTimer = null;
			const observer = new MutationObserver(() => {
				clearTimeout(debounceTimer);
				debounceTimer = setTimeout(() => {
					processConversationItems(chatHistoryList);
					positionFolderContainer(container);
				}, 100);
			});
			observer.observe(chatHistoryList, { childList: true, subtree: true });
			processConversationItems(chatHistoryList);
		}

		// Observe sidebar parent to ensure folders STAY positioned after Notebooks
		const sidebarParent = container.parentElement;
		if (sidebarParent && !sidebarParent.dataset.geminiModPosObserved) {
			sidebarParent.dataset.geminiModPosObserved = 'true';
			const posObserver = new MutationObserver(() => {
				positionFolderContainer(container);
			});
			posObserver.observe(sidebarParent, { childList: true });
		}

		return true;
	}

	// Helper functions for Angular Scoping
	function getAngularScope(selector) {
		const el = document.querySelector(selector);
		if (!el) return null;
		for (let attr of el.attributes) {
			if (attr.name.startsWith('_ngcontent-')) return attr.name;
		}
		return null;
	}

	function createChevronSvg(isOpen = true) {
		const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
		svg.setAttribute('viewBox', '0 0 24 24');
		svg.setAttribute('width', '18');
		svg.setAttribute('height', '18');
		svg.setAttribute('fill', 'currentColor');
		svg.setAttribute('aria-hidden', 'true');
		svg.style.display = 'block';
		svg.style.transition = 'transform 0.2s ease';
		svg.style.transform = isOpen ? 'rotate(0deg)' : 'rotate(-90deg)';
		const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		path.setAttribute('d', 'M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z');
		svg.appendChild(path);
		return svg;
	}

	let activeDraggedConvoItem = null;

	document.addEventListener('dragstart', (e) => {
		const item = e.target.closest(FOLDER_CHAT_ITEM_SELECTOR) || e.target.closest('.conversation-items-container');
		if (item) {
			activeDraggedConvoItem = item;
			if (e.dataTransfer) {
				e.dataTransfer.setData('text/plain', getConversationId(item) || '');
				e.dataTransfer.effectAllowed = 'move';
			}
		}
	}, true);

	document.addEventListener('dragend', () => {
		setTimeout(() => { activeDraggedConvoItem = null; }, 100);
		document.querySelectorAll('.folder-header.folder-drag-over, .folder.folder-drag-over').forEach(el => {
			el.classList.remove('folder-drag-over');
		});
	}, true);

	function renderFolders() {
		const container = document.getElementById('folder-ui-container');
		if (!container) return;

		const headerScope = getAngularScope('.expandable-section-title') || '';
		const itemScope = getAngularScope('gem-nav-list-item, .gem-nav-list-item') || getAngularScope('.title-text') || '';

		// --- Section header (clone native "Notebooks" style) ---
		const STORAGE_KEY_SECTION_OPEN = 'gemini_folder_section_open';
		const isSectionOpen = GM_getValue(STORAGE_KEY_SECTION_OPEN, true);

		// Ensure container has expanded class if open
		if (isSectionOpen) container.classList.add('expanded');

		// Remove old header if it exists
		let oldHeader = document.getElementById('folder-section-header');
		if (oldHeader) oldHeader.remove();

		// We use a button to exactly match the native Google 'Notebooks' expandable header
		const sectionHeader = document.createElement('button');
		sectionHeader.id = 'folder-section-header';
		sectionHeader.setAttribute('data-test-id', 'expandable-section-toggle');
		sectionHeader.setAttribute('aria-expanded', isSectionOpen ? 'true' : 'false');
		// It inherently has 'expandable-section-header' for native styles
		sectionHeader.className = 'expandable-section-header ' + (isSectionOpen ? '' : 'collapsed');
		if (headerScope) sectionHeader.setAttribute(headerScope, '');

		const sectionLabel = document.createElement('span');
		sectionLabel.className = 'expandable-section-title gds-body-s folder-section-label';
		sectionLabel.textContent = 'Folders';
		if (headerScope) sectionLabel.setAttribute(headerScope, '');

		// Use toggle-icon with SVG chevron
		const sectionChevron = document.createElement('span');
		sectionChevron.className = 'toggle-icon';
		sectionChevron.setAttribute('data-test-id', 'expandable-section-toggle-icon');
		if (headerScope) sectionChevron.setAttribute(headerScope, '');
		sectionChevron.appendChild(createChevronSvg(isSectionOpen));

		sectionHeader.appendChild(sectionLabel);
		sectionHeader.appendChild(sectionChevron);
		container.appendChild(sectionHeader);

		// Remove existing folder-container if exists to re-render, preserving items
		let folderWrapper = document.getElementById('folder-section-body');
		if (folderWrapper) {
			const mainList = document.querySelector(FOLDER_CHAT_LIST_CONTAINER_SELECTOR);
			if (mainList) {
				folderWrapper.querySelectorAll(FOLDER_CHAT_ITEM_SELECTOR).forEach(item => {
					mainList.appendChild(item);
				});
			}
			folderWrapper.remove();
		}

		// Inner container for folders (this gets collapsed)
		folderWrapper = document.createElement('div');
		folderWrapper.id = 'folder-section-body';
		folderWrapper.style.display = 'block';
		folderWrapper.style.width = '100%';
		folderWrapper.style.overflow = 'hidden';
		folderWrapper.style.transition = 'max-height 0.25s ease-in-out';
		folderWrapper.style.maxHeight = isSectionOpen ? '2000px' : '0px';
		container.appendChild(folderWrapper);

		sectionHeader.addEventListener('click', async () => {
			const nowCollapsed = sectionHeader.classList.toggle('collapsed');
			sectionHeader.setAttribute('aria-expanded', nowCollapsed ? 'false' : 'true');

			folderWrapper.style.maxHeight = nowCollapsed ? '0px' : '2000px';

			const svg = sectionChevron.querySelector('svg');
			if (svg) svg.style.transform = nowCollapsed ? 'rotate(-90deg)' : 'rotate(0deg)';
			await GM_setValue(STORAGE_KEY_SECTION_OPEN, !nowCollapsed);
		});

		folders.forEach(folder => {
			folderWrapper.appendChild(createFolderElement(folder, itemScope));
		});

		const addBtn = document.createElement('button');
		addBtn.id = 'add-folder-btn';

		const addIcon = document.createElement('mat-icon');
		addIcon.className = 'mat-icon notranslate lm-icon-s lumi-symbols mat-ligature-font mat-icon-no-color add-folder-icon';
		addIcon.textContent = 'add';
		addIcon.style.color = 'var(--lumi-sys-color--on-surface-variant, #c4c7c5)';

		const addBtnLabel = document.createElement('span');
		addBtnLabel.className = 'title-text gds-body-s add-folder-label';
		addBtnLabel.textContent = 'New Folder';
		if (itemScope) addBtnLabel.setAttribute(itemScope, '');

		addBtn.appendChild(addIcon);
		addBtn.appendChild(addBtnLabel);
		addBtn.addEventListener('click', () => {
			showPrompt("New Folder Name:", "", async (name) => {
				if (name) {
					folders.push({ id: Date.now().toString(), name: name, color: FOLDER_COLORS[0], isOpen: true });
					await saveFolderConfiguration();
					renderFolders();
				}
			});
		});
		folderWrapper.appendChild(addBtn);

		// Initialize Sortable for folders
		new Sortable(folderWrapper, {
			animation: 150,
			handle: '.folder-header',
			onEnd: async () => {
				const newOrder = [];
				folderWrapper.querySelectorAll('.folder').forEach(el => {
					const id = el.dataset.id;
					const folder = folders.find(f => f.id === id);
					if (folder) newOrder.push(folder);
				});
				folders = newOrder;
				await saveFolderConfiguration();
			}
		});

		const chatListEl = document.querySelector(FOLDER_INJECTION_POINT_SELECTOR);
		if (chatListEl) {
			processConversationItems(chatListEl);
		}
	}

	function createFolderElement(folder, itemScope) {
		const folderDiv = document.createElement('div');
		folderDiv.className = `folder ${folder.isOpen ? '' : 'closed'}`;
		folderDiv.dataset.id = folder.id;

		const header = document.createElement('div');
		header.className = 'folder-header';

		// Folder Icon (Open/Closed)
		const iconWrapper = document.createElement('div');
		iconWrapper.className = 'folder-icon-wrapper';

		const matIcon = document.createElement('mat-icon');
		matIcon.className = 'mat-icon notranslate lm-icon-s lumi-symbols mat-ligature-font mat-icon-no-color folder-icon';
		matIcon.textContent = folder.isOpen ? 'folder_open' : 'folder';
		matIcon.style.color = folder.color;
		iconWrapper.appendChild(matIcon);
		header.appendChild(iconWrapper);

		const nameSpan = document.createElement('span');
		nameSpan.className = 'title-text gds-body-s folder-name';
		nameSpan.textContent = folder.name;
		if (itemScope) nameSpan.setAttribute(itemScope, '');
		header.appendChild(nameSpan);

		const controls = document.createElement('div');
		controls.className = 'folder-controls';

		const settingsBtn = document.createElement('button');
		settingsBtn.className = 'folder-options-btn';
		settingsBtn.textContent = '⋮';
		settingsBtn.title = "Folder Options";
		settingsBtn.addEventListener('click', (e) => {
			e.stopPropagation();
			showFolderContextMenu(e, folder);
		});
		controls.appendChild(settingsBtn);

		const toggleIcon = document.createElement('span');
		toggleIcon.className = 'folder-toggle-icon';
		toggleIcon.appendChild(createChevronSvg(folder.isOpen));
		controls.appendChild(toggleIcon);

		header.appendChild(controls);

		header.addEventListener('click', async () => {
			folder.isOpen = !folder.isOpen;
			folderDiv.classList.toggle('closed', !folder.isOpen);
			const newIcon = folder.isOpen ? 'folder_open' : 'folder';
			matIcon.textContent = newIcon;
			const svg = toggleIcon.querySelector('svg');
			if (svg) svg.style.transform = folder.isOpen ? 'rotate(0deg)' : 'rotate(-90deg)';
			await saveFolderConfiguration();
		});

		// Drag & drop onto folder header (allows dropping to closed folder or open folder)
		let autoOpenTimer = null;

		function handleDragOver(e) {
			if (!activeDraggedConvoItem) return;
			e.preventDefault();
			e.stopPropagation();
			if (e.dataTransfer) {
				e.dataTransfer.dropEffect = 'move';
			}
			header.classList.add('folder-drag-over');

			const isClosed = folderDiv.classList.contains('closed') || !folder.isOpen;
			if (isClosed && !autoOpenTimer) {
				autoOpenTimer = setTimeout(async () => {
					if (folderDiv.classList.contains('closed') || !folder.isOpen) {
						folder.isOpen = true;
						folderDiv.classList.remove('closed');
						matIcon.textContent = 'folder_open';
						const svg = toggleIcon.querySelector('svg');
						if (svg) svg.style.transform = 'rotate(0deg)';
						await saveFolderConfiguration();
					}
				}, 500);
			}
		}

		function handleDragLeave(e) {
			if (!header.contains(e.relatedTarget) && !folderDiv.contains(e.relatedTarget)) {
				header.classList.remove('folder-drag-over');
				if (autoOpenTimer) {
					clearTimeout(autoOpenTimer);
					autoOpenTimer = null;
				}
			}
		}

		async function handleDrop(e) {
			if (!activeDraggedConvoItem) return;
			e.preventDefault();
			e.stopPropagation();
			header.classList.remove('folder-drag-over');
			if (autoOpenTimer) {
				clearTimeout(autoOpenTimer);
				autoOpenTimer = null;
			}

			const item = activeDraggedConvoItem;
			const convoId = getConversationId(item);
			if (convoId) {
				conversationFolders[convoId] = folder.id;
				await saveFolderConfiguration();
			}

			contentDiv.appendChild(item);

			if (folderDiv.classList.contains('closed') || !folder.isOpen) {
				folder.isOpen = true;
				folderDiv.classList.remove('closed');
				matIcon.textContent = 'folder_open';
				const svg = toggleIcon.querySelector('svg');
				if (svg) svg.style.transform = 'rotate(0deg)';
				await saveFolderConfiguration();
			}
		}

		header.addEventListener('dragenter', handleDragOver);
		header.addEventListener('dragover', handleDragOver);
		header.addEventListener('dragleave', handleDragLeave);
		header.addEventListener('drop', handleDrop);

		folderDiv.appendChild(header);

		const contentDiv = document.createElement('div');
		contentDiv.className = 'folder-content';
		// Populate content
		const convoIds = Object.keys(conversationFolders).filter(k => conversationFolders[k] === folder.id);
		contentDiv.dataset.folderId = folder.id;

		folderDiv.appendChild(contentDiv);

		// Initialize Sortable for dragging conversations INTO this folder
		new Sortable(contentDiv, {
			group: 'conversations',
			animation: 150,
			onStart: (evt) => {
				activeDraggedConvoItem = evt.item;
			},
			onEnd: () => {
				setTimeout(() => { activeDraggedConvoItem = null; }, 100);
				document.querySelectorAll('.folder-header.folder-drag-over').forEach(el => el.classList.remove('folder-drag-over'));
			},
			onAdd: async (evt) => {
				const item = evt.item;
				const convoId = getConversationId(item);
				if (convoId) {
					conversationFolders[convoId] = folder.id;
					await saveFolderConfiguration();
				}
			}
		});

		return folderDiv;
	}

	function getConversationId(element) {
		if (!element) return null;
		// Extract ID from Gemini's DOM. Needs to be robust.
		// Usually in the link href or data-test-id
		const link = (element.tagName === 'A' ? element : null) || element.querySelector('a') || element.closest('a');
		if (link) {
			const href = link.getAttribute('href') || link.href || '';
			const match = href.match(/\/(?:app|conversation)\/([a-zA-Z0-9_-]+)/);
			if (match) return match[1];
		}
		const jslog = (element.getAttribute && element.getAttribute('jslog')) || '';
		let m = jslog.match(/"c_([A-Za-z0-9_-]+)"/) || jslog.match(/c_([A-Za-z0-9_-]+)/);
		if (m) return m[1];
		return null;
	}

	function showFolderContextMenu(e, folder) {
		const existingMenu = document.getElementById('folder-context-menu');
		if (existingMenu) existingMenu.remove();

		const menu = document.createElement('div');
		menu.id = 'folder-context-menu';
		menu.className = 'folder-context-menu';

		const renameItem = document.createElement('div');
		renameItem.className = 'folder-context-menu-item';
		renameItem.textContent = '✏️ Rename';
		renameItem.onclick = () => {
			showPrompt("Rename Folder:", folder.name, async (newName) => {
				folder.name = newName;
				await saveFolderConfiguration();
				renderFolders();
			});
			menu.remove();
		};
		menu.appendChild(renameItem);

		const colorItem = document.createElement('div');
		colorItem.className = 'folder-context-menu-item';
		colorItem.textContent = '🎨 Change Color';
		colorItem.onclick = () => {
			showColorPicker(folder.color, async (newColor) => {
				folder.color = newColor;
				await saveFolderConfiguration();
				renderFolders();
			});
			menu.remove();
		};
		menu.appendChild(colorItem);

		const deleteItem = document.createElement('div');
		deleteItem.className = 'folder-context-menu-item delete';
		deleteItem.textContent = '🗑️ Delete';
		deleteItem.onclick = () => {
			showConfirm(`Delete folder "${folder.name}"? Conversations will return to the main list.`, async () => {
				folders = folders.filter(f => f.id !== folder.id);
				// Remove folder assignments for convos in this folder
				Object.keys(conversationFolders).forEach(k => {
					if (conversationFolders[k] === folder.id) delete conversationFolders[k];
				});
				await saveFolderConfiguration();
				renderFolders();
				// Trigger reprocessing of lists to move items back
				processConversationItems(document.querySelector(FOLDER_INJECTION_POINT_SELECTOR));
			}, "Delete", "dialog-btn-delete");
			menu.remove();
		};
		menu.appendChild(deleteItem);

		document.body.appendChild(menu);
		menu.style.display = 'block';
		menu.style.left = e.pageX + 'px';
		menu.style.top = e.pageY + 'px';

		const closeMenu = () => {
			menu.remove();
			document.removeEventListener('click', closeMenu);
		};
		setTimeout(() => document.addEventListener('click', closeMenu), 0);
	}

	function processConversationItems(chatHistoryList) {
		if (!chatHistoryList) return;

		// 1. Identify Main Conversation Container (Gemini's list)
		// Usually it's a specific container inside chatHistoryList
		const mainList = (chatHistoryList.matches && chatHistoryList.matches(FOLDER_CHAT_LIST_CONTAINER_SELECTOR))
			? chatHistoryList
			: (chatHistoryList.querySelector(FOLDER_CHAT_LIST_CONTAINER_SELECTOR) || chatHistoryList);

		const folderUiContainer = document.getElementById('folder-ui-container') || document.getElementById('folder-section-body') || document.getElementById('folder-container');

		// 2. Find all conversation items
		const items = Array.from(document.querySelectorAll(FOLDER_CHAT_ITEM_SELECTOR)).filter(el => {
			// Filter out items that are already inside our folders to update them if state changed,
			// or items in the main list.
			return listContains(chatHistoryList, el) || listContains(mainList, el) || listContains(folderUiContainer, el);
		});

		items.forEach(item => {
			// Ensure it has the sortable class/structure
			if (!item.parentNode?.classList?.contains('conversation-items-container')) {
				item.classList.add('conversation-items-container'); // reuse class for styling
			}

			const convoId = getConversationId(item);
			if (!convoId) return;

			const assignedFolderId = conversationFolders[convoId];

			if (assignedFolderId) {
				// Should be in a folder
				const folderContent = document.querySelector(`.folder-content[data-folder-id="${assignedFolderId}"]`);
				if (folderContent && !folderContent.contains(item)) {
					folderContent.appendChild(item);
				}
			} else {
				// Should be in the main list
				if (mainList && !mainList.contains(item)) {
					mainList.appendChild(item);
				}
			}
		});

		// 3. Ensure Main List is Sortable (so items can be dragged FROM it)
		if (mainList && typeof Sortable !== 'undefined' && (!mainList.classList.contains('gemini-mod-sortable-init') || !Sortable.get(mainList))) {
			mainList.classList.add('gemini-mod-sortable-init');
			const existingSortable = Sortable.get(mainList);
			if (existingSortable) {
				try { existingSortable.destroy(); } catch (e) { }
			}
			new Sortable(mainList, {
				group: 'conversations',
				animation: 150,
				onStart: (evt) => {
					activeDraggedConvoItem = evt.item;
				},
				onEnd: () => {
					setTimeout(() => { activeDraggedConvoItem = null; }, 100);
					document.querySelectorAll('.folder-header.folder-drag-over').forEach(el => el.classList.remove('folder-drag-over'));
				},
				onAdd: async (evt) => {
					// Item dragged BACK to main list
					const item = evt.item;
					const convoId = getConversationId(item);
					if (convoId && conversationFolders[convoId]) {
						delete conversationFolders[convoId];
						await saveFolderConfiguration();
					}
				}
			});
		}
	}

	function listContains(list, node) {
		return list && list.contains(node);
	}


	// --- Core Actions (Download, PDF, Copy) ---
	// kept as is, but ensuring they use displayUserscriptMessage via helper

	function getCanvasContent() {
		console.log("Gemini Mod: Starting Content Extraction (Accessing via unsafeWindow)...");
		// Access raw DOM via unsafeWindow
		const rawDoc = unsafeWindow.document;

		// 1. Try Monaco Editor directly via Global API (Most Robust for Code)
		if (unsafeWindow.monaco && unsafeWindow.monaco.editor) {
			console.log("Gemini Mod: Found Global Monaco API. Checking editors...");
			try {
				const editors = unsafeWindow.monaco.editor.getEditors();
				// Priority 1: Editor inside code-immersive-panel (Code Canvas)
				let canvasEditor = editors.find(e => {
					let node = e.getContainerDomNode();
					// Handle Xray wrapper
					if (node.wrappedJSObject) node = node.wrappedJSObject;
					return node.closest('code-immersive-panel') && rawDoc.body.contains(node) && node.offsetParent !== null;
				});

				// Priority 2: Fallback to any visible editor
				if (!canvasEditor) {
					canvasEditor = editors.find(e => {
						let node = e.getContainerDomNode();
						if (node.wrappedJSObject) node = node.wrappedJSObject;
						return rawDoc.body.contains(node) && node.offsetParent !== null;
					});
				}

				if (canvasEditor) {
					console.log("Gemini Mod: Found Active Monaco Editor.");
					const model = canvasEditor.getModel();
					if (model) {
						let title = "code_snippet";
						// Retrieve title
						let node = canvasEditor.getContainerDomNode();
						if (node.wrappedJSObject) node = node.wrappedJSObject;

						const parentPanel = node.closest('code-immersive-panel');
						if (parentPanel) {
							const header = parentPanel.querySelector('h2, [data-test-id="canvas-title"], .title, .filename');
							if (header && header.textContent.trim()) {
								title = header.textContent.trim();
							}
						}

						if (title === "code_snippet") {
							const broadTitle = rawDoc.querySelector('code-immersive-panel h2');
							if (broadTitle && broadTitle.textContent.trim()) {
								title = broadTitle.textContent.trim();
							}
						}

						console.log(`Gemini Mod: Extracted ${model.getValue().length} chars from Monaco.`);
						return { type: 'code', text: model.getValue(), title: title };
					}
				}
			} catch (e) {
				console.warn("Gemini Mod: Failed to access Monaco API", e);
			}
		}

		// 2. Try ProseMirror (Document Editor)
		const pmEditor = rawDoc.querySelector('.ProseMirror');
		if (pmEditor) {
			console.log("Gemini Mod: Found ProseMirror editor (raw).");
			if (pmEditor.pmView) {
				console.log("Gemini Mod: Found pmView. Extracting text...");
				const titleEl = rawDoc.querySelector(GEMINI_DOC_CANVAS_TITLE_SELECTOR);
				const title = titleEl ? titleEl.textContent.trim() : "GEMINI_DOCUMENT";
				try {
					const text = pmEditor.pmView.state.doc.textContent;
					return { type: 'text', text: text, title: title };
				} catch (e) {
					console.warn("Gemini Mod: Failed to read ProseMirror state", e);
				}
			}
		}

		// 3. Fallback: DOM Text Extraction (standard document)
		console.log("Gemini Mod: Fallback to DOM text.");
		// Use standard document for fallback selectors as they might rely on standard DOM API behavior
		const panels = document.querySelectorAll('code-immersive-panel, immersive-panel, .immersive-panel-container');
		for (const panel of panels) {
			const checkRoot = (root) => {
				if (!root) return null;
				const titleEl = root.querySelector('h2.title-text, .title');
				const title = titleEl ? titleEl.textContent.trim() : "gemini_artifact";

				const monacoEditor = root.querySelector('.monaco-editor');
				if (monacoEditor) {
					const viewLines = monacoEditor.querySelector('.view-lines');
					if (viewLines) return { type: 'code', text: viewLines.innerText, title: title };
				}
				const codeBlock = root.querySelector('code, pre');
				if (codeBlock) return { type: 'code', text: codeBlock.textContent, title: title };
				const editor = root.querySelector(GEMINI_DOC_CANVAS_EDITOR_SELECTOR) || root.querySelector('[contenteditable="true"]');
				if (editor) return { type: 'text', text: editor.innerText, title: title };

				return null;
			};

			// Check Shadow DOM
			if (panel.shadowRoot) {
				const res = checkRoot(panel.shadowRoot);
				if (res) return res;
			}
			const res = checkRoot(panel);
			if (res) return res;
		}

		return null;
	}

	async function handleCopy() {
		const content = getCanvasContent();
		if (content) {
			try {
				await navigator.clipboard.writeText(content.text);
				displayMessage("Content copied to clipboard!", false);
			} catch (err) {
				displayMessage("Failed to copy: " + err.message);
			}
		} else {
			displayMessage("No active canvas content found to copy.");
		}
	}

	function handleGlobalCanvasDownload() {
		const content = getCanvasContent();
		if (content) {
			let filename = (content.title || "gemini_export").replace(INVALID_FILENAME_CHARS_REGEX, "_");

			// Only append extension if it doesn't look like a filename already
			if (!FILENAME_WITH_EXT_REGEX.test(filename)) {
				filename += "." + DEFAULT_DOWNLOAD_EXTENSION;
			}

			downloadString(content.text, filename);
		} else {
			displayMessage("No active canvas content found to download.");
		}
	}

	function downloadString(text, filename) {
		const blob = new Blob([text], { type: 'text/plain' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = filename;
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
		URL.revokeObjectURL(url);
	}

	function handlePDFExport() {
		const content = getCanvasContent();
		if (!content) {
			displayMessage("No content to export.");
			return;
		}

		try {
			const { jsPDF } = window.jspdf;
			// Use 'pt' units for consistency with bridge.js logic
			const doc = new jsPDF({ unit: 'pt', format: 'a4' });

			const margins = { top: 40, bottom: 40, left: 40, right: 40 };
			const pageWidth = doc.internal.pageSize.getWidth();
			const pageHeight = doc.internal.pageSize.getHeight();
			const maxLineWidth = pageWidth - margins.left - margins.right;
			const lineHeight = 12;

			// sanitize content: replace tabs with spaces for correct width calc
			const textContent = (content.text || "")
				.replace(/\t/g, '    ')
				.replace(/\u00A0/g, ' ');

			let title = content.title || "gemini_export";


			// Title
			doc.setFont("helvetica", "bold");
			doc.setFontSize(14);
			doc.text(title, margins.left, margins.top);

			let y = margins.top + 25;

			// Content
			doc.setFont("courier", "normal");
			doc.setFontSize(10);

			// Split text to fit width
			const lines = doc.splitTextToSize(textContent, maxLineWidth);

			lines.forEach(line => {
				if (y > pageHeight - margins.bottom) {
					doc.addPage();
					y = margins.top;
				}
				doc.text(line, margins.left, y);
				y += lineHeight;
			});

			const filename = title.replace(INVALID_FILENAME_CHARS_REGEX, "_") + ".pdf";
			doc.save(filename);

		} catch (e) {
			console.error("Gemini Mod: PDF Generation Failed", e);
			displayMessage("PDF Generation Failed: " + e.message);
		}
	}


	// --- Initialization ---

	async function init() {
		console.log("Gemini Mod Userscript: Initializing (Modular Version)...");



		// Inject Styles (Using Module)
		injectCSS();

		// Handle Drive Auth Callback (if this is a popup)
		GeminiMod.drive.handleAuthCallback();

		// Setup Drive Message Listener (for main window)
		// Pass a callback to update UI if settings panel is open
		GeminiMod.drive.setupAuthMessageListener(() => {
			updateSettingsPanelDriveStatus();
		});


		await loadConfiguration();

		setTimeout(() => {
			try {
				createToolbar();
				createSettingsPanel();
				// Start folder initialization loop with backoff
				let attempts = 0;
				let folderInitInterval = setInterval(() => {
					attempts++;
					if (initializeFolders()) {
						clearInterval(folderInitInterval);
						console.log("Gemini Mod Userscript: Folders Initialized.");
					} else if (attempts === 60) {
						// After 30s, back off to 2500ms intervals instead of spinning at 500ms
						clearInterval(folderInitInterval);
						folderInitInterval = setInterval(() => {
							if (initializeFolders()) {
								clearInterval(folderInitInterval);
								console.log("Gemini Mod Userscript: Folders Initialized (delayed).");
							}
						}, 2500);
					}
				}, 500);
			} catch (e) {
				console.error("Gemini Mod: Error during delayed initialization:", e);
				displayMessage("Error initializing toolbar. See console.");
			}
		}, 1500);
	}

	// Run Init
	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', init);
	} else {
		init();
	}

})();