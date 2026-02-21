import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';
import { UsersService } from './users.service';
import { PushNotificationsService } from '../notifications/push-notifications.service';
import { ServiceRequest } from '../service-requests/service-request.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User, ServiceRequest])],
  providers: [UsersService, PushNotificationsService],
  exports: [UsersService],
})
export class UsersModule {}
