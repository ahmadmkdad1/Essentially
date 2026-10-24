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
import {
  ModerationAction,
  ReportReason,
  ReportStatus,
  ReportTargetType,
} from '../common/enums.js';
import { Listing } from '../listings/listing.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';

/** A violation flagged by a user or provider, reviewed by an admin. */
@Entity('reports')
export class Report extends BaseEntity {
  @ApiProperty()
  @Column()
  reporterId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter: Relation<User>;

  @ApiProperty({ enum: ReportTargetType })
  @Column({ type: 'simple-enum', enum: ReportTargetType })
  targetType: ReportTargetType;

  /** The account responsible for the violation (always set). */
  @ApiProperty()
  @Index()
  @Column()
  targetUserId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'targetUserId' })
  targetUser: Relation<User>;

  @ApiPropertyOptional()
  @Column({ type: 'varchar', nullable: true })
  targetListingId: string | null;

  @ManyToOne(() => Listing, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'targetListingId' })
  targetListing: Relation<Listing> | null;

  @ApiPropertyOptional()
  @Column({ type: 'varchar', nullable: true })
  targetReviewId: string | null;

  @ManyToOne(() => Review, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'targetReviewId' })
  targetReview: Relation<Review> | null;

  @ApiProperty({ enum: ReportReason })
  @Column({ type: 'simple-enum', enum: ReportReason })
  reason: ReportReason;

  @ApiProperty()
  @Column({ type: 'text' })
  details: string;

  @ApiProperty({ enum: ReportStatus })
  @Index()
  @Column({
    type: 'simple-enum',
    enum: ReportStatus,
    default: ReportStatus.OPEN,
  })
  status: ReportStatus;

  @ApiProperty({ enum: ModerationAction })
  @Column({
    type: 'simple-enum',
    enum: ModerationAction,
    default: ModerationAction.NONE,
  })
  actionTaken: ModerationAction;

  @ApiPropertyOptional()
  @Column({ type: 'text', nullable: true })
  resolutionNote: string | null;

  @ApiPropertyOptional()
  @Column({ type: 'varchar', nullable: true })
  resolvedById: string | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'resolvedById' })
  resolvedBy: Relation<User> | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  resolvedAt: Date | null;
}
