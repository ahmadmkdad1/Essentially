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
import { Role } from '../common/enums.js';
import {
  CreateRequestDto,
  ListRequestsDto,
  ProviderNoteDto,
  RejectRequestDto,
} from './dto/requests.dto.js';
import { RequestsService } from './requests.service.js';

@ApiTags('Service requests')
@ApiBearerAuth()
@Controller('requests')
export class RequestsController {
  constructor(private readonly requestsService: RequestsService) {}

  @Roles(Role.USER)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateRequestDto) {
    return this.requestsService.create(user, dto);
  }

  /** Customers get the requests they sent; providers get the ones they received. */
  @Roles(Role.USER, Role.PROVIDER)
  @Get()
  list(@CurrentUser() user: AuthUser, @Query() dto: ListRequestsDto) {
    return this.requestsService.list(user, dto);
  }

  @Roles(Role.PROVIDER)
  @Get('stats')
  stats(@CurrentUser() user: AuthUser) {
    return this.requestsService.providerStats(user.id);
  }

  @Get(':id')
  findOne(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.requestsService.findOne(user, id);
  }

  @Roles(Role.PROVIDER)
  @Patch(':id/accept')
  accept(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ProviderNoteDto,
  ) {
    return this.requestsService.accept(user, id, dto.note);
  }

  @Roles(Role.PROVIDER)
  @Patch(':id/reject')
  reject(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectRequestDto,
  ) {
    return this.requestsService.reject(user, id, dto.reason);
  }

  @Roles(Role.PROVIDER)
  @Patch(':id/complete')
  complete(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ProviderNoteDto,
  ) {
    return this.requestsService.complete(user, id, dto.note);
  }

  @Roles(Role.USER, Role.PROVIDER)
  @Patch(':id/cancel')
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ProviderNoteDto,
  ) {
    return this.requestsService.cancel(user, id, dto.note);
  }
}
