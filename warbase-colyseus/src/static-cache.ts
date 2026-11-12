/** HTML must revalidate even when the release manifest includes it. */
export function assetCacheControl(relative: string, manifestFiles: ReadonlySet<string>, mutableFiles: ReadonlySet<string>): string | undefined {
  if (relative.endsWith('.html') || mutableFiles.has(relative)) return 'no-cache';
  if (manifestFiles.has(relative)) return 'public, max-age=31536000, immutable';
  if (/\.(wasm|pck|dlink)$/.test(relative)) return 'public, max-age=300';
  if (relative.endsWith('.js')) return 'no-cache';
  return undefined;
}
