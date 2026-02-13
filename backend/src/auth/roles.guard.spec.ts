import { ForbiddenException, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '../users/user.entity';
import { RolesGuard } from './roles.guard';

describe('RolesGuard', () => {
  let reflector: { getAllAndOverride: jest.Mock };
  let guard: RolesGuard;

  beforeEach(() => {
    reflector = {
      getAllAndOverride: jest.fn(),
    };
    guard = new RolesGuard(reflector as unknown as Reflector);
  });

  it('allows access when role matches protected endpoint role', () => {
    reflector.getAllAndOverride.mockReturnValue([UserRole.PROVIDER]);
    const context = createHttpContext({ role: UserRole.PROVIDER });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('rejects access on role mismatch in protected endpoint', () => {
    reflector.getAllAndOverride.mockReturnValue([UserRole.PROVIDER]);
    const context = createHttpContext({ role: UserRole.CLIENT });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('allows access when endpoint has no role metadata', () => {
    reflector.getAllAndOverride.mockReturnValue(undefined);
    const context = createHttpContext({ role: UserRole.CLIENT });

    expect(guard.canActivate(context)).toBe(true);
  });
});

function createHttpContext(user: { role: UserRole }): ExecutionContext {
  return {
    getClass: jest.fn(),
    getHandler: jest.fn(),
    switchToHttp: () => ({
      getRequest: () => ({ user }),
      getResponse: jest.fn(),
      getNext: jest.fn(),
    }),
  } as unknown as ExecutionContext;
}
