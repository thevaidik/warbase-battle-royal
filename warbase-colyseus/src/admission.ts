import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { BlockList, isIP } from 'node:net';
import type { Request, RequestHandler } from 'express';
import jwt from 'jsonwebtoken';
import { FixedWindowLimiter } from './abuse-protection.js';

const TOKEN_TTL_SECONDS = 15 * 60;
const ISSUE_WINDOW_MS = 60_000;
const PER_CALLER_ISSUE_LIMIT = 30;
const GLOBAL_ISSUE_LIMIT = 300;
const MAX_TRACKED_CALLERS = 4096;
const PLAYER_JOIN_LIMIT = 30;
const PLAYER_ROOM_CREATE_LIMIT = 4;

export interface AnonymousAdmissionClaims extends jwt.JwtPayload {
  sub: string;
  id: string;
  typ: 'warbase-anonymous-admission';
  ver: 1;
}

export interface AdmissionOptions {
  secret: string;
  gatewaySecret?: string;
  trustedProxyCidrs?: string[];
  now?: () => number;
  perCallerLimit?: number;
  globalLimit?: number;
  playerJoinLimit?: number;
  playerRoomCreateLimit?: number;
}

export interface AdmissionMetrics {
  issued: number;
  rateLimited: number;
  rejectedAttribution: number;
}

export interface BattleAdmissionControls {
  /** HTTP ticket issuer for mounting at POST /api/admission. */
  issueTicket: RequestHandler;
  metrics: AdmissionMetrics;
  /** Validate JWT and consume one per-player join allowance. */
  authorizeJoin(token: string): AnonymousAdmissionClaims | null;
  /** Validate JWT and consume one per-player room-create allowance. */
  authorizeRoomCreate(token: string): AnonymousAdmissionClaims | null;
  /** Bearer-token middleware for POST /api/rooms. */
  roomCreateMiddleware: RequestHandler;
}

let configuredBattleAdmission: BattleAdmissionControls | undefined;

/** Load the ticket signing key from a mounted secret file. */
export function loadAdmissionSecret(environment: NodeJS.ProcessEnv): string {
  const path = String(environment.ADMISSION_JWT_SECRET_FILE ?? '').trim();
  if (!path) throw new Error('ADMISSION_JWT_SECRET_FILE must point to a mounted admission-only secret.');
  const secret = readFileSync(path, 'utf8').trim();
  if (Buffer.byteLength(secret, 'utf8') < 32) throw new Error('Admission JWT secret must contain at least 32 bytes.');
  return secret;
}

/** Load the gateway-to-candidate attribution secret from its own mounted file. */
export function loadAdmissionGatewaySecret(environment: NodeJS.ProcessEnv): string {
  const path = String(environment.ADMISSION_GATEWAY_SECRET_FILE ?? '').trim();
  if (!path) throw new Error('ADMISSION_GATEWAY_SECRET_FILE must point to a mounted gateway-only attribution secret.');
  const secret = readFileSync(path, 'utf8').trim();
  if (Buffer.byteLength(secret, 'utf8') < 32) throw new Error('Admission gateway secret must contain at least 32 bytes.');
  return secret;
}

function normalizeAddress(address: string): string | null {
  const normalized = address.startsWith('::ffff:') ? address.slice('::ffff:'.length) : address;
  return isIP(normalized) ? normalized : null;
}

function makeProxyBlockList(cidrs: string[]): BlockList {
  const list = new BlockList();
  for (const raw of cidrs) {
    const [address, prefixText, extra] = raw.trim().split('/');
    const normalized = normalizeAddress(address);
    if (extra !== undefined || !normalized) throw new Error(`Invalid admission trusted proxy CIDR: ${raw}`);
    const family = isIP(normalized) === 4 ? 'ipv4' : 'ipv6';
    const prefix = prefixText === undefined ? (family === 'ipv4' ? 32 : 128) : Number(prefixText);
    const max = family === 'ipv4' ? 32 : 128;
    if (!Number.isInteger(prefix) || prefix < 0 || prefix > max) throw new Error(`Invalid admission trusted proxy CIDR: ${raw}`);
    list.addSubnet(normalized, prefix, family);
  }
  return list;
}

/**
 * Resolve caller identity without trusting Express's global trust-proxy setting.
 * X-Forwarded-For is accepted only from an explicitly configured immediate peer;
 * the gateway must replace it with exactly one address.
 */
export function resolveAdmissionCaller(request: Request, trustedProxyCidrs: string[] = [], gatewaySecret?: string): string | null {
  const peer = normalizeAddress(request.socket.remoteAddress ?? '');
  if (!peer) return null;
  if (trustedProxyCidrs.length === 0) return peer;
  const proxies = makeProxyBlockList(trustedProxyCidrs);
  const family = isIP(peer) === 4 ? 'ipv4' : 'ipv6';
  if (!proxies.check(peer, family)) return peer;
  if (!gatewaySecret) return null;
  const suppliedGatewaySecret = request.header('x-warbase-gateway-token') ?? '';
  const expectedDigest = createHash('sha256').update(gatewaySecret).digest();
  const suppliedDigest = createHash('sha256').update(suppliedGatewaySecret).digest();
  if (!timingSafeEqual(suppliedDigest, expectedDigest)) return null;
  const forwarded = request.header('x-forwarded-for');
  if (!forwarded || forwarded.includes(',')) return null;
  return normalizeAddress(forwarded.trim());
}

export function signAnonymousAdmissionToken(secret: string, nowMs = Date.now()): { token: string; playerId: string; expiresIn: number } {
  if (Buffer.byteLength(secret, 'utf8') < 32) throw new Error('Admission JWT secret must contain at least 32 bytes.');
  const playerId = randomUUID();
  const nowSeconds = Math.floor(nowMs / 1000);
  const claims: AnonymousAdmissionClaims = {
    sub: playerId,
    id: playerId,
    typ: 'warbase-anonymous-admission',
    ver: 1,
    iat: nowSeconds,
    exp: nowSeconds + TOKEN_TTL_SECONDS,
    iss: 'warbase-admission',
    aud: 'warbase-game',
  };
  return { token: jwt.sign(claims, secret, { algorithm: 'HS256' }), playerId, expiresIn: TOKEN_TTL_SECONDS };
}

export function verifyAnonymousAdmissionToken(token: string, secret: string, nowMs = Date.now()): AnonymousAdmissionClaims | null {
  try {
    const payload = jwt.verify(token, secret, {
      algorithms: ['HS256'], issuer: 'warbase-admission', audience: 'warbase-game',
      clockTimestamp: Math.floor(nowMs / 1000),
    });
    if (typeof payload === 'string' || payload.typ !== 'warbase-anonymous-admission' || payload.ver !== 1 ||
        typeof payload.sub !== 'string' || payload.id !== payload.sub) return null;
    // Keep only the identity claims owned by this issuer. In particular, never
    // propagate a client/display username claim as authenticated identity.
    return {
      sub: payload.sub,
      id: payload.sub,
      typ: 'warbase-anonymous-admission',
      ver: 1,
      iat: payload.iat,
      exp: payload.exp,
      iss: 'warbase-admission',
      aud: 'warbase-game',
    };
  } catch {
    return null;
  }
}

export function createAdmissionIssuer(options: AdmissionOptions): {
  handler: RequestHandler;
  metrics: AdmissionMetrics;
} {
  if (Buffer.byteLength(options.secret, 'utf8') < 32) throw new Error('Admission JWT secret must contain at least 32 bytes.');
  if (options.gatewaySecret && Buffer.byteLength(options.gatewaySecret, 'utf8') < 32) throw new Error('Admission gateway secret must contain at least 32 bytes.');
  const trustedProxyCidrs = [...(options.trustedProxyCidrs ?? [])];
  // Validate configured proxy ranges during startup rather than on the first request.
  makeProxyBlockList(trustedProxyCidrs);
  const perCallerLimit = options.perCallerLimit ?? PER_CALLER_ISSUE_LIMIT;
  const globalLimit = options.globalLimit ?? GLOBAL_ISSUE_LIMIT;
  const now = options.now ?? Date.now;
  const windows = new Map<string, { startedAt: number; count: number }>();
  let globalWindow = { startedAt: 0, count: 0 };
  const metrics: AdmissionMetrics = { issued: 0, rateLimited: 0, rejectedAttribution: 0 };

  const handler: RequestHandler = (request, response) => {
    const caller = resolveAdmissionCaller(request, trustedProxyCidrs, options.gatewaySecret);
    if (!caller) {
      metrics.rejectedAttribution++;
      response.status(503).json({ error: 'caller_attribution_unavailable' });
      return;
    }
    const current = now();
    if (current - globalWindow.startedAt >= ISSUE_WINDOW_MS || current < globalWindow.startedAt) globalWindow = { startedAt: current, count: 0 };
    let callerWindow = windows.get(caller);
    if (!callerWindow || current - callerWindow.startedAt >= ISSUE_WINDOW_MS || current < callerWindow.startedAt) {
      // Bound memory under address churn; expired entries are removed first.
      for (const [address, window] of windows) if (current - window.startedAt >= ISSUE_WINDOW_MS || current < window.startedAt) windows.delete(address);
      if (windows.size >= MAX_TRACKED_CALLERS) {
        const oldest = windows.keys().next().value as string | undefined;
        if (oldest) windows.delete(oldest);
      }
      callerWindow = { startedAt: current, count: 0 };
      windows.set(caller, callerWindow);
    }
    if (globalWindow.count >= globalLimit || callerWindow.count >= perCallerLimit) {
      metrics.rateLimited++;
      response.setHeader('Retry-After', '60');
      response.status(429).json({ error: 'admission_rate_limited' });
      return;
    }
    globalWindow.count++;
    callerWindow.count++;
    metrics.issued++;
    response.setHeader('Cache-Control', 'no-store');
    response.status(200).json(signAnonymousAdmissionToken(options.secret, current));
  };
  return { handler, metrics };
}

/**
 * Build the endpoint, room-create guard, and signed-player join checks from one
 * isolated admission key. This deliberately does not use @colyseus/auth's
 * process-global JWT.settings.secret, which may belong to the separate admin.
 */
export function createBattleAdmissionControls(options: AdmissionOptions): BattleAdmissionControls {
  const issuer = createAdmissionIssuer(options);
  const joinLimiter = new FixedWindowLimiter(32_768);
  const roomCreateLimiter = new FixedWindowLimiter(32_768);
  const now = options.now ?? Date.now;
  const verify = (token: string) => verifyAnonymousAdmissionToken(token, options.secret, now());
  const authorizeJoin = (token: string): AnonymousAdmissionClaims | null => {
    const claims = verify(token);
    if (!claims || !joinLimiter.allow(claims.id, options.playerJoinLimit ?? PLAYER_JOIN_LIMIT, 60_000, now())) return null;
    return claims;
  };
  const authorizeRoomCreate = (token: string): AnonymousAdmissionClaims | null => {
    const claims = verify(token);
    if (!claims || !roomCreateLimiter.allow(claims.id, options.playerRoomCreateLimit ?? PLAYER_ROOM_CREATE_LIMIT, 60_000, now())) return null;
    return claims;
  };
  const roomCreateMiddleware: RequestHandler = (request, response, next) => {
    const authorization = request.header('authorization') ?? '';
    const match = /^Bearer ([A-Za-z0-9._~-]+)$/i.exec(authorization);
    const claims = match ? verify(match[1]) : null;
    if (!claims) {
      response.status(401).json({ error: 'valid_admission_required' });
      return;
    }
    if (!roomCreateLimiter.allow(claims.id, options.playerRoomCreateLimit ?? PLAYER_ROOM_CREATE_LIMIT, 60_000, now())) {
      response.setHeader('Retry-After', '60');
      response.status(429).json({ error: 'room_creation_rate_limited' });
      return;
    }
    response.locals.admission = claims;
    response.locals.anonymousPlayerId = claims.id;
    next();
  };
  return {
    issueTicket: issuer.handler,
    metrics: issuer.metrics,
    authorizeJoin,
    authorizeRoomCreate,
    roomCreateMiddleware,
  };
}

/** Configure the controls used by BattleRoom's static matchmaker admission hook. */
export function configureBattleAdmission(options?: AdmissionOptions): BattleAdmissionControls | undefined {
  configuredBattleAdmission = options ? createBattleAdmissionControls(options) : undefined;
  return configuredBattleAdmission;
}

export function getConfiguredBattleAdmission(): BattleAdmissionControls | undefined {
  return configuredBattleAdmission;
}
