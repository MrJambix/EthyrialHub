"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
electron_1.contextBridge.exposeInMainWorld('electronAPI', {
    // ── Pipe Bridge ──
    pipeConnect: (gamePid) => electron_1.ipcRenderer.invoke('pipe-connect', gamePid),
    pipeDisconnect: () => electron_1.ipcRenderer.invoke('pipe-disconnect'),
    pipeIsConnected: () => electron_1.ipcRenderer.invoke('pipe-is-connected'),
    pipeSend: (cmd) => electron_1.ipcRenderer.invoke('pipe-send', cmd),
    // ── Player ──
    getPlayerInfo: () => electron_1.ipcRenderer.invoke('get-player-info'),
    getTargetInfo: () => electron_1.ipcRenderer.invoke('get-target-info'),
    // ── Plugins ──
    listPlugins: () => electron_1.ipcRenderer.invoke('list-plugins'),
    scanPlugins: () => electron_1.ipcRenderer.invoke('scan-plugins'),
    scanLocalPlugins: () => electron_1.ipcRenderer.invoke('scan-local-plugins'),
    loadPlugin: (folder) => electron_1.ipcRenderer.invoke('load-plugin', folder),
    unloadPlugin: (folder) => electron_1.ipcRenderer.invoke('unload-plugin', folder),
    reloadPlugin: (folder) => electron_1.ipcRenderer.invoke('reload-plugin', folder),
    loadAllPlugins: () => electron_1.ipcRenderer.invoke('load-all-plugins'),
    unloadAllPlugins: () => electron_1.ipcRenderer.invoke('unload-all-plugins'),
    // ── Scripts ──
    runScript: (code) => electron_1.ipcRenderer.invoke('run-script', code),
    stopScript: () => electron_1.ipcRenderer.invoke('stop-script'),
    // ── Settings ──
    getRenderSettings: () => electron_1.ipcRenderer.invoke('get-render-settings'),
    setSetting: (cmd) => electron_1.ipcRenderer.invoke('set-setting', cmd),
    // ── Log ──
    getLog: () => electron_1.ipcRenderer.invoke('get-log'),
    clearLog: () => electron_1.ipcRenderer.invoke('clear-log'),
    // ── Process Scanning & Injection ──
    findGameProcesses: () => electron_1.ipcRenderer.invoke('find-game-processes'),
    injectDLL: (pid) => electron_1.ipcRenderer.invoke('inject-dll', pid),
    // ── Discovery ──
    downloadPlugin: (id, url) => electron_1.ipcRenderer.invoke('download-plugin', id, url),
    // ── Addon Manager ──
    getAddons: () => electron_1.ipcRenderer.invoke('get-addons'),
    rescan: () => electron_1.ipcRenderer.invoke('rescan'),
    enableAddon: (name) => electron_1.ipcRenderer.invoke('enable-addon', name),
    disableAddon: (name) => electron_1.ipcRenderer.invoke('disable-addon', name),
    deleteAddon: (name) => electron_1.ipcRenderer.invoke('delete-addon', name),
    createAddon: (opts) => electron_1.ipcRenderer.invoke('create-addon', opts),
    openFolder: (path) => electron_1.ipcRenderer.invoke('open-folder', path),
    getGamePath: () => electron_1.ipcRenderer.invoke('get-game-path'),
    getAddonsPath: () => electron_1.ipcRenderer.invoke('get-addons-path'),
    setGamePath: (p) => electron_1.ipcRenderer.invoke('set-game-path', p),
    selectFolder: () => electron_1.ipcRenderer.invoke('select-folder'),
    // ── Events from main ──
    onPipeStatus: (cb) => {
        const handler = (_e, val) => cb(val);
        electron_1.ipcRenderer.on('pipe-status', handler);
        return () => { electron_1.ipcRenderer.removeListener('pipe-status', handler); };
    },
    onPipeEvent: (cb) => {
        const handler = (_e, line) => cb(line);
        electron_1.ipcRenderer.on('pipe-event', handler);
        return () => { electron_1.ipcRenderer.removeListener('pipe-event', handler); };
    },
    onLogLine: (cb) => {
        const handler = (_e, line) => cb(line);
        electron_1.ipcRenderer.on('log-line', handler);
        return () => { electron_1.ipcRenderer.removeListener('log-line', handler); };
    },
    onPipeStatusMsg: (cb) => {
        const handler = (_e, msg) => cb(msg);
        electron_1.ipcRenderer.on('pipe-status-msg', handler);
        return () => { electron_1.ipcRenderer.removeListener('pipe-status-msg', handler); };
    },
    onInjectTimeout: (cb) => {
        const handler = () => cb();
        electron_1.ipcRenderer.on('inject-timeout', handler);
        return () => { electron_1.ipcRenderer.removeListener('inject-timeout', handler); };
    },
});
