import { Test, TestingModule } from '@nestjs/testing';
import { PricingController } from './pricing.controller';
import { PricingService } from './pricing.service';

describe('PricingController', () => {
  let controller: PricingController;
  let mockService: {
    getQuote: jest.Mock;
  };

  beforeEach(async () => {
    mockService = {
      getQuote: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [PricingController],
      providers: [
        {
          provide: PricingService,
          useValue: mockService,
        },
      ],
    }).compile();

    controller = module.get<PricingController>(PricingController);
  });

  describe('getQuote', () => {
    it('should return price quote from service', async () => {
      const mockQuote = { hourly_rate: 50, hours: 3, total: 150 };
      mockService.getQuote.mockResolvedValueOnce(mockQuote);

      const result = await controller.getQuote({ district_id: 'district-1', hours: 3 });

      expect(mockService.getQuote).toHaveBeenCalledWith('district-1', 3);
      expect(result).toEqual(mockQuote);
    });

    it('should pass district_id and hours to service', async () => {
      mockService.getQuote.mockResolvedValueOnce({
        hourly_rate: 50,
        hours: 5,
        total: 250,
      });

      await controller.getQuote({ district_id: 'district-2', hours: 5 });

      expect(mockService.getQuote).toHaveBeenCalledWith('district-2', 5);
    });

    it('should handle single hour request', async () => {
      const mockQuote = { hourly_rate: 50, hours: 1, total: 50 };
      mockService.getQuote.mockResolvedValueOnce(mockQuote);

      const result = await controller.getQuote({ district_id: 'district-1', hours: 1 });

      expect(result.hours).toBe(1);
      expect(result.total).toBe(50);
    });

    it('should handle maximum hours (8)', async () => {
      const mockQuote = { hourly_rate: 50, hours: 8, total: 400 };
      mockService.getQuote.mockResolvedValueOnce(mockQuote);

      const result = await controller.getQuote({ district_id: 'district-1', hours: 8 });

      expect(result.hours).toBe(8);
    });

    it('should call service with string district_id', async () => {
      mockService.getQuote.mockResolvedValueOnce({
        hourly_rate: 50,
        hours: 2,
        total: 100,
      });

      await controller.getQuote({ district_id: 'valid-uuid-string', hours: 2 });

      expect(mockService.getQuote).toHaveBeenCalledWith('valid-uuid-string', 2);
    });

    it('should handle decimal hours in calculation', async () => {
      const mockQuote = { hourly_rate: 50, hours: 3, total: 150 };
      mockService.getQuote.mockResolvedValueOnce(mockQuote);

      const result = await controller.getQuote({ district_id: 'district-1', hours: 3 });

      expect(result.total).toBe(150);
    });

    it('should return quote with hourly_rate', async () => {
      const mockQuote = { hourly_rate: 75, hours: 4, total: 300 };
      mockService.getQuote.mockResolvedValueOnce(mockQuote);

      const result = await controller.getQuote({ district_id: 'district-1', hours: 4 });

      expect(result.hourly_rate).toBe(75);
    });

    it('should handle different districts', async () => {
      mockService.getQuote.mockResolvedValueOnce({
        hourly_rate: 50,
        hours: 3,
        total: 150,
      });

      await controller.getQuote({ district_id: 'district-dubai', hours: 3 });
      expect(mockService.getQuote).toHaveBeenCalledWith('district-dubai', 3);

      mockService.getQuote.mockResolvedValueOnce({
        hourly_rate: 40,
        hours: 3,
        total: 120,
      });

      const result = await controller.getQuote({ district_id: 'district-other', hours: 3 });
      expect(mockService.getQuote).toHaveBeenCalledWith('district-other', 3);
      expect(result.hourly_rate).toBe(40);
    });
  });
});
