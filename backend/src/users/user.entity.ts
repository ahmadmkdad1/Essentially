import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Exclude } from 'class-transformer';
import { Column, Entity, Index } from 'typeorm';
import { BaseEntity } from '../common/entities/base.entity.js';
import { AccountStatus, Role } from '../common/enums.js';

@Entity('users')
export class User extends BaseEntity {
  @ApiProperty()
  @Column({ length: 120 })
  fullName: string;

  @ApiProperty()
  @Index({ unique: true })
  @Column({ length: 160 })
  email: string;

  @Exclude()
  @Column({ select: false })
  passwordHash: string;

  @ApiPropertyOptional()
  @Column({ type: 'varchar', length: 30, nullable: true })
  phone: string | null;

  @ApiProperty({ enum: Role })
  @Index()
  @Column({ type: 'simple-enum', enum: Role, default: Role.USER })
  role: Role;

  @ApiProperty({ enum: AccountStatus })
  @Column({
    type: 'simple-enum',
    enum: AccountStatus,
    default: AccountStatus.ACTIVE,
  })
  status: AccountStatus;

  @ApiPropertyOptional({ description: 'Why the account was suspended/banned' })
  @Column({ type: 'text', nullable: true })
  statusReason: string | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  suspendedUntil: Date | null;

  @ApiProperty()
  @Column({ type: 'int', default: 0 })
  warningCount: number;

  @ApiPropertyOptional({ description: 'Provider business / trade name' })
  @Column({ type: 'varchar', length: 120, nullable: true })
  businessName: string | null;

  @ApiPropertyOptional()
  @Column({ type: 'text', nullable: true })
  bio: string | null;

  @ApiPropertyOptional()
  @Column({ type: 'double precision', nullable: true })
  latitude: number | null;

  @ApiPropertyOptional()
  @Column({ type: 'double precision', nullable: true })
  longitude: number | null;

  @ApiPropertyOptional()
  @Column({ type: 'varchar', length: 255, nullable: true })
  address: string | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  lastLoginAt: Date | null;
}
