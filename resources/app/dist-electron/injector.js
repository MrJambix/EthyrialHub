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
exports.scanProcesses = scanProcesses;
exports.injectDLL = injectDLL;
exports.findEthyToolDLL = findEthyToolDLL;
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const child_process = __importStar(require("child_process"));
/** Scan for processes using tasklist */
function scanProcesses(filter) {
    try {
        const filterArg = filter || 'Ethyrial';
        const raw = child_process.execSync(`tasklist /FI "IMAGENAME eq ${filterArg}*" /FO CSV /NH`, { encoding: 'utf-8', timeout: 5000 });
        const procs = [];
        for (const line of raw.split('\n')) {
            const match = line.match(/"([^"]+)","(\d+)"/);
            if (match) {
                procs.push({ name: match[1], pid: parseInt(match[2]) });
            }
        }
        return procs;
    }
    catch {
        return [];
    }
}
/** Get path to the inject.ps1 script (shipped alongside the app) */
function getInjectScript() {
    const candidates = [
        path.join(process.resourcesPath || '', 'app', 'inject.ps1'),
        path.join(__dirname, '..', 'inject.ps1'),
    ];
    for (const p of candidates) {
        if (fs.existsSync(p))
            return p;
    }
    return path.join(__dirname, '..', 'inject.ps1');
}
/**
 * Inject a DLL into a process using a PowerShell script with inline C#.
 * Uses CreateRemoteThread + LoadLibraryW — same technique as the C++ injector.
 * No native Node addons or FFI libraries needed.
 */
function injectDLL(pid, dllPath) {
    const absPath = path.resolve(dllPath);
    if (!fs.existsSync(absPath)) {
        return { ok: false, error: `DLL not found: ${absPath}`, pid };
    }
    const scriptPath = getInjectScript();
    if (!fs.existsSync(scriptPath)) {
        return { ok: false, error: `Inject script not found: ${scriptPath}`, pid };
    }
    try {
        const result = child_process.execSync(`powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" -TargetPID ${pid} -DLLPath "${absPath}"`, { encoding: 'utf-8', timeout: 30000 }).trim();
        // Script outputs "OK" on success or "ERROR:message" on failure
        if (result.includes('OK')) {
            return { ok: true, pid };
        }
        else {
            const errLine = result.split('\n').find(l => l.startsWith('ERROR:'));
            return { ok: false, error: errLine ? errLine.substring(6) : (result || 'Unknown injection error'), pid };
        }
    }
    catch (err) {
        const stderr = err.stderr?.toString().trim();
        const stdout = err.stdout?.toString().trim();
        const msg = stderr || stdout || err.message || 'Injection process failed';
        return { ok: false, error: msg, pid };
    }
}
/** Find the EthyTool.dll path */
function findEthyToolDLL() {
    const candidates = [
        // Next to the packaged exe
        path.join(process.resourcesPath || '', '..', 'EthyTool.dll'),
        // In the app's root
        path.join(__dirname, '..', 'EthyTool.dll'),
        // Development: Release build
        path.join(__dirname, '..', '..', '..', 'EthyTool', 'x64', 'Release', 'EthyTool.dll'),
        // Development: Debug build
        path.join(__dirname, '..', '..', '..', 'EthyTool', 'x64', 'Debug', 'EthyTool.dll'),
        // Legacy location
        path.join(__dirname, '..', '..', '..', 'EthyrialInjector', 'EthyTool', 'EthyTool.dll'),
    ];
    for (const p of candidates) {
        const resolved = path.resolve(p);
        if (fs.existsSync(resolved))
            return resolved;
    }
    return null;
}
