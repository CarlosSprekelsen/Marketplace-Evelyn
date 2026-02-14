import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ServiceRequestsService } from './service-requests.service';

@ApiTags('Providers')
@Controller('providers')
export class ProvidersRatingsController {
  constructor(private readonly serviceRequestsService: ServiceRequestsService) {}

  @Get(':id/ratings')
  @ApiOperation({ summary: 'Get provider ratings summary and list' })
  async getProviderRatings(@Param('id') providerId: string) {
    return this.serviceRequestsService.getProviderRatings(providerId);
  }
}
