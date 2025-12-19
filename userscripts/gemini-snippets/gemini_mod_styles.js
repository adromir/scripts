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
    #folder-ui-container { padding: 0 8px; }
    #folder-container { padding-bottom: 8px; border-bottom: 1px solid var(--surface-3); }
    .folder { margin-bottom: 5px; border-radius: 8px; overflow: hidden; }
    .folder-header { display: flex; align-items: center; padding: 10px; cursor: pointer; background-color: var(--surface-2); position: relative; }
    .folder-header:hover { background-color: var(--surface-3); }
    
    /* Folder Icon Styles */
    .folder-icon-wrapper { margin-right: 10px; display: flex; align-items: center; justify-content: center; width: 24px; height: 24px; }
    .folder-icon { width: 20px; height: 20px; transition: transform 0.2s ease; }
    .folder.closed .icon-open { display: none; }
    .folder:not(.closed) .icon-closed { display: none; }
    
    .folder-name { flex-grow: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-family: 'Roboto', Arial, sans-serif !important; font-weight: 500; }
    .folder-controls { display: flex; align-items: center; margin-left: 5px; }
    .folder-toggle-icon { transition: transform 0.2s; margin-right: 5px; font-size: 0.8em; opacity: 0.7; }
    .folder.closed .folder-toggle-icon { transform: rotate(-90deg); }
    .folder-options-btn { background: none; border: none; color: inherit; cursor: pointer; padding: 2px 4px; border-radius: 4px; margin-left: 4px; font-size: 1.2em; line-height: 1; }
    .folder-options-btn:hover { background-color: rgba(255,255,255,0.1); }
    
    /* List View Styles for Content */
    .folder-content { 
        max-height: 500px; 
        overflow-y: auto; 
        transition: max-height 0.3s ease-in-out, padding 0.3s ease-in-out; 
        background-color: transparent; /* Transparent to let items stand out */
        min-height: 10px; 
        display: flex;
        flex-direction: column;
        gap: 4px; /* Gap between items */
        padding: 4px 0;
    }
    .folder.closed .folder-content { max-height: 0; padding-top: 0; padding-bottom: 0; min-height: 0; overflow: hidden; }
    
    /* Style the conversation items within the folder to look like list items */
    .folder-content .conversation-items-container {
        background-color: var(--surface-1);
        border-radius: 6px;
        margin: 0 4px;
        padding: 2px 0;
        border: 1px solid var(--surface-4);
        transition: background-color 0.2s;
        display: flex;
        align-items: center;
    }
    .folder-content .conversation-items-container::before {
        content: "•";
        margin: 0 6px 0 10px;
        color: var(--on-surface);
        font-size: 1.2em;
        line-height: 1;
    }
    .folder-content .conversation-items-container:hover {
        background-color: var(--surface-2);
        border-color: var(--surface-5);
    }

    #add-folder-btn { width: 100%; margin: 8px 0; padding: 10px; border: none; background-color: var(--primary-surface); color: var(--on-primary-surface); border-radius: 8px; cursor: pointer; font-weight: 500; }
    #add-folder-btn:hover { opacity: 0.9; }
    .conversation-items-container { cursor: grab; }
    .folder-context-menu { position: absolute; z-index: 10000; background-color: #333333; border: 1px solid var(--surface-4); border-radius: 8px; padding: 5px; box-shadow: 0 4px 8px rgba(0,0,0,0.2); display: none; }
    .folder-context-menu-item { padding: 8px 12px; cursor: pointer; border-radius: 4px; white-space: nowrap; font-family: 'Roboto', Arial, sans-serif !important; color: #FFFFFF; }
    .folder-context-menu-item:hover { background-color: var(--surface-4); }
    .folder-context-menu-item.delete { color: #DB4437; }
    .sortable-ghost { opacity: 0.4; background: var(--primary-surface-hover); }
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
