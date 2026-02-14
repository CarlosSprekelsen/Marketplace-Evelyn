import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { ServiceRequestsService } from './service-requests.service';
import { ServiceRequestStatus } from './service-request.entity';
import { UserRole } from '../users/user.entity';

describe('ServiceRequestsService', () => {
  let service: ServiceRequestsService;
  let serviceRequestsRepository: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
    find: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let districtsRepository: { findOne: jest.Mock };
  let ratingsRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
    find: jest.Mock;
  };
  let pricingService: { getQuote: jest.Mock };

  const clientUser = {
    id: 'client-1',
    role: UserRole.CLIENT,
  } as any;

  const providerUser = {
    id: 'provider-1',
    role: UserRole.PROVIDER,
    district_id: 'district-1',
    is_verified: true,
    is_blocked: false,
  } as any;

  const adminUser = {
    id: 'admin-1',
    role: UserRole.ADMIN,
  } as any;

  beforeEach(() => {
    serviceRequestsRepository = {
      create: jest.fn((input) => input),
      save: jest.fn(async (input) => input),
      findOne: jest.fn(),
      find: jest.fn(),
      createQueryBuilder: jest.fn(),
    };
    districtsRepository = {
      findOne: jest.fn(),
    };
    ratingsRepository = {
      findOne: jest.fn(),
      create: jest.fn((input) => input),
      save: jest.fn(async (input) => ({ id: 'rating-1', ...input })),
      find: jest.fn(),
    };
    pricingService = {
      getQuote: jest.fn(),
    };

    service = new ServiceRequestsService(
      serviceRequestsRepository as any,
      districtsRepository as any,
      ratingsRepository as any,
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

  it('returns available requests filtered for provider district with no client sensitive fields', async () => {
    serviceRequestsRepository.find.mockResolvedValue([
      {
        id: 'request-1',
        district: { name: 'Dubai Marina' },
        hours_requested: 2,
        price_total: '40.00',
        scheduled_at: new Date('2099-03-01T10:00:00.000Z'),
        expires_at: new Date(Date.now() + 120000),
        address_detail: 'Should not be returned',
      },
    ]);

    const available = await service.findAvailableForProvider(providerUser);

    expect(available[0]).toEqual(
      expect.objectContaining({
        id: 'request-1',
        district_name: 'Dubai Marina',
        hours_requested: 2,
      }),
    );
    expect(available[0]).not.toHaveProperty('address_detail');
  });

  it('accepts request atomically for verified provider in same district', async () => {
    serviceRequestsRepository.findOne
      .mockResolvedValueOnce({
        id: 'request-1',
        district_id: 'district-1',
      })
      .mockResolvedValueOnce({
        id: 'request-1',
        provider_id: 'provider-1',
        status: ServiceRequestStatus.ACCEPTED,
      });

    const execute = jest.fn().mockResolvedValue({ affected: 1 });
    serviceRequestsRepository.createQueryBuilder.mockReturnValue({
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute,
    });

    const result = await service.acceptRequest('request-1', providerUser);

    expect(execute).toHaveBeenCalled();
    expect(result).toEqual(expect.objectContaining({ status: ServiceRequestStatus.ACCEPTED }));
  });

  it('concurrent accept: only one provider wins and the other gets conflict', async () => {
    let acceptedProviderId: string | null = null;

    serviceRequestsRepository.findOne.mockImplementation(async (options) => {
      if (options.select) {
        return { id: 'request-1', district_id: 'district-1' };
      }
      if (acceptedProviderId) {
        return {
          id: 'request-1',
          status: ServiceRequestStatus.ACCEPTED,
          provider_id: acceptedProviderId,
        };
      }
      return null;
    });

    serviceRequestsRepository.createQueryBuilder.mockImplementation(() => {
      let nextProviderId: string | undefined;
      const qb = {
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockImplementation((input) => {
          nextProviderId = input.provider_id as string;
          return qb;
        }),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockImplementation(async () => {
          if (!acceptedProviderId) {
            acceptedProviderId = nextProviderId ?? null;
            return { affected: 1 };
          }
          return { affected: 0 };
        }),
      };
      qb.update.mockReturnValue(qb);
      qb.where.mockReturnValue(qb);
      qb.andWhere.mockReturnValue(qb);
      return qb;
    });

    const provider1 = { ...providerUser, id: 'provider-1' };
    const provider2 = { ...providerUser, id: 'provider-2' };

    const [r1, r2] = await Promise.allSettled([
      service.acceptRequest('request-1', provider1),
      service.acceptRequest('request-1', provider2),
    ]);

    const fulfilled = [r1, r2].filter((r) => r.status === 'fulfilled');
    const rejected = [r1, r2].filter((r) => r.status === 'rejected');

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect(rejected[0].reason).toBeInstanceOf(ConflictException);
  });

  it('starts ACCEPTED request by assigned provider', async () => {
    const request = {
      id: 'request-1',
      provider_id: 'provider-1',
      status: ServiceRequestStatus.ACCEPTED,
    };
    serviceRequestsRepository.findOne.mockResolvedValue(request);

    const result = await service.startRequest('request-1', providerUser);

    expect(result.status).toBe(ServiceRequestStatus.IN_PROGRESS);
    expect(result.started_at).toBeInstanceOf(Date);
  });

  it('completes IN_PROGRESS request by assigned provider', async () => {
    const request = {
      id: 'request-1',
      provider_id: 'provider-1',
      status: ServiceRequestStatus.IN_PROGRESS,
    };
    serviceRequestsRepository.findOne.mockResolvedValue(request);

    const result = await service.completeRequest('request-1', providerUser);

    expect(result.status).toBe(ServiceRequestStatus.COMPLETED);
    expect(result.completed_at).toBeInstanceOf(Date);
  });

  it('client can cancel PENDING request', async () => {
    const request = {
      id: 'request-1',
      status: ServiceRequestStatus.PENDING,
      client_id: 'client-1',
      provider_id: null,
    };
    serviceRequestsRepository.findOne.mockResolvedValue(request);

    const result = await service.cancelRequest('request-1', clientUser, {
      cancellation_reason: 'Need to reschedule',
    });

    expect(result.status).toBe(ServiceRequestStatus.CANCELLED);
    expect(result.cancelled_by).toBe('client-1');
  });

  it('client cannot cancel IN_PROGRESS request', async () => {
    const request = {
      id: 'request-1',
      status: ServiceRequestStatus.IN_PROGRESS,
      client_id: 'client-1',
      provider_id: 'provider-1',
    };
    serviceRequestsRepository.findOne.mockResolvedValue(request);

    await expect(
      service.cancelRequest('request-1', clientUser, {
        cancellation_reason: 'Need to stop',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('provider can cancel ACCEPTED request when assigned', async () => {
    const request = {
      id: 'request-1',
      status: ServiceRequestStatus.ACCEPTED,
      client_id: 'client-1',
      provider_id: 'provider-1',
    };
    serviceRequestsRepository.findOne.mockResolvedValue(request);

    const result = await service.cancelRequest('request-1', providerUser, {
      cancellation_reason: 'Emergency',
    });

    expect(result.status).toBe(ServiceRequestStatus.CANCELLED);
    expect(result.cancelled_by).toBe('provider-1');
  });

  it('admin can cancel IN_PROGRESS request', async () => {
    const request = {
      id: 'request-1',
      status: ServiceRequestStatus.IN_PROGRESS,
      client_id: 'client-1',
      provider_id: 'provider-1',
    };
    serviceRequestsRepository.findOne.mockResolvedValue(request);

    const result = await service.cancelRequest('request-1', adminUser, {
      cancellation_reason: 'Admin intervention',
    });

    expect(result.status).toBe(ServiceRequestStatus.CANCELLED);
    expect(result.cancelled_by_role).toBe(UserRole.ADMIN);
  });

  it('creates rating successfully for completed request', async () => {
    serviceRequestsRepository.findOne.mockResolvedValue({
      id: 'request-1',
      status: ServiceRequestStatus.COMPLETED,
      client_id: 'client-1',
      provider_id: 'provider-1',
    });
    ratingsRepository.findOne.mockResolvedValue(null);

    const rating = await service.createRating('request-1', clientUser, {
      stars: 5,
      comment: 'Excellent',
    });

    expect(ratingsRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        service_request_id: 'request-1',
        stars: 5,
      }),
    );
    expect(rating.stars).toBe(5);
  });

  it('rejects rating when request is not completed', async () => {
    serviceRequestsRepository.findOne.mockResolvedValue({
      id: 'request-1',
      status: ServiceRequestStatus.ACCEPTED,
      client_id: 'client-1',
      provider_id: 'provider-1',
    });

    await expect(
      service.createRating('request-1', clientUser, {
        stars: 5,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects rating twice on same request', async () => {
    serviceRequestsRepository.findOne.mockResolvedValue({
      id: 'request-1',
      status: ServiceRequestStatus.COMPLETED,
      client_id: 'client-1',
      provider_id: 'provider-1',
    });
    ratingsRepository.findOne.mockResolvedValue({
      id: 'rating-1',
      service_request_id: 'request-1',
    });

    await expect(
      service.createRating('request-1', clientUser, {
        stars: 5,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('returns provider ratings summary', async () => {
    ratingsRepository.find.mockResolvedValue([
      { id: 'r1', stars: 5, provider_id: 'provider-1', created_at: new Date() },
      { id: 'r2', stars: 3, provider_id: 'provider-1', created_at: new Date() },
    ]);

    const result = await service.getProviderRatings('provider-1');

    expect(result.total_ratings).toBe(2);
    expect(result.average_stars).toBe(4);
    expect(result.provider_id).toBe('provider-1');
  });
});
