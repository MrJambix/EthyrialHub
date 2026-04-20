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
exports.AddonManager = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const tocParser_1 = require("./tocParser");
function getDirSize(dirPath) {
    let total = 0;
    try {
        const entries = fs.readdirSync(dirPath, { withFileTypes: true });
        for (const e of entries) {
            const full = path.join(dirPath, e.name);
            if (e.isFile()) {
                total += fs.statSync(full).size;
            }
            else if (e.isDirectory()) {
                total += getDirSize(full);
            }
        }
    }
    catch { /* ignore */ }
    return total;
}
function getDirFileCount(dirPath) {
    let count = 0;
    try {
        const entries = fs.readdirSync(dirPath, { withFileTypes: true });
        for (const e of entries) {
            if (e.isFile()) {
                count++;
            }
            else if (e.isDirectory()) {
                count += getDirFileCount(path.join(dirPath, e.name));
            }
        }
    }
    catch { /* ignore */ }
    return count;
}
function getInstallDate(dirPath) {
    try {
        const stat = fs.statSync(dirPath);
        return stat.birthtime.toISOString().slice(0, 10);
    }
    catch {
        return 'unknown';
    }
}
class AddonManager {
    constructor() {
        this.gamePath = '';
        this.addonsPath = '';
        this.addons = [];
    }
    /** Auto-detect Ethyrial install from common Steam paths + libraryfolders.vdf */
    static detectGamePath() {
        const candidates = [
            'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Ethyrial Echoes of Yore',
            'C:\\Program Files\\Steam\\steamapps\\common\\Ethyrial Echoes of Yore',
            'D:\\Steam\\steamapps\\common\\Ethyrial Echoes of Yore',
            'D:\\SteamLibrary\\steamapps\\common\\Ethyrial Echoes of Yore',
            'E:\\SteamLibrary\\steamapps\\common\\Ethyrial Echoes of Yore',
            'F:\\SteamLibrary\\steamapps\\common\\Ethyrial Echoes of Yore',
        ];
        for (const p of candidates) {
            if (fs.existsSync(p))
                return p;
        }
        // Parse Steam's libraryfolders.vdf
        const vdfPath = 'C:\\Program Files (x86)\\Steam\\steamapps\\libraryfolders.vdf';
        if (fs.existsSync(vdfPath)) {
            try {
                const content = fs.readFileSync(vdfPath, 'utf-8');
                const pathRe = /"path"\s+"([^"]+)"/g;
                let m;
                while ((m = pathRe.exec(content)) !== null) {
                    const libPath = m[1].replace(/\\\\/g, '\\');
                    const gamePath = path.join(libPath, 'steamapps', 'common', 'Ethyrial Echoes of Yore');
                    if (fs.existsSync(gamePath))
                        return gamePath;
                }
            }
            catch { /* ignore */ }
        }
        return '';
    }
    setGamePath(gamePath) {
        this.gamePath = gamePath;
        this.addonsPath = path.join(gamePath, 'Addons');
    }
    getAddonsPath() { return this.addonsPath; }
    getGamePath() { return this.gamePath; }
    isReady() { return this.addonsPath !== ''; }
    ensureAddonsFolder() {
        if (!this.addonsPath)
            return false;
        if (!fs.existsSync(this.addonsPath)) {
            fs.mkdirSync(this.addonsPath, { recursive: true });
        }
        return true;
    }
    scanAddons() {
        this.addons = [];
        if (!this.addonsPath || !fs.existsSync(this.addonsPath))
            return [];
        let entries;
        try {
            entries = fs.readdirSync(this.addonsPath, { withFileTypes: true });
        }
        catch {
            return [];
        }
        for (const entry of entries) {
            if (!entry.isDirectory())
                continue;
            const folderName = entry.name;
            const folderPath = path.join(this.addonsPath, folderName);
            // Find .toc file
            let tocPath = path.join(folderPath, `${folderName}.toc`);
            let disabled = false;
            if (fs.existsSync(tocPath)) {
                // exact match
            }
            else if (fs.existsSync(tocPath + '.disabled')) {
                tocPath = tocPath + '.disabled';
                disabled = true;
            }
            else {
                // try any .toc in folder
                try {
                    const files = fs.readdirSync(folderPath);
                    const tocFile = files.find(f => f.endsWith('.toc') || f.endsWith('.toc.disabled'));
                    if (!tocFile)
                        continue;
                    tocPath = path.join(folderPath, tocFile);
                    disabled = tocFile.endsWith('.disabled');
                }
                catch {
                    continue;
                }
            }
            const toc = (0, tocParser_1.parseTOC)(tocPath);
            this.addons.push({
                folderName,
                folderPath,
                tocPath,
                title: toc.title || folderName,
                author: toc.author,
                version: toc.version,
                notes: toc.notes,
                category: toc.category,
                interfaceVer: toc.interfaceVer,
                website: toc.website,
                luaFiles: toc.files,
                enabled: !disabled,
                sizeBytes: getDirSize(folderPath),
                fileCount: getDirFileCount(folderPath),
                installDate: getInstallDate(folderPath),
                lastError: '',
            });
        }
        this.addons.sort((a, b) => a.title.localeCompare(b.title));
        return this.addons;
    }
    getAddons() {
        return this.addons;
    }
    enableAddon(folderName) {
        const addon = this.addons.find(a => a.folderName === folderName);
        if (!addon || addon.enabled)
            return !!addon;
        const disabledPath = path.join(addon.folderPath, `${folderName}.toc.disabled`);
        const enabledPath = path.join(addon.folderPath, `${folderName}.toc`);
        try {
            if (fs.existsSync(disabledPath)) {
                fs.renameSync(disabledPath, enabledPath);
            }
            addon.enabled = true;
            addon.tocPath = enabledPath;
            return true;
        }
        catch {
            return false;
        }
    }
    disableAddon(folderName) {
        const addon = this.addons.find(a => a.folderName === folderName);
        if (!addon || !addon.enabled)
            return !!addon;
        const enabledPath = path.join(addon.folderPath, `${folderName}.toc`);
        const disabledPath = enabledPath + '.disabled';
        try {
            if (fs.existsSync(enabledPath)) {
                fs.renameSync(enabledPath, disabledPath);
            }
            addon.enabled = false;
            addon.tocPath = disabledPath;
            return true;
        }
        catch {
            return false;
        }
    }
    deleteAddon(folderName) {
        const idx = this.addons.findIndex(a => a.folderName === folderName);
        if (idx < 0)
            return false;
        const addon = this.addons[idx];
        try {
            fs.rmSync(addon.folderPath, { recursive: true, force: true });
            this.addons.splice(idx, 1);
            return true;
        }
        catch {
            return false;
        }
    }
    createAddon(opts) {
        if (!this.addonsPath)
            return false;
        const folderPath = path.join(this.addonsPath, opts.name);
        try {
            fs.mkdirSync(folderPath, { recursive: true });
            // Write .toc
            const tocContent = [
                `## Title: ${opts.name}`,
                `## Author: ${opts.author || 'Unknown'}`,
                `## Version: 1.0.0`,
                `## Notes: A new Ethyrial addon`,
                `## Category: ${opts.category || 'General'}`,
                `## Interface: 1.0`,
                ``,
                `main.lua`,
            ].join('\n');
            fs.writeFileSync(path.join(folderPath, `${opts.name}.toc`), tocContent, 'utf-8');
            // Write main.lua
            const mainContent = [
                `-- ${opts.name} — Ethyrial Addon`,
                `-- Author: ${opts.author || 'Unknown'}`,
                `-- Version: 1.0.0`,
                ``,
                `print("[${opts.name}] Addon loaded!")`,
                ``,
                `-- Register callbacks`,
                `-- callbacks.on_update(function(dt)`,
                `--     -- Called every frame`,
                `-- end)`,
                ``,
                `-- callbacks.on_render(function()`,
                `--     -- Called every render frame`,
                `-- end)`,
            ].join('\n');
            fs.writeFileSync(path.join(folderPath, 'main.lua'), mainContent, 'utf-8');
            this.scanAddons();
            return true;
        }
        catch {
            return false;
        }
    }
}
exports.AddonManager = AddonManager;
