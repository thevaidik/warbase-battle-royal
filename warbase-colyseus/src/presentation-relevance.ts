import { StateView } from '@colyseus/schema';
import { PlayerState, PRESENTATION_VIEW_TAG } from './schema.js';

// All gameplay transforms, health, teams and objectives stay public. Only
// cosmetic fields outside every weapon's range use distance-based visibility.
export const PRESENTATION_ENTER_METERS = 240;
export const PRESENTATION_EXIT_METERS = 280;
export function presentationRelevant(observer: PlayerState, target: PlayerState, alreadyVisible: boolean): boolean {
  if (observer === target) return true;
  const radius = alreadyVisible ? PRESENTATION_EXIT_METERS : PRESENTATION_ENTER_METERS;
  const dx = observer.x - target.x, dy = observer.y - target.y, dz = observer.z - target.z;
  return dx * dx + dy * dy + dz * dz <= radius * radius;
}
export function updatePresentationView(view: StateView, observer: PlayerState, players: Iterable<PlayerState>, visible: Set<PlayerState>): void {
  const live = new Set(players);
  for (const target of live) {
    const previous = visible.has(target);
    const relevant = presentationRelevant(observer, target, previous);
    if (relevant && !previous) { view.add(target, PRESENTATION_VIEW_TAG); visible.add(target); }
    else if (!relevant && previous) { view.remove(target, PRESENTATION_VIEW_TAG); visible.delete(target); }
  }
  for (const target of visible) if (!live.has(target)) { view.remove(target, PRESENTATION_VIEW_TAG); visible.delete(target); }
}
