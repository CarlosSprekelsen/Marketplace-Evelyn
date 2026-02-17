import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { RecurringRequestsService } from './recurring-requests.service';

@Injectable()
export class RecurringGeneratorService {
  private readonly logger = new Logger(RecurringGeneratorService.name);

  constructor(private readonly recurringRequestsService: RecurringRequestsService) {}

  @Cron('5 0 * * *')
  async generateDueRequests() {
    const count = await this.recurringRequestsService.generateDueRequests();
    this.logger.log(`Generated ${count} recurring service request(s)`);
  }
}
