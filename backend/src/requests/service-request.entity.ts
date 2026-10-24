import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  type Relation,
} from 'typeorm';
import {
  BaseEntity,
  decimalTransformer,
} from '../common/entities/base.entity.js';
import { RequestStatus } from '../common/enums.js';
import { Listing } from '../listings/listing.entity.js';
import { User } from '../users/user.entity.js';

@Entity('service_requests')
export class ServiceRequest extends BaseEntity {
  @ApiProperty()
  @Column()
  listingId: string;

  @ManyToOne(() => Listing, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'listingId' })
  listing: Relation<Listing>;

  @ApiProperty()
  @Index()
  @Column()
  customerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'customerId' })
  customer: Relation<User>;

  @ApiProperty()
  @Index()
  @Column()
  providerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'providerId' })
  provider: Relation<User>;

  @ApiProperty({ enum: RequestStatus })
  @Index()
  @Column({
    type: 'simple-enum',
    enum: RequestStatus,
    default: RequestStatus.PENDING,
  })
  status: RequestStatus;

  @ApiPropertyOptional({ description: 'Note from the customer' })
  @Column({ type: 'text', nullable: true })
  message: string | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  preferredDate: Date | null;

  @ApiProperty()
  @Column({ length: 255 })
  address: string;

  @ApiProperty()
  @Column({ type: 'double precision' })
  latitude: number;

  @ApiProperty()
  @Column({ type: 'double precision' })
  longitude: number;

  @ApiProperty({ description: 'Price snapshot at the time of the request' })
  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    transformer: decimalTransformer,
  })
  quotedPrice: number;

  @ApiPropertyOptional({
    description: 'Provider reply (e.g. rejection reason)',
  })
  @Column({ type: 'text', nullable: true })
  providerNote: string | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  respondedAt: Date | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  completedAt: Date | null;

  @ApiPropertyOptional()
  @Column({ type: Date, nullable: true })
  cancelledAt: Date | null;
}
