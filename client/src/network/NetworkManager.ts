import { Vector3, Quaternion } from "@babylonjs/core";
import { warbase } from "./packets";

export interface PlayerState {
    id: string;
    x: number;
    y: number;
    z: number;
    rx: number;
    ry: number;
    rz: number;
    rw: number;
    anim: string;
    health: number;
    kills: number;
    deaths: number;
    isDead: boolean;
    platformId?: string;
    ping: number;
    weaponId?: string;
    team: string;
}

export interface GameStateData {
    players: Record<string, PlayerState>;
    roomMode: string;
    roomState: string;
    scoreTeamA: number;
    scoreTeamB: number;
    winnerId: string;
}

export class NetworkManager {
    private ws!: WebSocket;
    public username: string;
    public room: string;
    public onStateReceived: (state: GameStateData) => void = () => {};
    public onHitConfirmed: () => void = () => {};
    public onKillConfirmed: () => void = () => {};
    public onRespawn: (x: number, y: number, z: number) => void = () => {};
    public onFireReceived: (
        shooterId: string, 
        originX?: number, originY?: number, originZ?: number, 
        hitX?: number, hitY?: number, hitZ?: number, 
        normalX?: number, normalY?: number, normalZ?: number, 
        hitWall?: boolean
    ) => void = () => {};
    public onGrenadeReceived: (shooterId: string, px: number, py: number, pz: number, vx: number, vy: number, vz: number) => void = () => {};

    private onConnectCb: () => void;
    private onConnectionFailedCb?: () => void;
    private hasConnectedOnce = false;
    private reconnectAttempts = 0;
    private pingInterval: number | null = null;
    public currentPing: number = 0;
    
    constructor(username: string, room: string, onConnect: () => void, onConnectionFailed?: () => void) {
        this.username = username;
        this.room = room;
        this.onConnectCb = onConnect;
        this.onConnectionFailedCb = onConnectionFailed;
        this.connect();
    }

    private connect() {
        // Connect dynamically based on where the game is hosted
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const cid = sessionStorage.getItem('warbase_client_id') || '';
        this.ws = new WebSocket(`${protocol}//${window.location.host}/connect?user=${this.username}&room=${this.room}&cid=${cid}`);
        this.ws.binaryType = 'arraybuffer';

        this.ws.onopen = () => {
            console.log("WebSocket Connected!");
            this.hasConnectedOnce = true;
            this.reconnectAttempts = 0;
            const reconnectOverlay = document.getElementById("reconnectOverlay");
            if (reconnectOverlay) reconnectOverlay.style.display = "none";
            
            // Start Ping Loop
            if (this.pingInterval) clearInterval(this.pingInterval);
            this.pingInterval = window.setInterval(() => {
                if (this.ws.readyState === WebSocket.OPEN) {
                    const pingMsg = warbase.ClientEvent.create({
                        ping: { clientTime: Date.now() }
                    });
                    const buffer = warbase.ClientEvent.encode(pingMsg).finish();
                    this.ws.send(buffer as BufferSource);
                }
            }, 1000);

            this.onConnectCb();
        };

        this.ws.onerror = (e) => {
            console.error("WebSocket Error:", e);
        };

        this.ws.onclose = (e) => {
            console.warn("WebSocket Closed:", e);
            if (!this.hasConnectedOnce && this.onConnectionFailedCb) {
                this.onConnectionFailedCb();
                return;
            }

            const backoff = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 10000);
            this.reconnectAttempts++;
            
            const reconnectOverlay = document.getElementById("reconnectOverlay");
            const reconnectText = document.getElementById("reconnectText");
            if (reconnectOverlay) reconnectOverlay.style.display = "flex";
            if (reconnectText) reconnectText.innerText = `Attempting to reconnect in ${backoff / 1000}s... (Attempt ${this.reconnectAttempts})`;
            
            if (this.pingInterval) {
                clearInterval(this.pingInterval);
                this.pingInterval = null;
            }

            console.log(`Reconnecting in ${backoff}ms... (Attempt ${this.reconnectAttempts})`);
            setTimeout(() => this.connect(), backoff);
        };

        this.ws.onmessage = (event) => {
            try {
                const data = new Uint8Array(event.data as ArrayBuffer);
                const serverMsg = warbase.ServerMessage.decode(data);
                
                if (serverMsg.message === "gameState" && serverMsg.gameState) {
                    const state: Record<string, PlayerState> = {};
                    for (const id in serverMsg.gameState.players) {
                        const p = serverMsg.gameState.players[id]!;
                        state[id] = {
                            id,
                            x: p.x ?? 0,
                            y: p.y ?? 0,
                            z: p.z ?? 0,
                            rx: p.rx ?? 0,
                            ry: p.ry ?? 0,
                            rz: p.rz ?? 0,
                            rw: p.rw ?? 1,
                            anim: p.animation ?? "",
                            health: p.health ?? 0,
                            kills: p.kills ?? 0,
                            deaths: p.deaths ?? 0,
                            isDead: p.isDead ?? false,
                            platformId: p.platformId ?? undefined,
                            ping: p.ping ?? 0,
                            weaponId: p.weaponId ?? undefined,
                            team: p.team ?? ""
                        };
                    }
                    this.onStateReceived({
                        players: state,
                        roomMode: serverMsg.gameState.roomMode ?? "FFA",
                        roomState: serverMsg.gameState.roomState ?? "PLAYING",
                        scoreTeamA: serverMsg.gameState.scoreTeamA ?? 0,
                        scoreTeamB: serverMsg.gameState.scoreTeamB ?? 0,
                        winnerId: serverMsg.gameState.winnerId ?? ""
                    });
                } else if (serverMsg.message === "serverEvent" && serverMsg.serverEvent) {
                    const evt = serverMsg.serverEvent;
                    if (evt.event === "respawn" && evt.respawn) {
                        this.onRespawn(evt.respawn.x ?? 0, evt.respawn.y ?? 0, evt.respawn.z ?? 0);
                    } else if (evt.event === "fire" && evt.fire) {
                        this.onFireReceived(
                            evt.fire.shooterId ?? "",
                            evt.fire.originX ?? 0,
                            evt.fire.originY ?? 0,
                            evt.fire.originZ ?? 0,
                            evt.fire.hitX ?? 0,
                            evt.fire.hitY ?? 0,
                            evt.fire.hitZ ?? 0,
                            evt.fire.normalX ?? 0,
                            evt.fire.normalY ?? 0,
                            evt.fire.normalZ ?? 0,
                            evt.fire.hitWall ?? false
                        );
                    } else if (evt.event === "hitConfirmed") {
                        this.onHitConfirmed();
                    } else if (evt.event === "killConfirmed") {
                        this.onKillConfirmed();
                    } else if (evt.event === "throwGrenade" && evt.throwGrenade) {
                        this.onGrenadeReceived(
                            evt.throwGrenade.shooterId ?? "",
                            evt.throwGrenade.px ?? 0,
                            evt.throwGrenade.py ?? 0,
                            evt.throwGrenade.pz ?? 0,
                            evt.throwGrenade.vx ?? 0,
                            evt.throwGrenade.vy ?? 0,
                            evt.throwGrenade.vz ?? 0
                        );
                    } else if (evt.pong) {
                        const rtt = Date.now() - Number(evt.pong.clientTime);
                        this.currentPing = rtt;
                    }
                }
            } catch (e) {
                console.error("Error parsing game state:", e);
            }
        };
    }

    public sendFire(origin?: Vector3, hit?: Vector3, normal?: Vector3, hitWall?: boolean) {
        if (this.ws.readyState !== WebSocket.OPEN) return;
        const clientEvent = warbase.ClientEvent.create({
            event: "fire",
            fire: {
                originX: origin ? origin.x : 0,
                originY: origin ? origin.y : 0,
                originZ: origin ? origin.z : 0,
                hitX: hit ? hit.x : 0,
                hitY: hit ? hit.y : 0,
                hitZ: hit ? hit.z : 0,
                normalX: normal ? normal.x : 0,
                normalY: normal ? normal.y : 0,
                normalZ: normal ? normal.z : 0,
                hitWall: hitWall ?? false
            }
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public sendGrenade(pos: Vector3, vel: Vector3) {
        if (this.ws.readyState !== WebSocket.OPEN) return;
        const clientEvent = warbase.ClientEvent.create({
            event: "throwGrenade",
            throwGrenade: {
                px: pos.x, py: pos.y, pz: pos.z,
                vx: vel.x, vy: vel.y, vz: vel.z
            }
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public sendState(pos: Vector3, rot: Quaternion, anim: string, platformId?: string, weaponId?: string) {
        if (this.ws.readyState !== WebSocket.OPEN) return;

        // Prevent poisoned payloads from crashing/teleporting the server
        if (Number.isNaN(pos.x) || Number.isNaN(pos.y) || Number.isNaN(pos.z) || 
            Number.isNaN(rot.x) || Number.isNaN(rot.y) || Number.isNaN(rot.z) || Number.isNaN(rot.w)) {
            return;
        }

        const clientEvent = warbase.ClientEvent.create({
            event: "stateUpdate",
            stateUpdate: {
                x: pos.x,
                y: pos.y,
                z: pos.z,
                rx: rot.x,
                ry: rot.y,
                rz: rot.z,
                rw: rot.w,
                animation: anim,
                platformId: platformId,
                ping: this.currentPing,
                weaponId: weaponId
            }
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public sendHit(targetId: string, damage: number) {
        if (this.ws.readyState !== WebSocket.OPEN) return;

        const clientEvent = warbase.ClientEvent.create({
            event: "hit",
            hit: {
                targetId,
                damage
            }
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public sendReload() {
        if (this.ws.readyState !== WebSocket.OPEN) return;
        const clientEvent = warbase.ClientEvent.create({
            event: "reload",
            reload: {}
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public sendSwitchWeapon(weaponId: string) {
        if (this.ws.readyState !== WebSocket.OPEN) return;
        const clientEvent = warbase.ClientEvent.create({
            event: "switchWeapon",
            switchWeapon: {
                weaponId
            }
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public sendRespawnRequest() {
        if (this.ws.readyState !== WebSocket.OPEN) return;
        const clientEvent = warbase.ClientEvent.create({
            event: "respawnRequest",
            respawnRequest: {}
        });
        const buffer = warbase.ClientEvent.encode(clientEvent).finish();
        this.ws.send(buffer as BufferSource);
    }

    public disconnect() {
        if (this.pingInterval) {
            clearInterval(this.pingInterval);
            this.pingInterval = null;
        }
        if (this.ws) {
            this.ws.onclose = null; // Prevent reconnect attempts
            this.ws.onerror = null;
            this.ws.onmessage = null;
            this.ws.close();
        }
    }
}
