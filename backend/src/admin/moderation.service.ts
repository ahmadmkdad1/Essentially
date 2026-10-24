import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager, In } from 'typeorm';
import type { AuthUser } from '../auth/auth.types.js';
import {
  AccountStatus,
  ListingStatus,
  ModerationAction,
  ReportStatus,
  RequestStatus,
  Role,
} from '../common/enums.js';
import { Listing } from '../listings/listing.entity.js';
import { Report } from '../reports/report.entity.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';
import { AuditLog } from './audit-log.entity.js';
import { ResolveReportDto } from './dto/admin.dto.js';

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Executes moderation actions. Every action runs in a transaction and writes
 * an audit log entry, so the admin trail is always consistent with the data.
 */
@Injectable()
export class ModerationService {
  constructor(private readonly dataSource: DataSource) {}

  async resolveReport(
    admin: AuthUser,
    reportId: string,
    dto: ResolveReportDto,
  ) {
    return this.dataSource.transaction(async (em) => {
      const report = await em.findOne(Report, { where: { id: reportId } });
      if (!report) throw new NotFoundException('Report not found');
      if (report.status !== ReportStatus.OPEN) {
        throw new BadRequestException('This report has already been handled');
      }

      switch (dto.action) {
        case ModerationAction.NONE:
          break;
        case ModerationAction.WARN_USER:
          await this.warnUser(
            em,
            admin,
            report.targetUserId,
            dto.note,
            report.id,
          );
          break;
        case ModerationAction.REMOVE_LISTING:
          if (!report.targetListingId) {
            throw new BadRequestException('This report is not about a service');
          }
          await this.removeListing(
            em,
            admin,
            report.targetListingId,
            dto.note,
            report.id,
          );
          break;
        case ModerationAction.REMOVE_REVIEW:
          if (!report.targetReviewId) {
            throw new BadRequestException('This report is not about a review');
          }
          await this.setReviewHidden(
            em,
            admin,
            report.targetReviewId,
            dto.note,
            report.id,
          );
          break;
        case ModerationAction.SUSPEND_USER:
        case ModerationAction.BAN_USER:
          await this.setUserStatus(
            em,
            admin,
            report.targetUserId,
            dto.action === ModerationAction.BAN_USER
              ? AccountStatus.BANNED
              : AccountStatus.SUSPENDED,
            dto.note,
            dto.suspendDays,
            report.id,
          );
          break;
      }

      report.status =
        dto.action === ModerationAction.NONE
          ? ReportStatus.DISMISSED
          : ReportStatus.RESOLVED;
      report.actionTaken = dto.action;
      report.resolutionNote = dto.note;
      report.resolvedById = admin.id;
      report.resolvedAt = new Date();
      await em.save(report);

      if (dto.action === ModerationAction.NONE) {
        await this.log(
          em,
          admin,
          ModerationAction.NONE,
          'REPORT',
          report.id,
          `Report #${report.id.slice(0, 8)}`,
          dto.note,
          report.id,
        );
      }
      return report;
    });
  }

  updateUserStatus(
    admin: AuthUser,
    userId: string,
    status: AccountStatus,
    reason: string,
    suspendDays?: number,
  ) {
    return this.dataSource.transaction((em) =>
      this.setUserStatus(em, admin, userId, status, reason, suspendDays, null),
    );
  }

  warn(admin: AuthUser, userId: string, reason: string) {
    return this.dataSource.transaction((em) =>
      this.warnUser(em, admin, userId, reason, null),
    );
  }

  removeListingDirect(admin: AuthUser, listingId: string, reason: string) {
    return this.dataSource.transaction((em) =>
      this.removeListing(em, admin, listingId, reason, null),
    );
  }

  restoreListing(admin: AuthUser, listingId: string, reason: string) {
    return this.dataSource.transaction(async (em) => {
      const listing = await em.findOne(Listing, { where: { id: listingId } });
      if (!listing) throw new NotFoundException('Service not found');
      if (listing.status !== ListingStatus.REMOVED) {
        throw new BadRequestException('Only removed services can be restored');
      }
      listing.status = ListingStatus.ACTIVE;
      listing.removalReason = null;
      await em.save(listing);
      await this.log(
        em,
        admin,
        ModerationAction.RESTORE_LISTING,
        'LISTING',
        listing.id,
        listing.title,
        reason,
        null,
      );
      return listing;
    });
  }

  hideReviewDirect(admin: AuthUser, reviewId: string, reason: string) {
    return this.dataSource.transaction((em) =>
      this.setReviewHidden(em, admin, reviewId, reason, null),
    );
  }

  // ---------------------------------------------------------------------------

  private async loadModeratableUser(
    em: EntityManager,
    admin: AuthUser,
    userId: string,
  ) {
    const user = await em.findOne(User, { where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.role === Role.ADMIN || user.id === admin.id) {
      throw new ForbiddenException(
        'Administrator accounts cannot be moderated',
      );
    }
    return user;
  }

  private async warnUser(
    em: EntityManager,
    admin: AuthUser,
    userId: string,
    reason: string,
    reportId: string | null,
  ) {
    const user = await this.loadModeratableUser(em, admin, userId);
    user.warningCount += 1;
    await em.save(user);
    await this.log(
      em,
      admin,
      ModerationAction.WARN_USER,
      'USER',
      user.id,
      user.email,
      reason,
      reportId,
    );
    return user;
  }

  private async setUserStatus(
    em: EntityManager,
    admin: AuthUser,
    userId: string,
    status: AccountStatus,
    reason: string,
    suspendDays: number | undefined,
    reportId: string | null,
  ) {
    const user = await this.loadModeratableUser(em, admin, userId);
    if (status === AccountStatus.SUSPENDED && !suspendDays) {
      throw new BadRequestException(
        'suspendDays is required to suspend an account',
      );
    }

    user.status = status;
    user.statusReason = status === AccountStatus.ACTIVE ? null : reason;
    user.suspendedUntil =
      status === AccountStatus.SUSPENDED
        ? new Date(Date.now() + suspendDays! * DAY_MS)
        : null;
    await em.save(user);

    if (status === AccountStatus.BANNED) {
      await this.cancelOpenRequestsOf(
        em,
        user,
        'Cancelled: the account involved was banned by moderation.',
      );
    }

    const action =
      status === AccountStatus.ACTIVE
        ? ModerationAction.REACTIVATE_USER
        : status === AccountStatus.BANNED
          ? ModerationAction.BAN_USER
          : ModerationAction.SUSPEND_USER;
    const detail =
      status === AccountStatus.SUSPENDED
        ? `${reason} (suspended for ${suspendDays} days)`
        : reason;
    await this.log(
      em,
      admin,
      action,
      'USER',
      user.id,
      user.email,
      detail,
      reportId,
    );
    return user;
  }

  private async removeListing(
    em: EntityManager,
    admin: AuthUser,
    listingId: string,
    reason: string,
    reportId: string | null,
  ) {
    const listing = await em.findOne(Listing, { where: { id: listingId } });
    if (!listing) throw new NotFoundException('Service not found');
    listing.status = ListingStatus.REMOVED;
    listing.removalReason = reason;
    await em.save(listing);

    await em.update(
      ServiceRequest,
      { listingId: listing.id, status: RequestStatus.PENDING },
      {
        status: RequestStatus.CANCELLED,
        cancelledAt: new Date(),
        providerNote: 'Cancelled: this service was removed by moderation.',
      },
    );
    await this.log(
      em,
      admin,
      ModerationAction.REMOVE_LISTING,
      'LISTING',
      listing.id,
      listing.title,
      reason,
      reportId,
    );
    return listing;
  }

  private async setReviewHidden(
    em: EntityManager,
    admin: AuthUser,
    reviewId: string,
    reason: string,
    reportId: string | null,
  ) {
    const review = await em.findOne(Review, { where: { id: reviewId } });
    if (!review) throw new NotFoundException('Review not found');
    review.isHidden = true;
    await em.save(review);

    const row = await em
      .createQueryBuilder(Review, 'r')
      .select('AVG(r.rating)', 'avg')
      .addSelect('COUNT(*)', 'count')
      .where('r.listingId = :listingId', { listingId: review.listingId })
      .andWhere('r.isHidden = :hidden', { hidden: false })
      .getRawOne<{ avg: string | number | null; count: string | number }>();
    await em.update(
      Listing,
      { id: review.listingId },
      {
        ratingAverage: Math.round(Number(row?.avg ?? 0) * 100) / 100,
        ratingCount: Number(row?.count ?? 0),
      },
    );

    await this.log(
      em,
      admin,
      ModerationAction.REMOVE_REVIEW,
      'REVIEW',
      review.id,
      review.comment.slice(0, 120),
      reason,
      reportId,
    );
    return review;
  }

  private async cancelOpenRequestsOf(
    em: EntityManager,
    user: User,
    note: string,
  ) {
    const column = user.role === Role.PROVIDER ? 'providerId' : 'customerId';
    await em.update(
      ServiceRequest,
      {
        [column]: user.id,
        status: In([RequestStatus.PENDING, RequestStatus.ACCEPTED]),
      },
      {
        status: RequestStatus.CANCELLED,
        cancelledAt: new Date(),
        providerNote: note,
      },
    );
  }

  private async log(
    em: EntityManager,
    admin: AuthUser,
    action: ModerationAction,
    targetType: string,
    targetId: string,
    targetLabel: string,
    reason: string,
    reportId: string | null,
  ) {
    await em.save(
      em.create(AuditLog, {
        adminId: admin.id,
        action,
        targetType,
        targetId,
        targetLabel: targetLabel.slice(0, 200),
        reason,
        reportId,
      }),
    );
  }
}
