/** Small, process-local fixed-window limits for the anonymous game server. */
export class FixedWindowLimiter {
  private readonly windows = new Map<string, { startedAt: number; count: number }>();

  constructor(private readonly maxKeys = 8192) {}

  allow(key: string, limit: number, windowMs: number, now = Date.now()): boolean {
    if (!key || !Number.isFinite(now) || limit < 1 || windowMs < 1) return false;
    let bucket = this.windows.get(key);
    if (!bucket || now < bucket.startedAt || now - bucket.startedAt >= windowMs) {
      this.windows.delete(key);
      bucket = { startedAt: now, count: 0 };
      this.windows.set(key, bucket);
    } else {
      // Refresh insertion order so bounded eviction drops the least recently used key.
      this.windows.delete(key);
      this.windows.set(key, bucket);
    }
    if (bucket.count >= limit) return false;
    bucket.count++;
    while (this.windows.size > this.maxKeys) this.windows.delete(this.windows.keys().next().value!);
    return true;
  }
}

export const anonymousJoinLimiter = new FixedWindowLimiter(8192);
export const gameMessageLimiter = new FixedWindowLimiter(131072);
export const roomCreationLimiter = new FixedWindowLimiter(8192);

/** Normalize and bound the public display name without relying on an account system. */
export function canonicalizeUsername(value: unknown): string | undefined {
  if (typeof value !== 'string' || value.length > 128) return;
  const name = value.normalize('NFKC').trim();
  const length = [...name].length;
  if (length < 1 || length > 24 || /[\p{Cc}\p{Cf}]/u.test(name)) return;
  if (!/^[\p{L}\p{M}\p{N}_ .'’-]+$/u.test(name)) return;
  if (name.toLowerCase().startsWith('[bot]')) return;
  return name;
}
