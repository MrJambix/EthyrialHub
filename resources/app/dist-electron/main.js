"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const child_process = __importStar(require("child_process"));
const addonManager_1 = require("./addonManager");
const pipeBridge_1 = require("./pipeBridge");
const injector_1 = require("./injector");
// Use dev server only if vite is running AND dist doesn't exist
const distIndex = path.join(__dirname, '..', 'dist', 'index.html');
const isDev = !electron_1.app.isPackaged && !fs.existsSync(distIndex);
const mgr = new addonManager_1.AddonManager();
const pipe = new pipeBridge_1.PipeBridge();
let mainWindow = null;
const logLines = [];
const MAX_LOG = 2000;
function addLog(level, msg) {
    const ts = new Date().toLocaleTimeString();
    const entry = `[${ts}] [${level}] ${msg}`;
    logLines.push(entry);
    if (logLines.length > MAX_LOG)
        logLines.splice(0, logLines.length - MAX_LOG);
    mainWindow?.webContents.send('log-line', entry);
}
function createWindow() {
    mainWindow = new electron_1.BrowserWindow({
        width: 1200,
        height: 800,
        minWidth: 900,
        minHeight: 600,
        backgroundColor: '#0e0e16',
        titleBarStyle: 'hidden',
        titleBarOverlay: {
            color: '#111118',
            symbolColor: '#9898ae',
            height: 36,
        },
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: true,
            nodeIntegration: false,
            sandbox: false,
        },
    });
    if (isDev) {
        mainWindow.loadURL('http://localhost:5173');
    }
    else {
        mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
    }
    mainWindow.on('closed', () => { mainWindow = null; });
}
// ── Pipe Bridge Events ──────────────────────────────────────────────────────
// Game path is resolved at startup — used for plugins and addons directories
let g_gamePath = '';
let g_pluginsDir = '';
let g_addonsDir = '';
function initGameDirs(gamePath) {
    g_gamePath = gamePath;
    g_pluginsDir = path.join(gamePath, 'plugins');
    g_addonsDir = path.join(gamePath, 'addons');
    addLog('DEBUG', `initGameDirs: gamePath="${gamePath}"`);
    addLog('DEBUG', `initGameDirs: g_pluginsDir="${g_pluginsDir}" exists=${fs.existsSync(g_pluginsDir)}`);
    addLog('DEBUG', `initGameDirs: g_addonsDir="${g_addonsDir}" exists=${fs.existsSync(g_addonsDir)}`);
    // Create folders if they don't exist
    if (!fs.existsSync(g_pluginsDir))
        fs.mkdirSync(g_pluginsDir, { recursive: true });
    if (!fs.existsSync(g_addonsDir))
        fs.mkdirSync(g_addonsDir, { recursive: true });
}
pipe.on('connected', async () => {
    addLog('INFO', 'Connected to EthyTool pipe');
    mainWindow?.webContents.send('pipe-status', true);
    // Set scripts directory so the DLL knows where plugins live
    try {
        if (g_pluginsDir) {
            const resp = await pipe.sendCommand(`SET_SCRIPTS_DIR ${g_pluginsDir}`);
            addLog('INFO', `SET_SCRIPTS_DIR ${g_pluginsDir} → ${resp}`);
        }
        else {
            addLog('WARN', 'Game path not detected — plugins directory unknown');
        }
    }
    catch (err) {
        addLog('WARN', `Failed to set scripts dir: ${err.message}`);
    }
    // Start the in-game ImGui overlay so loaded plugins can render UI
    try {
        const ovr = await pipe.sendCommand('OVERLAY_START');
        addLog('INFO', `OVERLAY_START → ${ovr}`);
    }
    catch (err) {
        addLog('WARN', `Failed to start overlay: ${err.message}`);
    }
    // Scan plugins so the list is populated, but do NOT auto-load.
    // The user drives load via the Plugins page UI.
    try {
        await pipe.sendCommand('PLUGIN_SCAN');
        addLog('INFO', 'PLUGIN_SCAN complete (no auto-load)');
    }
    catch (err) {
        addLog('WARN', `Failed to scan plugins: ${err.message}`);
    }
});
pipe.on('disconnected', () => {
    addLog('WARN', 'Disconnected from EthyTool pipe (reconnect grace period exhausted)');
    mainWindow?.webContents.send('pipe-status', false);
});
pipe.on('reconnecting', (attempt) => {
    addLog('INFO', `Pipe dropped — reconnecting (attempt ${attempt + 1})...`);
    // Don't send pipe-status false yet — we're still trying to reconnect.
});
pipe.on('pipe-error', (detail) => {
    addLog('DEBUG', `Pipe error detail: ${detail}`);
});
pipe.on('event', (line) => {
    // Don't flood the log with high-frequency event pipe data
    mainWindow?.webContents.send('pipe-event', line);
});
pipe.on('status', (line) => {
    mainWindow?.webContents.send('pipe-status-msg', line);
});
// ── IPC: Pipe Bridge ────────────────────────────────────────────────────────
electron_1.ipcMain.handle('pipe-connect', async (_e, gamePid) => {
    pipe.enableAutoReconnect();
    const ok = await pipe.connect(gamePid);
    if (ok)
        addLog('INFO', 'Pipe connection established');
    return ok;
});
electron_1.ipcMain.handle('pipe-disconnect', () => {
    pipe.disconnect();
    return true;
});
electron_1.ipcMain.handle('pipe-is-connected', () => pipe.connected);
electron_1.ipcMain.handle('pipe-send', async (_e, cmd) => {
    try {
        const resp = await pipe.sendCommand(cmd);
        return { ok: true, data: resp };
    }
    catch (err) {
        return { ok: false, data: err.message };
    }
});
// ── IPC: Player Info ────────────────────────────────────────────────────────
electron_1.ipcMain.handle('get-player-info', async () => {
    if (!pipe.connected)
        return null;
    try {
        const resp = await pipe.sendCommand('PLAYER_INFO');
        return parseKVResponse(resp);
    }
    catch {
        return null;
    }
});
electron_1.ipcMain.handle('get-target-info', async () => {
    if (!pipe.connected)
        return null;
    try {
        const resp = await pipe.sendCommand('TARGET_INFO');
        return parseKVResponse(resp);
    }
    catch {
        return null;
    }
});
// ── IPC: Plugins ────────────────────────────────────────────────────────────
function parseHeaderLua(content) {
    const extract = (key) => {
        const m = content.match(new RegExp(`${key}\\s*=\\s*"([^"]*)"`, 'i'));
        return m ? m[1] : undefined;
    };
    return { name: extract('name'), description: extract('description'), version: extract('version'), author: extract('author') };
}
function readPluginMeta(folderPath, folderName) {
    let displayName = folderName;
    let author = '';
    let version = '';
    let description = '';
    // Try header.lua first
    const headerPath = path.join(folderPath, 'header.lua');
    if (fs.existsSync(headerPath)) {
        try {
            const parsed = parseHeaderLua(fs.readFileSync(headerPath, 'utf-8'));
            if (parsed.name)
                displayName = parsed.name;
            if (parsed.author)
                author = parsed.author;
            if (parsed.version)
                version = parsed.version;
            if (parsed.description)
                description = parsed.description;
        }
        catch { /* ignore */ }
    }
    else {
        // Fallback to plugin.json
        const jsonPath = path.join(folderPath, 'plugin.json');
        if (fs.existsSync(jsonPath)) {
            try {
                const meta = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
                if (meta.name)
                    displayName = meta.name;
                if (meta.author)
                    author = meta.author;
                if (meta.version)
                    version = meta.version;
                if (meta.description)
                    description = meta.description;
            }
            catch { /* ignore */ }
        }
    }
    return { displayName, author, version, description };
}
function scanLocalPlugins() {
    if (!g_pluginsDir) {
        addLog('WARN', 'scanLocalPlugins: plugins directory not set');
        return [];
    }
    if (!fs.existsSync(g_pluginsDir)) {
        addLog('WARN', `scanLocalPlugins: dir does not exist: ${g_pluginsDir}`);
        return [];
    }
    const result = [];
    try {
        const entries = fs.readdirSync(g_pluginsDir, { withFileTypes: true });
        for (const entry of entries) {
            if (!entry.isDirectory())
                continue;
            const folderPath = path.join(g_pluginsDir, entry.name);
            const hasMain = fs.existsSync(path.join(folderPath, 'main.lua'));
            if (!hasMain)
                continue;
            const meta = readPluginMeta(folderPath, entry.name);
            result.push({
                name: entry.name,
                folder: folderPath,
                loaded: false,
                enabled: true,
                lastError: '',
                ...meta,
            });
        }
    }
    catch (err) {
        addLog('ERROR', `scanLocalPlugins error: ${err.message}`);
    }
    addLog('INFO', `scanLocalPlugins: found ${result.length} plugins → [${result.map(p => p.name).join(', ')}]`);
    return result;
}
function parsePluginList(raw) {
    if (!raw || raw === 'NONE' || raw === 'EMPTY')
        return [];
    return raw.split('\x1F').filter(Boolean).map(line => {
        const parts = line.split('|');
        const folder = parts[1] || '';
        const meta = readPluginMeta(folder, parts[0] || '');
        return {
            name: parts[0] || '',
            folder,
            loaded: parts[2] === '1',
            enabled: parts[3] === '1',
            lastError: parts[4] || '',
            ...meta,
        };
    });
}
function mergeWithDllState(local, dllRaw) {
    const dllPlugins = parsePluginList(dllRaw);
    const dllByFolder = new Map(dllPlugins.map(p => [p.folder, p]));
    // Start with local scan, overlay DLL loaded/enabled/lastError state
    const merged = local.map(lp => {
        const dp = dllByFolder.get(lp.folder);
        if (dp) {
            dllByFolder.delete(lp.folder);
            return { ...lp, loaded: dp.loaded, enabled: dp.enabled, lastError: dp.lastError };
        }
        return lp;
    });
    // Add any DLL-only plugins not found locally (edge case)
    for (const dp of dllByFolder.values())
        merged.push(dp);
    const loadedCount = merged.filter(p => p.loaded).length;
    addLog('INFO', `mergeWithDllState: ${merged.length} plugins (${loadedCount} loaded)`);
    return merged;
}
electron_1.ipcMain.handle('list-plugins', async () => {
    const local = scanLocalPlugins();
    if (!pipe.connected)
        return local;
    try {
        const resp = await pipe.sendCommand('PLUGIN_LIST');
        return mergeWithDllState(local, resp);
    }
    catch (err) {
        addLog('ERROR', `list-plugins DLL error: ${err.message}`);
        return local;
    }
});
electron_1.ipcMain.handle('scan-plugins', async () => {
    const local = scanLocalPlugins();
    if (!pipe.connected)
        return local;
    try {
        await pipe.sendCommand('PLUGIN_SCAN');
        const resp = await pipe.sendCommand('PLUGIN_LIST');
        return mergeWithDllState(local, resp);
    }
    catch (err) {
        addLog('ERROR', `scan-plugins DLL error: ${err.message} — falling back to ${local.length} local`);
        return local;
    }
});
electron_1.ipcMain.handle('scan-local-plugins', () => scanLocalPlugins());
electron_1.ipcMain.handle('load-plugin', async (_e, folder) => {
    addLog('DEBUG', `load-plugin called — folder="${folder}" pipe.connected=${pipe.connected}`);
    if (!pipe.connected) {
        addLog('DEBUG', 'load-plugin: NOT connected, returning false');
        return false;
    }
    try {
        // Ensure DLL has scanned so it knows about this plugin
        const scanResp = await pipe.sendCommand('PLUGIN_SCAN');
        addLog('DEBUG', `load-plugin: PLUGIN_SCAN → "${scanResp}"`);
        const loadResp = await pipe.sendCommand(`PLUGIN_LOAD ${folder}`);
        addLog('DEBUG', `load-plugin: PLUGIN_LOAD ${folder} → "${loadResp}"`);
        return loadResp.startsWith('OK');
    }
    catch (err) {
        addLog('ERROR', `load-plugin error: ${err.message}`);
        return false;
    }
});
electron_1.ipcMain.handle('unload-plugin', async (_e, folder) => {
    addLog('DEBUG', `unload-plugin called — folder="${folder}" pipe.connected=${pipe.connected}`);
    if (!pipe.connected)
        return false;
    try {
        const resp = await pipe.sendCommand(`PLUGIN_UNLOAD ${folder}`);
        addLog('DEBUG', `unload-plugin: PLUGIN_UNLOAD → "${resp}"`);
        return resp.startsWith('OK');
    }
    catch (err) {
        addLog('ERROR', `unload-plugin error: ${err.message}`);
        return false;
    }
});
electron_1.ipcMain.handle('reload-plugin', async (_e, folder) => {
    addLog('DEBUG', `reload-plugin called — folder="${folder}" pipe.connected=${pipe.connected}`);
    if (!pipe.connected)
        return false;
    try {
        await pipe.sendCommand('PLUGIN_SCAN');
        await pipe.sendCommand(`PLUGIN_UNLOAD ${folder}`);
        const resp = await pipe.sendCommand(`PLUGIN_LOAD ${folder}`);
        addLog('DEBUG', `reload-plugin: PLUGIN_LOAD → "${resp}"`);
        return resp.startsWith('OK');
    }
    catch (err) {
        addLog('ERROR', `reload-plugin error: ${err.message}`);
        return false;
    }
});
electron_1.ipcMain.handle('load-all-plugins', async () => {
    addLog('DEBUG', `load-all-plugins called — pipe.connected=${pipe.connected}`);
    if (!pipe.connected)
        return false;
    try {
        await pipe.sendCommand('PLUGIN_SCAN');
        const resp = await pipe.sendCommand('PLUGIN_LOAD_ALL');
        addLog('DEBUG', `load-all-plugins: PLUGIN_LOAD_ALL → "${resp}"`);
        return resp.startsWith('OK');
    }
    catch (err) {
        addLog('ERROR', `load-all-plugins error: ${err.message}`);
        return false;
    }
});
electron_1.ipcMain.handle('unload-all-plugins', async () => {
    addLog('DEBUG', `unload-all-plugins called — pipe.connected=${pipe.connected}`);
    if (!pipe.connected)
        return false;
    try {
        const resp = await pipe.sendCommand('PLUGIN_UNLOAD_ALL');
        addLog('DEBUG', `unload-all-plugins: PLUGIN_UNLOAD_ALL → "${resp}"`);
        return resp.startsWith('OK');
    }
    catch (err) {
        addLog('ERROR', `unload-all-plugins error: ${err.message}`);
        return false;
    }
});
// ── IPC: Scripts ────────────────────────────────────────────────────────────
electron_1.ipcMain.handle('run-script', async (_e, code) => {
    if (!pipe.connected)
        return 'Not connected';
    try {
        return await pipe.sendCommand(`RUN_SCRIPT ${code}`);
    }
    catch (err) {
        return err.message;
    }
});
electron_1.ipcMain.handle('stop-script', async () => {
    if (!pipe.connected)
        return false;
    try {
        await pipe.sendCommand('STOP_SCRIPT');
        return true;
    }
    catch {
        return false;
    }
});
// ── IPC: Settings ───────────────────────────────────────────────────────────
electron_1.ipcMain.handle('get-render-settings', async () => {
    if (!pipe.connected)
        return null;
    try {
        const resp = await pipe.sendCommand('RENDER_SETTINGS');
        return parseKVResponse(resp);
    }
    catch {
        return null;
    }
});
electron_1.ipcMain.handle('set-setting', async (_e, cmd) => {
    if (!pipe.connected)
        return false;
    try {
        const resp = await pipe.sendCommand(cmd);
        return resp.startsWith('OK');
    }
    catch {
        return false;
    }
});
// ── IPC: Log ────────────────────────────────────────────────────────────────
electron_1.ipcMain.handle('get-log', () => logLines);
electron_1.ipcMain.handle('clear-log', () => { logLines.length = 0; return true; });
// ── IPC: Process Scanning & Injection ────────────────────────────────────────
electron_1.ipcMain.handle('find-game-processes', () => {
    try {
        return (0, injector_1.scanProcesses)('ethyrial');
    }
    catch {
        return [];
    }
});
electron_1.ipcMain.handle('inject-dll', async (_e, pid) => {
    try {
        // If no PID provided, find Ethyrial.exe automatically
        let targetPid = pid;
        if (!targetPid) {
            const procs = (0, injector_1.scanProcesses)('ethyrial.exe');
            const gameProcs = procs.filter(p => p.name.toLowerCase() === 'ethyrial.exe');
            if (gameProcs.length === 0) {
                addLog('WARN', 'Ethyrial.exe not found. Launch the game first.');
                return { ok: false, error: 'Ethyrial.exe not running' };
            }
            targetPid = gameProcs[0].pid;
        }
        // Try connecting to the pipe first — if the DLL is already injected
        // we can skip injection entirely and just reconnect.
        addLog('INFO', `Checking if DLL is already injected in PID ${targetPid}...`);
        const alreadyConnected = await pipe.connect(targetPid);
        if (alreadyConnected) {
            addLog('INFO', `DLL already present in PID ${targetPid} — skipped injection, pipe connected`);
            pipe.enableAutoReconnect();
            return { ok: true };
        }
        // DLL not injected yet — find and inject it
        const dllPath = (0, injector_1.findEthyToolDLL)();
        if (!dllPath) {
            addLog('ERROR', 'EthyTool.dll not found. Place it next to EthyrialHub.exe.');
            return { ok: false, error: 'EthyTool.dll not found' };
        }
        addLog('INFO', `Found EthyTool.dll: ${dllPath}`);
        addLog('INFO', `Injecting into PID ${targetPid}...`);
        // Inject
        const result = (0, injector_1.injectDLL)(targetPid, dllPath);
        if (result.ok) {
            addLog('INFO', `EthyTool.dll injected successfully into PID ${targetPid}`);
            // Retry pipe connection with aggressive polling after injection
            const MAX_RETRIES = 15;
            let attempt = 0;
            const tryConnect = async () => {
                attempt++;
                addLog('INFO', `Pipe connect attempt ${attempt}/${MAX_RETRIES}...`);
                const ok = await pipe.connect(targetPid);
                if (ok) {
                    addLog('INFO', 'Auto-connected to EthyTool pipe after injection');
                    pipe.enableAutoReconnect();
                }
                else if (attempt < MAX_RETRIES) {
                    setTimeout(tryConnect, 2000);
                }
                else {
                    addLog('WARN', 'Could not auto-connect to pipe. Click Reconnect to try again.');
                    mainWindow?.webContents.send('inject-timeout');
                }
            };
            // Give the DLL 3 seconds to initialize before first attempt
            setTimeout(tryConnect, 3000);
        }
        else {
            addLog('ERROR', `Injection failed: ${result.error}`);
        }
        return result;
    }
    catch (err) {
        addLog('ERROR', `Injection error: ${err.message}`);
        return { ok: false, error: err.message };
    }
});
// ── IPC: Discovery — Download & Install Plugin ─────────────────────────────
electron_1.ipcMain.handle('download-plugin', async (_e, id, url) => {
    if (!g_pluginsDir)
        return { ok: false, error: 'Plugins directory not set' };
    try {
        addLog('INFO', `Downloading plugin "${id}" from ${url}`);
        // Download the zip using Node https/http
        const zipBuffer = await new Promise((resolve, reject) => {
            const mod = url.startsWith('https') ? require('https') : require('http');
            mod.get(url, (res) => {
                // Follow redirects
                if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                    const rMod = res.headers.location.startsWith('https') ? require('https') : require('http');
                    rMod.get(res.headers.location, (r2) => {
                        const chunks = [];
                        r2.on('data', (c) => chunks.push(c));
                        r2.on('end', () => resolve(Buffer.concat(chunks)));
                        r2.on('error', reject);
                    }).on('error', reject);
                    return;
                }
                const chunks = [];
                res.on('data', (c) => chunks.push(c));
                res.on('end', () => resolve(Buffer.concat(chunks)));
                res.on('error', reject);
            }).on('error', reject);
        });
        // Write temp zip
        const tmpZip = path.join(electron_1.app.getPath('temp'), `plugin_${id}.zip`);
        fs.writeFileSync(tmpZip, zipBuffer);
        // Extract using PowerShell Expand-Archive
        const destDir = path.join(g_pluginsDir, id);
        if (!fs.existsSync(destDir))
            fs.mkdirSync(destDir, { recursive: true });
        await new Promise((resolve, reject) => {
            const ps = child_process.spawn('powershell', [
                '-NoProfile', '-Command',
                `Expand-Archive -Path '${tmpZip}' -DestinationPath '${destDir}' -Force`
            ]);
            ps.on('close', code => {
                try {
                    fs.unlinkSync(tmpZip);
                }
                catch { }
                if (code === 0)
                    resolve();
                else
                    reject(new Error(`Expand-Archive exit code ${code}`));
            });
            ps.on('error', reject);
        });
        // Verify main.lua exists (may be nested one level)
        if (!fs.existsSync(path.join(destDir, 'main.lua'))) {
            // Check if there's a single subfolder containing main.lua
            const entries = fs.readdirSync(destDir);
            const sub = entries.find(e => fs.statSync(path.join(destDir, e)).isDirectory() && fs.existsSync(path.join(destDir, e, 'main.lua')));
            if (sub) {
                // Move contents up one level
                const subDir = path.join(destDir, sub);
                for (const f of fs.readdirSync(subDir)) {
                    fs.renameSync(path.join(subDir, f), path.join(destDir, f));
                }
                fs.rmdirSync(subDir);
            }
        }
        addLog('INFO', `Plugin "${id}" installed to ${destDir}`);
        return { ok: true };
    }
    catch (err) {
        addLog('ERROR', `Plugin download failed: ${err.message}`);
        return { ok: false, error: err.message };
    }
});
// ── IPC: Addon Manager ─────────────────────────────────────────────────────
electron_1.ipcMain.handle('get-addons', () => mgr.getAddons());
electron_1.ipcMain.handle('rescan', () => mgr.scanAddons());
electron_1.ipcMain.handle('enable-addon', (_e, name) => mgr.enableAddon(name));
electron_1.ipcMain.handle('disable-addon', (_e, name) => mgr.disableAddon(name));
electron_1.ipcMain.handle('delete-addon', (_e, name) => mgr.deleteAddon(name));
electron_1.ipcMain.handle('create-addon', (_e, opts) => mgr.createAddon(opts));
electron_1.ipcMain.handle('get-game-path', () => mgr.getGamePath());
electron_1.ipcMain.handle('get-addons-path', () => mgr.getAddonsPath());
electron_1.ipcMain.handle('set-game-path', (_e, p) => {
    mgr.setGamePath(p);
    initGameDirs(p);
    mgr.ensureAddonsFolder();
    mgr.scanAddons();
    return true;
});
electron_1.ipcMain.handle('get-plugins-path', () => g_pluginsDir);
electron_1.ipcMain.handle('open-folder', (_e, folderPath) => {
    electron_1.shell.openPath(folderPath);
});
electron_1.ipcMain.handle('select-folder', async () => {
    const result = await electron_1.dialog.showOpenDialog({
        properties: ['openDirectory'],
        title: 'Select Ethyrial Echoes of Yore install folder',
    });
    if (result.canceled || result.filePaths.length === 0)
        return '';
    return result.filePaths[0];
});
// ── Helpers ─────────────────────────────────────────────────────────────────
function parseKVResponse(raw) {
    const result = {};
    if (!raw)
        return result;
    const parts = raw.split('|');
    for (const part of parts) {
        const eq = part.indexOf('=');
        if (eq > 0) {
            result[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
        }
        else {
            result[part.trim()] = '';
        }
    }
    return result;
}
// ── App Lifecycle ───────────────────────────────────────────────────────────
electron_1.app.whenReady().then(() => {
    const detected = addonManager_1.AddonManager.detectGamePath();
    const gamePath = detected || 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Ethyrial Echoes of Yore';
    mgr.setGamePath(gamePath);
    initGameDirs(gamePath);
    mgr.ensureAddonsFolder();
    mgr.scanAddons();
    createWindow();
    addLog('INFO', 'EthyrialHub started');
    // Try to auto-connect on launch (if DLL is already injected from a previous session).
    // Don't enable autoReconnect yet — that happens after injection or explicit connect.
    pipe.connect().then(ok => {
        if (ok) {
            addLog('INFO', 'Auto-connected to EthyTool');
            pipe.enableAutoReconnect();
        }
        else {
            addLog('INFO', 'EthyTool not detected — waiting for injection');
        }
    });
    electron_1.app.on('activate', () => {
        if (electron_1.BrowserWindow.getAllWindows().length === 0)
            createWindow();
    });
});
electron_1.app.on('window-all-closed', () => {
    pipe.disconnect();
    electron_1.app.quit();
});
