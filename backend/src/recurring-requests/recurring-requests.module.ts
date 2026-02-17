import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecurringRequest } from './recurring-request.entity';
import { District } from '../districts/district.entity';
import { User } from '../users/user.entity';
import { RecurringRequestsService } from './recurring-requests.service';
import { RecurringRequestsController } from './recurring-requests.controller';
import { RecurringGeneratorService } from './recurring-generator.service';
import { ServiceRequestsModule } from '../service-requests/service-requests.module';

@Module({
  imports: [TypeOrmModule.forFeature([RecurringRequest, District, User]), ServiceRequestsModule],
  providers: [RecurringRequestsService, RecurringGeneratorService],
  controllers: [RecurringRequestsController],
})
export class RecurringRequestsModule {}
