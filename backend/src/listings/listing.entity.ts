import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  Column,
  DeleteDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  type Relation,
} from 'typeorm';
import { Category } from '../categories/category.entity.js';
import {
  BaseEntity,
  decimalTransformer,
} from '../common/entities/base.entity.js';
import { ListingStatus, PriceUnit } from '../common/enums.js';
import { User } from '../users/user.entity.js';

/** A service offered by a provider (e.g. "Gas cylinder refill — $12"). */
@Entity('listings')
@Index(['latitude', 'longitude'])
export class Listing extends BaseEntity {
  @ApiProperty()
  @Column({ length: 120 })
  title: string;

  @ApiProperty()
  @Column({ type: 'text' })
  description: string;

  @ApiProperty()
  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    transformer: decimalTransformer,
  })
  price: number;

  @ApiProperty({ enum: PriceUnit })
  @Column({ type: 'simple-enum', enum: PriceUnit, default: PriceUnit.FIXED })
  priceUnit: PriceUnit;

  @ApiProperty({ example: 'USD' })
  @Column({ length: 3, default: 'USD' })
  currency: string;

  @ApiProperty()
  @Column()
  categoryId: string;

  @ManyToOne(() => Category, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'categoryId' })
  category: Relation<Category>;

  @ApiProperty()
  @Index()
  @Column()
  providerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'providerId' })
  provider: Relation<User>;

  @ApiProperty()
  @Column({ type: 'double precision' })
  latitude: number;

  @ApiProperty()
  @Column({ type: 'double precision' })
  longitude: number;

  @ApiProperty()
  @Column({ length: 255 })
  address: string;

  @ApiProperty({
    description: 'How far (km) the provider travels from the listing location',
  })
  @Column({ type: 'int', default: 15 })
  serviceRadiusKm: number;

  @ApiProperty({ enum: ListingStatus })
  @Index()
  @Column({
    type: 'simple-enum',
    enum: ListingStatus,
    default: ListingStatus.ACTIVE,
  })
  status: ListingStatus;

  @ApiPropertyOptional({ description: 'Set when an admin removes the listing' })
  @Column({ type: 'text', nullable: true })
  removalReason: string | null;

  @ApiProperty()
  @Column({
    type: 'decimal',
    precision: 3,
    scale: 2,
    default: 0,
    transformer: decimalTransformer,
  })
  ratingAverage: number;

  @ApiProperty()
  @Column({ type: 'int', default: 0 })
  ratingCount: number;

  /** Soft delete keeps request/review history intact. */
  @DeleteDateColumn({ select: false })
  deletedAt?: Date | null;
}
