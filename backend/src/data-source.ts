import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { District } from './districts/district.entity';
import { User } from './users/user.entity';
import { ServiceRequest } from './service-requests/service-request.entity';
import { PricingRule } from './pricing/pricing-rule.entity';
import { Rating } from './ratings/rating.entity';
import { RecurringRequest } from './recurring-requests/recurring-request.entity';
import { UserAddress } from './user-addresses/user-address.entity';

// Load environment variables
config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/marketplace',
  entities: [District, User, ServiceRequest, PricingRule, Rating, RecurringRequest, UserAddress],
  migrations: [__dirname + '/migrations/*{.ts,.js}'],
  synchronize: false,
  logging: true,
});
