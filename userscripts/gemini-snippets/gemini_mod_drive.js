/**
 * gemini_mod_drive.js
 * Contains Google Drive Authorization and API logic for the Gemini Mod Userscript.
 */

window.GeminiMod = window.GeminiMod || {};

window.GeminiMod.drive = {
    STORAGE_KEY_GDRIVE_TOKEN: 'gemini_gdrive_token',
    STORAGE_KEY_GDRIVE_CLIENT_ID: 'gemini_gdrive_client_id',

    getGoogleDriveToken: async function () {
        return await GM_getValue(this.STORAGE_KEY_GDRIVE_TOKEN);
    },

    getGoogleDriveClientId: async function () {
        return await GM_getValue(this.STORAGE_KEY_GDRIVE_CLIENT_ID);
    },

    initiateGoogleDriveAuth: async function () {
        const clientId = await this.getGoogleDriveClientId();
        if (!clientId) {
            GeminiMod.utils.displayUserscriptMessage("Please enter your Google Cloud Client ID in the settings first.");
            return;
        }

        const redirectUri = window.location.origin + window.location.pathname;
        const scope = "https://www.googleapis.com/auth/drive.file";
        const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=token&scope=${encodeURIComponent(scope)}&state=gdrive_auth_v1&include_granted_scopes=true&prompt=consent`;

        const width = 500;
        const height = 600;
        const left = (window.screen.width / 2) - (width / 2);
        const top = (window.screen.height / 2) - (height / 2);
        window.open(authUrl, "_blank", `width=${width},height=${height},top=${top},left=${left}`);
    },

    handleAuthCallback: function () {
        const hash = window.location.hash;
        if (hash && hash.includes("access_token") && hash.includes("state=gdrive_auth_v1")) {
            const params = new URLSearchParams(hash.substring(1));
            const token = params.get("access_token");
            if (token) {
                if (window.opener) {
                    window.opener.postMessage({ type: "GDRIVE_TOKEN", token: token }, window.location.origin);
                    window.close();
                } else {
                    console.log("Gemini Mod: Token received but no opener found.");
                }
            }
        }
    },

    setupAuthMessageListener: function (rendererCallback) {
        window.addEventListener("message", async (event) => {
            if (event.origin !== window.location.origin) return;
            if (event.data && event.data.type === "GDRIVE_TOKEN") {
                await GM_setValue(this.STORAGE_KEY_GDRIVE_TOKEN, event.data.token);
                GeminiMod.utils.displayUserscriptMessage("Google Drive connected successfully!", false);
                if (rendererCallback) rendererCallback();
            }
        });
    },

    saveToDrive: async function (currentSettings) {
        const token = await this.getGoogleDriveToken();
        if (!token) {
            GeminiMod.utils.displayUserscriptMessage("Google Drive not connected.");
            return;
        }

        GeminiMod.utils.displayUserscriptMessage("Saving settings to Google Drive...", false);

        const dataToSave = {
            ...currentSettings,
            timestamp: Date.now(),
            version: 1
        };
        const fileContent = JSON.stringify(dataToSave, null, 2);
        const fileName = "gemini_userscript_settings.json";

        GM_xmlhttpRequest({
            method: "GET",
            url: "https://www.googleapis.com/drive/v3/files?q=name='" + fileName + "' and trashed=false",
            headers: { "Authorization": "Bearer " + token },
            onload: (response) => {
                try {
                    const result = JSON.parse(response.responseText);
                    if (result.error) throw new Error(result.error.message);

                    const existingFile = result.files && result.files.length > 0 ? result.files[0] : null;

                    if (existingFile) {
                        this.updateDriveFile(existingFile.id, fileContent, token);
                    } else {
                        this.createDriveFile(fileName, fileContent, token);
                    }
                } catch (e) {
                    console.error("GDrive Search Error:", e);
                    GeminiMod.utils.displayUserscriptMessage("Failed to search Drive: " + e.message);
                }
            }
        });
    },

    createDriveFile: function (name, content, token) {
        const metadata = {
            name: name,
            mimeType: 'application/json'
        };

        const form = new FormData();
        form.append('metadata', new Blob([JSON.stringify(metadata)], { type: 'application/json' }));
        form.append('file', new Blob([content], { type: 'application/json' }));

        GM_xmlhttpRequest({
            method: "POST",
            url: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
            headers: { "Authorization": "Bearer " + token },
            data: form,
            onload: function (response) {
                if (response.status >= 200 && response.status < 300) {
                    GeminiMod.utils.displayUserscriptMessage("Settings saved to Google Drive successfully!", false);
                } else {
                    GeminiMod.utils.displayUserscriptMessage("Failed to create file on Drive.");
                    console.error("GDrive Create Error:", response.responseText);
                }
            }
        });
    },

    updateDriveFile: function (fileId, content, token) {
        GM_xmlhttpRequest({
            method: "PATCH",
            url: "https://www.googleapis.com/upload/drive/v3/files/" + fileId + "?uploadType=media",
            headers: { "Authorization": "Bearer " + token, "Content-Type": "application/json" },
            data: content,
            onload: function (response) {
                if (response.status >= 200 && response.status < 300) {
                    GeminiMod.utils.displayUserscriptMessage("Settings updated on Google Drive successfully!", false);
                } else {
                    GeminiMod.utils.displayUserscriptMessage("Failed to update file on Drive.");
                    console.error("GDrive Update Error:", response.responseText);
                }
            }
        });
    },

    loadFromDrive: async function (onLoadSuccess) {
        const token = await this.getGoogleDriveToken();
        if (!token) {
            GeminiMod.utils.displayUserscriptMessage("Google Drive not connected.");
            return;
        }

        GeminiMod.utils.displayUserscriptMessage("Loading settings from Google Drive...", false);

        const fileName = "gemini_userscript_settings.json";

        GM_xmlhttpRequest({
            method: "GET",
            url: "https://www.googleapis.com/drive/v3/files?q=name='" + fileName + "' and trashed=false",
            headers: { "Authorization": "Bearer " + token },
            onload: (response) => {
                try {
                    const result = JSON.parse(response.responseText);
                    if (result.error) throw new Error(result.error.message);

                    const existingFile = result.files && result.files.length > 0 ? result.files[0] : null;

                    if (existingFile) {
                        this.downloadDriveFile(existingFile.id, token, onLoadSuccess);
                    } else {
                        GeminiMod.utils.displayUserscriptMessage("No backup file (" + fileName + ") found on Drive.");
                    }
                } catch (e) {
                    GeminiMod.utils.displayUserscriptMessage("Failed to search Drive: " + e.message);
                }
            }
        });
    },

    downloadDriveFile: function (fileId, token, onLoadSuccess) {
        GM_xmlhttpRequest({
            method: "GET",
            url: "https://www.googleapis.com/drive/v3/files/" + fileId + "?alt=media",
            headers: { "Authorization": "Bearer " + token },
            onload: async function (response) {
                try {
                    const data = JSON.parse(response.responseText);
                    await onLoadSuccess(data);
                } catch (e) {
                    GeminiMod.utils.displayUserscriptMessage("Failed to parse downloaded file: " + e.message);
                }
            }
        });
    },

    // --- File Backup/Restore ---

    exportSettingsToFile: function (dataToSave) {
        const fullData = {
            ...dataToSave,
            timestamp: Date.now(),
            version: 1,
            // gdriveClientId: GM_getValue(STORAGE_KEY_GDRIVE_CLIENT_ID) // Caller must provide this if needed
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
        GeminiMod.utils.displayUserscriptMessage("Settings exported to file!", false);
    },

    importSettingsFromFile: function (file, onImportSuccess) {
        const reader = new FileReader();
        reader.onload = async (e) => {
            try {
                const data = JSON.parse(e.target.result);
                if (data && data.toolbarItems && data.folders) {
                    GeminiMod.utils.showConfirmationDialog("This will overwrite your current settings with the imported file. Continue?", async () => {
                        await onImportSuccess(data);
                    }, "Import", "dialog-btn-confirm");
                } else {
                    GeminiMod.utils.displayUserscriptMessage("Invalid backup file.");
                }
            } catch (err) {
                GeminiMod.utils.displayUserscriptMessage("Error reading file: " + err.message);
            }
        };
        reader.readAsText(file);
    }
};
