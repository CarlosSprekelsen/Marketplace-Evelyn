import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServiceRequest } from './service-request.entity';
import { District } from '../districts/district.entity';
import { ServiceRequestsService } from './service-requests.service';
import { ServiceRequestsController } from './service-requests.controller';
import { PricingModule } from '../pricing/pricing.module';
import { ExpirationService } from './expiration.service';
import { Rating } from '../ratings/rating.entity';
import { ProvidersRatingsController } from './providers-ratings.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ServiceRequest, District, Rating]), PricingModule],
  providers: [ServiceRequestsService, ExpirationService],
  controllers: [ServiceRequestsController, ProvidersRatingsController],
  exports: [ServiceRequestsService],
})
export class ServiceRequestsModule {}
