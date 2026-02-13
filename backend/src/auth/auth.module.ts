import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { UsersModule } from '../users/users.module';
import { District } from '../districts/district.entity';
import { JwtStrategy } from './jwt.strategy';
import { JwtRefreshStrategy } from './jwt-refresh.strategy';
import { RolesGuard } from './roles.guard';

@Module({
  imports: [
    UsersModule,
    PassportModule,
    JwtModule.register({}), // Configuration is done in strategies
    TypeOrmModule.forFeature([District]),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, JwtRefreshStrategy, RolesGuard],
  exports: [AuthService],
})
export class AuthModule {}
