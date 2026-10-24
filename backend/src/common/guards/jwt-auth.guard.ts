import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../decorators/auth.decorators.js';

/**
 * Global guard: every route requires a valid JWT unless marked @Public().
 * Public routes still resolve the user when a valid token is sent, so they
 * can personalise responses (e.g. let owners view their paused services).
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  private isPublic(context: ExecutionContext): boolean {
    return !!this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (!this.isPublic(context)) {
      return (await super.canActivate(context)) as boolean;
    }
    const hasToken = !!context.switchToHttp().getRequest().headers
      ?.authorization;
    if (!hasToken) return true;
    try {
      await super.canActivate(context);
    } catch {
      // Invalid token on a public route: continue anonymously.
    }
    return true;
  }

  handleRequest<TUser>(
    err: unknown,
    user: TUser,
    _info: unknown,
    context: ExecutionContext,
  ): TUser {
    if (this.isPublic(context)) return (user || undefined) as TUser;
    return super.handleRequest(err, user, _info, context);
  }
}
