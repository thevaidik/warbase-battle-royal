import type { Application, RequestHandler } from 'express';
import { monitor } from '@colyseus/monitor';
import { playground } from '@colyseus/playground';

export const monitorColumns = [
  'roomId', { metadata: 'name' }, { metadata: 'map' }, { metadata: 'mode' },
  { metadata: 'timeOfDay' }, 'clients', 'maxClients', 'locked', 'elapsedTime',
] satisfies NonNullable<Parameters<typeof monitor>[0]>['columns'];

export function mountOperationsTools(app: Application, options: {
  monitorEnabled: boolean;
  localPlaygroundEnabled: boolean;
  host: string;
  production: boolean;
  adminGuard?: unknown;
}): void {
  if (options.localPlaygroundEnabled && (options.production || !['127.0.0.1', '::1'].includes(options.host))) {
    throw new Error('Playground requires a non-production loopback listener.');
  }
  const privateOnly: RequestHandler = (req, res, next) => {
    if (req.get('x-forwarded-prefix')) { res.sendStatus(404); return; }
    res.setHeader('Cache-Control', 'no-store');
    next();
  };
  if (options.monitorEnabled) app.use('/monitor', privateOnly, monitor({ columns: monitorColumns,
    use: options.adminGuard ? [options.adminGuard] : [] }));
  // Playground patches room message introspection and exposes profiling/debug
  // actions. Keep it out of the live combat process entirely.
  if (options.localPlaygroundEnabled) app.use('/playground', privateOnly, playground());
}
