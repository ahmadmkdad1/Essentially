import { ApiProperty } from '@nestjs/swagger';
import { Column, Entity, Index } from 'typeorm';
import { BaseEntity } from '../common/entities/base.entity.js';

@Entity('categories')
export class Category extends BaseEntity {
  @ApiProperty()
  @Column({ length: 60 })
  name: string;

  @ApiProperty()
  @Index({ unique: true })
  @Column({ length: 60 })
  slug: string;

  @ApiProperty({ description: 'Icon key understood by the mobile client' })
  @Column({ length: 40 })
  icon: string;

  @ApiProperty()
  @Column({ type: 'varchar', length: 255, default: '' })
  description: string;

  @ApiProperty()
  @Column({ type: 'int', default: 0 })
  sortOrder: number;
}
