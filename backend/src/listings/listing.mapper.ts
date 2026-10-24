import type { User } from '../users/user.entity.js';

/** Fields of a provider that are safe to show to any customer. */
export interface PublicProvider {
  id: string;
  fullName: string;
  businessName: string | null;
  phone: string | null;
  bio: string | null;
  address: string | null;
  createdAt: Date;
}

export function toPublicProvider(user: User): PublicProvider {
  return {
    id: user.id,
    fullName: user.fullName,
    businessName: user.businessName,
    phone: user.phone,
    bio: user.bio,
    address: user.address,
    createdAt: user.createdAt,
  };
}

/** Customer fields a provider needs to fulfil a request. */
export interface PublicCustomer {
  id: string;
  fullName: string;
  phone: string | null;
}

export function toPublicCustomer(user: User): PublicCustomer {
  return { id: user.id, fullName: user.fullName, phone: user.phone };
}
