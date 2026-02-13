import { BadRequestException } from '@nestjs/common';
import { PricingService } from './pricing.service';

describe('PricingService', () => {
  let service: PricingService;
  let pricingRulesRepository: { findOne: jest.Mock };
  let districtsRepository: { findOne: jest.Mock };

  beforeEach(() => {
    pricingRulesRepository = {
      findOne: jest.fn(),
    };
    districtsRepository = {
      findOne: jest.fn(),
    };
    service = new PricingService(pricingRulesRepository as any, districtsRepository as any);
  });

  it('returns quote successfully', async () => {
    districtsRepository.findOne.mockResolvedValue({
      id: 'district-1',
      name: 'Dubai Marina',
    });
    pricingRulesRepository.findOne.mockResolvedValue({
      district_id: 'district-1',
      min_hours: 1,
      max_hours: 8,
      price_per_hour: 15,
    });

    const result = await service.getQuote('district-1', 3);

    expect(result).toEqual({
      district: { id: 'district-1', name: 'Dubai Marina' },
      hours: 3,
      price_per_hour: 15,
      price_total: 45,
    });
  });

  it('throws when district has no active pricing', async () => {
    districtsRepository.findOne.mockResolvedValue({
      id: 'district-1',
      name: 'Dubai Marina',
    });
    pricingRulesRepository.findOne.mockResolvedValue(null);

    await expect(service.getQuote('district-1', 3)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('throws when hours are out of range', async () => {
    districtsRepository.findOne.mockResolvedValue({
      id: 'district-1',
      name: 'Dubai Marina',
    });
    pricingRulesRepository.findOne.mockResolvedValue({
      district_id: 'district-1',
      min_hours: 2,
      max_hours: 4,
      price_per_hour: 15,
    });

    await expect(service.getQuote('district-1', 1)).rejects.toBeInstanceOf(BadRequestException);
  });
});
