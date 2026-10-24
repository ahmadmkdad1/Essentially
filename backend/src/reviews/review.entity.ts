import { ApiProperty } from '@nestjs/swagger';
import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  type Relation,
} from 'typeorm';
import { BaseEntity } from '../common/entities/base.entity.js';
import { Listing } from '../listings/listing.entity.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import { User } from '../users/user.entity.js';

@Entity('reviews')
export class Review extends BaseEntity {
  @ApiProperty()
  @Index({ unique: true })
  @Column()
  requestId: string;

  @ManyToOne(() => ServiceRequest, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'requestId' })
  request: Relation<ServiceRequest>;

  @ApiProperty()
  @Index()
  @Column()
  listingId: string;

  @ManyToOne(() => Listing, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'listingId' })
  listing: Relation<Listing>;

  @ApiProperty()
  @Column()
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'authorId' })
  author: Relation<User>;

  @ApiProperty()
  @Index()
  @Column()
  providerId: string;

  @ApiProperty({ minimum: 1, maximum: 5 })
  @Column({ type: 'int' })
  rating: number;

  @ApiProperty()
  @Column({ type: 'text', default: '' })
  comment: string;

  @ApiProperty({ description: 'Hidden by an admin after a violation' })
  @Column({ default: false })
  isHidden: boolean;
}
