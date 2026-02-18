import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecurringRequest } from './recurring-request.entity';
import { District } from '../districts/district.entity';
import { User } from '../users/user.entity';
import { RecurringRequestsService } from './recurring-requests.service';
import { RecurringRequestsController } from './recurring-requests.controller';
import { RecurringGeneratorService } from './recurring-generator.service';
import { ServiceRequestsModule } from '../service-requests/service-requests.module';
import { UserAddress } from '../user-addresses/user-address.entity';

@Module({
  imports: [TypeOrmModule.forFeature([RecurringRequest, District, User, UserAddress]), ServiceRequestsModule],
  providers: [RecurringRequestsService, RecurringGeneratorService],
  controllers: [RecurringRequestsController],
})
export class RecurringRequestsModule {}
