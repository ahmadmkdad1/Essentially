import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto.js';
import {
  AccountStatus,
  ListingStatus,
  ModerationAction,
  ReportStatus,
  ReportTargetType,
  Role,
} from '../../common/enums.js';

export const REPORT_ACTIONS = [
  ModerationAction.NONE,
  ModerationAction.WARN_USER,
  ModerationAction.REMOVE_LISTING,
  ModerationAction.REMOVE_REVIEW,
  ModerationAction.SUSPEND_USER,
  ModerationAction.BAN_USER,
] as const;

export class ResolveReportDto {
  @ApiProperty({
    enum: REPORT_ACTIONS,
    description: 'NONE dismisses the report without taking action',
  })
  @IsIn(REPORT_ACTIONS)
  action: (typeof REPORT_ACTIONS)[number];

  @ApiProperty({
    example: 'Confirmed misleading pricing after reviewing the listing.',
  })
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  note: string;

  @ApiPropertyOptional({
    minimum: 1,
    maximum: 365,
    description: 'Required for SUSPEND_USER',
  })
  @ValidateIf(
    (o: ResolveReportDto) => o.action === ModerationAction.SUSPEND_USER,
  )
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  suspendDays?: number;
}

export class SetUserStatusDto {
  @ApiProperty({ enum: AccountStatus })
  @IsEnum(AccountStatus)
  status: AccountStatus;

  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 365 })
  @ValidateIf((o: SetUserStatusDto) => o.status === AccountStatus.SUSPENDED)
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  suspendDays?: number;
}

export class ReasonDto {
  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason: string;
}

export class ListReportsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: ReportStatus })
  @IsOptional()
  @IsEnum(ReportStatus)
  status?: ReportStatus;

  @ApiPropertyOptional({ enum: ReportTargetType })
  @IsOptional()
  @IsEnum(ReportTargetType)
  targetType?: ReportTargetType;
}

export class ListUsersDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional({ enum: AccountStatus })
  @IsOptional()
  @IsEnum(AccountStatus)
  status?: AccountStatus;

  @ApiPropertyOptional({ description: 'Search by name, email or business' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;
}

export class ListAdminListingsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: ListingStatus })
  @IsOptional()
  @IsEnum(ListingStatus)
  status?: ListingStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;
}
