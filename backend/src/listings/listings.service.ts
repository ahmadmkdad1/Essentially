import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository, SelectQueryBuilder } from 'typeorm';
import type { AuthUser } from '../auth/auth.types.js';
import { CategoriesService } from '../categories/categories.module.js';
import { paginate, Paginated } from '../common/dto/pagination.dto.js';
import {
  AccountStatus,
  ListingStatus,
  RequestStatus,
  Role,
} from '../common/enums.js';
import { boundingBox, haversineKm, roundTo } from '../common/utils/geo.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import {
  CreateListingDto,
  ListingSort,
  SearchListingsDto,
  UpdateListingDto,
} from './dto/listings.dto.js';
import { Listing } from './listing.entity.js';
import { toPublicProvider } from './listing.mapper.js';

/** Upper bound of rows pulled into memory for exact distance sorting. */
const GEO_CANDIDATE_LIMIT = 2000;

export type ListingView = Omit<Listing, 'provider'> & {
  provider?: ReturnType<typeof toPublicProvider>;
  distanceKm: number | null;
  withinServiceArea: boolean | null;
};

@Injectable()
export class ListingsService {
  constructor(
    @InjectRepository(Listing) private readonly listings: Repository<Listing>,
    @InjectRepository(ServiceRequest)
    private readonly requests: Repository<ServiceRequest>,
    private readonly categoriesService: CategoriesService,
  ) {}

  /** Public search, optionally centred on the customer's location. */
  async search(dto: SearchListingsDto): Promise<Paginated<ListingView>> {
    const { page, limit } = dto;
    const hasLocation = dto.lat !== undefined && dto.lng !== undefined;

    const qb = this.publicQuery();
    if (dto.categoryId)
      qb.andWhere('l.categoryId = :categoryId', { categoryId: dto.categoryId });
    if (dto.maxPrice !== undefined)
      qb.andWhere('l.price <= :maxPrice', { maxPrice: dto.maxPrice });
    if (dto.q) {
      qb.andWhere('(LOWER(l.title) LIKE :q OR LOWER(l.description) LIKE :q)', {
        q: `%${dto.q.toLowerCase()}%`,
      });
    }

    if (!hasLocation) {
      this.applySqlSort(qb, dto.sort);
      const [rows, total] = await qb
        .skip((page - 1) * limit)
        .take(limit)
        .getManyAndCount();
      return paginate(
        rows.map((l) => this.toView(l, null)),
        total,
        page,
        limit,
      );
    }

    const origin = { latitude: dto.lat!, longitude: dto.lng! };
    const box = boundingBox(origin, dto.radiusKm);
    qb.andWhere('l.latitude BETWEEN :minLat AND :maxLat', box).andWhere(
      'l.longitude BETWEEN :minLng AND :maxLng',
      box,
    );

    const candidates = await qb.take(GEO_CANDIDATE_LIMIT).getMany();
    const inRange = candidates
      .map((l) => this.toView(l, origin))
      .filter((l) => (l.distanceKm ?? Infinity) <= dto.radiusKm);

    inRange.sort(this.comparator(dto.sort));
    const start = (page - 1) * limit;
    return paginate(
      inRange.slice(start, start + limit),
      inRange.length,
      page,
      limit,
    );
  }

  async findOne(
    id: string,
    viewer?: AuthUser,
    origin?: { latitude: number; longitude: number },
  ): Promise<ListingView> {
    const listing = await this.listings.findOne({
      where: { id },
      relations: { category: true, provider: true },
    });
    if (!listing) throw new NotFoundException('Service not found');

    const privileged =
      viewer &&
      (viewer.role === Role.ADMIN || viewer.id === listing.providerId);
    const publiclyVisible =
      listing.status === ListingStatus.ACTIVE &&
      listing.provider.status === AccountStatus.ACTIVE;
    if (!publiclyVisible && !privileged) {
      throw new NotFoundException('Service not found');
    }
    return this.toView(listing, origin ?? null);
  }

  /** Raw entity for internal use (ownership checks, requests, reports). */
  async getEntity(id: string): Promise<Listing> {
    const listing = await this.listings.findOne({
      where: { id },
      relations: { provider: true, category: true },
    });
    if (!listing) throw new NotFoundException('Service not found');
    return listing;
  }

  findByProvider(providerId: string, onlyPublic = false): Promise<Listing[]> {
    return this.listings.find({
      where: {
        providerId,
        ...(onlyPublic && { status: ListingStatus.ACTIVE }),
      },
      relations: { category: true },
      order: { createdAt: 'DESC' },
    });
  }

  async create(provider: AuthUser, dto: CreateListingDto): Promise<Listing> {
    await this.categoriesService.findById(dto.categoryId);
    const listing = this.listings.create({
      ...dto,
      currency: (dto.currency ?? 'USD').toUpperCase(),
      providerId: provider.id,
      status: ListingStatus.ACTIVE,
    });
    const saved = await this.listings.save(listing);
    return this.getEntityWithoutProvider(saved.id);
  }

  async update(
    provider: AuthUser,
    id: string,
    dto: UpdateListingDto,
  ): Promise<Listing> {
    const listing = await this.getOwned(provider, id);
    if (listing.status === ListingStatus.REMOVED) {
      throw new ForbiddenException(
        'This service was removed by an administrator and can no longer be edited',
      );
    }
    if (dto.categoryId) await this.categoriesService.findById(dto.categoryId);
    Object.assign(listing, dto);
    if (dto.currency) listing.currency = dto.currency.toUpperCase();
    await this.listings.save(listing);
    return this.getEntityWithoutProvider(id);
  }

  async setStatus(
    provider: AuthUser,
    id: string,
    status: ListingStatus.ACTIVE | ListingStatus.PAUSED,
  ): Promise<Listing> {
    const listing = await this.getOwned(provider, id);
    if (listing.status === ListingStatus.REMOVED) {
      throw new ForbiddenException(
        'This service was removed by an administrator and cannot be reactivated',
      );
    }
    await this.listings.update(id, { status });
    return this.getEntityWithoutProvider(id);
  }

  async remove(provider: AuthUser, id: string): Promise<void> {
    await this.getOwned(provider, id);
    const openRequests = await this.requests.countBy({
      listingId: id,
      status: In([RequestStatus.PENDING, RequestStatus.ACCEPTED]),
    });
    if (openRequests > 0) {
      throw new ConflictException(
        'This service has open requests. Complete or reject them before deleting it, or pause it instead.',
      );
    }
    await this.listings.softDelete(id);
  }

  /** Recomputes the cached rating from visible reviews. */
  async refreshRating(
    listingId: string,
    stats: { average: number; count: number },
  ): Promise<void> {
    await this.listings.update(listingId, {
      ratingAverage: roundTo(stats.average, 2),
      ratingCount: stats.count,
    });
  }

  // ---------------------------------------------------------------------------

  private publicQuery(): SelectQueryBuilder<Listing> {
    return this.listings
      .createQueryBuilder('l')
      .innerJoinAndSelect('l.provider', 'p')
      .innerJoinAndSelect('l.category', 'c')
      .where('l.status = :status', { status: ListingStatus.ACTIVE })
      .andWhere('p.status = :providerStatus', {
        providerStatus: AccountStatus.ACTIVE,
      });
  }

  private applySqlSort(qb: SelectQueryBuilder<Listing>, sort: ListingSort) {
    switch (sort) {
      case ListingSort.PRICE_ASC:
        qb.orderBy('l.price', 'ASC');
        break;
      case ListingSort.PRICE_DESC:
        qb.orderBy('l.price', 'DESC');
        break;
      case ListingSort.RATING:
        qb.orderBy('l.ratingAverage', 'DESC').addOrderBy(
          'l.ratingCount',
          'DESC',
        );
        break;
      default:
        qb.orderBy('l.createdAt', 'DESC');
    }
  }

  private comparator(sort: ListingSort) {
    return (a: ListingView, b: ListingView): number => {
      switch (sort) {
        case ListingSort.PRICE_ASC:
          return a.price - b.price;
        case ListingSort.PRICE_DESC:
          return b.price - a.price;
        case ListingSort.RATING:
          return (
            b.ratingAverage - a.ratingAverage || b.ratingCount - a.ratingCount
          );
        case ListingSort.NEWEST:
          return b.createdAt.getTime() - a.createdAt.getTime();
        default:
          return (a.distanceKm ?? 0) - (b.distanceKm ?? 0);
      }
    };
  }

  private toView(
    listing: Listing,
    origin: { latitude: number; longitude: number } | null,
  ): ListingView {
    const distance = origin ? haversineKm(origin, listing) : null;
    const { provider, ...rest } = listing;
    return {
      ...rest,
      ...(provider && { provider: toPublicProvider(provider) }),
      distanceKm: distance === null ? null : roundTo(distance, 2),
      withinServiceArea:
        distance === null ? null : distance <= listing.serviceRadiusKm,
    };
  }

  private async getOwned(provider: AuthUser, id: string): Promise<Listing> {
    const listing = await this.listings.findOneBy({ id });
    if (!listing) throw new NotFoundException('Service not found');
    if (listing.providerId !== provider.id) {
      throw new ForbiddenException('You can only manage your own services');
    }
    return listing;
  }

  private async getEntityWithoutProvider(id: string): Promise<Listing> {
    const listing = await this.listings.findOne({
      where: { id },
      relations: { category: true },
    });
    if (!listing) throw new BadRequestException('Service could not be loaded');
    return listing;
  }
}
