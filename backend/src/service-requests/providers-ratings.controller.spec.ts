import { Test, TestingModule } from '@nestjs/testing';
import { ProvidersRatingsController } from './providers-ratings.controller';
import { ServiceRequestsService } from './service-requests.service';

describe('ProvidersRatingsController', () => {
  let controller: ProvidersRatingsController;
  let mockService: {
    getProviderRatings: jest.Mock;
  };

  beforeEach(async () => {
    mockService = {
      getProviderRatings: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ProvidersRatingsController],
      providers: [
        {
          provide: ServiceRequestsService,
          useValue: mockService,
        },
      ],
    }).compile();

    controller = module.get<ProvidersRatingsController>(ProvidersRatingsController);
  });

  it('returns provider ratings summary', async () => {
    mockService.getProviderRatings.mockResolvedValueOnce({
      provider_id: 'provider-1',
      average_stars: 4.5,
      total_ratings: 2,
      ratings: [],
    });

    const result = await controller.getProviderRatings('provider-1');

    expect(mockService.getProviderRatings).toHaveBeenCalledWith('provider-1');
    expect(result.average_stars).toBe(4.5);
  });
});
