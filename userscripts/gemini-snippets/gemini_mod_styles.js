/**
 * gemini_mod_styles.js
 * Contains the CSS styles for the Gemini Mod Userscript.
 * Usage: The main script will inject this CSS using GM_addStyle or a <style> tag.
 */

window.GeminiMod = window.GeminiMod || {};

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
    #gemini-mod-settings-panel {
        position: fixed !important; top: 50% !important; left: 50% !important;
        transform: translate(-50%, -50%) !important;
        background-color: #202124 !important; color: #e3e3e3 !important; border-radius: 16px !important;
        padding: 0 !important; box-shadow: 0 16px 40px rgba(0,0,0,0.6) !important;
        border: 1px solid #3c4043 !important;
        font-family: "Google Sans Flex", "Google Sans", 'Roboto', 'Arial', sans-serif !important;
        width: 90vw !important; max-width: 860px !important;
        height: 620px !important; max-height: 85vh !important;
        display: flex !important; flex-direction: column !important;
        overflow: hidden !important; z-index: 1000000 !important;
    }
    #gemini-mod-type-modal {
        position: fixed !important; top: 50% !important; left: 50% !important;
        transform: translate(-50%, -50%) !important;
        background-color: #282a2c !important; color: #e3e3e3 !important; border-radius: 16px !important;
        padding: 24px !important; box-shadow: 0 12px 32px rgba(0,0,0,0.6) !important;
        border: 1px solid #3c4043 !important;
        font-family: "Google Sans Flex", "Google Sans", 'Roboto', 'Arial', sans-serif !important;
        text-align: center !important; z-index: 1000001 !important;
    }
    #gemini-mod-type-modal h3 { margin-top: 0 !important; }
    #gemini-mod-type-modal button { margin: 0 10px !important; }
    #gemini-mod-settings-panel .settings-header {
        display: flex !important; align-items: center !important; justify-content: space-between !important;
        padding: 16px 24px !important; border-bottom: 1px solid #3c4043 !important;
        background-color: #242628 !important; margin: 0 !important; flex-shrink: 0 !important;
    }
    #gemini-mod-settings-panel .settings-header h2 {
        margin: 0 !important; padding: 0 !important; font-size: 1.2rem !important;
        font-weight: 600 !important; color: #e3e3e3 !important; border-bottom: none !important;
    }
    #gemini-mod-settings-panel h3 { margin-top: 20px; border-bottom: 1px solid #444; padding-bottom: 8px; }
    #gemini-mod-settings-panel label { display: block; margin: 10px 0 5px; font-weight: 500; }
    #gemini-mod-settings-panel input[type="text"], #gemini-mod-settings-panel input[type="email"], #gemini-mod-settings-panel input[type="password"], #gemini-mod-settings-panel textarea {
        width: 100% !important; padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important;
        background-color: #202122 !important; color: #e3e3e3 !important; box-sizing: border-box !important;
        font-size: 14px !important; font-family: inherit !important;
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
    #gemini-mod-settings-panel .item-group button {
        padding: 4px 10px !important; cursor: pointer !important; background-color: #3c4043 !important;
        color: #e3e3e3 !important; border-radius: 16px !important; font-size: 13px !important;
        border: none !important; transition: background-color 0.2s ease;
    }
    #gemini-mod-settings-panel .item-group button:hover { background-color: #4a4e51 !important; }
    #gemini-mod-settings-panel .remove-btn { background-color: #5c2b2b !important; color: white !important; }
    #gemini-mod-settings-panel .remove-btn:hover { background-color: #7d3a3a !important; }
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
    /* --- Dialog & Color Picker Styles --- */
    .custom-dialog-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.7); z-index: 1000000; display: flex; align-items: center; justify-content: center; }
    .custom-dialog-box { background-color: #282a2c; padding: 24px; border-radius: 16px; box-shadow: 0 12px 32px rgba(0,0,0,0.5); text-align: center; max-width: 440px; border: 1px solid #3c4043; font-family: "Google Sans Flex", "Google Sans", 'Roboto', Arial, sans-serif !important; }
    .custom-dialog-box p, .custom-dialog-box h2 { margin: 0 0 18px; color: #FFFFFF; }
    .custom-dialog-btn {
        display: inline-flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important;
        border: none !important; border-radius: 8px !important; padding: 8px 16px !important; cursor: pointer !important;
        font-weight: 500 !important; font-size: 13px !important; font-family: inherit !important;
        transition: background-color 0.2s ease, transform 0.1s ease !important; box-sizing: border-box !important;
    }
    .custom-dialog-btn:active { transform: scale(0.98) !important; }
    .dialog-btn-confirm { background-color: #8ab4f8 !important; color: #1f1f1f !important; font-weight: 600 !important; }
    .dialog-btn-confirm:hover { background-color: #aecbfa !important; }
    .dialog-btn-cancel { background-color: #353739 !important; color: #e3e3e3 !important; border: 1px solid #5f6368 !important; }
    .dialog-btn-cancel:hover { background-color: #4a4e51 !important; }
    .dialog-btn-delete { background-color: #d93025 !important; color: #ffffff !important; font-weight: 500 !important; }
    .dialog-btn-delete:hover { background-color: #ea4335 !important; }
    .custom-dialog-input { width: 100%; box-sizing: border-box; padding: 10px; border-radius: 8px; border: 1px solid #5f6368; background-color: #1e1f20; color: #e3e3e3; font-size: 14px; margin-bottom: 20px; }
    .color-picker-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px; margin-bottom: 20px; }
    .color-picker-dialog .color-swatch { width: 32px; height: 32px; border-radius: 50%; cursor: pointer; border: 2px solid transparent; position: relative; }
    .color-picker-dialog .color-swatch:hover { border: 2px solid #8ab4f8; }
    .color-picker-dialog .color-swatch.selected::after { content: ""; position: absolute; inset: 0; border: 3px solid #fff; border-radius: 50%; box-sizing: border-box; pointer-events: none; }

    /* --- Tabbed Settings Styles --- */
    .settings-container {
        display: flex !important; flex: 1 1 auto !important; height: 100% !important; min-height: 0 !important; overflow: hidden !important;
    }
    .settings-sidebar {
        width: 240px !important; min-width: 240px !important; flex-shrink: 0 !important;
        border-right: 1px solid #3c4043 !important; padding: 16px 12px !important;
        display: flex !important; flex-direction: column !important; gap: 8px !important;
        background-color: #1e2022 !important; box-sizing: border-box !important; overflow-y: auto !important;
    }
    .tab-btn {
        display: flex !important; align-items: center !important; gap: 10px !important; text-align: left !important;
        padding: 10px 14px !important; background: transparent !important; border: none !important;
        color: #9aa0a6 !important; cursor: pointer !important; border-radius: 8px !important;
        font-size: 14px !important; font-weight: 500 !important; white-space: nowrap !important;
        width: 100% !important; box-sizing: border-box !important;
        transition: background-color 0.15s ease, color 0.15s ease !important;
    }
    .tab-btn:hover { background-color: rgba(255, 255, 255, 0.08) !important; color: #e3e3e3 !important; }
    .tab-btn.active { background-color: #1a73e8 !important; color: #ffffff !important; font-weight: 600 !important; }
    .settings-sidebar-footer {
        margin-top: auto !important; display: flex !important; flex-direction: column !important;
        gap: 10px !important; width: 100% !important; padding-top: 14px !important;
        border-top: 1px solid #3c4043 !important; box-sizing: border-box !important; flex-shrink: 0 !important;
    }
    .settings-sidebar-footer button {
        width: 100% !important; height: 38px !important; box-sizing: border-box !important; margin: 0 !important;
        border-radius: 8px !important; font-size: 13px !important; cursor: pointer !important;
        display: inline-flex !important; align-items: center !important; justify-content: center !important;
        transition: background-color 0.15s ease !important;
    }
    .settings-sidebar-footer .dialog-btn-cancel {
        background-color: #353739 !important; color: #e3e3e3 !important;
        border: 1px solid #5f6368 !important; font-weight: 500 !important;
    }
    .settings-sidebar-footer .dialog-btn-cancel:hover { background-color: #4a4e51 !important; }
    .settings-sidebar-footer .dialog-btn-confirm {
        background-color: #8ab4f8 !important; color: #1f1f1f !important;
        border: none !important; font-weight: 600 !important;
    }
    .settings-sidebar-footer .dialog-btn-confirm:hover { background-color: #aecbfa !important; }
    .settings-content {
        flex: 1 1 auto !important; height: 100% !important; min-height: 0 !important;
        padding: 24px 28px !important; overflow-y: auto !important;
        background-color: #242628 !important; box-sizing: border-box !important;
    }
    .tab-pane { display: none; animation: fadeIn 0.2s; }
    .tab-pane.active { display: block; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }
    
    /* Help Link */
    .help-link { font-size: 12px; color: #8ab4f8; text-decoration: none; margin-left: 5px; display: inline-flex; align-items: center; }
    .help-link:hover { text-decoration: underline; }

    /* Cloud Sync tab UI */
    .sync-heading {
        margin: 0 0 6px 0 !important; font-size: 1.15rem !important; font-weight: 600 !important; color: #e3e3e3 !important;
    }
    .sync-subheading {
        font-size: 13px !important; color: #9aa0a6 !important; margin: 0 0 18px 0 !important; line-height: 1.4 !important;
    }
    .sync-status-card {
        background-color: #1a1c1e !important; border: 1px solid #3c4043 !important; border-radius: 12px !important;
        padding: 16px 20px !important; margin-bottom: 20px !important; display: flex !important;
        flex-direction: column !important; gap: 4px !important;
    }
    .sync-status-title {
        font-size: 14px !important; font-weight: 600 !important; margin: 0 !important;
        display: flex !important; align-items: center !important; gap: 8px !important;
    }
    .sync-status-detail { font-size: 12px !important; color: #9aa0a6 !important; margin: 0 !important; }
    .sync-user-card {
        display: flex !important; align-items: center !important; justify-content: space-between !important;
        background-color: #1a1c1e !important; border: 1px solid #3c4043 !important; border-radius: 12px !important;
        padding: 14px 18px !important; margin-bottom: 18px !important;
    }
    .sync-user-info { display: flex !important; align-items: center !important; gap: 10px !important; font-size: 14px !important; color: #e3e3e3 !important; font-weight: 500 !important; }
    .sync-actions-box { display: flex !important; gap: 12px !important; flex-wrap: wrap !important; margin-top: 16px !important; margin-bottom: 24px !important; }
    .sync-auth-box {
        background-color: #1e2022 !important; border: 1px solid #3c4043 !important; border-radius: 12px !important;
        padding: 20px !important; margin-bottom: 22px !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15) !important;
    }
    .sync-auth-notice {
        background-color: rgba(138, 180, 248, 0.08) !important; border: 1px solid rgba(138, 180, 248, 0.25) !important;
        border-radius: 8px !important; padding: 12px 14px !important; color: #8ab4f8 !important;
        font-size: 13px !important; line-height: 1.45 !important; margin-bottom: 16px !important;
    }
    .sync-input-group { margin-bottom: 14px !important; width: 100% !important; max-width: 480px !important; }
    .sync-input-group label { display: block !important; margin: 0 0 6px 0 !important; font-size: 13px !important; font-weight: 500 !important; color: #c4c7c5 !important; }
    .sync-input-group input[type="email"],
    .sync-input-group input[type="text"],
    .sync-input-group input[type="password"] {
        width: 100% !important; max-width: 480px !important; height: 40px !important; padding: 8px 12px !important;
        border-radius: 8px !important; border: 1px solid #5f6368 !important; background-color: #282a2c !important;
        color: #e3e3e3 !important; box-sizing: border-box !important; font-size: 14px !important; outline: none !important;
        font-family: inherit !important; transition: border-color 0.2s, box-shadow 0.2s !important;
    }
    .sync-input-group input:focus { border-color: #8ab4f8 !important; box-shadow: 0 0 0 2px rgba(138, 180, 248, 0.2) !important; }
    .sync-password-wrapper { display: flex !important; align-items: center !important; gap: 8px !important; width: 100% !important; max-width: 480px !important; }
    .sync-password-wrapper input {
        flex: 1 1 auto !important; min-width: 0 !important; width: 100% !important; height: 40px !important;
        padding: 8px 12px !important; border-radius: 8px !important; border: 1px solid #5f6368 !important;
        background-color: #282a2c !important; color: #e3e3e3 !important; box-sizing: border-box !important;
        font-size: 14px !important; outline: none !important; font-family: inherit !important;
    }
    .sync-password-wrapper input:focus { border-color: #8ab4f8 !important; box-shadow: 0 0 0 2px rgba(138, 180, 248, 0.2) !important; }
    .sync-password-toggle-btn {
        height: 40px !important; width: 42px !important; min-width: 42px !important; padding: 0 !important;
        background-color: #353739 !important; border: 1px solid #5f6368 !important; border-radius: 8px !important;
        color: #e3e3e3 !important; cursor: pointer !important; display: inline-flex !important;
        align-items: center !important; justify-content: center !important; font-size: 16px !important;
        flex-shrink: 0 !important; transition: background-color 0.15s ease !important;
    }
    .sync-password-toggle-btn:hover { background-color: #4a4e51 !important; }
    .sync-auth-btns { display: flex !important; gap: 12px !important; margin-top: 18px !important; align-items: center !important; }
    .sync-btn-primary {
        background-color: #8ab4f8 !important; color: #1f1f1f !important; font-weight: 600 !important;
        border: none !important; border-radius: 8px !important; padding: 0 20px !important; height: 38px !important;
        font-size: 14px !important; cursor: pointer !important; display: inline-flex !important;
        align-items: center !important; justify-content: center !important; gap: 6px !important;
        transition: background-color 0.15s ease, transform 0.1s ease !important;
    }
    .sync-btn-primary:hover { background-color: #aecbfa !important; }
    .sync-btn-secondary {
        background-color: #353739 !important; color: #e3e3e3 !important; font-weight: 500 !important;
        border: 1px solid #5f6368 !important; border-radius: 8px !important; padding: 0 18px !important; height: 38px !important;
        font-size: 14px !important; cursor: pointer !important; display: inline-flex !important;
        align-items: center !important; justify-content: center !important; gap: 6px !important;
        transition: background-color 0.15s ease, transform 0.1s ease !important;
    }
    .sync-btn-secondary:hover { background-color: #4a4e51 !important; }
    .sync-help-text { font-size: 12px !important; color: #9aa0a6 !important; margin: 12px 0 0 0 !important; line-height: 1.4 !important; }
    .sync-file-row { display: flex !important; gap: 12px !important; margin-bottom: 24px !important; align-items: center !important; }
    .sync-advanced-details { margin-top: 20px !important; border-top: 1px solid #3c4043 !important; padding-top: 16px !important; margin-bottom: 20px !important; }
    .sync-advanced-details summary { cursor: pointer !important; color: #8ab4f8 !important; font-size: 13px !important; font-weight: 500 !important; user-select: none !important; outline: none !important; padding: 4px 0 !important; transition: color 0.15s ease !important; }
    .sync-advanced-details summary:hover { color: #aecbfa !important; }
    .sync-advanced-body { margin-top: 14px !important; padding: 16px !important; background-color: #1e2022 !important; border: 1px solid #3c4043 !important; border-radius: 10px !important; }
`;
