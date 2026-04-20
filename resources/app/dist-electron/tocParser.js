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
exports.parseTOC = parseTOC;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/**
 * Parse a WoW-style .toc file.
 *
 * Format:
 *   ## Title: My Addon
 *   ## Author: SomeAuthor
 *   ## Version: 1.0.0
 *   ## Notes: Description text
 *   ## Category: Combat
 *   ## Interface: 1.0
 *   main.lua
 *   libs/utils.lua
 */
function parseTOC(tocPath) {
    const data = {
        title: '',
        author: '',
        version: '',
        notes: '',
        category: '',
        interfaceVer: '',
        website: '',
        files: [],
    };
    if (!fs.existsSync(tocPath))
        return data;
    const content = fs.readFileSync(tocPath, 'utf-8');
    const lines = content.split(/\r?\n/);
    for (const raw of lines) {
        const line = raw.trim();
        if (!line)
            continue;
        // ## Key: Value
        if (line.startsWith('##')) {
            const rest = line.slice(2).trim();
            const colon = rest.indexOf(':');
            if (colon < 0)
                continue;
            const key = rest.slice(0, colon).trim().toLowerCase();
            const val = rest.slice(colon + 1).trim();
            switch (key) {
                case 'title':
                    data.title = val;
                    break;
                case 'author':
                    data.author = val;
                    break;
                case 'version':
                    data.version = val;
                    break;
                case 'notes':
                    data.notes = val;
                    break;
                case 'category':
                    data.category = val;
                    break;
                case 'interface':
                    data.interfaceVer = val;
                    break;
                case 'website':
                    data.website = val;
                    break;
            }
            continue;
        }
        // Single-line comments
        if (line.startsWith('#'))
            continue;
        // Everything else is a file reference
        data.files.push(line.replace(/\//g, path.sep));
    }
    return data;
}
