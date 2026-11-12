import { LobbyRoom, ServerError, type AuthContext, type RegisteredHandler } from '@colyseus/core';
import type { Server } from 'colyseus';
import { getConfiguredBattleAdmission } from './admission.js';

/** Lobby subscriptions use the same signed anonymous issuer as combat. */
export class AuthenticatedLobbyRoom extends LobbyRoom {
  static async onAuth(token: string, _options: unknown, _context: AuthContext) {
    const admission = getConfiguredBattleAdmission();
    if (!admission) return true; // Isolated/local unsigned fixtures only.
    const claims = admission.authorizeJoin(token);
    if (!claims) throw new ServerError(401, 'valid_admission_required');
    return { id: claims.id, sub: claims.sub };
  }
}

/** Register the official Colyseus realtime lobby and enable battle listings. */
export function configureRealtimeLobby(server: Server, battle: RegisteredHandler): void {
  battle.enableRealtimeListing();
  server.define('lobby', AuthenticatedLobbyRoom);
}
