import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user.entity';
import { CreateServiceRequestDto } from './dto/create-service-request.dto';
import { ServiceRequestsService } from './service-requests.service';
import { CancelServiceRequestDto } from './dto/cancel-service-request.dto';
import { CreateRatingDto } from './dto/create-rating.dto';

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

  @Get('available')
  @Roles(UserRole.PROVIDER)
  @ApiOperation({ summary: 'List available pending requests for provider district' })
  async findAvailable(@Request() req) {
    return this.serviceRequestsService.findAvailableForProvider(req.user);
  }

  @Get('assigned')
  @Roles(UserRole.PROVIDER)
  @ApiOperation({ summary: 'List assigned provider jobs (accepted/in_progress/completed)' })
  async findAssigned(@Request() req) {
    return this.serviceRequestsService.findAssignedForProvider(req.user.id);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.PROVIDER)
  @ApiOperation({ summary: 'Accept pending service request atomically' })
  async accept(@Param('id') id: string, @Request() req) {
    return this.serviceRequestsService.acceptRequest(id, req.user);
  }

  @Put(':id/start')
  @Roles(UserRole.PROVIDER)
  @ApiOperation({ summary: 'Start service request (assigned provider)' })
  async start(@Param('id') id: string, @Request() req) {
    return this.serviceRequestsService.startRequest(id, req.user);
  }

  @Put(':id/complete')
  @Roles(UserRole.PROVIDER)
  @ApiOperation({ summary: 'Complete service request (assigned provider)' })
  async complete(@Param('id') id: string, @Request() req) {
    return this.serviceRequestsService.completeRequest(id, req.user);
  }

  @Put(':id/cancel')
  @Roles(UserRole.CLIENT, UserRole.PROVIDER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Cancel service request with role-based permissions' })
  async cancel(@Param('id') id: string, @Request() req, @Body() dto: CancelServiceRequestDto) {
    return this.serviceRequestsService.cancelRequest(id, req.user, dto);
  }

  @Post(':id/rating')
  @Roles(UserRole.CLIENT)
  @ApiOperation({ summary: 'Create rating for completed service request (client only)' })
  async createRating(@Param('id') id: string, @Request() req, @Body() dto: CreateRatingDto) {
    return this.serviceRequestsService.createRating(id, req.user, dto);
  }

  @Get(':id')
  @Roles(UserRole.CLIENT, UserRole.PROVIDER)
  @ApiOperation({ summary: 'Get service request by id for owner/assigned user' })
  async findOne(@Param('id') id: string, @Request() req) {
    return this.serviceRequestsService.findByIdForUser(id, req.user);
  }
}
