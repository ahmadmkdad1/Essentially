import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Listing } from '../listings/listing.entity.js';
import { Report } from '../reports/report.entity.js';
import { ServiceRequest } from '../requests/service-request.entity.js';
import { Review } from '../reviews/review.entity.js';
import { User } from '../users/user.entity.js';
import { AdminController } from './admin.controller.js';
import { AdminService } from './admin.service.js';
import { AuditLog } from './audit-log.entity.js';
import { ModerationService } from './moderation.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      Listing,
      ServiceRequest,
      Report,
      Review,
      AuditLog,
    ]),
  ],
  controllers: [AdminController],
  providers: [AdminService, ModerationService],
})
export class AdminModule {}
