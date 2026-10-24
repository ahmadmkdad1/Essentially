import { BadRequestException } from '@nestjs/common';
import { RequestStatus } from '../common/enums.js';

export type RequestActor = 'customer' | 'provider';

/**
 * Allowed transitions of a service request and who may perform them.
 *
 *   PENDING  ──accept──▶ ACCEPTED ──complete──▶ COMPLETED
 *      │                    │
 *      ├─reject─▶ REJECTED  └─cancel─▶ CANCELLED
 *      └─cancel─▶ CANCELLED
 */
const TRANSITIONS: Record<
  RequestStatus,
  Partial<Record<RequestStatus, RequestActor[]>>
> = {
  [RequestStatus.PENDING]: {
    [RequestStatus.ACCEPTED]: ['provider'],
    [RequestStatus.REJECTED]: ['provider'],
    [RequestStatus.CANCELLED]: ['customer'],
  },
  [RequestStatus.ACCEPTED]: {
    [RequestStatus.COMPLETED]: ['provider'],
    [RequestStatus.CANCELLED]: ['customer', 'provider'],
  },
  [RequestStatus.REJECTED]: {},
  [RequestStatus.CANCELLED]: {},
  [RequestStatus.COMPLETED]: {},
};

export function canTransition(
  from: RequestStatus,
  to: RequestStatus,
  actor: RequestActor,
): boolean {
  return TRANSITIONS[from][to]?.includes(actor) ?? false;
}

export function assertTransition(
  from: RequestStatus,
  to: RequestStatus,
  actor: RequestActor,
): void {
  if (!canTransition(from, to, actor)) {
    throw new BadRequestException(
      `A ${from.toLowerCase()} request cannot be moved to ${to.toLowerCase()} by the ${actor}`,
    );
  }
}

export const OPEN_STATUSES = [RequestStatus.PENDING, RequestStatus.ACCEPTED];
