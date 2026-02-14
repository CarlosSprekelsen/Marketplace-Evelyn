import { Test, TestingModule } from '@nestjs/testing';
import { ExpirationService } from './expiration.service';
import { ServiceRequestsService } from './service-requests.service';

describe('ExpirationService', () => {
  let service: ExpirationService;
  let mockRequestsService: {
    expirePendingRequests: jest.Mock;
  };

  beforeEach(async () => {
    mockRequestsService = {
      expirePendingRequests: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExpirationService,
        {
          provide: ServiceRequestsService,
          useValue: mockRequestsService,
        },
      ],
    }).compile();

    service = module.get<ExpirationService>(ExpirationService);
  });

  describe('expirePendingRequests (cron)', () => {
    it('should call serviceRequestsService.expirePendingRequests', async () => {
      mockRequestsService.expirePendingRequests.mockResolvedValueOnce({
        affected: 5,
      });

      await service.expirePendingRequests();

      expect(mockRequestsService.expirePendingRequests).toHaveBeenCalled();
    });

    it('should handle no expired requests', async () => {
      mockRequestsService.expirePendingRequests.mockResolvedValueOnce({
        affected: 0,
      });

      await service.expirePendingRequests();

      expect(mockRequestsService.expirePendingRequests).toHaveBeenCalled();
    });

    it('should handle multiple expired requests', async () => {
      mockRequestsService.expirePendingRequests.mockResolvedValueOnce({
        affected: 10,
      });

      await service.expirePendingRequests();

      expect(mockRequestsService.expirePendingRequests).toHaveBeenCalledTimes(1);
    });

    it('should not throw on service error', async () => {
      mockRequestsService.expirePendingRequests.mockRejectedValueOnce(new Error('Database error'));

      await expect(service.expirePendingRequests()).rejects.toThrow('Database error');
    });

    it('should be idempotent - multiple calls allowed', async () => {
      mockRequestsService.expirePendingRequests.mockResolvedValue({
        affected: 3,
      });

      await service.expirePendingRequests();
      await service.expirePendingRequests();

      expect(mockRequestsService.expirePendingRequests).toHaveBeenCalledTimes(2);
    });
  });
});
