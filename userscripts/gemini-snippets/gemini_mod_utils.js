/**
 * gemini_mod_utils.js
 * Contains utility functions and UI dialog helpers for the Gemini Mod Userscript.
 */

window.GeminiMod = window.GeminiMod || {};

window.GeminiMod.utils = {
    displayUserscriptMessage: function (message, isError = true) {
        const prefix = "Gemini Mod Userscript: ";
        if (isError) console.error(prefix + message);
        else console.log(prefix + message);
        alert(prefix + message);
    },

    clearElement: function (element) {
        if (element) {
            while (element.firstChild) {
                element.removeChild(element.firstChild);
            }
        }
    },

    showConfirmationDialog: function (message, onConfirm, confirmText = 'Confirm', confirmButtonClass = 'dialog-btn-confirm') {
        const overlay = document.createElement('div');
        overlay.className = 'custom-dialog-overlay';

        const dialogBox = document.createElement('div');
        dialogBox.className = 'custom-dialog-box';

        const text = document.createElement('p');
        text.textContent = message;
        dialogBox.appendChild(text);

        const confirmBtn = document.createElement('button');
        confirmBtn.textContent = confirmText;
        confirmBtn.className = `custom-dialog-btn ${confirmButtonClass}`;
        confirmBtn.addEventListener('click', () => {
            onConfirm();
            document.body.removeChild(overlay);
        });

        const cancelBtn = document.createElement('button');
        cancelBtn.textContent = 'Cancel';
        cancelBtn.className = 'custom-dialog-btn dialog-btn-cancel';
        cancelBtn.addEventListener('click', () => {
            document.body.removeChild(overlay);
        });

        dialogBox.appendChild(confirmBtn);
        dialogBox.appendChild(cancelBtn);
        overlay.appendChild(dialogBox);
        document.body.appendChild(overlay);
    },

    showCustomPromptDialog: function (message, defaultValue, onConfirm) {
        const overlay = document.createElement('div');
        overlay.className = 'custom-dialog-overlay';

        const dialogBox = document.createElement('div');
        dialogBox.className = 'custom-dialog-box';

        const title = document.createElement('h2');
        title.textContent = 'Edit Item';
        dialogBox.appendChild(title);

        const input = document.createElement('input');
        input.type = 'text';
        input.value = defaultValue;
        input.className = 'custom-dialog-input';
        dialogBox.appendChild(input);

        const confirmBtn = document.createElement('button');
        confirmBtn.textContent = 'Save';
        confirmBtn.className = 'custom-dialog-btn dialog-btn-confirm';
        confirmBtn.addEventListener('click', () => {
            if (input.value.trim()) {
                onConfirm(input.value.trim());
                document.body.removeChild(overlay);
            }
        });

        const cancelBtn = document.createElement('button');
        cancelBtn.textContent = 'Cancel';
        cancelBtn.className = 'custom-dialog-btn dialog-btn-cancel';
        cancelBtn.addEventListener('click', () => {
            document.body.removeChild(overlay);
        });

        dialogBox.appendChild(confirmBtn);
        dialogBox.appendChild(cancelBtn);
        overlay.appendChild(dialogBox);
        document.body.appendChild(overlay);
        input.focus();
    },

    showColorPickerDialog: function (currentColor, onSelect) {
        const overlay = document.createElement('div');
        overlay.className = 'custom-dialog-overlay color-picker-dialog';

        const dialogBox = document.createElement('div');
        dialogBox.className = 'custom-dialog-box';

        dialogBox.appendChild(document.createElement('h2')).textContent = 'Select Color';

        const grid = document.createElement('div');
        grid.className = 'color-picker-grid';

        const FOLDER_COLORS = ['#370000', '#0D3800', '#001B38', '#383200', '#380031', '#7DAC89', '#7A82AF', '#AC7D98', '#7AA7AF', '#9CA881'];

        FOLDER_COLORS.forEach(color => {
            const swatch = document.createElement('div');
            swatch.className = 'color-swatch';
            swatch.style.backgroundColor = color;
            if (color === currentColor) swatch.classList.add('selected');

            swatch.addEventListener('click', () => {
                onSelect(color);
                document.body.removeChild(overlay);
            });
            grid.appendChild(swatch);
        });

        dialogBox.appendChild(grid);

        const cancelBtn = document.createElement('button');
        cancelBtn.textContent = 'Cancel';
        cancelBtn.className = 'custom-dialog-btn dialog-btn-cancel';
        cancelBtn.addEventListener('click', () => document.body.removeChild(overlay));

        dialogBox.appendChild(cancelBtn);
        overlay.appendChild(dialogBox);
        document.body.appendChild(overlay);
    },

    injectCustomCSS: function () {
        if (!window.GeminiMod.styles) {
            console.error("GeminiMod.styles not found!");
            return;
        }
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
    },

    /**
     * Attempts to retrieve the internal React props of a DOM element.
     * Useful for extracting data from virtualized components like Monaco Editor.
     */
    getReactProps: function (element) {
        if (!element) return null;
        const key = Object.keys(element).find(k => k.startsWith('__reactProps'));
        return key ? element[key] : null;
    },

    /**
     * Safely accesses a property path on an object (like lodash.get).
     */
    getClassProperty: function (obj, prop) {
        if (!obj) return null;
        return prop.split('.').reduce((o, i) => (o ? o[i] : null), obj);
    }
};
