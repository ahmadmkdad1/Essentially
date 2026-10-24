import {
  Controller,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Param,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/auth.decorators.js';
import { AccountStatus, Role } from '../common/enums.js';
import { toPublicProvider } from '../listings/listing.mapper.js';
import { ListingsModule } from '../listings/listings.module.js';
import { ListingsService } from '../listings/listings.service.js';
import { RequestsModule } from '../requests/requests.module.js';
import { RequestsService } from '../requests/requests.service.js';
import { ReviewsModule, ReviewsService } from '../reviews/reviews.module.js';
import { UsersModule } from '../users/users.module.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class ProvidersService {
  constructor(
    private readonly usersService: UsersService,
    private readonly listingsService: ListingsService,
    private readonly requestsService: RequestsService,
    private readonly reviewsService: ReviewsService,
  ) {}

  async publicProfile(id: string) {
    const user = await this.usersService.findById(id).catch(() => null);
    if (
      !user ||
      user.role !== Role.PROVIDER ||
      user.status !== AccountStatus.ACTIVE
    ) {
      throw new NotFoundException('Provider not found');
    }
    const [listings, stats, reviews] = await Promise.all([
      this.listingsService.findByProvider(id, true),
      this.requestsService.providerStats(id),
      this.reviewsService.list({ providerId: id, page: 1, limit: 10 }),
    ]);
    return {
      provider: toPublicProvider(user),
      listings,
      stats: {
        completedJobs: stats.requests.COMPLETED,
        ratingAverage: stats.ratingAverage,
        ratingCount: stats.ratingCount,
        activeListings: stats.activeListings,
      },
      reviews: reviews.items,
    };
  }
}

@ApiTags('Providers')
@Controller('providers')
export class ProvidersController {
  constructor(private readonly providersService: ProvidersService) {}

  @Public()
  @Get(':id')
  profile(@Param('id', ParseUUIDPipe) id: string) {
    return this.providersService.publicProfile(id);
  }
}

@Module({
  imports: [UsersModule, ListingsModule, RequestsModule, ReviewsModule],
  controllers: [ProvidersController],
  providers: [ProvidersService],
})
export class ProvidersModule {}
