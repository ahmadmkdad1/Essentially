import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThanOrEqual, ObjectLiteral, Repository } from 'typeorm';
import { paginate, PaginationQueryDto } from '../common/dto/pagination.dto.js';
import {
  AccountStatus,
  ListingStatus,
  ReportStatus,
  RequestStatus,
  Role,
} from '../common/enums.js';
import { Listing } from '../listings/listing.entity.js';
import { toPublicProvider } from '../listings/listing.mapper.js';
import { Report } from '../reports/report.entity.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';
import { AuditLog } from './audit-log.entity.js';
import {
  ListAdminListingsDto,
  ListReportsDto,
  ListUsersDto,
} from './dto/admin.dto.js';

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

function zeroed<E extends string>(values: E[]): Record<E, number> {
  return Object.fromEntries(values.map((v) => [v, 0])) as Record<E, number>;
}

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Listing) private readonly listings: Repository<Listing>,
    @InjectRepository(ServiceRequest)
    private readonly requests: Repository<ServiceRequest>,
    @InjectRepository(Report) private readonly reports: Repository<Report>,
    @InjectRepository(Review) private readonly reviews: Repository<Review>,
    @InjectRepository(AuditLog)
    private readonly auditLogs: Repository<AuditLog>,
  ) {}

  async stats() {
    const weekAgo = new Date(Date.now() - WEEK_MS);
    const [
      usersByRole,
      usersByStatus,
      listingsByStatus,
      requestsByStatus,
      reportsByStatus,
    ] = await Promise.all([
      this.groupCount(this.users, 'role', Object.values(Role)),
      this.groupCount(this.users, 'status', Object.values(AccountStatus)),
      this.groupCount(this.listings, 'status', Object.values(ListingStatus)),
      this.groupCount(this.requests, 'status', Object.values(RequestStatus)),
      this.groupCount(this.reports, 'status', Object.values(ReportStatus)),
    ]);
    const [newUsersThisWeek, reportsThisWeek, requestsThisWeek] =
      await Promise.all([
        this.users.countBy({ createdAt: MoreThanOrEqual(weekAgo) }),
        this.reports.countBy({ createdAt: MoreThanOrEqual(weekAgo) }),
        this.requests.countBy({ createdAt: MoreThanOrEqual(weekAgo) }),
      ]);

    return {
      users: {
        byRole: usersByRole,
        byStatus: usersByStatus,
        newThisWeek: newUsersThisWeek,
      },
      listings: { byStatus: listingsByStatus },
      requests: { byStatus: requestsByStatus, newThisWeek: requestsThisWeek },
      reports: { byStatus: reportsByStatus, newThisWeek: reportsThisWeek },
    };
  }

  async listReports(dto: ListReportsDto) {
    const [rows, total] = await this.reports.findAndCount({
      where: {
        ...(dto.status && { status: dto.status }),
        ...(dto.targetType && { targetType: dto.targetType }),
      },
      relations: {
        reporter: true,
        targetUser: true,
        targetListing: true,
        targetReview: true,
      },
      withDeleted: true,
      // Oldest open reports first so the queue is handled fairly.
      order: { createdAt: dto.status === ReportStatus.OPEN ? 'ASC' : 'DESC' },
      skip: (dto.page - 1) * dto.limit,
      take: dto.limit,
    });
    const offenderCounts = await this.reportCountsFor(
      rows.map((r) => r.targetUserId),
    );
    return paginate(
      rows.map((r) =>
        this.toReportView(r, offenderCounts.get(r.targetUserId) ?? 0),
      ),
      total,
      dto.page,
      dto.limit,
    );
  }

  async getReport(id: string) {
    const report = await this.reports.findOne({
      where: { id },
      relations: {
        reporter: true,
        targetUser: true,
        targetListing: true,
        targetReview: true,
        resolvedBy: true,
      },
      withDeleted: true,
    });
    if (!report) throw new NotFoundException('Report not found');
    const counts = await this.reportCountsFor([report.targetUserId]);
    const history = await this.auditLogs.find({
      where: { targetId: report.targetUserId },
      order: { createdAt: 'DESC' },
      take: 10,
    });
    return {
      ...this.toReportView(report, counts.get(report.targetUserId) ?? 0),
      resolvedBy: report.resolvedBy
        ? { id: report.resolvedBy.id, fullName: report.resolvedBy.fullName }
        : null,
      targetUserHistory: history,
    };
  }

  async listUsers(dto: ListUsersDto) {
    const qb = this.users
      .createQueryBuilder('u')
      .orderBy('u.createdAt', 'DESC');
    if (dto.role) qb.andWhere('u.role = :role', { role: dto.role });
    if (dto.status) qb.andWhere('u.status = :status', { status: dto.status });
    if (dto.q) {
      qb.andWhere(
        '(LOWER(u.fullName) LIKE :q OR LOWER(u.email) LIKE :q OR LOWER(u.businessName) LIKE :q)',
        { q: `%${dto.q.toLowerCase()}%` },
      );
    }
    const [rows, total] = await qb
      .skip((dto.page - 1) * dto.limit)
      .take(dto.limit)
      .getManyAndCount();
    const counts = await this.reportCountsFor(rows.map((u) => u.id));
    return paginate(
      rows.map((u) => ({ ...u, openReports: counts.get(u.id) ?? 0 })),
      total,
      dto.page,
      dto.limit,
    );
  }

  async getUser(id: string) {
    const user = await this.users.findOneBy({ id });
    if (!user) throw new NotFoundException('User not found');
    const column = user.role === Role.PROVIDER ? 'providerId' : 'customerId';
    const [listings, requests, reportsAgainst, reportsFiled, history] =
      await Promise.all([
        user.role === Role.PROVIDER
          ? this.listings.find({
              where: { providerId: id },
              relations: { category: true },
              order: { createdAt: 'DESC' },
            })
          : Promise.resolve([]),
        this.requests.countBy({ [column]: id }),
        this.reports.find({
          where: { targetUserId: id },
          order: { createdAt: 'DESC' },
          take: 20,
        }),
        this.reports.countBy({ reporterId: id }),
        this.auditLogs.find({
          where: { targetId: id },
          order: { createdAt: 'DESC' },
          take: 20,
        }),
      ]);
    return {
      user,
      listings,
      totals: { requests, reportsAgainst: reportsAgainst.length, reportsFiled },
      reportsAgainst,
      history,
    };
  }

  async listListings(dto: ListAdminListingsDto) {
    const qb = this.listings
      .createQueryBuilder('l')
      .innerJoinAndSelect('l.provider', 'p')
      .innerJoinAndSelect('l.category', 'c')
      .orderBy('l.createdAt', 'DESC');
    if (dto.status) qb.andWhere('l.status = :status', { status: dto.status });
    if (dto.q) {
      qb.andWhere(
        '(LOWER(l.title) LIKE :q OR LOWER(p.businessName) LIKE :q OR LOWER(p.fullName) LIKE :q)',
        {
          q: `%${dto.q.toLowerCase()}%`,
        },
      );
    }
    const [rows, total] = await qb
      .skip((dto.page - 1) * dto.limit)
      .take(dto.limit)
      .getManyAndCount();
    const reportCounts = await this.listingReportCounts(rows.map((l) => l.id));
    return paginate(
      rows.map(({ provider, ...l }) => ({
        ...l,
        provider: {
          ...toPublicProvider(provider),
          status: provider.status,
          email: provider.email,
        },
        openReports: reportCounts.get(l.id) ?? 0,
      })),
      total,
      dto.page,
      dto.limit,
    );
  }

  async auditLog(dto: PaginationQueryDto) {
    const [rows, total] = await this.auditLogs.findAndCount({
      relations: { admin: true },
      order: { createdAt: 'DESC' },
      skip: (dto.page - 1) * dto.limit,
      take: dto.limit,
    });
    return paginate(
      rows.map(({ admin, ...entry }) => ({
        ...entry,
        admin: { id: admin.id, fullName: admin.fullName },
      })),
      total,
      dto.page,
      dto.limit,
    );
  }

  // ---------------------------------------------------------------------------

  private async groupCount<E extends ObjectLiteral, K extends string>(
    repo: Repository<E>,
    column: string,
    values: K[],
  ): Promise<Record<K, number>> {
    const rows = await repo
      .createQueryBuilder('t')
      .select(`t.${column}`, 'key')
      .addSelect('COUNT(*)', 'count')
      .groupBy(`t.${column}`)
      .getRawMany<{ key: K; count: string | number }>();
    const result = zeroed(values);
    for (const row of rows) result[row.key] = Number(row.count);
    return result;
  }

  /** Number of OPEN reports against each user — highlights repeat offenders. */
  private async reportCountsFor(
    userIds: string[],
  ): Promise<Map<string, number>> {
    if (userIds.length === 0) return new Map();
    const rows = await this.reports
      .createQueryBuilder('r')
      .select('r.targetUserId', 'id')
      .addSelect('COUNT(*)', 'count')
      .where('r.targetUserId IN (:...ids)', { ids: [...new Set(userIds)] })
      .andWhere('r.status = :status', { status: ReportStatus.OPEN })
      .groupBy('r.targetUserId')
      .getRawMany<{ id: string; count: string | number }>();
    return new Map(rows.map((r) => [r.id, Number(r.count)]));
  }

  private async listingReportCounts(
    ids: string[],
  ): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows = await this.reports
      .createQueryBuilder('r')
      .select('r.targetListingId', 'id')
      .addSelect('COUNT(*)', 'count')
      .where('r.targetListingId IN (:...ids)', { ids })
      .andWhere('r.status = :status', { status: ReportStatus.OPEN })
      .groupBy('r.targetListingId')
      .getRawMany<{ id: string; count: string | number }>();
    return new Map(rows.map((r) => [r.id, Number(r.count)]));
  }

  private toReportView(r: Report, openReportsAgainstTarget: number) {
    return {
      id: r.id,
      targetType: r.targetType,
      reason: r.reason,
      details: r.details,
      status: r.status,
      actionTaken: r.actionTaken,
      resolutionNote: r.resolutionNote,
      createdAt: r.createdAt,
      resolvedAt: r.resolvedAt,
      reporter: {
        id: r.reporter.id,
        fullName: r.reporter.fullName,
        email: r.reporter.email,
        role: r.reporter.role,
      },
      targetUser: {
        id: r.targetUser.id,
        fullName: r.targetUser.fullName,
        businessName: r.targetUser.businessName,
        email: r.targetUser.email,
        role: r.targetUser.role,
        status: r.targetUser.status,
        warningCount: r.targetUser.warningCount,
        openReports: openReportsAgainstTarget,
      },
      targetListing: r.targetListing
        ? {
            id: r.targetListing.id,
            title: r.targetListing.title,
            status: r.targetListing.status,
            price: r.targetListing.price,
            currency: r.targetListing.currency,
          }
        : null,
      targetReview: r.targetReview
        ? {
            id: r.targetReview.id,
            rating: r.targetReview.rating,
            comment: r.targetReview.comment,
            isHidden: r.targetReview.isHidden,
          }
        : null,
    };
  }
}
