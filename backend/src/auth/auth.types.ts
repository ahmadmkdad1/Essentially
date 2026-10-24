import { Role } from '../common/enums.js';

export interface JwtPayload {
  sub: string;
  email: string;
  role: Role;
}

/** Shape of `request.user` after the JWT strategy has validated the token. */
export interface AuthUser {
  id: string;
  email: string;
  role: Role;
  fullName: string;
}
