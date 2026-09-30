/**
 * gemini_mod_sync.js
 * Supabase Synchronization and Local File Backup logic for Google Gemini Mod.
 * Supports cross-device and cross-platform sync (Ferdium Recipe <-> Userscript).
 * Fully hardened against unauthorized access using Supabase Auth & Row-Level Security (RLS).
 */

window.GeminiMod = window.GeminiMod || {};

(function () {
    'use strict';

    const GeminiSync = {
        DEFAULT_SUPABASE_URL: 'https://wurrurgloawzvtiyilyr.supabase.co',
        DEFAULT_SUPABASE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1cnJ1cmdsb2F3enZ0aXlpbHlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NzgwODQsImV4cCI6MjEwNjM1NDA4NH0.aQ8GNObnE9xH8Jd3Rpv9eSp3c72ymjKuWC4Z8qGUQh4',

        STORAGE_KEY_AUTH_SESSION: 'gemini_mod_auth_session',
        STORAGE_KEY_SUPABASE_URL: 'gemini_mod_supabase_url',
        STORAGE_KEY_SUPABASE_KEY: 'gemini_mod_supabase_key',
        STORAGE_KEY_LAST_SYNC: 'gemini_mod_last_sync',
        STORAGE_KEY_LAST_SYNC_CLIENT: 'gemini_mod_last_sync_client',

        getSession: async function () {
            try {
                let raw;
                if (typeof GM_getValue !== 'undefined') {
                    raw = await GM_getValue(this.STORAGE_KEY_AUTH_SESSION, null);
                } else {
                    raw = localStorage.getItem(this.STORAGE_KEY_AUTH_SESSION);
                }
                if (!raw) return null;
                return typeof raw === 'string' ? JSON.parse(raw) : raw;
            } catch (_) {
                return null;
            }
        },

        setSession: async function (session) {
            if (session) {
                const val = JSON.stringify(session);
                if (typeof GM_setValue !== 'undefined') {
                    await GM_setValue(this.STORAGE_KEY_AUTH_SESSION, val);
                } else {
                    localStorage.setItem(this.STORAGE_KEY_AUTH_SESSION, val);
                }
            } else {
                await this.clearSession();
            }
        },

        clearSession: async function () {
            if (typeof GM_deleteValue !== 'undefined') {
                await GM_deleteValue(this.STORAGE_KEY_AUTH_SESSION);
            } else {
                localStorage.removeItem(this.STORAGE_KEY_AUTH_SESSION);
            }
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
            let url, key;
            if (typeof GM_getValue !== 'undefined') {
                url = await GM_getValue(this.STORAGE_KEY_SUPABASE_URL, this.DEFAULT_SUPABASE_URL);
                key = await GM_getValue(this.STORAGE_KEY_SUPABASE_KEY, this.DEFAULT_SUPABASE_KEY);
            } else {
                url = localStorage.getItem(this.STORAGE_KEY_SUPABASE_URL) || this.DEFAULT_SUPABASE_URL;
                key = localStorage.getItem(this.STORAGE_KEY_SUPABASE_KEY) || this.DEFAULT_SUPABASE_KEY;
            }
            return {
                url: (url || this.DEFAULT_SUPABASE_URL).trim().replace(/\/+$/, ''),
                key: (key || this.DEFAULT_SUPABASE_KEY).trim()
            };
        },

        setSupabaseConfig: async function (url, key) {
            const cleanUrl = (url || '').trim().replace(/\/+$/, '');
            const cleanKey = (key || '').trim();
            if (typeof GM_setValue !== 'undefined') {
                await GM_setValue(this.STORAGE_KEY_SUPABASE_URL, cleanUrl);
                await GM_setValue(this.STORAGE_KEY_SUPABASE_KEY, cleanKey);
            } else {
                localStorage.setItem(this.STORAGE_KEY_SUPABASE_URL, cleanUrl);
                localStorage.setItem(this.STORAGE_KEY_SUPABASE_KEY, cleanKey);
            }
        },

        resetSupabaseConfig: async function () {
            if (typeof GM_deleteValue !== 'undefined') {
                await GM_deleteValue(this.STORAGE_KEY_SUPABASE_URL);
                await GM_deleteValue(this.STORAGE_KEY_SUPABASE_KEY);
            } else {
                localStorage.removeItem(this.STORAGE_KEY_SUPABASE_URL);
                localStorage.removeItem(this.STORAGE_KEY_SUPABASE_KEY);
            }
        },

        getLastSyncInfo: async function () {
            let timestamp, client;
            if (typeof GM_getValue !== 'undefined') {
                timestamp = await GM_getValue(this.STORAGE_KEY_LAST_SYNC, null);
                client = await GM_getValue(this.STORAGE_KEY_LAST_SYNC_CLIENT, null);
            } else {
                timestamp = localStorage.getItem(this.STORAGE_KEY_LAST_SYNC);
                client = localStorage.getItem(this.STORAGE_KEY_LAST_SYNC_CLIENT);
            }
            return {
                timestamp: timestamp ? parseInt(timestamp, 10) : null,
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
                if (data) {
                    headers['Content-Type'] = 'application/json';
                }
                if (method === 'POST') {
                    headers['Prefer'] = 'resolution=merge-duplicates,return=representation';
                }

                if (typeof GM_xmlhttpRequest !== 'undefined') {
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
                                    const parsed = JSON.parse(res.responseText);
                                    if (parsed.msg) msg = parsed.msg;
                                    else if (parsed.message) msg = parsed.message;
                                    else if (parsed.error_description) msg = parsed.error_description;
                                    else if (parsed.error) msg = typeof parsed.error === 'string' ? parsed.error : JSON.stringify(parsed.error);
                                } catch (_) {
                                    if (res.responseText) msg += `: ${res.responseText.slice(0, 120)}`;
                                }
                                reject(new Error(msg));
                            }
                        },
                        onerror: (err) => reject(new Error(err.statusText || 'Network request failed'))
                    });
                    return;
                }

                if (typeof require !== 'undefined') {
                    try {
                        const https = require('https');
                        const parsedUrl = new URL(url);
                        const postData = data ? JSON.stringify(data) : null;
                        const reqOptions = {
                            hostname: parsedUrl.hostname,
                            port: parsedUrl.port || 443,
                            path: parsedUrl.pathname + parsedUrl.search,
                            method: method,
                            headers: {
                                ...headers,
                                ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {})
                            }
                        };
                        const req = https.request(reqOptions, (res) => {
                            let body = '';
                            res.on('data', chunk => body += chunk);
                            res.on('end', () => {
                                if (res.statusCode >= 200 && res.statusCode < 300) {
                                    try {
                                        resolve(body ? JSON.parse(body) : null);
                                    } catch (_) {
                                        resolve(body);
                                    }
                                } else {
                                    let msg = `HTTP ${res.statusCode}`;
                                    try {
                                        const p = JSON.parse(body);
                                        if (p.msg) msg = p.msg;
                                        else if (p.message) msg = p.message;
                                        else if (p.error_description) msg = p.error_description;
                                        else if (p.error) msg = typeof p.error === 'string' ? p.error : JSON.stringify(p.error);
                                    } catch (_) {
                                        if (body) msg += `: ${body.slice(0, 100)}`;
                                    }
                                    reject(new Error(msg));
                                }
                            });
                        });
                        req.on('error', reject);
                        if (postData) req.write(postData);
                        req.end();
                        return;
                    } catch (nodeErr) {
                        // Fallback to fetch
                    }
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
            if (typeof GM_setValue !== 'undefined') {
                await GM_setValue(this.STORAGE_KEY_LAST_SYNC, now.toString());
                await GM_setValue(this.STORAGE_KEY_LAST_SYNC_CLIENT, clientName);
            } else {
                localStorage.setItem(this.STORAGE_KEY_LAST_SYNC, now.toString());
                localStorage.setItem(this.STORAGE_KEY_LAST_SYNC_CLIENT, clientName);
            }
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

            const now = Date.now();
            const sourceClient = record.client_name || data.client || 'Cloud';
            if (typeof GM_setValue !== 'undefined') {
                await GM_setValue(this.STORAGE_KEY_LAST_SYNC, now.toString());
                await GM_setValue(this.STORAGE_KEY_LAST_SYNC_CLIENT, sourceClient);
            } else {
                localStorage.setItem(this.STORAGE_KEY_LAST_SYNC, now.toString());
                localStorage.setItem(this.STORAGE_KEY_LAST_SYNC_CLIENT, sourceClient);
            }

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
                        alert("Invalid backup file: file must contain toolbarItems or folders.");
                    }
                } catch (err) {
                    alert("Error reading file: " + err.message);
                }
            };
            reader.readAsText(file);
        }
    };

    window.GeminiMod.sync = GeminiSync;
    window.GeminiMod.drive = GeminiSync; // Backwards compatibility alias
})();
