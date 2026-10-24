import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { AccountStatus, Role } from '../common/enums.js';
import {
  ChangePasswordDto,
  UpdateLocationDto,
  UpdateProfileDto,
} from './dto/users.dto.js';
import { User } from './user.entity.js';

const BCRYPT_ROUNDS = 10;

export interface CreateUserInput {
  fullName: string;
  email: string;
  password: string;
  role: Role;
  phone?: string | null;
  businessName?: string | null;
  bio?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  address?: string | null;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  static normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, BCRYPT_ROUNDS);
  }

  async create(input: CreateUserInput): Promise<User> {
    const email = UsersService.normalizeEmail(input.email);
    if (await this.users.existsBy({ email })) {
      throw new ConflictException('An account with this email already exists');
    }
    const user = this.users.create({
      fullName: input.fullName.trim(),
      email,
      passwordHash: await this.hashPassword(input.password),
      role: input.role,
      phone: input.phone ?? null,
      businessName: input.businessName ?? null,
      bio: input.bio ?? null,
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      address: input.address ?? null,
    });
    const saved = await this.users.save(user);
    return this.findById(saved.id);
  }

  async findById(id: string): Promise<User> {
    const user = await this.users.findOneBy({ id });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  /** Includes the password hash — only for credential checks. */
  findByEmailWithPassword(email: string): Promise<User | null> {
    return this.users
      .createQueryBuilder('u')
      .addSelect('u.passwordHash')
      .where('u.email = :email', { email: UsersService.normalizeEmail(email) })
      .getOne();
  }

  async verifyPassword(user: User, password: string): Promise<boolean> {
    return bcrypt.compare(password, user.passwordHash);
  }

  /**
   * Lifts expired suspensions and rejects accounts that may not use the
   * platform. Called on login and on every authenticated request.
   */
  async ensureCanAccess(user: User): Promise<User> {
    if (
      user.status === AccountStatus.SUSPENDED &&
      user.suspendedUntil &&
      user.suspendedUntil.getTime() <= Date.now()
    ) {
      user.status = AccountStatus.ACTIVE;
      user.suspendedUntil = null;
      user.statusReason = null;
      await this.users.update(user.id, {
        status: AccountStatus.ACTIVE,
        suspendedUntil: null,
        statusReason: null,
      });
    }

    if (user.status === AccountStatus.BANNED) {
      throw new ForbiddenException({
        code: 'ACCOUNT_BANNED',
        message: `This account has been banned${user.statusReason ? `: ${user.statusReason}` : ''}`,
      });
    }
    if (user.status === AccountStatus.SUSPENDED) {
      const until = user.suspendedUntil
        ? ` until ${user.suspendedUntil.toISOString().slice(0, 10)}`
        : '';
      throw new ForbiddenException({
        code: 'ACCOUNT_SUSPENDED',
        message: `This account is suspended${until}${user.statusReason ? `: ${user.statusReason}` : ''}`,
      });
    }
    return user;
  }

  async touchLastLogin(id: string): Promise<void> {
    await this.users.update(id, { lastLoginAt: new Date() });
  }

  async updateProfile(id: string, dto: UpdateProfileDto): Promise<User> {
    const user = await this.findById(id);
    if (user.role !== Role.PROVIDER && dto.businessName !== undefined) {
      throw new BadRequestException('Only providers can set a business name');
    }
    Object.assign(user, {
      ...(dto.fullName !== undefined && { fullName: dto.fullName.trim() }),
      ...(dto.phone !== undefined && { phone: dto.phone }),
      ...(dto.businessName !== undefined && { businessName: dto.businessName }),
      ...(dto.bio !== undefined && { bio: dto.bio }),
    });
    await this.users.save(user);
    return this.findById(id);
  }

  async updateLocation(id: string, dto: UpdateLocationDto): Promise<User> {
    await this.findById(id);
    await this.users.update(id, {
      latitude: dto.latitude,
      longitude: dto.longitude,
      address: dto.address,
    });
    return this.findById(id);
  }

  async changePassword(id: string, dto: ChangePasswordDto): Promise<void> {
    const current = await this.findById(id);
    const user = await this.findByEmailWithPassword(current.email);
    if (!user || !(await this.verifyPassword(user, dto.currentPassword))) {
      throw new BadRequestException('Current password is incorrect');
    }
    await this.users.update(id, {
      passwordHash: await this.hashPassword(dto.newPassword),
    });
  }
}
