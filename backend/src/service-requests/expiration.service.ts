import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ServiceRequestsService } from './service-requests.service';

@Injectable()
export class ExpirationService {
  private readonly logger = new Logger(ExpirationService.name);

  constructor(private readonly serviceRequestsService: ServiceRequestsService) {}

  @Cron('*/1 * * * *')
  async expirePendingRequests() {
    const result = await this.serviceRequestsService.expirePendingRequests();
    const expiredCount = result.affected ?? 0;

    this.logger.log(`Expired pending requests: ${expiredCount}`);
  }
}
