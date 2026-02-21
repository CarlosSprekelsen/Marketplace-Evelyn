import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user.entity';
import { PushNotificationsService } from '../notifications/push-notifications.service';

@ApiTags('Ops')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@Controller('ops')
export class OpsController {
  constructor(private readonly pushNotificationsService: PushNotificationsService) {}

  @Get('push-observability')
  @ApiOperation({ summary: 'Get push delivery counters and recent events' })
  getPushObservability() {
    return this.pushNotificationsService.getObservabilitySnapshot();
  }
}
