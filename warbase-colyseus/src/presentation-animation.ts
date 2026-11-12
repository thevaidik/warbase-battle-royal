/** Lightweight presentation clip tags shared by the room and legacy hitbox rewind tooling. */
export const REWIND_ANIMATION_CLIPS = ['idle', 'run', 'firing', 'firing walk', 'jump'] as const;

export function animationCodeForClip(animation: string): number {
  const index = REWIND_ANIMATION_CLIPS.indexOf(animation as (typeof REWIND_ANIMATION_CLIPS)[number]);
  return index < 0 ? 0 : index;
}

export function clipForAnimationCode(code: number): (typeof REWIND_ANIMATION_CLIPS)[number] {
  return REWIND_ANIMATION_CLIPS[Math.trunc(code)] ?? 'idle';
}
