import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
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
      currency: rule.currency ?? 'AED',
    };
  }

  async listRulesForAdmin() {
    const rules = await this.pricingRulesRepository.find({
      relations: ['district'],
    });

    return rules
      .map((rule) => ({
        ...rule,
        price_per_hour: this.toNumber(rule.price_per_hour),
        currency: (rule.currency ?? 'AED').toUpperCase(),
      }))
      .sort((a, b) => {
        const districtA = a.district?.name?.toLowerCase() ?? '';
        const districtB = b.district?.name?.toLowerCase() ?? '';
        return districtA.localeCompare(districtB);
      });
  }

  async updatePricingRuleById(
    id: string,
    dto: {
      price_per_hour: number;
      currency?: string;
    },
  ) {
    if (!Number.isFinite(dto.price_per_hour) || dto.price_per_hour <= 0) {
      throw new BadRequestException('price_per_hour must be greater than 0');
    }

    const rule = await this.pricingRulesRepository.findOne({
      where: { id },
      relations: ['district'],
    });
    if (!rule) {
      throw new NotFoundException('Pricing rule not found');
    }

    rule.price_per_hour = Number(dto.price_per_hour.toFixed(2));
    if (dto.currency !== undefined) {
      rule.currency = dto.currency.trim().toUpperCase();
    }

    await this.pricingRulesRepository.save(rule);

    const updated = await this.pricingRulesRepository.findOne({
      where: { id: rule.id },
      relations: ['district'],
    });
    if (!updated) {
      throw new NotFoundException('Pricing rule not found');
    }

    return {
      ...updated,
      price_per_hour: this.toNumber(updated.price_per_hour),
      currency: (updated.currency ?? 'AED').toUpperCase(),
    };
  }

  private toNumber(value: number | string): number {
    if (typeof value === 'number') {
      return value;
    }
    return Number(value);
  }
}
