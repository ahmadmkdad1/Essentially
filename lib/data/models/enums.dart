import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'json_utils.dart';

enum Role {
  user,
  provider,
  admin;

  String get api => name.toUpperCase();
  String get label => switch (this) {
    Role.user => 'Customer',
    Role.provider => 'Service provider',
    Role.admin => 'Administrator',
  };

  static Role parse(Object? v) => enumFromName(values, v, Role.user);
}

enum AccountStatus {
  active,
  suspended,
  banned;

  String get api => name.toUpperCase();
  String get label => humanize(name);
  Color get color => switch (this) {
    AccountStatus.active => AppColors.success,
    AccountStatus.suspended => AppColors.warning,
    AccountStatus.banned => AppColors.danger,
  };

  static AccountStatus parse(Object? v) => enumFromName(values, v, AccountStatus.active);
}

enum PriceUnit {
  fixed,
  hourly,
  monthly;

  String get api => name.toUpperCase();
  String get suffix => switch (this) {
    PriceUnit.fixed => '',
    PriceUnit.hourly => '/hr',
    PriceUnit.monthly => '/mo',
  };
  String get label => switch (this) {
    PriceUnit.fixed => 'Fixed price',
    PriceUnit.hourly => 'Per hour',
    PriceUnit.monthly => 'Per month',
  };

  static PriceUnit parse(Object? v) => enumFromName(values, v, PriceUnit.fixed);
}

enum ListingStatus {
  active,
  paused,
  removed;

  String get api => name.toUpperCase();
  String get label => switch (this) {
    ListingStatus.active => 'Active',
    ListingStatus.paused => 'Paused',
    ListingStatus.removed => 'Removed by admin',
  };
  Color get color => switch (this) {
    ListingStatus.active => AppColors.success,
    ListingStatus.paused => AppColors.textSecondary,
    ListingStatus.removed => AppColors.danger,
  };

  static ListingStatus parse(Object? v) => enumFromName(values, v, ListingStatus.active);
}

enum RequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  completed;

  String get api => name.toUpperCase();
  String get label => humanize(name);
  bool get isOpen => this == pending || this == accepted;

  Color get color => switch (this) {
    RequestStatus.pending => AppColors.warning,
    RequestStatus.accepted => AppColors.info,
    RequestStatus.rejected => AppColors.danger,
    RequestStatus.cancelled => AppColors.textMuted,
    RequestStatus.completed => AppColors.success,
  };

  IconData get icon => switch (this) {
    RequestStatus.pending => Icons.schedule_rounded,
    RequestStatus.accepted => Icons.handshake_outlined,
    RequestStatus.rejected => Icons.block_rounded,
    RequestStatus.cancelled => Icons.cancel_outlined,
    RequestStatus.completed => Icons.task_alt_rounded,
  };

  static RequestStatus parse(Object? v) => enumFromName(values, v, RequestStatus.pending);
}

enum ReportTargetType {
  user,
  listing,
  review;

  String get api => name.toUpperCase();
  String get label => switch (this) {
    ReportTargetType.user => 'Account',
    ReportTargetType.listing => 'Service',
    ReportTargetType.review => 'Review',
  };
  IconData get icon => switch (this) {
    ReportTargetType.user => Icons.person_outline_rounded,
    ReportTargetType.listing => Icons.storefront_outlined,
    ReportTargetType.review => Icons.rate_review_outlined,
  };

  static ReportTargetType parse(Object? v) => enumFromName(values, v, ReportTargetType.user);
}

enum ReportReason {
  fraud,
  inappropriateContent,
  harassment,
  spam,
  misleadingPricing,
  noShow,
  other;

  String get api => switch (this) {
    ReportReason.inappropriateContent => 'INAPPROPRIATE_CONTENT',
    ReportReason.misleadingPricing => 'MISLEADING_PRICING',
    ReportReason.noShow => 'NO_SHOW',
    _ => name.toUpperCase(),
  };
  String get label => humanize(api);

  static ReportReason parse(Object? v) {
    for (final r in values) {
      if (r.api == v?.toString()) return r;
    }
    return ReportReason.other;
  }
}

enum ReportStatus {
  open,
  resolved,
  dismissed;

  String get api => name.toUpperCase();
  String get label => humanize(name);
  Color get color => switch (this) {
    ReportStatus.open => AppColors.warning,
    ReportStatus.resolved => AppColors.success,
    ReportStatus.dismissed => AppColors.textMuted,
  };

  static ReportStatus parse(Object? v) => enumFromName(values, v, ReportStatus.open);
}

enum ModerationAction {
  none,
  warnUser,
  removeListing,
  removeReview,
  suspendUser,
  banUser,
  reactivateUser,
  restoreListing;

  String get api => switch (this) {
    ModerationAction.none => 'NONE',
    ModerationAction.warnUser => 'WARN_USER',
    ModerationAction.removeListing => 'REMOVE_LISTING',
    ModerationAction.removeReview => 'REMOVE_REVIEW',
    ModerationAction.suspendUser => 'SUSPEND_USER',
    ModerationAction.banUser => 'BAN_USER',
    ModerationAction.reactivateUser => 'REACTIVATE_USER',
    ModerationAction.restoreListing => 'RESTORE_LISTING',
  };

  String get label => switch (this) {
    ModerationAction.none => 'Dismiss (no violation)',
    ModerationAction.warnUser => 'Warn account',
    ModerationAction.removeListing => 'Remove service',
    ModerationAction.removeReview => 'Hide review',
    ModerationAction.suspendUser => 'Suspend account',
    ModerationAction.banUser => 'Ban account',
    ModerationAction.reactivateUser => 'Reactivate account',
    ModerationAction.restoreListing => 'Restore service',
  };

  IconData get icon => switch (this) {
    ModerationAction.none => Icons.do_not_disturb_alt_rounded,
    ModerationAction.warnUser => Icons.warning_amber_rounded,
    ModerationAction.removeListing => Icons.remove_shopping_cart_outlined,
    ModerationAction.removeReview => Icons.visibility_off_outlined,
    ModerationAction.suspendUser => Icons.pause_circle_outline_rounded,
    ModerationAction.banUser => Icons.gpp_bad_outlined,
    ModerationAction.reactivateUser => Icons.restart_alt_rounded,
    ModerationAction.restoreListing => Icons.restore_rounded,
  };

  Color get color => switch (this) {
    ModerationAction.none => AppColors.textSecondary,
    ModerationAction.warnUser => AppColors.warning,
    ModerationAction.removeListing || ModerationAction.removeReview => AppColors.violet,
    ModerationAction.suspendUser => AppColors.warning,
    ModerationAction.banUser => AppColors.danger,
    ModerationAction.reactivateUser || ModerationAction.restoreListing => AppColors.success,
  };

  static ModerationAction parse(Object? v) {
    for (final a in values) {
      if (a.api == v?.toString()) return a;
    }
    return ModerationAction.none;
  }
}

enum ListingSort {
  distance('distance', 'Nearest'),
  priceAsc('price_asc', 'Lowest price'),
  priceDesc('price_desc', 'Highest price'),
  rating('rating', 'Top rated'),
  newest('newest', 'Newest');

  const ListingSort(this.api, this.label);
  final String api;
  final String label;
}
