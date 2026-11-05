export type ConquestObjective = { id: string; x: number; y: number; z: number; radius: number; owner: '' | 'A' | 'B'; capturing_team: '' | 'A' | 'B'; progress: number; contested: boolean };
export type ConquestPlayer = { x: number; y: number; z: number; team: string; is_dead: boolean; driving_vehicle?: string };
export type ConquestState = { objectives: ConquestObjective[]; ticketsA: number; ticketsB: number; roomState: 'active' | 'finished'; winner: string; bleedMs: number; bleedDirection: number };
export const CONQUEST_CAPTURE_RADIUS = 12;
export const CONQUEST_CAPTURE_MS = 12_000;
export const CONQUEST_TICKET_START = 500;

export function createConquestState(spawns: readonly (readonly number[])[]): ConquestState {
  if (spawns.length < 4) throw new Error('Conquest requires at least four valid map spawns');
  const valid = spawns.filter((point) => point.length >= 3 && point.slice(0, 3).every(Number.isFinite));
  if (valid.length < 4) throw new Error('Conquest requires at least four valid map spawns');
  const centroid = [0, 1, 2].map((axis) => valid.reduce((sum, point) => sum + point[axis], 0) / valid.length);
  const distanceSq = (a: readonly number[], b: readonly number[]) => (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2;
  const chosen: (readonly number[])[] = [valid.reduce((best, point) => distanceSq(point, centroid) < distanceSq(best, centroid) ? point : best, valid[0])];
  while (chosen.length < 4) {
    const remaining = valid.filter((point) => !chosen.includes(point));
    const next = remaining.reduce((best, point) => Math.min(...chosen.map((selected) => distanceSq(point, selected))) > Math.min(...chosen.map((selected) => distanceSq(best, selected))) ? point : best, remaining[0]);
    chosen.push(next);
  }
  if (new Set(chosen.map((point) => point.join(','))).size < 4) throw new Error('Conquest requires four distinct map spawns');
  return { objectives: chosen.map((p, index) => {
    const nearest = Math.sqrt(Math.min(...chosen.filter((other) => other !== p).map((other) => distanceSq(p, other))));
    return { id: String.fromCharCode(65 + index), x: p[0], y: p[1], z: p[2], radius: Math.min(CONQUEST_CAPTURE_RADIUS, nearest * 0.4), owner: '', capturing_team: '', progress: 0, contested: false };
  }), ticketsA: CONQUEST_TICKET_START, ticketsB: CONQUEST_TICKET_START, roomState: 'active', winner: '', bleedMs: 0, bleedDirection: 0 };
}

export function stepConquest(state: ConquestState, players: Iterable<ConquestPlayer>, dtSeconds: number): void {
  if (state.roomState !== 'active') return;
  const nearby = state.objectives.map((objective) => ({ A: 0, B: 0, objective }));
  for (const player of players) {
    if (player.is_dead || player.driving_vehicle || (player.team !== 'A' && player.team !== 'B')) continue;
    for (const item of nearby) {
      const dx = player.x - item.objective.x, dy = player.y - item.objective.y, dz = player.z - item.objective.z;
      if (dx * dx + dy * dy + dz * dz <= item.objective.radius ** 2) item[player.team as 'A' | 'B']++;
    }
  }
  for (const { objective, A, B } of nearby) {
    objective.contested = A > 0 && B > 0;
    const team: '' | 'A' | 'B' = A === B ? '' : A > B ? 'A' : 'B';
    if (objective.contested || !team) continue;
    if (team === objective.owner) { objective.capturing_team = ''; objective.progress = 0; continue; }
    if (objective.capturing_team !== team) { objective.capturing_team = team; objective.progress = 0; }
    objective.progress = Math.min(1, objective.progress + Math.max(0, dtSeconds) * 1000 / CONQUEST_CAPTURE_MS);
    if (objective.progress >= 1) {
      if (objective.owner && objective.owner !== team) { objective.owner = ''; objective.progress = 0; }
      else { objective.owner = team; objective.capturing_team = ''; objective.progress = 0; }
    }
  }
  const ownedA = state.objectives.filter((o) => o.owner === 'A').length, ownedB = state.objectives.filter((o) => o.owner === 'B').length;
  const advantage = ownedA - ownedB;
  const direction = Math.sign(advantage);
  if (direction !== state.bleedDirection) state.bleedMs = 0;
  state.bleedDirection = direction;
  state.bleedMs += Math.max(0, dtSeconds) * 1000 * Math.abs(advantage);
  while (state.bleedMs >= 5000 && advantage !== 0) {
    state.bleedMs -= 5000;
    if (advantage > 0) state.ticketsB = Math.max(0, state.ticketsB - 1);
    else state.ticketsA = Math.max(0, state.ticketsA - 1);
  }
  if (state.ticketsA === 0 || state.ticketsB === 0) { state.roomState = 'finished'; state.winner = state.ticketsA === state.ticketsB ? '' : state.ticketsA > state.ticketsB ? 'A' : 'B'; }
}

export function awardConquestKill(state: ConquestState, team: string): void {
  if (state.roomState !== 'active' || (team !== 'A' && team !== 'B')) return;
  if (team === 'A') state.ticketsB = Math.max(0, state.ticketsB - 1); else state.ticketsA = Math.max(0, state.ticketsA - 1);
  if (state.ticketsA === 0 || state.ticketsB === 0) { state.roomState = 'finished'; state.winner = state.ticketsA === state.ticketsB ? '' : state.ticketsA > state.ticketsB ? 'A' : 'B'; }
}
