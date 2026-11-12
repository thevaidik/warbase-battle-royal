import { randomUUID } from 'node:crypto';
import { QueueRoom, ServerError, type AuthContext, type Client, type QueueOptions } from '@colyseus/core';
import { createRoom } from '@colyseus/core/MatchMaker';
import { canonicalizeUsername } from './abuse-protection.js';
import { getConfiguredBattleAdmission } from './admission.js';
import { GAME_PROTOCOL_VERSION } from './schema.js';
import { normalizeMapId } from './world-geometry.js';

type QueueAuth = { id: string; sub: string; username: string; queueTeam?: 'A' | 'B' };
type JoinOptions = { username?: unknown; map?: unknown; protocol_version?: unknown };

export class ConquestQueue extends QueueRoom {
  static async onAuth(token: string, options: JoinOptions, _context: AuthContext): Promise<QueueAuth> {
    if (options?.protocol_version !== GAME_PROTOCOL_VERSION) throw new ServerError(409, 'Game update required.');
    const admission = getConfiguredBattleAdmission()?.authorizeJoin(token);
    const username = canonicalizeUsername(options.username);
    if (!admission || !username || !normalizeMapId(options.map)) throw new ServerError(401, 'Queue admission denied.');
    return { id: admission.id, sub: admission.sub, username };
  }

  onCreate(options: QueueOptions & { map?: string }) {
    const map = normalizeMapId(options.map);
    if (!map) throw new ServerError(400, 'Select a playable map.');
    this.maxClients = 64;
    super.onCreate({
      matchRoomName: 'battle',
      maxPlayers: 4,
      maxWaitingCycles: 8,
      maxTeamSize: 2,
      allowIncompleteGroups: true,
      onGroupReady: async (group) => {
        group.clients.forEach((client, index) => {
          const auth = client.auth as QueueAuth;
          client.auth = { ...auth, queueTeam: index % 2 === 0 ? 'A' : 'B' };
        });
        return createRoom('battle', { room: `${map}-quick-${randomUUID()}`, map, mode: 'CONQUEST', name: 'Quick Conquest' });
      },
    });
  }

  onJoin(client: Client, _options: JoinOptions, auth?: QueueAuth) {
    if (!auth || this.clients.some(peer => peer !== client && (peer.auth?.id === auth.id || peer.auth?.username?.toLowerCase() === auth.username.toLowerCase()))) {
      throw new ServerError(409, 'This player is already queued.');
    }
    // Solo entrants are single-member teams. The queue owns grouping and the
    // reserved seat carries our authoritative side assignment to BattleRoom.
    super.onJoin(client, { rank: 100, teamId: auth.id, username: auth.username }, auth);
  }
}
