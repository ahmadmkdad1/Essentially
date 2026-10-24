import { Body, Controller, Get, HttpCode, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/auth.decorators.js';
import type { AuthUser } from '../auth/auth.types.js';
import {
  ChangePasswordDto,
  UpdateLocationDto,
  UpdateProfileDto,
} from './dto/users.dto.js';
import { User } from './user.entity.js';
import { UsersService } from './users.service.js';

@ApiTags('Account')
@ApiBearerAuth()
@Controller('users/me')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @ApiOkResponse({ type: User })
  me(@CurrentUser() user: AuthUser) {
    return this.usersService.findById(user.id);
  }

  @Patch()
  @ApiOkResponse({ type: User })
  updateProfile(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(user.id, dto);
  }

  @Patch('location')
  @ApiOkResponse({ type: User })
  updateLocation(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateLocationDto,
  ) {
    return this.usersService.updateLocation(user.id, dto);
  }

  @Patch('password')
  @HttpCode(204)
  async changePassword(
    @CurrentUser() user: AuthUser,
    @Body() dto: ChangePasswordDto,
  ) {
    await this.usersService.changePassword(user.id, dto);
  }
}
