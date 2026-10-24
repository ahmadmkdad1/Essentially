import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import type { AuthUser } from '../auth/auth.types.js';
import { paginate, Paginated } from '../common/dto/pagination.dto.js';
import {
  AccountStatus,
  ListingStatus,
  RequestStatus,
  Role,
} from '../common/enums.js';
import { haversineKm, roundTo } from '../common/utils/geo.js';
import {
  toPublicCustomer,
  toPublicProvider,
} from '../listings/listing.mapper.js';
import { ListingsService } from '../listings/listings.service.js';
import { Review } from '../reviews/review.entity.js';
import { UsersService } from '../users/users.service.js';
import { CreateRequestDto, ListRequestsDto } from './dto/requests.dto.js';
import {
  assertTransition,
  OPEN_STATUSES,
  RequestActor,
} from './request-state.js';
import { ServiceRequest } from './service-request.entity.js';

export interface RequestView extends Omit<
  ServiceRequest,
  'customer' | 'provider' | 'listing'
> {
  listing: {
    id: string;
    title: string;
    price: number;
    priceUnit: string;
    currency: string;
    address: string;
    categoryName: string | null;
  } | null;
  customer?: ReturnType<typeof toPublicCustomer>;
  provider?: ReturnType<typeof toPublicProvider>;
  distanceKm: number | null;
  hasReview: boolean;
}

export interface ProviderStats {
  requests: Record<RequestStatus, number>;
  totalRequests: number;
  completedRevenue: number;
  acceptanceRate: number | null;
  activeListings: number;
  totalListings: number;
  ratingAverage: number | null;
  ratingCount: number;
}

@Injectable()
export class RequestsService {
  constructor(
    @InjectRepository(ServiceRequest)
    private readonly requests: Repository<ServiceRequest>,
    @InjectRepository(Review) private readonly reviews: Repository<Review>,
    private readonly listingsService: ListingsService,
    private readonly usersService: UsersService,
  ) {}

  async create(actor: AuthUser, dto: CreateRequestDto): Promise<RequestView> {
    const listing = await this.listingsService.getEntity(dto.listingId);
    if (
      listing.status !== ListingStatus.ACTIVE ||
      listing.provider.status !== AccountStatus.ACTIVE
    ) {
      throw new BadRequestException('This service is not currently available');
    }
    if (listing.providerId === actor.id) {
      throw new BadRequestException('You cannot request your own service');
    }

    const duplicate = await this.requests.existsBy({
      listingId: listing.id,
      customerId: actor.id,
      status: In(OPEN_STATUSES),
    });
    if (duplicate) {
      throw new ConflictException(
        'You already have an open request for this service',
      );
    }

    const customer = await this.usersService.findById(actor.id);
    const latitude = dto.latitude ?? customer.latitude;
    const longitude = dto.longitude ?? customer.longitude;
    const address = dto.address ?? customer.address;
    if (latitude == null || longitude == null || !address) {
      throw new BadRequestException(
        'A service location is required. Set your location in your profile or include it in the request.',
      );
    }

    const request = this.requests.create({
      listingId: listing.id,
      customerId: actor.id,
      providerId: listing.providerId,
      status: RequestStatus.PENDING,
      message: dto.message ?? null,
      preferredDate: dto.preferredDate ? new Date(dto.preferredDate) : null,
      address,
      latitude,
      longitude,
      quotedPrice: listing.price,
    });
    const saved = await this.requests.save(request);
    return this.findOne(actor, saved.id);
  }

  async list(
    actor: AuthUser,
    dto: ListRequestsDto,
  ): Promise<Paginated<RequestView>> {
    const where =
      actor.role === Role.PROVIDER
        ? { providerId: actor.id }
        : { customerId: actor.id };
    const [rows, total] = await this.requests.findAndCount({
      where: { ...where, ...(dto.status && { status: dto.status }) },
      relations: {
        listing: { category: true },
        customer: true,
        provider: true,
      },
      withDeleted: true,
      order: { createdAt: 'DESC' },
      skip: (dto.page - 1) * dto.limit,
      take: dto.limit,
    });
    const reviewed = await this.reviewedRequestIds(rows.map((r) => r.id));
    return paginate(
      rows.map((r) => this.toView(r, reviewed)),
      total,
      dto.page,
      dto.limit,
    );
  }

  async findOne(actor: AuthUser, id: string): Promise<RequestView> {
    const request = await this.load(id);
    const isParticipant =
      request.customerId === actor.id || request.providerId === actor.id;
    if (!isParticipant && actor.role !== Role.ADMIN) {
      throw new NotFoundException('Request not found');
    }
    const reviewed = await this.reviewedRequestIds([request.id]);
    return this.toView(request, reviewed);
  }

  accept(actor: AuthUser, id: string, note?: string) {
    return this.transition(
      actor,
      id,
      RequestStatus.ACCEPTED,
      'provider',
      (r) => {
        r.respondedAt = new Date();
        r.providerNote = note ?? r.providerNote;
      },
    );
  }

  reject(actor: AuthUser, id: string, reason: string) {
    return this.transition(
      actor,
      id,
      RequestStatus.REJECTED,
      'provider',
      (r) => {
        r.respondedAt = new Date();
        r.providerNote = reason;
      },
    );
  }

  complete(actor: AuthUser, id: string, note?: string) {
    return this.transition(
      actor,
      id,
      RequestStatus.COMPLETED,
      'provider',
      (r) => {
        r.completedAt = new Date();
        if (note) r.providerNote = note;
      },
    );
  }

  async cancel(actor: AuthUser, id: string, reason?: string) {
    const request = await this.load(id);
    const role: RequestActor =
      request.customerId === actor.id ? 'customer' : 'provider';
    return this.transition(actor, id, RequestStatus.CANCELLED, role, (r) => {
      r.cancelledAt = new Date();
      if (reason) r.providerNote = reason;
    });
  }

  /** Raw entity for other modules (reviews, reports). */
  async getEntity(id: string): Promise<ServiceRequest> {
    const request = await this.requests.findOne({
      where: { id },
      withDeleted: true,
    });
    if (!request) throw new NotFoundException('Request not found');
    return request;
  }

  async providerStats(providerId: string): Promise<ProviderStats> {
    const grouped = await this.requests
      .createQueryBuilder('r')
      .select('r.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .where('r.providerId = :providerId', { providerId })
      .groupBy('r.status')
      .getRawMany<{ status: RequestStatus; count: string | number }>();

    const counts = Object.fromEntries(
      Object.values(RequestStatus).map((s) => [s, 0]),
    ) as Record<RequestStatus, number>;
    for (const row of grouped) counts[row.status] = Number(row.count);

    const revenueRow = await this.requests
      .createQueryBuilder('r')
      .select('COALESCE(SUM(r.quotedPrice), 0)', 'sum')
      .where('r.providerId = :providerId', { providerId })
      .andWhere('r.status = :status', { status: RequestStatus.COMPLETED })
      .getRawOne<{ sum: string | number }>();

    const ratingRow = await this.reviews
      .createQueryBuilder('rv')
      .select('AVG(rv.rating)', 'avg')
      .addSelect('COUNT(*)', 'count')
      .where('rv.providerId = :providerId', { providerId })
      .andWhere('rv.isHidden = :hidden', { hidden: false })
      .getRawOne<{ avg: string | number | null; count: string | number }>();

    const listings = await this.listingsService.findByProvider(providerId);
    const responded = counts.ACCEPTED + counts.COMPLETED + counts.REJECTED;
    const ratingCount = Number(ratingRow?.count ?? 0);

    return {
      requests: counts,
      totalRequests: Object.values(counts).reduce((a, b) => a + b, 0),
      completedRevenue: roundTo(Number(revenueRow?.sum ?? 0), 2),
      acceptanceRate:
        responded === 0
          ? null
          : roundTo((counts.ACCEPTED + counts.COMPLETED) / responded, 3),
      activeListings: listings.filter((l) => l.status === ListingStatus.ACTIVE)
        .length,
      totalListings: listings.length,
      ratingAverage: ratingCount
        ? roundTo(Number(ratingRow?.avg ?? 0), 2)
        : null,
      ratingCount,
    };
  }

  // ---------------------------------------------------------------------------

  private async transition(
    actor: AuthUser,
    id: string,
    to: RequestStatus,
    as: RequestActor,
    mutate: (r: ServiceRequest) => void,
  ): Promise<RequestView> {
    const request = await this.load(id);
    const ownerId = as === 'provider' ? request.providerId : request.customerId;
    if (ownerId !== actor.id) {
      throw new ForbiddenException('You are not part of this request');
    }
    assertTransition(request.status, to, as);
    request.status = to;
    mutate(request);
    await this.requests.save(request);
    return this.findOne(actor, id);
  }

  private async load(id: string): Promise<ServiceRequest> {
    const request = await this.requests.findOne({
      where: { id },
      relations: {
        listing: { category: true },
        customer: true,
        provider: true,
      },
      withDeleted: true,
    });
    if (!request) throw new NotFoundException('Request not found');
    return request;
  }

  private async reviewedRequestIds(ids: string[]): Promise<Set<string>> {
    if (ids.length === 0) return new Set();
    const rows = await this.reviews.find({
      where: { requestId: In(ids) },
      select: { requestId: true },
    });
    return new Set(rows.map((r) => r.requestId));
  }

  private toView(r: ServiceRequest, reviewed: Set<string>): RequestView {
    const { listing, customer, provider, ...rest } = r;
    return {
      ...rest,
      listing: listing
        ? {
            id: listing.id,
            title: listing.title,
            price: listing.price,
            priceUnit: listing.priceUnit,
            currency: listing.currency,
            address: listing.address,
            categoryName: listing.category?.name ?? null,
          }
        : null,
      ...(customer && { customer: toPublicCustomer(customer) }),
      ...(provider && { provider: toPublicProvider(provider) }),
      distanceKm: listing
        ? roundTo(
            haversineKm(listing, {
              latitude: r.latitude,
              longitude: r.longitude,
            }),
            2,
          )
        : null,
      hasReview: reviewed.has(r.id),
    };
  }
}
