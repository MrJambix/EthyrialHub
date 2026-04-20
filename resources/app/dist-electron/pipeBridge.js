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
exports.PipeBridge = void 0;
const net = __importStar(require("net"));
const events_1 = require("events");
/**
 * Port of DeriveFullPipeName from EthyTool's pipe_names.h.
 * Must produce identical output to the C++ version so both sides agree.
 * Result: \\.\pipe\<8-hex-chars>_<pid>
 */
function derivePipeName(pid, channel) {
    let hash = (pid ^ 0xA7B3C1D9) >>> 0; // unsigned 32-bit
    for (let i = 0; i < channel.length; i++) {
        hash = (Math.imul(hash, 31) + channel.charCodeAt(i)) >>> 0;
    }
    hash = (hash ^ (hash >>> 16)) >>> 0;
    hash = Math.imul(hash, 0x45d9f3b) >>> 0;
    hash = (hash ^ (hash >>> 16)) >>> 0;
    const hex = hash.toString(16).toUpperCase().padStart(8, '0');
    return `\\\\.\\pipe\\${hex}_${pid}`;
}
class PipeBridge extends events_1.EventEmitter {
    constructor() {
        super(...arguments);
        this.cmdSocket = null;
        this.eventSocket = null;
        this.statusSocket = null;
        this._connected = false;
        this._gamePid = 0;
        this.pendingResolve = null;
        this.pendingReject = null;
        this.pendingTimeout = null;
        this.cmdQueue = [];
        this.cmdBusy = false;
        this.cmdBuffer = '';
        this.eventBuffer = '';
        this.statusBuffer = '';
        this.reconnectTimer = null;
        this.keepaliveTimer = null;
        this._autoReconnect = false;
        this._emittedDisconnect = false;
        this._reconnectAttempt = 0;
        this._lastError = '';
    }
    get connected() { return this._connected; }
    get gamePid() { return this._gamePid; }
    async connect(gamePid) {
        if (gamePid)
            this._gamePid = gamePid;
        if (!this._gamePid)
            return false;
        const PIPE_CMD = derivePipeName(this._gamePid, 'cmd');
        const PIPE_EVENT = derivePipeName(this._gamePid, 'ev');
        const PIPE_STATUS = derivePipeName(this._gamePid, 'st');
        // Cancel any pending reconnect timer to avoid interference
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        // Clean up sockets without touching _autoReconnect
        this.cleanupSockets();
        this._emittedDisconnect = false;
        return new Promise((resolve) => {
            let resolved = false;
            const done = (value) => {
                if (resolved)
                    return;
                resolved = true;
                resolve(value);
            };
            try {
                this.cmdSocket = net.connect(PIPE_CMD);
                const timeout = setTimeout(() => {
                    if (!this._connected) {
                        this.cmdSocket?.destroy();
                        this.cmdSocket = null;
                        done(false);
                        this.scheduleReconnect();
                    }
                }, 3000);
                this.cmdSocket.on('connect', () => {
                    clearTimeout(timeout);
                    this._connected = true;
                    this._emittedDisconnect = false;
                    this._reconnectAttempt = 0;
                    this._lastError = '';
                    this.startKeepalive();
                    this.emit('connected');
                    this.connectEventPipe();
                    this.connectStatusPipe();
                    done(true);
                });
                this.cmdSocket.on('data', (data) => {
                    this.cmdBuffer += data.toString();
                    let idx;
                    while ((idx = this.cmdBuffer.indexOf('\n')) >= 0) {
                        const line = this.cmdBuffer.substring(0, idx);
                        this.cmdBuffer = this.cmdBuffer.substring(idx + 1);
                        if (this.pendingResolve) {
                            const r = this.pendingResolve;
                            this.pendingResolve = null;
                            this.pendingReject = null;
                            if (this.pendingTimeout) {
                                clearTimeout(this.pendingTimeout);
                                this.pendingTimeout = null;
                            }
                            this.cmdBusy = false;
                            r(line);
                            this.drainQueue();
                        }
                    }
                });
                this.cmdSocket.on('error', (err) => {
                    clearTimeout(timeout);
                    this._lastError = err.message || 'unknown';
                    this.emit('pipe-error', this._lastError);
                    // Don't emit disconnect here — let 'close' handle it (close always fires after error)
                });
                this.cmdSocket.on('close', (hadError) => {
                    const wasConnected = this._connected;
                    this._connected = false;
                    this.cmdSocket = null;
                    this.cmdBusy = false;
                    this.stopKeepalive();
                    if (wasConnected) {
                        this.emit('pipe-error', `pipe closed (hadError=${hadError}, lastErr=${this._lastError})`);
                    }
                    if (this.pendingTimeout) {
                        clearTimeout(this.pendingTimeout);
                        this.pendingTimeout = null;
                    }
                    if (this.pendingReject) {
                        this.pendingReject(new Error('Pipe closed'));
                        this.pendingResolve = null;
                        this.pendingReject = null;
                    }
                    // Reject all queued commands
                    for (const q of this.cmdQueue)
                        q.reject(new Error('Pipe closed'));
                    this.cmdQueue = [];
                    // Resolve the connect() promise if it hasn't been resolved yet
                    // (error fired before timeout, so timeout was cleared and never resolved)
                    done(false);
                    if (wasConnected && !this._emittedDisconnect) {
                        // Don't immediately tell the UI we're disconnected — enter
                        // grace period and try fast reconnects first.
                        if (this._autoReconnect) {
                            this.emit('reconnecting', this._reconnectAttempt);
                            this.scheduleReconnect();
                        }
                        else {
                            this._emittedDisconnect = true;
                            this.emit('disconnected');
                        }
                    }
                    else if (this._autoReconnect) {
                        this.scheduleReconnect();
                    }
                });
            }
            catch {
                done(false);
                this.scheduleReconnect();
            }
        });
    }
    connectEventPipe() {
        if (!this._gamePid)
            return;
        const PIPE_EVENT = derivePipeName(this._gamePid, 'ev');
        try {
            this.eventSocket = net.connect(PIPE_EVENT);
            this.eventSocket.on('data', (data) => {
                this.eventBuffer += data.toString();
                let idx;
                while ((idx = this.eventBuffer.indexOf('\n')) >= 0) {
                    const line = this.eventBuffer.substring(0, idx);
                    this.eventBuffer = this.eventBuffer.substring(idx + 1);
                    if (line.trim())
                        this.emit('event', line);
                }
            });
            this.eventSocket.on('error', () => { });
            this.eventSocket.on('close', () => { this.eventSocket = null; });
        }
        catch { }
    }
    connectStatusPipe() {
        if (!this._gamePid)
            return;
        const PIPE_STATUS = derivePipeName(this._gamePid, 'st');
        try {
            this.statusSocket = net.connect(PIPE_STATUS);
            this.statusSocket.on('data', (data) => {
                this.statusBuffer += data.toString();
                let idx;
                while ((idx = this.statusBuffer.indexOf('\n')) >= 0) {
                    const line = this.statusBuffer.substring(0, idx);
                    this.statusBuffer = this.statusBuffer.substring(idx + 1);
                    if (line.trim())
                        this.emit('status', line);
                }
            });
            this.statusSocket.on('error', () => { });
            this.statusSocket.on('close', () => { this.statusSocket = null; });
        }
        catch { }
    }
    async sendCommand(cmd) {
        return new Promise((resolve, reject) => {
            if (!this.cmdSocket || !this._connected) {
                reject(new Error('Not connected'));
                return;
            }
            this.cmdQueue.push({ cmd, resolve, reject });
            this.drainQueue();
        });
    }
    drainQueue() {
        if (this.cmdBusy)
            return;
        const next = this.cmdQueue.shift();
        if (!next)
            return;
        if (!this.cmdSocket || !this._connected) {
            next.reject(new Error('Not connected'));
            this.drainQueue();
            return;
        }
        if (!this.cmdSocket.writable) {
            next.reject(new Error('Socket not writable'));
            this.cmdBusy = false;
            this.drainQueue();
            return;
        }
        this.cmdBusy = true;
        this.pendingResolve = next.resolve;
        this.pendingReject = next.reject;
        this.cmdSocket.write(next.cmd + '\n');
        this.pendingTimeout = setTimeout(() => {
            if (this.pendingResolve === next.resolve) {
                this.pendingResolve = null;
                this.pendingReject = null;
                this.pendingTimeout = null;
                this.cmdBusy = false;
                next.reject(new Error('Command timeout'));
                this.drainQueue();
            }
        }, 5000);
    }
    startKeepalive() {
        this.stopKeepalive();
        // Send PING every 10s to detect dead pipes early and keep the
        // connection alive (some pipe implementations time-out idle clients).
        this.keepaliveTimer = setInterval(() => {
            if (!this.cmdSocket || !this._connected)
                return;
            // Only send keepalive when the command queue is idle — don't
            // interfere with real commands.
            if (this.cmdBusy)
                return;
            this.sendCommand('PING').catch(() => {
                // If PING fails, the error/close handlers will trigger reconnect.
            });
        }, 10000);
    }
    stopKeepalive() {
        if (this.keepaliveTimer) {
            clearInterval(this.keepaliveTimer);
            this.keepaliveTimer = null;
        }
    }
    disconnect() {
        this._autoReconnect = false;
        this.stopKeepalive();
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        if (this.pendingTimeout) {
            clearTimeout(this.pendingTimeout);
            this.pendingTimeout = null;
        }
        if (this.pendingReject) {
            this.pendingReject(new Error('Disconnected'));
            this.pendingResolve = null;
            this.pendingReject = null;
        }
        // Reject all queued commands
        for (const q of this.cmdQueue)
            q.reject(new Error('Disconnected'));
        this.cmdQueue = [];
        this.cmdBusy = false;
        this.cleanupSockets();
        if (this._connected) {
            this._connected = false;
            this.emit('disconnected');
        }
    }
    cleanupSockets() {
        this.cmdSocket?.removeAllListeners();
        this.eventSocket?.removeAllListeners();
        this.statusSocket?.removeAllListeners();
        this.cmdSocket?.destroy();
        this.eventSocket?.destroy();
        this.statusSocket?.destroy();
        this.cmdSocket = null;
        this.eventSocket = null;
        this.statusSocket = null;
        this.cmdBuffer = '';
        this.eventBuffer = '';
        this.statusBuffer = '';
    }
    enableAutoReconnect() {
        this._autoReconnect = true;
    }
    scheduleReconnect() {
        if (!this._autoReconnect)
            return;
        if (this.reconnectTimer)
            return;
        this._reconnectAttempt++;
        // After burst retries are exhausted, emit 'disconnected' once so the
        // UI can react, but keep trying at the slower interval.
        if (this._reconnectAttempt > PipeBridge.BURST_RETRIES && !this._emittedDisconnect) {
            this._emittedDisconnect = true;
            this.emit('disconnected');
        }
        // Unlimited retries (MAX_RETRIES === 0) — never give up.
        if (PipeBridge.MAX_RETRIES > 0 && this._reconnectAttempt > PipeBridge.MAX_RETRIES) {
            this._autoReconnect = false;
            return;
        }
        const delay = this._reconnectAttempt <= PipeBridge.BURST_RETRIES
            ? PipeBridge.BURST_INTERVAL
            : PipeBridge.SLOW_INTERVAL;
        this.reconnectTimer = setTimeout(async () => {
            this.reconnectTimer = null;
            if (this._autoReconnect) {
                const ok = await this.connect();
                // connect() internally calls scheduleReconnect on failure,
                // so we only need to handle the success path here:
                if (ok) {
                    this._reconnectAttempt = 0;
                }
            }
        }, delay);
    }
}
exports.PipeBridge = PipeBridge;
PipeBridge.BURST_RETRIES = 5; // fast retries before slowing down
PipeBridge.BURST_INTERVAL = 2000; // 2 s between burst retries
PipeBridge.SLOW_INTERVAL = 5000; // 5 s after burst exhausted
PipeBridge.MAX_RETRIES = 0; // 0 = unlimited
