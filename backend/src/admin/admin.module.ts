import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module';
import { ServiceRequestsModule } from '../service-requests/service-requests.module';
import { AdminController } from './admin.controller';

@Module({
  imports: [UsersModule, ServiceRequestsModule],
  controllers: [AdminController],
})
export class AdminModule {}
