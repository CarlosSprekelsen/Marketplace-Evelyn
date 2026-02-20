import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module';
import { ServiceRequestsModule } from '../service-requests/service-requests.module';
import { AdminController } from './admin.controller';
import { PricingModule } from '../pricing/pricing.module';

@Module({
  imports: [UsersModule, ServiceRequestsModule, PricingModule],
  controllers: [AdminController],
})
export class AdminModule {}
