import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module';
import { ServiceRequestsModule } from '../service-requests/service-requests.module';
import { UsersModule } from '../users/users.module';
import { AdminWebController } from './admin-web.controller';

@Module({
  imports: [UsersModule, ServiceRequestsModule, PricingModule],
  controllers: [AdminWebController],
})
export class AdminWebModule {}
