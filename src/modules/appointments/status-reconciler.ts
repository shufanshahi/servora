import type { Config } from '../../config';
import type { Db } from '../../db/pool';
import { AppointmentsRepository } from './appointments.repository';

const DEFAULT_INTERVAL_MS = 30_000;

/**
 * Runs the status progression on a timer so bookings advance even when nobody reads them.
 * Reads also reconcile first, so the timer only bounds how stale the stored status can be.
 * Returns a function that stops it.
 */
export function startStatusReconciler(
  db: Db,
  config: Pick<Config, 'CONFIRM_DELAY_MINUTES'>,
  options: { intervalMs?: number; clock?: () => Date; onError?: (error: Error) => void } = {},
): () => void {
  const repository = new AppointmentsRepository(db);
  const clock = options.clock ?? (() => new Date());
  const onError =
    options.onError ?? ((error) => console.error(`Status reconcile failed: ${error.message}`));
  let running = false;

  const tick = (): void => {
    if (running) return; // never overlap with a slow previous run
    running = true;
    repository
      .reconcile(clock(), config.CONFIRM_DELAY_MINUTES)
      .catch(onError)
      .finally(() => {
        running = false;
      });
  };

  const timer = setInterval(tick, options.intervalMs ?? DEFAULT_INTERVAL_MS);
  timer.unref(); // never keeps the process alive on its own
  return () => clearInterval(timer);
}
