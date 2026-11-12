import assert from 'node:assert/strict';
import type { Request, Response } from 'express';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import {
  createAdmissionIssuer,
  createBattleAdmissionControls,
  resolveAdmissionCaller,
  signAnonymousAdmissionToken,
  verifyAnonymousAdmissionToken,
} from './admission.js';

const secret = 'admission test secret with more than thirty two bytes';

function request(remoteAddress: string, forwarded?: string, headers: Record<string, string> = {}): Request {
  return {
    socket: { remoteAddress },
    header: (name: string) => name.toLowerCase() === 'x-forwarded-for' ? forwarded : headers[name.toLowerCase()],
  } as unknown as Request;
}

function response() {
  const state: { statusCode: number; headers: Record<string, string>; body?: unknown; locals: Record<string, any> } = { statusCode: 200, headers: {}, locals: {} };
  const target = {
    setHeader(name: string, value: string) { state.headers[name.toLowerCase()] = value; return target; },
    status(code: number) { state.statusCode = code; return target; },
    json(body: unknown) { state.body = body; return target; },
    locals: state.locals,
  };
  return { state, target: target as unknown as Response };
}

test('direct clients cannot forge caller attribution with forwarded headers', () => {
  assert.equal(resolveAdmissionCaller(request('198.51.100.9', '203.0.113.7'), ['172.20.0.0/16']), '198.51.100.9');
});

test('trusted proxy attribution accepts one forwarded address and rejects chains', () => {
  const gatewaySecret = 'private gateway token with more than thirty two bytes';
  const trusted = ['172.20.0.0/16'];
  const signedHeaders = { 'x-warbase-gateway-token': gatewaySecret };
  assert.equal(resolveAdmissionCaller(request('172.20.0.5', '203.0.113.7', signedHeaders), trusted, gatewaySecret), '203.0.113.7');
  assert.equal(resolveAdmissionCaller(request('172.20.0.5', '203.0.113.7, 10.0.0.1', signedHeaders), trusted, gatewaySecret), null);
  assert.equal(resolveAdmissionCaller(request('172.20.0.5', 'garbage', signedHeaders), trusted, gatewaySecret), null);
  assert.equal(resolveAdmissionCaller(request('172.20.0.5', '203.0.113.7', { 'x-warbase-gateway-token': 'forged' }), trusted, gatewaySecret), null);
  assert.equal(resolveAdmissionCaller(request('172.20.0.5', '203.0.113.7', signedHeaders), trusted), null);
});

test('anonymous ticket is signed, stable within a token, and expires', () => {
  const { token, playerId, expiresIn } = signAnonymousAdmissionToken(secret, 1_000_000);
  const verified = verifyAnonymousAdmissionToken(token, secret, 1_000_000);
  assert.equal(verified?.id, playerId);
  assert.equal(verified?.sub, playerId);
  assert.equal(expiresIn, 900);
  assert.equal(verifyAnonymousAdmissionToken(token, secret, 1_901_000), null);
  assert.equal(verifyAnonymousAdmissionToken(token, 'different secret with enough bytes here'), null);
});

test('ticket verifier rejects forged claims and wrong token purpose', () => {
  const invalidSignature = jwt.sign({
    sub: 'forged', id: 'forged', typ: 'warbase-anonymous-admission', ver: 1,
    iss: 'warbase-admission', aud: 'warbase-game',
  }, 'attacker-controlled secret that is sufficiently long', { algorithm: 'HS256', expiresIn: 900 });
  const wrongPurpose = jwt.sign({
    sub: 'forged', id: 'forged', username: 'trusted-looking-name', typ: 'other', ver: 1,
    iss: 'warbase-admission', aud: 'warbase-game',
  }, secret, { algorithm: 'HS256', expiresIn: 900 });
  assert.equal(verifyAnonymousAdmissionToken(invalidSignature, secret), null);
  assert.equal(verifyAnonymousAdmissionToken(wrongPurpose, secret), null);
});

test('signed username claims are stripped and identity quotas use the signed player ID', () => {
  let now = 3_000_000;
  const playerId = 'player-session-123';
  const forgedProfile = jwt.sign({
    sub: playerId, id: playerId, username: 'trusted-looking-name', typ: 'warbase-anonymous-admission', ver: 1,
    iss: 'warbase-admission', aud: 'warbase-game',
  }, secret, { algorithm: 'HS256', expiresIn: 900 });
  const controls = createBattleAdmissionControls({ secret, now: () => now, playerJoinLimit: 2, playerRoomCreateLimit: 1 });
  const firstJoin = controls.authorizeJoin(forgedProfile);
  assert.equal(firstJoin?.id, playerId);
  assert.equal('username' in (firstJoin ?? {}), false);
  assert.equal(controls.authorizeJoin(forgedProfile)?.id, playerId);
  assert.equal(controls.authorizeJoin(forgedProfile), null);

  const headers = { authorization: `Bearer ${forgedProfile}` };
  const firstResponse = response();
  let nextCalls = 0;
  controls.roomCreateMiddleware(request('198.51.100.10', undefined, headers), firstResponse.target, (() => { nextCalls++; }) as never);
  assert.equal(nextCalls, 1);
  assert.equal(firstResponse.state.statusCode, 200);
  assert.equal('username' in (firstResponse.target.locals.admission ?? {}), false);
  const secondResponse = response();
  controls.roomCreateMiddleware(request('198.51.100.10', undefined, headers), secondResponse.target, (() => { nextCalls++; }) as never);
  assert.equal(secondResponse.state.statusCode, 429);
  assert.deepEqual(secondResponse.state.body, { error: 'room_creation_rate_limited' });
  assert.equal(nextCalls, 1);

  now += 60_000;
  assert.equal(controls.authorizeJoin(forgedProfile)?.id, playerId);
});

test('issuer enforces caller and global limits and emits no-store tickets', () => {
  let now = 2_000_000;
  const issuer = createAdmissionIssuer({
    secret,
    now: () => now,
    perCallerLimit: 2,
    globalLimit: 3,
  });
  const issue = (caller: string) => {
    const result = response();
    issuer.handler(request(caller), result.target, (() => undefined) as never);
    return result.state;
  };
  const first = issue('198.51.100.1');
  assert.equal(first.statusCode, 200);
  assert.equal(first.headers['cache-control'], 'no-store');
  const ticket = first.body as { token: string; playerId: string; expiresIn: number };
  assert.equal(verifyAnonymousAdmissionToken(ticket.token, secret, now)?.id, ticket.playerId);
  assert.equal(issue('198.51.100.1').statusCode, 200);
  assert.equal(issue('198.51.100.1').statusCode, 429);
  assert.equal(issue('198.51.100.2').statusCode, 200);
  assert.equal(issue('198.51.100.3').statusCode, 429);
  assert.deepEqual(issuer.metrics, { issued: 3, rateLimited: 2, rejectedAttribution: 0 });
  now += 60_000;
  assert.equal(issue('198.51.100.1').statusCode, 200);
});

test('configured trusted proxy with missing forwarded address fails closed', () => {
  const issuer = createAdmissionIssuer({ secret, trustedProxyCidrs: ['127.0.0.0/8'] });
  const result = response();
  issuer.handler(request('127.0.0.1'), result.target, (() => undefined) as never);
  assert.equal(result.state.statusCode, 503);
  assert.equal(issuer.metrics.rejectedAttribution, 1);
});

test('ticket issuance requires the trusted gateway secret and applies limits to its forwarded caller', () => {
  const gatewaySecret = 'gateway-only test token with more than thirty two bytes';
  const issuer = createAdmissionIssuer({
    secret,
    gatewaySecret,
    trustedProxyCidrs: ['172.20.0.0/16'],
    perCallerLimit: 1,
    globalLimit: 5,
  });
  const issue = (caller: string, gatewayToken?: string) => {
    const result = response();
    issuer.handler(request('172.20.0.5', caller, gatewayToken ? { 'x-warbase-gateway-token': gatewayToken } : {}), result.target, (() => undefined) as never);
    return result.state;
  };
  assert.equal(issue('198.51.100.1').statusCode, 503, 'caller cannot inject a forwarding header directly');
  assert.equal(issue('198.51.100.1', 'wrong gateway token').statusCode, 503, 'gateway marker without shared secret is rejected');
  assert.equal(issue('198.51.100.1', gatewaySecret).statusCode, 200);
  assert.equal(issue('198.51.100.1', gatewaySecret).statusCode, 429, 'verified source quota is applied to forwarded caller');
  assert.equal(issue('198.51.100.2', gatewaySecret).statusCode, 200, 'separate forwarded caller has its own quota');
  assert.equal(issuer.metrics.rejectedAttribution, 2);
});
