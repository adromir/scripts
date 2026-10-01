// ==UserScript==
// @name          Google Gemini Mod (Toolbar, Folders & Download)
// @namespace     http://tampermonkey.net/
// @version       0.0.33
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
// @require       https://update.greasyfork.org/scripts/584958/gemini_mod_styles.js?v=0.0.33
// @require       https://update.greasyfork.org/scripts/584959/gemini_mod_utils.js
// @downloadURL   https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js
// @updateURL     https://github.com/adromir/scripts/raw/refs/heads/main/userscripts/gemini-snippets/google_gemini_mod.user.js
// ==/UserScript==

(function () {
	'use strict';

	// Ensure Namespace exists
	window.GeminiMod = window.GeminiMod || {};

// ===================================================================================
	// I. CONFIGURATION SECTION
	// ===================================================================================

	// --- Storage Keys ---
	const STORAGE_KEY_TOOLBAR_ITEMS = "geminiModToolbarItems_v2";
	const STORAGE_KEY_FOLDERS = 'gemini_folders';
	const STORAGE_KEY_CONVO_FOLDERS = 'gemini_convo_folders';
	const STORAGE_KEY_SYNC_KEY = 'gemini_mod_sync_key';
	const STORAGE_KEY_AUTH_SESSION = 'gemini_mod_auth_session';
	const STORAGE_KEY_SUPABASE_URL = 'gemini_mod_supabase_url';
	const STORAGE_KEY_SUPABASE_KEY = 'gemini_mod_supabase_key';
	const STORAGE_KEY_LAST_SYNC = 'gemini_mod_last_sync';
	const STORAGE_KEY_LAST_SYNC_CLIENT = 'gemini_mod_last_sync_client';
	const CLIENT_NAME = 'Userscript';

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
		const settingsCSS = `
			#gemini-mod-settings-panel {
				width: 90vw !important; max-width: 860px !important;
				height: 620px !important; max-height: 85vh !important;
				display: flex !important; flex-direction: column !important; overflow: hidden !important;
			}
			#gemini-mod-settings-panel .settings-container {
				display: flex !important; flex: 1 1 0% !important; min-height: 0 !important;
				height: calc(100% - 57px) !important; overflow: hidden !important;
			}
			#gemini-mod-settings-panel .settings-sidebar {
				width: 240px !important; min-width: 240px !important; flex-shrink: 0 !important;
				border-right: 1px solid #3c4043 !important; padding: 16px 12px !important;
				display: flex !important; flex-direction: column !important; gap: 8px !important;
				background-color: #1e2022 !important; box-sizing: border-box !important; overflow-y: auto !important;
			}
			#gemini-mod-settings-panel .tab-btn {
				display: flex !important; align-items: center !important; gap: 10px !important; text-align: left !important;
				padding: 10px 14px !important; background: transparent !important; border: none !important;
				color: #9aa0a6 !important; cursor: pointer !important; border-radius: 8px !important;
				font-size: 14px !important; font-weight: 500 !important; white-space: nowrap !important;
				width: 100% !important; box-sizing: border-box !important;
				transition: background-color 0.15s ease, color 0.15s ease !important;
			}
			#gemini-mod-settings-panel .tab-btn:hover { background-color: rgba(255, 255, 255, 0.08) !important; color: #e3e3e3 !important; }
			#gemini-mod-settings-panel .tab-btn.active { background-color: #1a73e8 !important; color: #ffffff !important; font-weight: 600 !important; }
			#gemini-mod-settings-panel .settings-sidebar-footer {
				margin-top: auto !important; display: flex !important; flex-direction: column !important;
				gap: 10px !important; width: 100% !important; padding-top: 14px !important;
				border-top: 1px solid #3c4043 !important; box-sizing: border-box !important; flex-shrink: 0 !important;
			}
			#gemini-mod-settings-panel .settings-sidebar-footer button {
				width: 100% !important; height: 38px !important; box-sizing: border-box !important; margin: 0 !important;
				border-radius: 8px !important; font-size: 13px !important; cursor: pointer !important;
				display: inline-flex !important; align-items: center !important; justify-content: center !important;
				transition: background-color 0.15s ease !important;
			}
			#gemini-mod-settings-panel .settings-sidebar-footer .dialog-btn-cancel {
				background-color: #353739 !important; color: #e3e3e3 !important;
				border: 1px solid #5f6368 !important; font-weight: 500 !important;
			}
			#gemini-mod-settings-panel .settings-sidebar-footer .dialog-btn-cancel:hover { background-color: #4a4e51 !important; }
			#gemini-mod-settings-panel .settings-sidebar-footer .dialog-btn-confirm {
				background-color: #8ab4f8 !important; color: #1f1f1f !important;
				border: none !important; font-weight: 600 !important;
			}
			#gemini-mod-settings-panel .settings-sidebar-footer .dialog-btn-confirm:hover { background-color: #aecbfa !important; }
			#gemini-mod-settings-panel .settings-content {
				flex: 1 1 auto !important; height: 100% !important; min-height: 0 !important;
				padding: 24px 28px !important; overflow-y: auto !important;
				background-color: #242628 !important; box-sizing: border-box !important;
			}
			#gemini-mod-settings-panel .sync-heading {
				margin: 0 0 6px 0 !important; font-size: 1.15rem !important; font-weight: 600 !important; color: #e3e3e3 !important;
			}
			#gemini-mod-settings-panel .sync-subheading {
				font-size: 13px !important; color: #9aa0a6 !important; margin: 0 0 18px 0 !important; line-height: 1.4 !important;
			}
			#gemini-mod-settings-panel .sync-status-card {
				background-color: #1a1c1e !important; border: 1px solid #3c4043 !important; border-radius: 12px !important;
				padding: 16px 20px !important; margin-bottom: 20px !important; display: flex !important;
				flex-direction: column !important; gap: 4px !important; box-sizing: border-box !important;
			}
			#gemini-mod-settings-panel .sync-auth-box {
				background-color: #1e2022 !important; border: 1px solid #3c4043 !important; border-radius: 12px !important;
				padding: 20px !important; margin-bottom: 22px !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15) !important;
				box-sizing: border-box !important;
			}
			#gemini-mod-settings-panel .sync-input-group { margin-bottom: 14px !important; width: 100% !important; max-width: 480px !important; }
			#gemini-mod-settings-panel .sync-input-group label { display: block !important; margin: 0 0 6px 0 !important; font-size: 13px !important; font-weight: 500 !important; color: #c4c7c5 !important; }
			#gemini-mod-settings-panel .sync-input-group input {
				width: 100% !important; max-width: 480px !important; height: 40px !important; padding: 8px 12px !important;
				border-radius: 8px !important; border: 1px solid #5f6368 !important; background-color: #282a2c !important;
				color: #e3e3e3 !important; box-sizing: border-box !important; font-size: 14px !important; outline: none !important;
			}
			#gemini-mod-settings-panel .sync-password-wrapper { display: flex !important; align-items: center !important; gap: 8px !important; width: 100% !important; max-width: 480px !important; box-sizing: border-box !important; }
			#gemini-mod-settings-panel .sync-password-wrapper input {
				flex: 1 1 auto !important; min-width: 0 !important; width: 100% !important; height: 40px !important;
				padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important;
				background-color: #282a2c !important; color: #e3e3e3 !important; box-sizing: border-box !important;
				font-size: 14px !important; outline: none !important;
			}
			#gemini-mod-settings-panel .sync-password-toggle-btn {
				height: 40px !important; width: 42px !important; min-width: 42px !important; padding: 0 !important;
				background-color: #353739 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important;
				color: #e3e3e3 !important; cursor: pointer !important; display: inline-flex !important;
				align-items: center !important; justify-content: center !important; font-size: 16px !important; flex-shrink: 0 !important;
				box-sizing: border-box !important;
			}
		`;
		const fullCSS = (window.GeminiMod.styles || '') + '\n' + settingsCSS;
		try {
			if (typeof GM_addStyle !== 'undefined') {
				GM_addStyle(fullCSS);
			} else {
				const style = document.createElement('style');
				style.textContent = fullCSS;
				document.head.appendChild(style);
			}
		} catch (error) {
			console.error("Gemini Mod Userscript: Failed to inject custom CSS:", error);
			const style = document.createElement('style');
			style.textContent = fullCSS;
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
				toolbarItems = toolbarItems.filter(item => item && item.type !== 'settings');
			} else {
				toolbarItems = defaultToolbarItems.filter(item => item && item.type !== 'settings');
			}
			// Folder items
			folders = await GM_getValue(STORAGE_KEY_FOLDERS, []);
			conversationFolders = await GM_getValue(STORAGE_KEY_CONVO_FOLDERS, {});
		} catch (e) {
			console.error("Gemini Mod: Error loading configuration, using defaults.", e);
			toolbarItems = defaultToolbarItems.filter(item => item && item.type !== 'settings');
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

	function toggleSettingsPanel(forceState) {
		let overlay = document.getElementById('gemini-mod-settings-overlay');
		let panel = document.getElementById('gemini-mod-settings-panel');

		if (!overlay) {
			createSettingsPanel();
			overlay = document.getElementById('gemini-mod-settings-overlay');
			panel = document.getElementById('gemini-mod-settings-panel');
		}
		if (!overlay) return;
		const isVisible = overlay.style.display === 'block';
		const show = typeof forceState === 'boolean' ? forceState : !isVisible;

		if (show) {
			populateSettingsPanel(panel);
			overlay.style.display = 'block';
		} else {
			overlay.style.display = 'none';
		}
	}

	// ===================================================================================
	// III.A CLOUD SYNC ENGINE (Supabase & Local File Backup)
	// ===================================================================================

	const GeminiSync = {
		DEFAULT_SUPABASE_URL: 'https://wurrurgloawzvtiyilyr.supabase.co',
		DEFAULT_SUPABASE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1cnJ1cmdsb2F3enZ0aXlpbHlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NzgwODQsImV4cCI6MjEwNjM1NDA4NH0.aQ8GNObnE9xH8Jd3Rpv9eSp3c72ymjKuWC4Z8qGUQh4',

		getSession: async function () {
			try {
				const raw = await GM_getValue(STORAGE_KEY_AUTH_SESSION, null);
				if (!raw) return null;
				return typeof raw === 'string' ? JSON.parse(raw) : raw;
			} catch (_) {
				return null;
			}
		},

		setSession: async function (session) {
			if (session) {
				await GM_setValue(STORAGE_KEY_AUTH_SESSION, JSON.stringify(session));
			} else {
				await this.clearSession();
			}
		},

		clearSession: async function () {
			await GM_deleteValue(STORAGE_KEY_AUTH_SESSION);
		},

		isAuthenticated: async function () {
			const s = await this.getSession();
			return !!(s && s.access_token && s.user);
		},

		getCurrentUser: async function () {
			const s = await this.getSession();
			return s ? s.user : null;
		},

		getSupabaseConfig: async function () {
			const url = (await GM_getValue(STORAGE_KEY_SUPABASE_URL, '')) || this.DEFAULT_SUPABASE_URL;
			const key = (await GM_getValue(STORAGE_KEY_SUPABASE_KEY, '')) || this.DEFAULT_SUPABASE_KEY;
			return {
				url: url.trim().replace(/\/+$/, ''),
				key: key.trim()
			};
		},

		setSupabaseConfig: async function (url, key) {
			await GM_setValue(STORAGE_KEY_SUPABASE_URL, (url || '').trim().replace(/\/+$/, ''));
			await GM_setValue(STORAGE_KEY_SUPABASE_KEY, (key || '').trim());
		},

		resetSupabaseConfig: async function () {
			await GM_deleteValue(STORAGE_KEY_SUPABASE_URL);
			await GM_deleteValue(STORAGE_KEY_SUPABASE_KEY);
		},

		getLastSyncInfo: async function () {
			const ts = await GM_getValue(STORAGE_KEY_LAST_SYNC, null);
			const client = await GM_getValue(STORAGE_KEY_LAST_SYNC_CLIENT, null);
			return {
				timestamp: ts ? parseInt(ts, 10) : null,
				client: client || null
			};
		},

		request: function (endpoint, method, data, config, customToken = null) {
			return new Promise((resolve, reject) => {
				const url = `${config.url}${endpoint}`;
				const authToken = customToken || config.key;
				const headers = {
					'apikey': config.key,
					'Authorization': `Bearer ${authToken}`
				};
				if (data) headers['Content-Type'] = 'application/json';
				if (method === 'POST') {
					headers['Prefer'] = 'resolution=merge-duplicates,return=representation';
				}

				if (typeof GM_xmlhttpRequest === 'function') {
					GM_xmlhttpRequest({
						method: method,
						url: url,
						headers: headers,
						data: data ? JSON.stringify(data) : undefined,
						onload: (res) => {
							if (res.status >= 200 && res.status < 300) {
								try {
									resolve(res.responseText ? JSON.parse(res.responseText) : null);
								} catch (_) {
									resolve(res.responseText);
								}
							} else {
								let msg = `HTTP ${res.status}`;
								try {
									const p = JSON.parse(res.responseText);
									if (p.msg) msg = p.msg;
									else if (p.message) msg = p.message;
									else if (p.error_description) msg = p.error_description;
									else if (p.error) msg = typeof p.error === 'string' ? p.error : JSON.stringify(p.error);
								} catch (_) {
									if (res.responseText) msg += `: ${res.responseText.slice(0, 120)}`;
								}
								reject(new Error(msg));
							}
						},
						onerror: () => reject(new Error("Network request failed"))
					});
					return;
				}

				fetch(url, {
					method: method,
					headers: headers,
					body: data ? JSON.stringify(data) : undefined
				}).then(async res => {
					if (res.ok) {
						const txt = await res.text();
						try { resolve(txt ? JSON.parse(txt) : null); }
						catch (_) { resolve(txt); }
					} else {
						const txt = await res.text();
						let msg = `HTTP ${res.status}`;
						try {
							const p = JSON.parse(txt);
							if (p.msg) msg = p.msg;
							else if (p.message) msg = p.message;
							else if (p.error_description) msg = p.error_description;
							else if (p.error) msg = typeof p.error === 'string' ? p.error : JSON.stringify(p.error);
						} catch (_) {
							if (txt) msg += `: ${txt.slice(0, 100)}`;
						}
						reject(new Error(msg));
					}
				}).catch(reject);
			});
		},

		getValidAccessToken: async function () {
			const session = await this.getSession();
			if (!session || !session.access_token) {
				throw new Error("You must be logged in to sync settings.");
			}

			// If token expires in less than 60 seconds, refresh it
			if (session.refresh_token && session.expires_at && (session.expires_at - Date.now() < 60000)) {
				const config = await this.getSupabaseConfig();
				try {
					const res = await this.request('/auth/v1/token?grant_type=refresh_token', 'POST', {
						refresh_token: session.refresh_token
					}, config);

					if (res && res.access_token) {
						const updatedSession = {
							access_token: res.access_token,
							refresh_token: res.refresh_token || session.refresh_token,
							expires_at: Date.now() + ((res.expires_in || 3600) * 1000),
							user: res.user || session.user
						};
						await this.setSession(updatedSession);
						return updatedSession.access_token;
					}
				} catch (refreshErr) {
					console.warn("Gemini Mod: Token refresh failed:", refreshErr);
					await this.clearSession();
					throw new Error("Session expired. Please log in again.");
				}
			}

			return session.access_token;
		},

		signUp: async function (email, password) {
			const cleanEmail = (email || '').trim();
			const cleanPass = (password || '').trim();
			if (!cleanEmail || !cleanEmail.includes('@')) {
				throw new Error("Please enter a valid email address.");
			}
			if (!cleanPass || cleanPass.length < 6) {
				throw new Error("Password must be at least 6 characters.");
			}

			const config = await this.getSupabaseConfig();
			const res = await this.request('/auth/v1/signup', 'POST', {
				email: cleanEmail,
				password: cleanPass
			}, config);

			// If auto-confirm gave us a session immediately:
			if (res && res.access_token) {
				const session = {
					access_token: res.access_token,
					refresh_token: res.refresh_token,
					expires_at: Date.now() + ((res.expires_in || 3600) * 1000),
					user: {
						id: res.user.id,
						email: res.user.email
					}
				};
				await this.setSession(session);
				return session.user;
			}

			// Otherwise, perform sign in to fetch session tokens
			return await this.signIn(cleanEmail, cleanPass);
		},

		signIn: async function (email, password) {
			const cleanEmail = (email || '').trim();
			const cleanPass = (password || '').trim();
			if (!cleanEmail || !cleanPass) {
				throw new Error("Please enter your email and password.");
			}

			const config = await this.getSupabaseConfig();
			const res = await this.request('/auth/v1/token?grant_type=password', 'POST', {
				email: cleanEmail,
				password: cleanPass
			}, config);

			if (!res || !res.access_token || !res.user) {
				throw new Error("Invalid response received from authentication server.");
			}

			const session = {
				access_token: res.access_token,
				refresh_token: res.refresh_token,
				expires_at: Date.now() + ((res.expires_in || 3600) * 1000),
				user: {
					id: res.user.id,
					email: res.user.email
				}
			};
			await this.setSession(session);
			return session.user;
		},

		signOut: async function () {
			const session = await this.getSession();
			if (session && session.access_token) {
				const config = await this.getSupabaseConfig();
				try {
					await this.request('/auth/v1/logout', 'POST', null, config, session.access_token);
				} catch (_) {
					// Best effort
				}
			}
			await this.clearSession();
		},

		saveToCloud: async function (currentSettings, clientName = 'Userscript') {
			const token = await this.getValidAccessToken();
			const session = await this.getSession();
			if (!session || !session.user || !session.user.id) {
				throw new Error("Unable to identify authenticated user. Please log in again.");
			}

			const config = await this.getSupabaseConfig();
			const payload = {
				user_id: session.user.id,
				data: {
					toolbarItems: currentSettings.toolbarItems,
					folders: currentSettings.folders,
					conversationFolders: currentSettings.conversationFolders,
					timestamp: Date.now(),
					client: clientName
				},
				client_name: clientName,
				updated_at: new Date().toISOString()
			};

			// Check client-side payload size limit (Postgres limit is 500KB)
			const serialized = JSON.stringify(payload.data);
			if (serialized.length > 450000) {
				throw new Error(`Settings size (${Math.round(serialized.length / 1024)} KB) exceeds the 450 KB safety limit.`);
			}

			await this.request('/rest/v1/gemini_mod_settings', 'POST', payload, config, token);

			const now = Date.now();
			await GM_setValue(STORAGE_KEY_LAST_SYNC, now.toString());
			await GM_setValue(STORAGE_KEY_LAST_SYNC_CLIENT, clientName);
			return payload;
		},

		loadFromCloud: async function () {
			const token = await this.getValidAccessToken();
			const config = await this.getSupabaseConfig();
			const endpoint = '/rest/v1/gemini_mod_settings?select=*';
			const res = await this.request(endpoint, 'GET', null, config, token);

			if (!res || !Array.isArray(res) || res.length === 0) {
				throw new Error("No cloud backup found for this account. Upload your settings to the cloud first!");
			}

			const record = res[0];
			const data = record.data;
			if (!data || (!data.toolbarItems && !data.folders)) {
				throw new Error("Invalid or empty data received from cloud.");
			}

			const sourceClient = record.client_name || data.client || 'Cloud';
			const now = Date.now();
			await GM_setValue(STORAGE_KEY_LAST_SYNC, now.toString());
			await GM_setValue(STORAGE_KEY_LAST_SYNC_CLIENT, sourceClient);

			return {
				toolbarItems: data.toolbarItems || [],
				folders: data.folders || [],
				conversationFolders: data.conversationFolders || {},
				timestamp: data.timestamp || record.updated_at,
				client: sourceClient
			};
		},

		exportSettingsToFile: function (dataToSave) {
			const fullData = {
				toolbarItems: dataToSave.toolbarItems,
				folders: dataToSave.folders,
				conversationFolders: dataToSave.conversationFolders,
				timestamp: Date.now(),
				version: 1
			};
			const blob = new Blob([JSON.stringify(fullData, null, 2)], { type: "application/json" });
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = `gemini_settings_backup_${new Date().toISOString().slice(0, 10)}.json`;
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			URL.revokeObjectURL(url);
		},

		importSettingsFromFile: function (file, onImportSuccess) {
			const reader = new FileReader();
			reader.onload = async (e) => {
				try {
					const data = JSON.parse(e.target.result);
					if (data && (data.toolbarItems || data.folders)) {
						onImportSuccess(data);
					} else {
						displayMessage("Invalid backup file: file must contain toolbarItems or folders.");
					}
				} catch (err) {
					displayMessage("Error reading file: " + err.message);
				}
			};
			reader.readAsText(file);
		}
	};

	window.GeminiMod.sync = GeminiSync;
	window.GeminiMod.drive = GeminiSync; // Backwards compatibility alias

	function createSettingsPanel() {
		if (document.getElementById('gemini-mod-settings-overlay')) return;

		const overlay = document.createElement('div');
		overlay.id = 'gemini-mod-settings-overlay';
		overlay.style.cssText = 'display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.6); z-index: 999999;';

		const panel = document.createElement('div');
		panel.id = 'gemini-mod-settings-panel';
		panel.style.cssText = 'position: fixed !important; top: 50% !important; left: 50% !important; transform: translate(-50%, -50%) !important; width: 90vw !important; max-width: 860px !important; height: 620px !important; max-height: 85vh !important; background-color: #202124 !important; color: #e3e3e3 !important; border-radius: 16px !important; border: 1px solid #3c4043 !important; box-shadow: 0 16px 40px rgba(0,0,0,0.6) !important; display: flex !important; flex-direction: column !important; overflow: hidden !important; padding: 0 !important; font-family: "Google Sans Flex", "Google Sans", Roboto, Arial, sans-serif !important; z-index: 1000000 !important; box-sizing: border-box !important;';
		overlay.appendChild(panel);

		const header = document.createElement('div');
		header.className = 'settings-header';
		header.style.cssText = 'display: flex !important; align-items: center !important; justify-content: space-between !important; padding: 16px 24px !important; border-bottom: 1px solid #3c4043 !important; background-color: #242628 !important; margin: 0 !important; flex-shrink: 0 !important;';
		const title = document.createElement('h2');
		title.textContent = 'Gemini Mod Settings';
		title.style.cssText = 'margin: 0 !important; padding: 0 !important; font-size: 1.2rem !important; font-weight: 600 !important; color: #e3e3e3 !important; border: none !important;';
		header.appendChild(title);
		panel.appendChild(header);

		// Create Container for Tabbed Layout
		const container = document.createElement('div');
		container.className = 'settings-container';
		container.style.cssText = 'display: flex !important; flex: 1 1 0% !important; height: calc(100% - 57px) !important; min-height: 0 !important; overflow: hidden !important;';

		// --- SIDEBAR ---
		const sidebar = document.createElement('div');
		sidebar.className = 'settings-sidebar';
		sidebar.style.cssText = 'width: 240px !important; min-width: 240px !important; flex-shrink: 0 !important; border-right: 1px solid #3c4043 !important; padding: 16px 12px !important; display: flex !important; flex-direction: column !important; gap: 8px !important; background-color: #1e2022 !important; box-sizing: border-box !important; overflow-y: auto !important;';

		const tabs = [
			{ id: 'tab-toolbar', label: '🛠️ Toolbar' },
			{ id: 'tab-sync', label: '☁️ Cloud Sync' },
			{ id: 'tab-reset', label: '⚠️ Danger Zone' }
		];

		tabs.forEach((tab, index) => {
			const btn = document.createElement('button');
			btn.className = 'tab-btn' + (index === 0 ? ' active' : '');
			btn.textContent = tab.label;
			btn.dataset.target = tab.id;
			btn.style.cssText = `display: flex !important; align-items: center !important; gap: 10px !important; text-align: left !important; padding: 10px 14px !important; background-color: ${index === 0 ? '#1a73e8' : 'transparent'} !important; border: none !important; color: ${index === 0 ? '#ffffff' : '#9aa0a6'} !important; cursor: pointer !important; border-radius: 8px !important; font-size: 14px !important; font-weight: ${index === 0 ? '600' : '500'} !important; white-space: nowrap !important; width: 100% !important; box-sizing: border-box !important; transition: background-color 0.15s ease, color 0.15s ease !important;`;
			btn.onclick = () => {
				document.querySelectorAll('.tab-btn').forEach(b => {
					b.classList.remove('active');
					b.style.backgroundColor = 'transparent';
					b.style.color = '#9aa0a6';
					b.style.fontWeight = '500';
				});
				document.querySelectorAll('.tab-pane').forEach(p => {
					p.classList.remove('active');
					p.style.display = 'none';
				});
				btn.classList.add('active');
				btn.style.backgroundColor = '#1a73e8';
				btn.style.color = '#ffffff';
				btn.style.fontWeight = '600';
				const targetPane = document.getElementById(tab.id);
				if (targetPane) {
					targetPane.classList.add('active');
					targetPane.style.display = 'block';
				}
				if (tab.id === 'tab-sync') updateSettingsPanelSyncStatus();
			};
			sidebar.appendChild(btn);
		});

		// Footer Buttons Container (pinned strictly to bottom of sidebar)
		const sidebarFooter = document.createElement('div');
		sidebarFooter.className = 'settings-sidebar-footer';
		sidebarFooter.style.cssText = 'margin-top: auto !important; display: flex !important; flex-direction: column !important; gap: 10px !important; width: 100% !important; padding-top: 14px !important; border-top: 1px solid #3c4043 !important; box-sizing: border-box !important; flex-shrink: 0 !important;';

		// Close Button
		const closeButton = document.createElement('button');
		closeButton.textContent = 'Close';
		closeButton.className = 'custom-dialog-btn dialog-btn-cancel';
		closeButton.style.cssText = 'width: 100% !important; height: 38px !important; box-sizing: border-box !important; margin: 0 !important; background-color: #353739 !important; color: #e3e3e3 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; font-weight: 500 !important; font-size: 13px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; transition: background-color 0.15s ease !important;';
		closeButton.addEventListener('click', () => toggleSettingsPanel(false));
		sidebarFooter.appendChild(closeButton);

		// Save Button
		const saveBtnClose = document.createElement('button');
		saveBtnClose.textContent = 'Save & Close';
		saveBtnClose.className = 'custom-dialog-btn dialog-btn-confirm';
		saveBtnClose.style.cssText = 'width: 100% !important; height: 38px !important; box-sizing: border-box !important; margin: 0 !important; background-color: #8ab4f8 !important; color: #1f1f1f !important; border: none !important; border-radius: 8px !important; font-weight: 600 !important; font-size: 13px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; transition: background-color 0.15s ease !important;';
		saveBtnClose.addEventListener('click', saveToolbarConfiguration);
		sidebarFooter.appendChild(saveBtnClose);

		sidebar.appendChild(sidebarFooter);

		container.appendChild(sidebar);

		// Content Area
		const content = document.createElement('div');
		content.className = 'settings-content';
		content.style.cssText = 'flex: 1 1 auto !important; height: 100% !important; min-height: 0 !important; padding: 24px 28px !important; overflow-y: auto !important; background-color: #242628 !important; box-sizing: border-box !important;';

		// --- TAB 1: TOOLBAR ---
		const tabToolbar = document.createElement('div');
		tabToolbar.id = 'tab-toolbar';
		tabToolbar.className = 'tab-pane active';
		tabToolbar.style.display = 'block';

		// Add Item Button
		const addItemBtn = document.createElement('button');
		addItemBtn.textContent = '+ Add New Item';
		addItemBtn.className = 'custom-dialog-btn dialog-btn-confirm';
		addItemBtn.style.cssText = 'background-color: #8ab4f8 !important; color: #1f1f1f !important; font-weight: 600 !important; border: none !important; border-radius: 8px !important; padding: 0 20px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; margin-bottom: 20px !important; display: inline-flex !important; align-items: center !important; justify-content: center !important;';
		addItemBtn.addEventListener('click', showAddItemModal);
		tabToolbar.appendChild(addItemBtn);

		const itemsContainer = document.createElement('div');
		itemsContainer.id = 'toolbar-items-container';
		tabToolbar.appendChild(itemsContainer);

		content.appendChild(tabToolbar);


		// --- TAB 2: CLOUD SYNC ---
		const tabSync = document.createElement('div');
		tabSync.id = 'tab-sync';
		tabSync.className = 'tab-pane';
		tabSync.style.display = 'none';

		const syncHeading = document.createElement('h3');
		syncHeading.className = 'sync-heading';
		syncHeading.textContent = 'Cloud Synchronization (Supabase)';
		syncHeading.style.cssText = 'margin: 0 0 6px 0 !important; font-size: 1.15rem !important; font-weight: 600 !important; color: #e3e3e3 !important; border: none !important;';
		tabSync.appendChild(syncHeading);

		const syncDesc = document.createElement('p');
		syncDesc.className = 'sync-subheading';
		syncDesc.textContent = 'Synchronize toolbar items, folders, and conversation mappings between Ferdium, browser userscripts, and across devices.';
		syncDesc.style.cssText = 'font-size: 13px !important; color: #9aa0a6 !important; margin: 0 0 18px 0 !important; line-height: 1.4 !important;';
		tabSync.appendChild(syncDesc);

		// Status card
		const statusCard = document.createElement('div');
		statusCard.className = 'sync-status-card';
		statusCard.style.cssText = 'background-color: #1a1c1e !important; border: 1px solid #3c4043 !important; border-radius: 12px !important; padding: 16px 20px !important; margin-bottom: 20px !important; display: flex !important; flex-direction: column !important; gap: 4px !important; box-sizing: border-box !important;';
		const statusTitle = document.createElement('div');
		statusTitle.id = 'sync-status-text';
		statusTitle.className = 'sync-status-title';
		statusTitle.textContent = 'Status: Checking...';
		statusTitle.style.cssText = 'font-size: 14px !important; font-weight: 600 !important; margin: 0 !important; display: flex !important; align-items: center !important; gap: 8px !important; color: #8ab4f8 !important;';
		const statusDetail = document.createElement('div');
		statusDetail.id = 'sync-last-time-text';
		statusDetail.className = 'sync-status-detail';
		statusDetail.textContent = '';
		statusDetail.style.cssText = 'font-size: 12px !important; color: #9aa0a6 !important; margin: 0 !important;';
		statusCard.appendChild(statusTitle);
		statusCard.appendChild(statusDetail);
		tabSync.appendChild(statusCard);

		// Container 1: Logged-in view
		const loggedInBox = document.createElement('div');
		loggedInBox.id = 'sync-auth-logged-in';
		loggedInBox.style.display = 'none';

		const userCard = document.createElement('div');
		userCard.className = 'sync-user-card';
		userCard.style.cssText = 'display: flex !important; align-items: center !important; justify-content: space-between !important; background-color: #1a1c1e !important; border: 1px solid #3c4043 !important; border-radius: 12px !important; padding: 14px 18px !important; margin-bottom: 18px !important; box-sizing: border-box !important;';

		const userInfo = document.createElement('div');
		userInfo.className = 'sync-user-info';
		userInfo.style.cssText = 'display: flex !important; align-items: center !important; gap: 10px !important; font-size: 14px !important; color: #e3e3e3 !important; font-weight: 500 !important;';
		const userIcon = document.createElement('span');
		userIcon.textContent = '👤';
		const userEmail = document.createElement('span');
		userEmail.id = 'sync-user-email';
		userEmail.textContent = '';
		userInfo.appendChild(userIcon);
		userInfo.appendChild(userEmail);

		const logoutBtn = document.createElement('button');
		logoutBtn.textContent = '🚪 Log Out';
		logoutBtn.className = 'custom-dialog-btn dialog-btn-delete';
		logoutBtn.title = 'Log out of Supabase on this device';
		logoutBtn.style.cssText = 'background-color: #d93025 !important; color: #ffffff !important; border: none !important; border-radius: 8px !important; padding: 8px 16px !important; font-size: 13px !important; font-weight: 500 !important; cursor: pointer !important;';
		logoutBtn.onclick = async () => {
			await GeminiSync.signOut();
			await updateSettingsPanelSyncStatus();
			displayMessage("Logged out successfully.", false);
		};

		userCard.appendChild(userInfo);
		userCard.appendChild(logoutBtn);
		loggedInBox.appendChild(userCard);

		// Sync Actions Box
		const actionsBox = document.createElement('div');
		actionsBox.className = 'sync-actions-box';
		actionsBox.style.cssText = 'display: flex !important; gap: 12px !important; flex-wrap: wrap !important; margin-top: 16px !important; margin-bottom: 24px !important;';

		const uploadBtn = document.createElement('button');
		uploadBtn.textContent = '☁️ Upload to Cloud (Backup)';
		uploadBtn.className = 'custom-dialog-btn sync-btn-primary';
		uploadBtn.title = 'Upload current settings and folders to Supabase';
		uploadBtn.style.cssText = 'background-color: #8ab4f8 !important; color: #1f1f1f !important; font-weight: 600 !important; border: none !important; border-radius: 8px !important; padding: 0 20px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important;';
		uploadBtn.onclick = async () => {
			try {
				await GeminiSync.saveToCloud({
					toolbarItems,
					folders,
					conversationFolders
				}, CLIENT_NAME);
				await updateSettingsPanelSyncStatus();
				displayMessage("Settings uploaded to Cloud successfully!", false);
			} catch (err) {
				displayMessage("Upload failed: " + err.message);
			}
		};

		const downloadBtn = document.createElement('button');
		downloadBtn.textContent = '☁️ Download from Cloud (Sync)';
		downloadBtn.className = 'custom-dialog-btn sync-btn-primary';
		downloadBtn.title = 'Download settings and folders from Supabase and apply them';
		downloadBtn.style.cssText = 'background-color: #8ab4f8 !important; color: #1f1f1f !important; font-weight: 600 !important; border: none !important; border-radius: 8px !important; padding: 0 20px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important;';
		downloadBtn.onclick = async () => {
			try {
				const remote = await GeminiSync.loadFromCloud();
				const clientStr = remote.client ? ` (from ${remote.client})` : '';
				const timeStr = remote.timestamp ? ` from ${new Date(remote.timestamp).toLocaleString()}` : '';
				showConfirm(`This will overwrite your local configuration with cloud settings${clientStr}${timeStr}. Continue?`, async () => {
					await GM_setValue(STORAGE_KEY_TOOLBAR_ITEMS, JSON.stringify(remote.toolbarItems));
					await GM_setValue(STORAGE_KEY_FOLDERS, remote.folders);
					await GM_setValue(STORAGE_KEY_CONVO_FOLDERS, remote.conversationFolders || {});
					displayMessage("Settings downloaded from Cloud! Reloading...", false);
					setTimeout(() => location.reload(), 1000);
				}, 'Overwrite & Apply', 'dialog-btn-confirm');
			} catch (err) {
				displayMessage("Download failed: " + err.message);
			}
		};

		actionsBox.appendChild(uploadBtn);
		actionsBox.appendChild(downloadBtn);
		loggedInBox.appendChild(actionsBox);
		tabSync.appendChild(loggedInBox);

		// Container 2: Logged-out view (Sign Up / Log In)
		const loggedOutBox = document.createElement('div');
		loggedOutBox.id = 'sync-auth-logged-out';
		loggedOutBox.className = 'sync-auth-box';
		loggedOutBox.style.cssText = 'background-color: #1e2022 !important; border: 1px solid #3c4043 !important; border-radius: 12px !important; padding: 20px !important; margin-bottom: 22px !important; box-shadow: 0 4px 12px rgba(0,0,0,0.15) !important; box-sizing: border-box !important;';

		const authNotice = document.createElement('div');
		authNotice.className = 'sync-auth-notice';
		authNotice.textContent = '🛡️ Multi-User Protection: Log in with your email and password to securely access your settings. Each user\'s configuration is strictly isolated with Row-Level Security.';
		authNotice.style.cssText = 'background-color: rgba(138, 180, 248, 0.08) !important; border: 1px solid rgba(138, 180, 248, 0.25) !important; border-radius: 8px !important; padding: 12px 14px !important; color: #8ab4f8 !important; font-size: 13px !important; line-height: 1.45 !important; margin-bottom: 16px !important;';
		loggedOutBox.appendChild(authNotice);

		const emailGroup = document.createElement('div');
		emailGroup.className = 'sync-input-group';
		emailGroup.style.cssText = 'margin-bottom: 14px !important; width: 100% !important; max-width: 480px !important;';
		const emailLabel = document.createElement('label');
		emailLabel.textContent = 'Email:';
		emailLabel.style.cssText = 'display: block !important; margin: 0 0 6px 0 !important; font-size: 13px !important; font-weight: 500 !important; color: #c4c7c5 !important;';
		emailGroup.appendChild(emailLabel);

		const emailInput = document.createElement('input');
		emailInput.id = 'sync-email-input';
		emailInput.type = 'email';
		emailInput.placeholder = 'your.email@example.com';
		emailInput.style.cssText = 'width: 100% !important; max-width: 480px !important; height: 40px !important; padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important; background-color: #282a2c !important; color: #e3e3e3 !important; box-sizing: border-box !important; font-size: 14px !important; outline: none !important; font-family: inherit !important; display: block !important;';
		emailGroup.appendChild(emailInput);
		loggedOutBox.appendChild(emailGroup);

		const passGroup = document.createElement('div');
		passGroup.className = 'sync-input-group';
		passGroup.style.cssText = 'margin-bottom: 14px !important; width: 100% !important; max-width: 480px !important;';
		const passLabel = document.createElement('label');
		passLabel.textContent = 'Password:';
		passLabel.style.cssText = 'display: block !important; margin: 0 0 6px 0 !important; font-size: 13px !important; font-weight: 500 !important; color: #c4c7c5 !important;';
		passGroup.appendChild(passLabel);

		const passRow = document.createElement('div');
		passRow.className = 'sync-password-wrapper';
		passRow.style.cssText = 'display: flex !important; align-items: center !important; gap: 8px !important; width: 100% !important; max-width: 480px !important; box-sizing: border-box !important;';

		const passInput = document.createElement('input');
		passInput.id = 'sync-password-input';
		passInput.type = 'password';
		passInput.placeholder = 'Password (min. 6 characters)';
		passInput.style.cssText = 'flex: 1 1 auto !important; min-width: 0 !important; width: 100% !important; height: 40px !important; padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important; background-color: #282a2c !important; color: #e3e3e3 !important; box-sizing: border-box !important; font-size: 14px !important; outline: none !important; font-family: inherit !important;';

		const togglePassBtn = document.createElement('button');
		togglePassBtn.textContent = '👁️';
		togglePassBtn.type = 'button';
		togglePassBtn.className = 'sync-password-toggle-btn';
		togglePassBtn.title = 'Toggle Password Visibility';
		togglePassBtn.style.cssText = 'height: 40px !important; width: 42px !important; min-width: 42px !important; padding: 0 !important; background-color: #353739 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; color: #e3e3e3 !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; font-size: 16px !important; flex-shrink: 0 !important; box-sizing: border-box !important;';
		togglePassBtn.onclick = () => {
			passInput.type = passInput.type === 'password' ? 'text' : 'password';
		};

		passRow.appendChild(passInput);
		passRow.appendChild(togglePassBtn);
		passGroup.appendChild(passRow);
		loggedOutBox.appendChild(passGroup);

		const authBtnsRow = document.createElement('div');
		authBtnsRow.className = 'sync-auth-btns';
		authBtnsRow.style.cssText = 'display: flex !important; gap: 12px !important; margin-top: 18px !important; align-items: center !important;';

		const loginBtn = document.createElement('button');
		loginBtn.textContent = '🔑 Log In';
		loginBtn.className = 'custom-dialog-btn sync-btn-primary';
		loginBtn.style.cssText = 'background-color: #8ab4f8 !important; color: #1f1f1f !important; font-weight: 600 !important; border: none !important; border-radius: 8px !important; padding: 0 20px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important; box-sizing: border-box !important;';
		loginBtn.onclick = async () => {
			const email = emailInput.value.trim();
			const pass = passInput.value.trim();
			if (!email || !pass) {
				displayMessage("Please enter your email and password.");
				return;
			}
			try {
				loginBtn.disabled = true;
				loginBtn.textContent = 'Logging in...';
				const user = await GeminiSync.signIn(email, pass);
				passInput.value = '';
				await updateSettingsPanelSyncStatus();
				displayMessage(`Welcome back, ${user.email}!`, false);
			} catch (err) {
				displayMessage("Login failed: " + err.message);
			} finally {
				loginBtn.disabled = false;
				loginBtn.textContent = '🔑 Log In';
			}
		};

		const signupBtn = document.createElement('button');
		signupBtn.textContent = '✨ Sign Up';
		signupBtn.className = 'custom-dialog-btn sync-btn-secondary';
		signupBtn.title = 'Create a new sync account with this email and password';
		signupBtn.style.cssText = 'background-color: #353739 !important; color: #e3e3e3 !important; font-weight: 500 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; padding: 0 18px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important; box-sizing: border-box !important;';
		signupBtn.onclick = async () => {
			const email = emailInput.value.trim();
			const pass = passInput.value.trim();
			if (!email || !pass) {
				displayMessage("Please enter an email and password to create an account.");
				return;
			}
			try {
				signupBtn.disabled = true;
				signupBtn.textContent = 'Signing up...';
				const user = await GeminiSync.signUp(email, pass);
				passInput.value = '';
				await updateSettingsPanelSyncStatus();
				displayMessage(`Account created and connected as ${user.email}!`, false);
			} catch (err) {
				displayMessage("Sign up failed: " + err.message);
			} finally {
				signupBtn.disabled = false;
				signupBtn.textContent = '✨ Sign Up';
			}
		};

		authBtnsRow.appendChild(loginBtn);
		authBtnsRow.appendChild(signupBtn);
		loggedOutBox.appendChild(authBtnsRow);

		const signupHelp = document.createElement('p');
		signupHelp.className = 'sync-help-text';
		signupHelp.textContent = '💡 First time? Enter your email and password, then click "Sign Up" to create your personal account.';
		signupHelp.style.cssText = 'font-size: 12px !important; color: #9aa0a6 !important; margin: 12px 0 0 0 !important; line-height: 1.4 !important;';
		loggedOutBox.appendChild(signupHelp);

		tabSync.appendChild(loggedOutBox);

		// Manual File Backup Section
		const manualHeader = document.createElement('h3');
		manualHeader.textContent = '📁 Manual File Backup';
		manualHeader.className = 'sync-heading';
		manualHeader.style.cssText = 'margin: 26px 0 6px 0 !important; font-size: 1.15rem !important; font-weight: 600 !important; color: #e3e3e3 !important; border-top: 1px solid #3c4043 !important; padding-top: 18px !important;';
		tabSync.appendChild(manualHeader);

		const manualDesc = document.createElement('p');
		manualDesc.className = 'sync-subheading';
		manualDesc.textContent = 'Export or import your complete configuration to/from a local .json file.';
		manualDesc.style.cssText = 'font-size: 13px !important; color: #9aa0a6 !important; margin: 0 0 14px 0 !important; line-height: 1.4 !important;';
		tabSync.appendChild(manualDesc);

		const fileRow = document.createElement('div');
		fileRow.className = 'sync-file-row';
		fileRow.style.cssText = 'display: flex !important; gap: 12px !important; margin-bottom: 24px !important; align-items: center !important;';

		const exportBtn = document.createElement('button');
		exportBtn.textContent = '⬇️ Export to File';
		exportBtn.className = 'custom-dialog-btn sync-btn-secondary';
		exportBtn.style.cssText = 'background-color: #353739 !important; color: #e3e3e3 !important; font-weight: 500 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; padding: 0 18px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important; margin: 0 !important; box-sizing: border-box !important;';
		exportBtn.onclick = () => {
			GeminiSync.exportSettingsToFile({ toolbarItems, folders, conversationFolders });
		};

		const importInput = document.createElement('input');
		importInput.type = 'file';
		importInput.accept = '.json';
		importInput.style.display = 'none';
		importInput.onchange = (e) => {
			if (e.target.files.length > 0) {
				GeminiSync.importSettingsFromFile(e.target.files[0], (imported) => {
					showConfirm('Overwrite local settings with imported backup file?', async () => {
						if (imported.toolbarItems) await GM_setValue(STORAGE_KEY_TOOLBAR_ITEMS, JSON.stringify(imported.toolbarItems));
						if (imported.folders) await GM_setValue(STORAGE_KEY_FOLDERS, imported.folders);
						if (imported.conversationFolders) await GM_setValue(STORAGE_KEY_CONVO_FOLDERS, imported.conversationFolders);
						displayMessage("Backup imported successfully! Reloading...", false);
						setTimeout(() => location.reload(), 1000);
					}, 'Import & Overwrite', 'dialog-btn-confirm');
				});
			}
		};

		const importBtn = document.createElement('button');
		importBtn.textContent = '⬆️ Import from File';
		importBtn.className = 'custom-dialog-btn sync-btn-secondary';
		importBtn.style.cssText = 'background-color: #353739 !important; color: #e3e3e3 !important; font-weight: 500 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; padding: 0 18px !important; height: 38px !important; font-size: 14px !important; cursor: pointer !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important; margin: 0 !important; box-sizing: border-box !important;';
		importBtn.onclick = () => importInput.click();

		fileRow.appendChild(exportBtn);
		fileRow.appendChild(importBtn);
		fileRow.appendChild(importInput);
		tabSync.appendChild(fileRow);

		// Advanced Supabase Connection
		const advancedDetails = document.createElement('details');
		advancedDetails.className = 'sync-advanced-details';
		advancedDetails.style.cssText = 'margin-top: 20px !important; border-top: 1px solid #3c4043 !important; padding-top: 16px !important; margin-bottom: 20px !important;';
		const advancedSummary = document.createElement('summary');
		advancedSummary.textContent = '⚙️ Advanced Supabase Connection Settings';
		advancedSummary.style.cssText = 'cursor: pointer !important; color: #8ab4f8 !important; font-size: 13px !important; font-weight: 500 !important; user-select: none !important; outline: none !important; padding: 4px 0 !important;';
		advancedDetails.appendChild(advancedSummary);

		const advBody = document.createElement('div');
		advBody.className = 'sync-advanced-body';
		advBody.style.cssText = 'margin-top: 14px !important; padding: 16px !important; background-color: #1e2022 !important; border: 1px solid #3c4043 !important; border-radius: 10px !important; box-sizing: border-box !important;';

		const urlGroup = document.createElement('div');
		urlGroup.className = 'sync-input-group';
		urlGroup.style.cssText = 'margin-bottom: 14px !important; width: 100% !important; max-width: 480px !important;';
		const urlLabel = document.createElement('label');
		urlLabel.textContent = 'Supabase Project URL:';
		urlLabel.style.cssText = 'display: block !important; margin: 0 0 6px 0 !important; font-size: 13px !important; font-weight: 500 !important; color: #c4c7c5 !important;';
		urlGroup.appendChild(urlLabel);
		const urlInput = document.createElement('input');
		urlInput.id = 'supabase-url-input';
		urlInput.type = 'text';
		urlInput.style.cssText = 'width: 100% !important; max-width: 480px !important; height: 40px !important; padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important; background-color: #282a2c !important; color: #e3e3e3 !important; box-sizing: border-box !important; font-size: 14px !important; outline: none !important; font-family: inherit !important; display: block !important;';
		urlGroup.appendChild(urlInput);
		advBody.appendChild(urlGroup);

		const keyAdvGroup = document.createElement('div');
		keyAdvGroup.className = 'sync-input-group';
		keyAdvGroup.style.cssText = 'margin-bottom: 14px !important; width: 100% !important; max-width: 480px !important;';
		const keyAdvLabel = document.createElement('label');
		keyAdvLabel.textContent = 'Supabase Anon/Publishable Key:';
		keyAdvLabel.style.cssText = 'display: block !important; margin: 0 0 6px 0 !important; font-size: 13px !important; font-weight: 500 !important; color: #c4c7c5 !important;';
		keyAdvGroup.appendChild(keyAdvLabel);
		const keyAdvInput = document.createElement('input');
		keyAdvInput.id = 'supabase-key-input';
		keyAdvInput.type = 'password';
		keyAdvInput.style.cssText = 'width: 100% !important; max-width: 480px !important; height: 40px !important; padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important; background-color: #282a2c !important; color: #e3e3e3 !important; box-sizing: border-box !important; font-size: 14px !important; outline: none !important; font-family: inherit !important; display: block !important;';
		keyAdvGroup.appendChild(keyAdvInput);
		advBody.appendChild(keyAdvGroup);

		const advBtnsRow = document.createElement('div');
		advBtnsRow.style.cssText = 'display: flex !important; gap: 10px !important; margin-top: 14px !important; align-items: center !important;';

		const saveCfgBtn = document.createElement('button');
		saveCfgBtn.textContent = 'Save Custom Connection';
		saveCfgBtn.className = 'custom-dialog-btn sync-btn-secondary';
		saveCfgBtn.style.cssText = 'background-color: #353739 !important; color: #e3e3e3 !important; font-weight: 500 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; padding: 0 16px !important; height: 36px !important; font-size: 13px !important; cursor: pointer !important; margin: 0 !important; box-sizing: border-box !important;';
		saveCfgBtn.onclick = async () => {
			await GeminiSync.setSupabaseConfig(urlInput.value, keyAdvInput.value);
			displayMessage("Custom Supabase connection saved!", false);
		};

		const resetCfgBtn = document.createElement('button');
		resetCfgBtn.textContent = 'Reset to Default Supabase Project';
		resetCfgBtn.className = 'custom-dialog-btn sync-btn-secondary';
		resetCfgBtn.style.cssText = 'background-color: #353739 !important; color: #e3e3e3 !important; font-weight: 500 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important; padding: 0 16px !important; height: 36px !important; font-size: 13px !important; cursor: pointer !important; margin: 0 !important; box-sizing: border-box !important;';
		resetCfgBtn.onclick = async () => {
			await GeminiSync.resetSupabaseConfig();
			urlInput.value = GeminiSync.DEFAULT_SUPABASE_URL;
			keyAdvInput.value = GeminiSync.DEFAULT_SUPABASE_KEY;
			displayMessage("Reset to default Supabase project.", false);
		};

		advBtnsRow.appendChild(saveCfgBtn);
		advBtnsRow.appendChild(resetCfgBtn);
		advBody.appendChild(advBtnsRow);
		advancedDetails.appendChild(advBody);

		tabSync.appendChild(advancedDetails);
		content.appendChild(tabSync);


		// --- TAB 3: RESET ---
		const tabReset = document.createElement('div');
		tabReset.id = 'tab-reset';
		tabReset.className = 'tab-pane';

		const dangerHeading = document.createElement('h3');
		dangerHeading.textContent = 'Danger Zone';
		dangerHeading.style.cssText = 'margin: 0 0 8px 0 !important; font-size: 1.15rem !important; font-weight: 600 !important; color: #f28b82 !important; border: none !important;';
		tabReset.appendChild(dangerHeading);

		const dangerDesc = document.createElement('p');
		dangerDesc.textContent = 'Irreversible reset options for local folder structures and saved configurations.';
		dangerDesc.style.cssText = 'font-size: 13px !important; color: #9aa0a6 !important; margin: 0 0 20px 0 !important; line-height: 1.4 !important;';
		tabReset.appendChild(dangerDesc);

		const resetFoldersBtn = document.createElement('button');
		resetFoldersBtn.textContent = 'Reset Folders Only';
		resetFoldersBtn.className = 'custom-dialog-btn dialog-btn-delete';
		resetFoldersBtn.style.cssText = 'background-color: #d93025 !important; color: #ffffff !important; border: none !important; border-radius: 8px !important; padding: 10px 18px !important; font-size: 13px !important; font-weight: 500 !important; cursor: pointer !important; display: block !important; margin-bottom: 16px !important;';
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
		resetAllBtn.style.cssText = 'background-color: #b3261e !important; color: #ffffff !important; border: none !important; border-radius: 8px !important; padding: 10px 18px !important; font-size: 13px !important; font-weight: 600 !important; cursor: pointer !important; display: block !important;';
		resetAllBtn.addEventListener('click', () => {
			showConfirm("Are you sure? This will execute a full factory reset of the userscript, including Toolbar items, Folders, and Sync configuration.", async () => {
				await GM_deleteValue(STORAGE_KEY_TOOLBAR_ITEMS);
				await GM_deleteValue(STORAGE_KEY_FOLDERS);
				await GM_deleteValue(STORAGE_KEY_CONVO_FOLDERS);
				await GM_deleteValue(STORAGE_KEY_SYNC_KEY);
				await GM_deleteValue(STORAGE_KEY_AUTH_SESSION);
				await GM_deleteValue(STORAGE_KEY_SUPABASE_URL);
				await GM_deleteValue(STORAGE_KEY_SUPABASE_KEY);
				await GM_deleteValue(STORAGE_KEY_LAST_SYNC);
				await GM_deleteValue(STORAGE_KEY_LAST_SYNC_CLIENT);
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

	async function updateSettingsPanelSyncStatus() {
		const statusText = document.getElementById('sync-status-text');
		const lastTimeText = document.getElementById('sync-last-time-text');
		const loggedInBox = document.getElementById('sync-auth-logged-in');
		const loggedOutBox = document.getElementById('sync-auth-logged-out');
		const userEmailEl = document.getElementById('sync-user-email');
		if (!statusText) return;

		const isAuth = await GeminiSync.isAuthenticated();
		const user = await GeminiSync.getCurrentUser();

		if (isAuth && user) {
			statusText.textContent = `Status: Connected as ${user.email} ✅`;
			statusText.style.color = "#81c995";
			if (userEmailEl) userEmailEl.textContent = user.email;
			if (loggedInBox) loggedInBox.style.display = 'block';
			if (loggedOutBox) loggedOutBox.style.display = 'none';
		} else {
			statusText.textContent = "Status: Not logged in (Authentication required) 🔒";
			statusText.style.color = "#f2994a";
			if (loggedInBox) loggedInBox.style.display = 'none';
			if (loggedOutBox) loggedOutBox.style.display = 'block';
		}

		if (lastTimeText) {
			const { timestamp, client } = await GeminiSync.getLastSyncInfo();
			if (timestamp) {
				lastTimeText.textContent = `Last synchronized: ${new Date(timestamp).toLocaleString()} (${client || 'Cloud'})`;
			} else {
				lastTimeText.textContent = "Never synchronized yet.";
			}
		}
	}

	async function populateSettingsPanel(panel) {
		const container = panel.querySelector('#toolbar-items-container');
		if (!container) return; // Should not happen
		clearEl(container);

		toolbarItems.forEach(item => addItemToPanel(container, item));

		const urlInput = document.getElementById('supabase-url-input');
		const keyAdvInput = document.getElementById('supabase-key-input');
		if (urlInput && keyAdvInput) {
			const cfg = await GeminiSync.getSupabaseConfig();
			urlInput.value = cfg.url;
			keyAdvInput.value = cfg.key;
		}
		await updateSettingsPanelSyncStatus();
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



		// Inject Styles
		injectCSS();

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