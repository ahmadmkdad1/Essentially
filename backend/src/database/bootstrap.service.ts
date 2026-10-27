import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CategoriesService } from '../categories/categories.module.js';
import { Role } from '../common/enums.js';
import { UsersService } from '../users/users.service.js';

/** Guarantees the reference data every environment needs. */
@Injectable()
export class BootstrapService implements OnApplicationBootstrap {
  private readonly logger = new Logger(BootstrapService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly categories: CategoriesService,
    private readonly users: UsersService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    await this.categories.ensureDefaults();

    const email = this.config.get<string>(
      'ADMIN_EMAIL',
      'admin@essentially.app',
    );
    const password = this.config.get<string>('ADMIN_PASSWORD');
    if (!password) {
      this.logger.warn(
        'ADMIN_PASSWORD is not set — skipping admin account bootstrap.',
      );
      return;
    }
    if (!(await this.users.findByEmailWithPassword(email))) {
      await this.users.create({
        fullName: this.config.get<string>('ADMIN_NAME', 'Admin Team'),
        email,
        password,
        role: Role.ADMIN,
      });
      this.logger.log(`Created admin account ${email}`);
    }
  }
}
