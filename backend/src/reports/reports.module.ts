import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import {
  IsEnum,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Repository } from 'typeorm';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../common/decorators/auth.decorators.js';
import { paginate, PaginationQueryDto } from '../common/dto/pagination.dto.js';
import {
  ReportReason,
  ReportStatus,
  ReportTargetType,
  Role,
} from '../common/enums.js';
import { Listing } from '../listings/listing.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';
import { Report } from './report.entity.js';

export class CreateReportDto {
  @ApiProperty({ enum: ReportTargetType })
  @IsEnum(ReportTargetType)
  targetType: ReportTargetType;

  @ApiProperty({
    format: 'uuid',
    description: 'Id of the user, service or review',
  })
  @IsUUID()
  targetId: string;

  @ApiProperty({ enum: ReportReason })
  @IsEnum(ReportReason)
  reason: ReportReason;

  @ApiProperty({
    example: 'The provider asked for payment upfront and never showed up.',
  })
  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  details: string;
}

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(Report) private readonly reports: Repository<Report>,
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Listing) private readonly listings: Repository<Listing>,
    @InjectRepository(Review) private readonly reviews: Repository<Review>,
  ) {}

  async create(actor: AuthUser, dto: CreateReportDto): Promise<Report> {
    const target = await this.resolveTarget(dto.targetType, dto.targetId);
    if (target.targetUserId === actor.id) {
      throw new BadRequestException(
        'You cannot report yourself or your own content',
      );
    }

    const duplicate = await this.reports.existsBy({
      reporterId: actor.id,
      targetType: dto.targetType,
      targetUserId: target.targetUserId,
      ...(target.targetListingId && {
        targetListingId: target.targetListingId,
      }),
      ...(target.targetReviewId && { targetReviewId: target.targetReviewId }),
      status: ReportStatus.OPEN,
    });
    if (duplicate) {
      throw new ConflictException('You already have an open report about this');
    }

    return this.reports.save(
      this.reports.create({
        reporterId: actor.id,
        targetType: dto.targetType,
        reason: dto.reason,
        details: dto.details.trim(),
        ...target,
      }),
    );
  }

  async mine(actor: AuthUser, dto: PaginationQueryDto) {
    const [items, total] = await this.reports.findAndCount({
      where: { reporterId: actor.id },
      relations: { targetUser: true, targetListing: true },
      withDeleted: true,
      order: { createdAt: 'DESC' },
      skip: (dto.page - 1) * dto.limit,
      take: dto.limit,
    });
    return paginate(
      items.map((r) => ({
        id: r.id,
        targetType: r.targetType,
        reason: r.reason,
        details: r.details,
        status: r.status,
        actionTaken: r.actionTaken,
        resolutionNote: r.resolutionNote,
        createdAt: r.createdAt,
        resolvedAt: r.resolvedAt,
        targetLabel:
          r.targetListing?.title ??
          r.targetUser?.businessName ??
          r.targetUser?.fullName ??
          null,
      })),
      total,
      dto.page,
      dto.limit,
    );
  }

  private async resolveTarget(
    type: ReportTargetType,
    id: string,
  ): Promise<
    Pick<Report, 'targetUserId' | 'targetListingId' | 'targetReviewId'>
  > {
    switch (type) {
      case ReportTargetType.USER: {
        const user = await this.users.findOneBy({ id });
        if (!user) throw new NotFoundException('User not found');
        if (user.role === Role.ADMIN) {
          throw new BadRequestException('Administrators cannot be reported');
        }
        return {
          targetUserId: user.id,
          targetListingId: null,
          targetReviewId: null,
        };
      }
      case ReportTargetType.LISTING: {
        const listing = await this.listings.findOneBy({ id });
        if (!listing) throw new NotFoundException('Service not found');
        return {
          targetUserId: listing.providerId,
          targetListingId: listing.id,
          targetReviewId: null,
        };
      }
      case ReportTargetType.REVIEW: {
        const review = await this.reviews.findOneBy({ id });
        if (!review) throw new NotFoundException('Review not found');
        return {
          targetUserId: review.authorId,
          targetListingId: review.listingId,
          targetReviewId: review.id,
        };
      }
    }
  }
}

@ApiTags('Reports')
@ApiBearerAuth()
@Roles(Role.USER, Role.PROVIDER)
@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateReportDto) {
    return this.reportsService.create(user, dto);
  }

  @Get('mine')
  mine(@CurrentUser() user: AuthUser, @Query() dto: PaginationQueryDto) {
    return this.reportsService.mine(user, dto);
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([Report, User, Listing, Review])],
  controllers: [ReportsController],
  providers: [ReportsService],
})
export class ReportsModule {}
