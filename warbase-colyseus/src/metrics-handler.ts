import { timingSafeEqual } from 'node:crypto';
import type { Request, Response } from 'express';

export function createOperationsMetricsHandler(token: string, snapshot: () => unknown) {
  return (req: Request, res: Response) => {
    if (!token) return res.sendStatus(404);
    const peer = req.socket.remoteAddress ?? '';
    const loopback = peer === '127.0.0.1' || peer === '::1' || peer.startsWith('::ffff:127.');
    if (!loopback) return res.sendStatus(403);
    res.setHeader('Cache-Control', 'no-store');
    const authorization = req.get('authorization') ?? '';
    const suppliedToken = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';
    const supplied = Buffer.from(suppliedToken), expected = Buffer.from(token);
    if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) return res.sendStatus(401);
    return res.json(snapshot());
  };
}
