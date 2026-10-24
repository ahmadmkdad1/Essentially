import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth.types.js';
import {
  CurrentUser,
  Public,
  Roles,
} from '../common/decorators/auth.decorators.js';
import { Role } from '../common/enums.js';
import {
  CreateListingDto,
  ListingWithDistance,
  SearchListingsDto,
  SetListingActiveDto,
  UpdateListingDto,
} from './dto/listings.dto.js';
import { Listing } from './listing.entity.js';
import { ListingsService } from './listings.service.js';

@ApiTags('Services')
@Controller('services')
export class ListingsController {
  constructor(private readonly listingsService: ListingsService) {}

  @Public()
  @Get()
  @ApiOkResponse({
    description:
      'Paginated list of services, nearest first when lat/lng are given',
  })
  search(@Query() dto: SearchListingsDto) {
    return this.listingsService.search(dto);
  }

  @ApiBearerAuth()
  @Roles(Role.PROVIDER)
  @Get('mine')
  @ApiOkResponse({ type: [Listing] })
  mine(@CurrentUser() user: AuthUser) {
    return this.listingsService.findByProvider(user.id);
  }

  @Public()
  @Get(':id')
  @ApiQuery({ name: 'lat', required: false, type: Number })
  @ApiQuery({ name: 'lng', required: false, type: Number })
  @ApiOkResponse({ type: ListingWithDistance })
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser | undefined,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const latitude = Number(lat);
    const longitude = Number(lng);
    const origin =
      lat !== undefined &&
      lng !== undefined &&
      Number.isFinite(latitude) &&
      Number.isFinite(longitude)
        ? { latitude, longitude }
        : undefined;
    return this.listingsService.findOne(id, user, origin);
  }

  @ApiBearerAuth()
  @Roles(Role.PROVIDER)
  @Post()
  @ApiOkResponse({ type: Listing })
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateListingDto) {
    return this.listingsService.create(user, dto);
  }

  @ApiBearerAuth()
  @Roles(Role.PROVIDER)
  @Patch(':id')
  @ApiOkResponse({ type: Listing })
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateListingDto,
  ) {
    return this.listingsService.update(user, id, dto);
  }

  @ApiBearerAuth()
  @Roles(Role.PROVIDER)
  @Patch(':id/status')
  @ApiOkResponse({ type: Listing })
  setStatus(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetListingActiveDto,
  ) {
    return this.listingsService.setStatus(user, id, dto.status);
  }

  @ApiBearerAuth()
  @Roles(Role.PROVIDER)
  @Delete(':id')
  @HttpCode(204)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.listingsService.remove(user, id);
  }
}
