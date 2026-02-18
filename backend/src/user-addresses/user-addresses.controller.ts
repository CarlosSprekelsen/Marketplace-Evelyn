import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Patch,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user.entity';
import { UserAddressesService } from './user-addresses.service';
import { CreateUserAddressDto } from './dto/create-user-address.dto';
import { UpdateUserAddressDto } from './dto/update-user-address.dto';

@ApiTags('User Addresses')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CLIENT)
@Controller('user-addresses')
export class UserAddressesController {
  constructor(private readonly userAddressesService: UserAddressesService) {}

  @Post()
  @ApiOperation({ summary: 'Create a saved address' })
  @ApiResponse({ status: 201, description: 'Address created' })
  async create(@Request() req, @Body() dto: CreateUserAddressDto) {
    return this.userAddressesService.create(req.user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List my saved addresses' })
  @ApiResponse({ status: 200, description: 'List of addresses' })
  async findAll(@Request() req) {
    return this.userAddressesService.findAllByUser(req.user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a saved address' })
  @ApiResponse({ status: 200, description: 'Address updated' })
  async update(@Request() req, @Param('id') id: string, @Body() dto: UpdateUserAddressDto) {
    return this.userAddressesService.update(id, req.user.id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a saved address' })
  @ApiResponse({ status: 200, description: 'Address deleted' })
  async remove(@Request() req, @Param('id') id: string) {
    await this.userAddressesService.remove(id, req.user.id);
    return { message: 'Address deleted' };
  }

  @Patch(':id/default')
  @ApiOperation({ summary: 'Set address as default' })
  @ApiResponse({ status: 200, description: 'Address set as default' })
  async setDefault(@Request() req, @Param('id') id: string) {
    return this.userAddressesService.setDefault(id, req.user.id);
  }
}
