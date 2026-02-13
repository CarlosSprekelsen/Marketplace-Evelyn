import { BadRequestException } from '@nestjs/common';
import { ServiceRequestsService } from './service-requests.service';
import { UserRole } from '../users/user.entity';
import { ServiceRequestStatus } from './service-request.entity';

describe('ServiceRequestsService', () => {
  let service: ServiceRequestsService;
  let serviceRequestsRepository: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let districtsRepository: { findOne: jest.Mock };
  let pricingService: { getQuote: jest.Mock };

  const clientUser = {
    id: 'client-1',
    role: UserRole.CLIENT,
  } as any;

  beforeEach(() => {
    serviceRequestsRepository = {
      create: jest.fn((input) => input),
      save: jest.fn(),
      findOne: jest.fn(),
      createQueryBuilder: jest.fn(),
    };
    districtsRepository = {
      findOne: jest.fn(),
    };
    pricingService = {
      getQuote: jest.fn(),
    };
    service = new ServiceRequestsService(
      serviceRequestsRepository as any,
      districtsRepository as any,
      pricingService as any,
    );
  });

  it('creates request successfully', async () => {
    districtsRepository.findOne.mockResolvedValue({
      id: 'district-1',
      is_active: true,
      name: 'Dubai Marina',
    });
    pricingService.getQuote.mockResolvedValue({
      price_total: 45,
    });
    serviceRequestsRepository.save.mockResolvedValue({ id: 'request-1' });
    serviceRequestsRepository.findOne.mockResolvedValue({
      id: 'request-1',
      status: ServiceRequestStatus.PENDING,
    });

    const result = await service.create(clientUser, {
      district_id: 'district-1',
      address_detail: 'Calle 1 #23',
      hours_requested: 3,
      scheduled_at: '2099-03-01T10:00:00.000Z',
    });

    expect(pricingService.getQuote).toHaveBeenCalledWith('district-1', 3);
    expect(serviceRequestsRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        client_id: 'client-1',
        district_id: 'district-1',
        status: ServiceRequestStatus.PENDING,
      }),
    );
    expect(result).toEqual(expect.objectContaining({ id: 'request-1' }));
  });

  it('throws on invalid district', async () => {
    districtsRepository.findOne.mockResolvedValue(null);

    await expect(
      service.create(clientUser, {
        district_id: 'district-x',
        address_detail: 'Calle 1 #23',
        hours_requested: 3,
        scheduled_at: '2099-03-01T10:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('throws when hours are out of pricing range', async () => {
    districtsRepository.findOne.mockResolvedValue({
      id: 'district-1',
      is_active: true,
      name: 'Dubai Marina',
    });
    pricingService.getQuote.mockRejectedValue(new BadRequestException('Hours must be between 1 and 8'));

    await expect(
      service.create(clientUser, {
        district_id: 'district-1',
        address_detail: 'Calle 1 #23',
        hours_requested: 12,
        scheduled_at: '2099-03-01T10:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('throws when scheduled_at is in the past', async () => {
    districtsRepository.findOne.mockResolvedValue({
      id: 'district-1',
      is_active: true,
      name: 'Dubai Marina',
    });

    await expect(
      service.create(clientUser, {
        district_id: 'district-1',
        address_detail: 'Calle 1 #23',
        hours_requested: 3,
        scheduled_at: '2020-03-01T10:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
