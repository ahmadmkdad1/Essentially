import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../common/decorators/auth.decorators.js';
import { PaginationQueryDto } from '../common/dto/pagination.dto.js';
import { Role } from '../common/enums.js';
import { AdminService } from './admin.service.js';
import {
  ListAdminListingsDto,
  ListReportsDto,
  ListUsersDto,
  ReasonDto,
  ResolveReportDto,
  SetUserStatusDto,
} from './dto/admin.dto.js';
import { ModerationService } from './moderation.service.js';

@ApiTags('Admin')
@ApiBearerAuth()
@Roles(Role.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly moderation: ModerationService,
  ) {}

  @Get('stats')
  stats() {
    return this.adminService.stats();
  }

  // Reports -------------------------------------------------------------------

  @Get('reports')
  listReports(@Query() dto: ListReportsDto) {
    return this.adminService.listReports(dto);
  }

  @Get('reports/:id')
  getReport(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.getReport(id);
  }

  @Post('reports/:id/resolve')
  async resolveReport(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ResolveReportDto,
  ) {
    await this.moderation.resolveReport(admin, id, dto);
    return this.adminService.getReport(id);
  }

  // Users ---------------------------------------------------------------------

  @Get('users')
  listUsers(@Query() dto: ListUsersDto) {
    return this.adminService.listUsers(dto);
  }

  @Get('users/:id')
  getUser(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.getUser(id);
  }

  @Patch('users/:id/status')
  setUserStatus(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetUserStatusDto,
  ) {
    return this.moderation.updateUserStatus(
      admin,
      id,
      dto.status,
      dto.reason,
      dto.suspendDays,
    );
  }

  @Post('users/:id/warn')
  warnUser(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.moderation.warn(admin, id, dto.reason);
  }

  // Services ------------------------------------------------------------------

  @Get('services')
  listListings(@Query() dto: ListAdminListingsDto) {
    return this.adminService.listListings(dto);
  }

  @Patch('services/:id/remove')
  removeListing(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.moderation.removeListingDirect(admin, id, dto.reason);
  }

  @Patch('services/:id/restore')
  restoreListing(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.moderation.restoreListing(admin, id, dto.reason);
  }

  // Reviews -------------------------------------------------------------------

  @Patch('reviews/:id/hide')
  hideReview(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.moderation.hideReviewDirect(admin, id, dto.reason);
  }

  // Audit ---------------------------------------------------------------------

  @Get('audit-log')
  auditLog(@Query() dto: PaginationQueryDto) {
    return this.adminService.auditLog(dto);
  }
}
