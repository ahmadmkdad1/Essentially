import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ListingsModule } from '../listings/listings.module.js';
import { Review } from '../reviews/review.entity.js';
import { UsersModule } from '../users/users.module.js';
import { RequestsController } from './requests.controller.js';
import { RequestsService } from './requests.service.js';
import { ServiceRequest } from './service-request.entity.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([ServiceRequest, Review]),
    ListingsModule,
    UsersModule,
  ],
  controllers: [RequestsController],
  providers: [RequestsService],
  exports: [RequestsService],
})
export class RequestsModule {}
