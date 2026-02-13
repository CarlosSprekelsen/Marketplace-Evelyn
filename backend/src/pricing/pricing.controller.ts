import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PricingService } from './pricing.service';
import { QuoteQueryDto } from './dto/quote-query.dto';

@ApiTags('Pricing')
@Controller('pricing')
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  @Get('quote')
  @ApiOperation({ summary: 'Get service price quote by district and hours' })
  async getQuote(@Query() query: QuoteQueryDto) {
    return this.pricingService.getQuote(query.district_id, query.hours);
  }
}
