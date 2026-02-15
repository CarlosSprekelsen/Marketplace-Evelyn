import { Controller, Get, Param, Patch, Query, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user.entity';
import { UsersService } from '../users/users.service';
import { SetUserVerifiedDto } from './dto/set-user-verified.dto';
import { SetUserBlockedDto } from './dto/set-user-blocked.dto';
import { Body } from '@nestjs/common';
import { ServiceRequestsService } from '../service-requests/service-requests.service';
import { SetRequestStatusDto } from './dto/set-request-status.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly usersService: UsersService,
    private readonly serviceRequestsService: ServiceRequestsService,
  ) {}

  @Get('users')
  @ApiOperation({ summary: 'List users for admin dashboard (optional role filter)' })
  async listUsers(@Query('role') role?: string) {
    const validRole =
      role && Object.values(UserRole).includes(role as UserRole) ? (role as UserRole) : undefined;
    const users = await this.usersService.listUsers(validRole);
    return users.map((user) => this.sanitizeUser(user));
  }

  @Patch('users/:id/verify')
  @ApiOperation({ summary: 'Set provider verification state' })
  async setVerified(@Param('id') id: string, @Body() dto: SetUserVerifiedDto) {
    const user = await this.usersService.setVerified(id, dto.is_verified);
    return this.sanitizeUser(user);
  }

  @Patch('users/:id/block')
  @ApiOperation({ summary: 'Set user block state' })
  async setBlocked(@Param('id') id: string, @Body() dto: SetUserBlockedDto) {
    const user = await this.usersService.setBlocked(id, dto.is_blocked);
    return this.sanitizeUser(user);
  }

  @Get('service-requests')
  @ApiOperation({ summary: 'List service requests for admin dashboard' })
  async listServiceRequests() {
    return this.serviceRequestsService.findAllForAdmin();
  }

  @Patch('service-requests/:id/status')
  @ApiOperation({ summary: 'Manually update service request status' })
  async setRequestStatus(
    @Param('id') id: string,
    @Body() dto: SetRequestStatusDto,
    @Request() req,
  ) {
    return this.serviceRequestsService.adminUpdateStatus(
      id,
      dto.status,
      dto.cancellation_reason ?? `Admin update by ${req.user.id}`,
    );
  }

  private sanitizeUser(user: Record<string, unknown>) {
    const { password_hash, refresh_token_hash, ...safeUser } = user;
    return safeUser;
  }
}
