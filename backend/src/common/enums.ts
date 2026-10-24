export enum Role {
  USER = 'USER',
  PROVIDER = 'PROVIDER',
  ADMIN = 'ADMIN',
}

export enum AccountStatus {
  ACTIVE = 'ACTIVE',
  SUSPENDED = 'SUSPENDED',
  BANNED = 'BANNED',
}

export enum PriceUnit {
  FIXED = 'FIXED',
  HOURLY = 'HOURLY',
  MONTHLY = 'MONTHLY',
}

export enum ListingStatus {
  ACTIVE = 'ACTIVE',
  /** Temporarily switched off by its provider. */
  PAUSED = 'PAUSED',
  /** Taken down by an admin after a violation. */
  REMOVED = 'REMOVED',
}

export enum RequestStatus {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  REJECTED = 'REJECTED',
  CANCELLED = 'CANCELLED',
  COMPLETED = 'COMPLETED',
}

export enum ReportTargetType {
  USER = 'USER',
  LISTING = 'LISTING',
  REVIEW = 'REVIEW',
}

export enum ReportReason {
  FRAUD = 'FRAUD',
  INAPPROPRIATE_CONTENT = 'INAPPROPRIATE_CONTENT',
  HARASSMENT = 'HARASSMENT',
  SPAM = 'SPAM',
  MISLEADING_PRICING = 'MISLEADING_PRICING',
  NO_SHOW = 'NO_SHOW',
  OTHER = 'OTHER',
}

export enum ReportStatus {
  OPEN = 'OPEN',
  RESOLVED = 'RESOLVED',
  DISMISSED = 'DISMISSED',
}

export enum ModerationAction {
  NONE = 'NONE',
  WARN_USER = 'WARN_USER',
  REMOVE_LISTING = 'REMOVE_LISTING',
  REMOVE_REVIEW = 'REMOVE_REVIEW',
  SUSPEND_USER = 'SUSPEND_USER',
  BAN_USER = 'BAN_USER',
  REACTIVATE_USER = 'REACTIVATE_USER',
  RESTORE_LISTING = 'RESTORE_LISTING',
}
