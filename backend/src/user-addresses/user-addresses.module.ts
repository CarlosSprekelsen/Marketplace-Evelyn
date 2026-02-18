import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserAddress } from './user-address.entity';
import { District } from '../districts/district.entity';
import { UserAddressesService } from './user-addresses.service';
import { UserAddressesController } from './user-addresses.controller';

@Module({
  imports: [TypeOrmModule.forFeature([UserAddress, District])],
  providers: [UserAddressesService],
  controllers: [UserAddressesController],
  exports: [UserAddressesService],
})
export class UserAddressesModule {}
