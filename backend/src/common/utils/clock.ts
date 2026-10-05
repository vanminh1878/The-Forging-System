/**
 * Injectable clock. Production uses the system time; tests and batch
 * simulations can freeze or advance it.
 */
export interface Clock {
  now(): Date;
}

class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}

let current: Clock = new SystemClock();

export const clock: Clock = {
  now: () => current.now(),
};

export function setClock(next: Clock): void {
  current = next;
}

export function resetClock(): void {
  current = new SystemClock();
}

export function fixedClock(date: Date): Clock {
  return { now: () => new Date(date.getTime()) };
}
