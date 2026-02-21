import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import configuration from './config/configuration';
import { createClient } from 'redis';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { DistrictsModule } from './districts/districts.module';
import { PricingModule } from './pricing/pricing.module';
import { ServiceRequestsModule } from './service-requests/service-requests.module';
import { AdminModule } from './admin/admin.module';
import { RecurringRequestsModule } from './recurring-requests/recurring-requests.module';
import { UserAddressesModule } from './user-addresses/user-addresses.module';
import { AdminWebModule } from './admin-web/admin-web.module';
import { OpsModule } from './ops/ops.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        url: configService.get<string>('database.url'),
        autoLoadEntities: true,
        synchronize: false, // Use migrations in production
        logging: process.env.NODE_ENV === 'development',
      }),
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000, // 1 minute
        limit: 60, // 60 requests per minute
      },
    ]),
    ScheduleModule.forRoot(),
    UsersModule,
    AuthModule,
    DistrictsModule,
    PricingModule,
    ServiceRequestsModule,
    AdminModule,
    AdminWebModule,
    OpsModule,
    RecurringRequestsModule,
    UserAddressesModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: 'REDIS_CLIENT',
      useFactory: async (configService: ConfigService) => {
        const client = createClient({
          url: configService.get<string>('redis.url'),
        });
        client.on('error', (err) => console.error('Redis Client Error:', err));
        await client.connect();
        return client;
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT'],
})
export class AppModule {}
