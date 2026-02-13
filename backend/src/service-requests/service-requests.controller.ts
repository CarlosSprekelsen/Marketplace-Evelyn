import { Body, Controller, Get, Param, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user.entity';
import { CreateServiceRequestDto } from './dto/create-service-request.dto';
import { ServiceRequestsService } from './service-requests.service';

@ApiTags('Service Requests')
@Controller('service-requests')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class ServiceRequestsController {
  constructor(private readonly serviceRequestsService: ServiceRequestsService) {}

  @Post()
  @Roles(UserRole.CLIENT)
  @ApiOperation({ summary: 'Create service request (client only)' })
  async create(@Request() req, @Body() dto: CreateServiceRequestDto) {
    return this.serviceRequestsService.create(req.user, dto);
  }

  @Get('mine')
  @Roles(UserRole.CLIENT)
  @ApiOperation({ summary: 'List service requests for current client' })
  async findMine(@Request() req) {
    return this.serviceRequestsService.findMine(req.user.id);
  }

  @Get(':id')
  @Roles(UserRole.CLIENT, UserRole.PROVIDER)
  @ApiOperation({ summary: 'Get service request by id for owner/assigned user' })
  async findOne(@Param('id') id: string, @Request() req) {
    return this.serviceRequestsService.findByIdForUser(id, req.user);
  }
}
