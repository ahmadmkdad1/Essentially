import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  type Relation,
} from 'typeorm';
import { BaseEntity } from '../common/entities/base.entity.js';
import { ModerationAction } from '../common/enums.js';
import { User } from '../users/user.entity.js';

/** Immutable record of every moderation action an admin performs. */
@Entity('audit_logs')
export class AuditLog extends BaseEntity {
  @ApiProperty()
  @Index()
  @Column()
  adminId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'adminId' })
  admin: Relation<User>;

  @ApiProperty({ enum: ModerationAction })
  @Column({ type: 'simple-enum', enum: ModerationAction })
  action: ModerationAction;

  @ApiProperty({ example: 'USER' })
  @Column({ length: 20 })
  targetType: string;

  @ApiProperty()
  @Column()
  targetId: string;

  @ApiProperty({
    description: 'Human readable label of the target at the time',
  })
  @Column({ length: 200, default: '' })
  targetLabel: string;

  @ApiProperty()
  @Column({ type: 'text' })
  reason: string;

  @ApiPropertyOptional()
  @Column({ type: 'varchar', nullable: true })
  reportId: string | null;
}
