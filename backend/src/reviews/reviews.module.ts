import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  ForbiddenException,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiProperty,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Repository } from 'typeorm';
import type { AuthUser } from '../auth/auth.types.js';
import {
  CurrentUser,
  Public,
  Roles,
} from '../common/decorators/auth.decorators.js';
import { paginate, PaginationQueryDto } from '../common/dto/pagination.dto.js';
import { RequestStatus, Role } from '../common/enums.js';
import { ListingsModule } from '../listings/listings.module.js';
import { ListingsService } from '../listings/listings.service.js';
import { RequestsModule } from '../requests/requests.module.js';
import { RequestsService } from '../requests/requests.service.js';
import { Review } from './review.entity.js';

export class CreateReviewDto {
  @ApiProperty({ format: 'uuid', description: 'A completed request' })
  @IsUUID()
  requestId: string;

  @ApiProperty({ minimum: 1, maximum: 5, example: 5 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @ApiPropertyOptional({ example: 'Fast and professional.' })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  comment?: string;
}

export class ListReviewsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  listingId?: string;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  providerId?: string;
}

export interface ReviewView {
  id: string;
  rating: number;
  comment: string;
  createdAt: Date;
  listingId: string;
  listingTitle: string | null;
  providerId: string;
  author: { id: string; fullName: string };
}

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review) private readonly reviews: Repository<Review>,
    private readonly requestsService: RequestsService,
    private readonly listingsService: ListingsService,
  ) {}

  async create(actor: AuthUser, dto: CreateReviewDto): Promise<ReviewView> {
    const request = await this.requestsService.getEntity(dto.requestId);
    if (request.customerId !== actor.id) {
      throw new ForbiddenException('You can only review your own requests');
    }
    if (request.status !== RequestStatus.COMPLETED) {
      throw new BadRequestException('Only completed requests can be reviewed');
    }
    if (await this.reviews.existsBy({ requestId: request.id })) {
      throw new ConflictException('You already reviewed this request');
    }
    const saved = await this.reviews.save(
      this.reviews.create({
        requestId: request.id,
        listingId: request.listingId,
        providerId: request.providerId,
        authorId: actor.id,
        rating: dto.rating,
        comment: dto.comment?.trim() ?? '',
      }),
    );
    await this.refreshListingRating(request.listingId);
    return this.findView(saved.id);
  }

  async list(dto: ListReviewsDto) {
    const [rows, total] = await this.reviews.findAndCount({
      where: {
        isHidden: false,
        ...(dto.listingId && { listingId: dto.listingId }),
        ...(dto.providerId && { providerId: dto.providerId }),
      },
      relations: { author: true, listing: true },
      withDeleted: true,
      order: { createdAt: 'DESC' },
      skip: (dto.page - 1) * dto.limit,
      take: dto.limit,
    });
    return paginate(rows.map(toReviewView), total, dto.page, dto.limit);
  }

  async getEntity(id: string): Promise<Review> {
    const review = await this.reviews.findOneBy({ id });
    if (!review) throw new NotFoundException('Review not found');
    return review;
  }

  async refreshListingRating(listingId: string): Promise<void> {
    const row = await this.reviews
      .createQueryBuilder('r')
      .select('AVG(r.rating)', 'avg')
      .addSelect('COUNT(*)', 'count')
      .where('r.listingId = :listingId', { listingId })
      .andWhere('r.isHidden = :hidden', { hidden: false })
      .getRawOne<{ avg: string | number | null; count: string | number }>();
    await this.listingsService.refreshRating(listingId, {
      average: Number(row?.avg ?? 0),
      count: Number(row?.count ?? 0),
    });
  }

  private async findView(id: string): Promise<ReviewView> {
    const review = await this.reviews.findOne({
      where: { id },
      relations: { author: true, listing: true },
      withDeleted: true,
    });
    if (!review) throw new NotFoundException('Review not found');
    return toReviewView(review);
  }
}

function toReviewView(r: Review): ReviewView {
  return {
    id: r.id,
    rating: r.rating,
    comment: r.comment,
    createdAt: r.createdAt,
    listingId: r.listingId,
    listingTitle: r.listing?.title ?? null,
    providerId: r.providerId,
    author: { id: r.author.id, fullName: r.author.fullName },
  };
}

@ApiTags('Reviews')
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @ApiBearerAuth()
  @Roles(Role.USER)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateReviewDto) {
    return this.reviewsService.create(user, dto);
  }

  @Public()
  @Get()
  list(@Query() dto: ListReviewsDto) {
    return this.reviewsService.list(dto);
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([Review]), RequestsModule, ListingsModule],
  controllers: [ReviewsController],
  providers: [ReviewsService],
  exports: [ReviewsService],
})
export class ReviewsModule {}
