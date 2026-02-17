import { Controller, Post, Get, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user.entity';
import { RecurringRequestsService } from './recurring-requests.service';
import { CreateRecurringRequestDto } from './dto/create-recurring-request.dto';

@ApiTags('Recurring Requests')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CLIENT)
@Controller('recurring-requests')
export class RecurringRequestsController {
  constructor(private readonly recurringRequestsService: RecurringRequestsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a recurring cleaning request' })
  @ApiResponse({ status: 201, description: 'Recurring request created' })
  async create(@Request() req, @Body() dto: CreateRecurringRequestDto) {
    return this.recurringRequestsService.create(req.user.id, dto);
  }

  @Get('mine')
  @ApiOperation({ summary: 'List my active recurring requests' })
  @ApiResponse({ status: 200, description: 'List of recurring requests' })
  async findMine(@Request() req) {
    return this.recurringRequestsService.findMine(req.user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Cancel a recurring request' })
  @ApiResponse({ status: 200, description: 'Recurring request cancelled' })
  async cancel(@Request() req, @Param('id') id: string) {
    await this.recurringRequestsService.cancel(id, req.user.id);
    return { message: 'Recurring request cancelled' };
  }
}
