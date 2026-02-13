import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PricingRule } from './pricing-rule.entity';
import { District } from '../districts/district.entity';

@Injectable()
export class PricingService {
  constructor(
    @InjectRepository(PricingRule)
    private readonly pricingRulesRepository: Repository<PricingRule>,
    @InjectRepository(District)
    private readonly districtsRepository: Repository<District>,
  ) {}

  async getQuote(districtId: string, hours: number) {
    const district = await this.districtsRepository.findOne({
      where: { id: districtId, is_active: true },
      select: ['id', 'name'],
    });

    if (!district) {
      throw new BadRequestException('District not found or inactive');
    }

    const rule = await this.pricingRulesRepository.findOne({
      where: {
        district_id: districtId,
        is_active: true,
      },
    });

    if (!rule) {
      throw new BadRequestException('No active pricing rule found for district');
    }

    if (hours < rule.min_hours || hours > rule.max_hours) {
      throw new BadRequestException(
        `Hours must be between ${rule.min_hours} and ${rule.max_hours} for this district`,
      );
    }

    const pricePerHour = this.toNumber(rule.price_per_hour);
    return {
      district: {
        id: district.id,
        name: district.name,
      },
      hours,
      price_per_hour: pricePerHour,
      price_total: Number((pricePerHour * hours).toFixed(2)),
    };
  }

  private toNumber(value: number | string): number {
    if (typeof value === 'number') {
      return value;
    }
    return Number(value);
  }
}
