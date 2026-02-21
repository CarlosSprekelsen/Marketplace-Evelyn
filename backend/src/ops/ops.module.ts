import { Module } from '@nestjs/common';
import { OpsController } from './ops.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [OpsController],
})
export class OpsModule {}
