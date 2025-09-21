// ==UserScript==
// @name          Google Gemini Mod (Toolbar & Download)
// @namespace     http://tampermonkey.net/
// @version       0.0.9
// @description   Enhances Google Gemini with a configurable, sortable toolbar for snippets and canvas content download.
// @description[de] Verbessert Google Gemini mit einer konfigurierbaren, sortierbaren Symbolleiste für Snippets und dem Herunterladen von Canvas-Inhalten.
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

	const STORAGE_KEY_TOOLBAR_ITEMS = "geminiModToolbarItems_v2";

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

	// ===================================================================================
	// II. DEFAULT TOOLBAR DEFINITIONS (Used if no custom config is saved)
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
	];

	// ===================================================================================
	// III. SCRIPT LOGIC
	// ===================================================================================

	let toolbarItems = [];

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
		#gemini-mod-settings-panel label { display: block; margin: 10px 0 5px; font-weight: 500; }
		#gemini-mod-settings-panel input[type="text"], #gemini-mod-settings-panel textarea {
			width: 100%; padding: 8px; border-radius: 8px; border: 1px solid #5f6368;
			background-color: #202122; color: #e3e3e3; box-sizing: border-box;
		}
		#gemini-mod-settings-panel textarea { min-height: 80px; resize: vertical; }
		#gemini-mod-settings-panel .item-group {
			border: 1px solid #444; border-radius: 8px; padding: 15px; margin-bottom: 10px;
			display: flex; gap: 10px; align-items: flex-start;
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
		#gemini-mod-settings-panel .remove-btn { background-color: #5c2b2b !important; }
		#gemini-mod-settings-panel .remove-btn:hover { background-color: #7d3a3a !important; }
		#gemini-mod-settings-panel .settings-actions {
			margin-top: 20px; display: flex; justify-content: flex-end; gap: 8px;
		}
		#gemini-mod-settings-panel .sort-controls { display: flex; flex-direction: column; gap: 4px; justify-content: center; align-self: center; }
		#gemini-mod-settings-panel .sort-btn { padding: 2px 6px !important; height: auto !important; line-height: 1; }
		#gemini-mod-settings-panel .sort-btn:disabled { background-color: #202122 !important; color: #5f6368 !important; cursor: not-allowed; }
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
				return element.classList.contains('ql-editor') ? (element.querySelector('p') || element) : element;
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
			const savedItems = await GM_getValue(STORAGE_KEY_TOOLBAR_ITEMS);
			toolbarItems = savedItems ? JSON.parse(savedItems) : defaultToolbarItems;
		} catch (e) {
			console.error("Gemini Mod: Error loading configuration, using defaults.", e);
			toolbarItems = defaultToolbarItems;
		}
	}

	async function saveConfiguration() {
		const settingsPanel = document.getElementById('gemini-mod-settings-panel');
		if (!settingsPanel) return;

		const newItems = [];
		settingsPanel.querySelectorAll('#items-container > .item-group').forEach(group => {
			const type = group.dataset.type;
			if (type === 'button') {
				const label = group.querySelector('.label-input').value.trim();
				const text = group.querySelector('.text-input').value;
				if (label) newItems.push({ type, label, text });
			} else if (type === 'dropdown') {
				const placeholder = group.querySelector('.placeholder-input').value.trim();
				const options = [];
				group.querySelectorAll('.option-item').forEach(opt => {
					const label = opt.querySelector('.label-input').value.trim();
					const text = opt.querySelector('.text-input').value;
					if (label) options.push({ label, text });
				});
				if (placeholder && options.length > 0) {
					newItems.push({ type, placeholder, options });
				}
			}
		});

		try {
			await GM_setValue(STORAGE_KEY_TOOLBAR_ITEMS, JSON.stringify(newItems));
			await loadConfiguration();
			rebuildToolbar();
			toggleSettingsPanel(false);
		} catch (e) {
			displayUserscriptMessage("Failed to save settings. See console for details.");
			console.error("Gemini Mod: Error saving settings:", e);
		}
	}

	function clearElement(element) {
		if (element) {
			while (element.firstChild) {
				element.removeChild(element.firstChild);
			}
		}
	}

	// --- Toolbar Creation ---

	function createToolbar() {
		const toolbarId = 'gemini-snippet-toolbar-userscript';
		let toolbar = document.getElementById(toolbarId);
		if (toolbar) {
			clearElement(toolbar);
		} else {
			toolbar = document.createElement('div');
			toolbar.id = toolbarId;
			document.body.insertBefore(toolbar, document.body.firstChild);
		}

		toolbarItems.forEach(item => {
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
			}
		});

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
	}

	function rebuildToolbar() {
		const toolbar = document.getElementById('gemini-snippet-toolbar-userscript');
		if (toolbar) createToolbar();
	}


	// --- Settings Panel UI ---

	function updateSortButtonsState(container) {
		const items = Array.from(container.children);
		items.forEach((item, i) => {
			item.querySelector('.sort-btn-up').disabled = (i === 0);
			item.querySelector('.sort-btn-down').disabled = (i === items.length - 1);
		});
	}

	function createSettingsPanel() {
		if (document.getElementById('gemini-mod-settings-overlay')) return;

		const overlay = document.createElement('div');
		overlay.id = 'gemini-mod-settings-overlay';

		const panel = document.createElement('div');
		panel.id = 'gemini-mod-settings-panel';
		overlay.appendChild(panel);

		panel.appendChild(document.createElement('h2')).textContent = 'Gemini Mod Settings';

		const itemsContainer = document.createElement('div');
		itemsContainer.id = 'items-container';
		panel.appendChild(itemsContainer);

		const addItemBtn = document.createElement('button');
		addItemBtn.textContent = 'Add Item';
		addItemBtn.addEventListener('click', showItemTypeModal);
		panel.appendChild(addItemBtn);

		const actionsDiv = document.createElement('div');
		actionsDiv.className = 'settings-actions';
		const saveBtn = document.createElement('button');
		saveBtn.textContent = 'Save & Close';
		saveBtn.addEventListener('click', saveConfiguration);
		actionsDiv.appendChild(saveBtn);

		const cancelBtn = document.createElement('button');
		cancelBtn.textContent = 'Cancel';
		cancelBtn.addEventListener('click', () => toggleSettingsPanel(false));
		actionsDiv.appendChild(cancelBtn);
		panel.appendChild(actionsDiv);

		document.body.appendChild(overlay);
	}

	function showItemTypeModal() {
		let modal = document.getElementById('gemini-mod-type-modal-overlay');
		if (!modal) {
			modal = document.createElement('div');
			modal.id = 'gemini-mod-type-modal-overlay';
			const modalContent = document.createElement('div');
			modalContent.id = 'gemini-mod-type-modal';
			modalContent.innerHTML = '<h3>Select Item Type</h3>';

			const btnButton = document.createElement('button');
			btnButton.textContent = 'Button';
			btnButton.addEventListener('click', () => {
				addItemToPanel({ type: 'button' });
				modal.style.display = 'none';
			});

			const btnDropdown = document.createElement('button');
			btnDropdown.textContent = 'Dropdown';
			btnDropdown.addEventListener('click', () => {
				addItemToPanel({ type: 'dropdown' });
				modal.style.display = 'none';
			});

			modalContent.appendChild(btnButton);
			modalContent.appendChild(btnDropdown);
			modal.appendChild(modalContent);
			document.body.appendChild(modal);
		}
		modal.style.display = 'block';
	}

	function populateSettingsPanel() {
		const container = document.getElementById('items-container');
		clearElement(container);
		toolbarItems.forEach(item => addItemToPanel(item));
	}

	function addItemToPanel(item) {
		const container = document.getElementById('items-container');
		const group = document.createElement('div');
		group.className = 'item-group';
		group.dataset.type = item.type;

		// Sort Controls
		const sortControls = document.createElement('div');
		sortControls.className = 'sort-controls';
		const upBtn = document.createElement('button');
		upBtn.textContent = '▲';
		upBtn.className = 'sort-btn sort-btn-up';
		upBtn.addEventListener('click', () => {
			if (group.previousElementSibling) {
				container.insertBefore(group, group.previousElementSibling);
				updateSortButtonsState(container);
			}
		});
		const downBtn = document.createElement('button');
		downBtn.textContent = '▼';
		downBtn.className = 'sort-btn sort-btn-down';
		downBtn.addEventListener('click', () => {
			if (group.nextElementSibling) {
				container.insertBefore(group.nextElementSibling, group);
				updateSortButtonsState(container);
			}
		});
		sortControls.appendChild(upBtn);
		sortControls.appendChild(downBtn);
		group.appendChild(sortControls);

		// Item Content
		const contentDiv = document.createElement('div');
		contentDiv.className = 'item-content';

		if (item.type === 'button') {
			const button = item || { label: '', text: '' };
			const labelLabel = document.createElement('label');
			labelLabel.textContent = 'Button Label';
			contentDiv.appendChild(labelLabel);

			const labelInput = document.createElement('input');
			labelInput.type = 'text';
			labelInput.className = 'label-input';
			labelInput.value = button.label || '';
			contentDiv.appendChild(labelInput);

			const textLabel = document.createElement('label');
			textLabel.textContent = 'Snippet Text';
			contentDiv.appendChild(textLabel);

			const textInput = document.createElement('textarea');
			textInput.className = 'text-input';
			textInput.value = button.text || '';
			contentDiv.appendChild(textInput);
		} else if (item.type === 'dropdown') {
			const dropdown = item || { placeholder: '', options: [] };
			const placeholderLabel = document.createElement('label');
			placeholderLabel.textContent = 'Dropdown Placeholder';
			contentDiv.appendChild(placeholderLabel);

			const placeholderInput = document.createElement('input');
			placeholderInput.type = 'text';
			placeholderInput.className = 'placeholder-input';
			placeholderInput.value = dropdown.placeholder || '';
			contentDiv.appendChild(placeholderInput);

			const optionsContainer = document.createElement('div');
			optionsContainer.className = 'dropdown-options-container';
			optionsContainer.appendChild(document.createElement('label')).textContent = 'Options';
			contentDiv.appendChild(optionsContainer);

			const addOptionBtn = document.createElement('button');
			addOptionBtn.textContent = 'Add Option';
			addOptionBtn.addEventListener('click', () => addOptionToDropdownPanel(optionsContainer));
			contentDiv.appendChild(addOptionBtn);

			if (dropdown.options && dropdown.options.length > 0) {
				dropdown.options.forEach(opt => addOptionToDropdownPanel(optionsContainer, opt));
			} else {
				addOptionToDropdownPanel(optionsContainer);
			}
		}
		group.appendChild(contentDiv);

		// Remove Button
		const removeBtn = document.createElement('button');
		removeBtn.className = 'remove-btn';
		removeBtn.textContent = 'Remove';
		removeBtn.addEventListener('click', () => {
			group.remove();
			updateSortButtonsState(container);
		});
		group.appendChild(removeBtn);

		container.appendChild(group);
		updateSortButtonsState(container);
	}

	function addOptionToDropdownPanel(container, option = { label: '', text: '' }) {
		const item = document.createElement('div');
		item.className = 'option-item';

		const labelInput = document.createElement('input');
		labelInput.type = 'text';
		labelInput.className = 'label-input';
		labelInput.placeholder = 'Option Label';
		labelInput.value = option.label;
		item.appendChild(labelInput);

		const textInput = document.createElement('textarea');
		textInput.className = 'text-input';
		textInput.placeholder = 'Snippet Text';
		textInput.value = option.text;
		item.appendChild(textInput);

		const removeBtn = document.createElement('button');
		removeBtn.className = 'remove-btn';
		removeBtn.textContent = 'X';
		removeBtn.addEventListener('click', () => item.remove());
		item.appendChild(removeBtn);

		container.appendChild(item);
	}


	function toggleSettingsPanel(forceState) {
		const overlay = document.getElementById('gemini-mod-settings-overlay');
		if (!overlay) return;
		const isVisible = overlay.style.display === 'block';
		const show = typeof forceState === 'boolean' ? forceState : !isVisible;

		if (show) {
			populateSettingsPanel();
			overlay.style.display = 'block';
		} else {
			overlay.style.display = 'none';
		}
	}


	// --- Download Logic ---

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
			return `${sanitizeBasename(match[1])}.${match[2].toLowerCase()}`;
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
		setTimeout(() => {
			try {
				createToolbar();
				createSettingsPanel();
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