import { BadRequestException } from '@nestjs/common';
import { RequestStatus as S } from '../common/enums.js';
import { assertTransition, canTransition } from './request-state.js';

describe('request state machine', () => {
  it('lets the provider accept or reject a pending request', () => {
    expect(canTransition(S.PENDING, S.ACCEPTED, 'provider')).toBe(true);
    expect(canTransition(S.PENDING, S.REJECTED, 'provider')).toBe(true);
  });

  it('does not let the customer accept their own request', () => {
    expect(canTransition(S.PENDING, S.ACCEPTED, 'customer')).toBe(false);
  });

  it('lets only the customer cancel a pending request', () => {
    expect(canTransition(S.PENDING, S.CANCELLED, 'customer')).toBe(true);
    expect(canTransition(S.PENDING, S.CANCELLED, 'provider')).toBe(false);
  });

  it('lets either side cancel an accepted request', () => {
    expect(canTransition(S.ACCEPTED, S.CANCELLED, 'customer')).toBe(true);
    expect(canTransition(S.ACCEPTED, S.CANCELLED, 'provider')).toBe(true);
  });

  it('only allows completing accepted requests', () => {
    expect(canTransition(S.ACCEPTED, S.COMPLETED, 'provider')).toBe(true);
    expect(canTransition(S.PENDING, S.COMPLETED, 'provider')).toBe(false);
  });

  it.each([S.REJECTED, S.CANCELLED, S.COMPLETED])(
    'treats %s as terminal',
    (terminal) => {
      for (const to of Object.values(S)) {
        expect(canTransition(terminal, to, 'provider')).toBe(false);
        expect(canTransition(terminal, to, 'customer')).toBe(false);
      }
    },
  );

  it('throws a 400 for invalid transitions', () => {
    expect(() => assertTransition(S.COMPLETED, S.ACCEPTED, 'provider')).toThrow(
      BadRequestException,
    );
  });
});
