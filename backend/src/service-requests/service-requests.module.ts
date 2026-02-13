import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServiceRequest } from './service-request.entity';
import { District } from '../districts/district.entity';
import { ServiceRequestsService } from './service-requests.service';
import { ServiceRequestsController } from './service-requests.controller';
import { PricingModule } from '../pricing/pricing.module';
import { ExpirationService } from './expiration.service';

@Module({
  imports: [TypeOrmModule.forFeature([ServiceRequest, District]), PricingModule],
  providers: [ServiceRequestsService, ExpirationService],
  controllers: [ServiceRequestsController],
  exports: [ServiceRequestsService],
})
export class ServiceRequestsModule {}
