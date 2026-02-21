import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';
import { UsersService } from './users.service';
import { ServiceRequest } from '../service-requests/service-request.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [TypeOrmModule.forFeature([User, ServiceRequest]), NotificationsModule],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
