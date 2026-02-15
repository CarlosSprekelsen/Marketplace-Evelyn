import { Test, TestingModule } from '@nestjs/testing';
import { ServiceRequestsController } from './service-requests.controller';
import { ServiceRequestsService } from './service-requests.service';
import { UserRole } from '../users/user.entity';

describe('ServiceRequestsController', () => {
  let controller: ServiceRequestsController;
  let mockService: {
    create: jest.Mock;
    findMine: jest.Mock;
    findAvailableForProvider: jest.Mock;
    findAssignedForProvider: jest.Mock;
    acceptRequest: jest.Mock;
    startRequest: jest.Mock;
    completeRequest: jest.Mock;
    cancelRequest: jest.Mock;
    createRating: jest.Mock;
    findByIdForUser: jest.Mock;
  };

  const mockUser = {
    id: 'user-1',
    email: 'client@test.com',
    role: UserRole.CLIENT,
  };

  const mockServiceRequest = {
    id: 'request-1',
    client_id: 'user-1',
    provider_id: null,
    district_id: 'district-1',
    address_detail: 'Test Address',
    hours_requested: 3,
    price_total: 150,
    scheduled_at: new Date('2026-03-01T10:00:00Z'),
    status: 'PENDING',
    expires_at: new Date(Date.now() + 300000),
    created_at: new Date(),
    updated_at: new Date(),
    district: { id: 'district-1', name: 'Dubai Marina' },
    provider: null,
  };

  beforeEach(async () => {
    mockService = {
      create: jest.fn(),
      findMine: jest.fn(),
      findAvailableForProvider: jest.fn(),
      findAssignedForProvider: jest.fn(),
      acceptRequest: jest.fn(),
      startRequest: jest.fn(),
      completeRequest: jest.fn(),
      cancelRequest: jest.fn(),
      createRating: jest.fn(),
      findByIdForUser: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ServiceRequestsController],
      providers: [
        {
          provide: ServiceRequestsService,
          useValue: mockService,
        },
      ],
    }).compile();

    controller = module.get<ServiceRequestsController>(ServiceRequestsController);
  });

  describe('create', () => {
    it('should create a service request', async () => {
      mockService.create.mockResolvedValueOnce(mockServiceRequest);
      const dto = {
        district_id: 'district-1',
        address_detail: 'Test Address',
        hours_requested: 3,
        scheduled_at: new Date('2026-03-01T10:00:00Z'),
      };

      const result = await controller.create({ user: mockUser }, dto);

      expect(mockService.create).toHaveBeenCalledWith(mockUser, dto);
      expect(result.id).toEqual('request-1');
    });

    it('should return service request with all fields', async () => {
      const mock2Hour = { ...mockServiceRequest, hours_requested: 2, price_total: 100 };
      mockService.create.mockResolvedValueOnce(mock2Hour);
      const dto = {
        district_id: 'district-1',
        address_detail: 'Test',
        hours_requested: 2,
        scheduled_at: new Date('2026-03-01T10:00:00Z'),
      };

      const result = await controller.create({ user: mockUser }, dto);

      expect(result.status).toEqual('PENDING');
      expect(result.client_id).toEqual('user-1');
      expect(result.hours_requested).toBe(2);
    });

    it('should handle different hours', async () => {
      const mock5Hour = { ...mockServiceRequest, hours_requested: 5, price_total: 250 };
      mockService.create.mockResolvedValueOnce(mock5Hour);
      const dto = {
        district_id: 'district-1',
        address_detail: 'Test',
        hours_requested: 5,
        scheduled_at: new Date('2026-03-01T10:00:00Z'),
      };

      const result = await controller.create({ user: mockUser }, dto);

      expect(result.hours_requested).toBe(5);
      expect(mockService.create).toHaveBeenCalledWith(
        mockUser,
        expect.objectContaining({ hours_requested: 5 }),
      );
    });
  });

  describe('findMine', () => {
    it('should return list of requests for current user', async () => {
      const mockRequests = [mockServiceRequest];
      mockService.findMine.mockResolvedValueOnce(mockRequests);

      const result = await controller.findMine({ user: mockUser }, undefined);

      expect(mockService.findMine).toHaveBeenCalledWith('user-1', undefined);
      expect(result).toEqual(mockRequests);
    });

    it('should return empty list when no requests', async () => {
      mockService.findMine.mockResolvedValueOnce([]);

      const result = await controller.findMine({ user: mockUser });

      expect(result).toEqual([]);
    });

    it('should maintain order from service', async () => {
      const mockRequests = [
        { ...mockServiceRequest, id: 'request-2', created_at: new Date('2026-02-13') },
        { ...mockServiceRequest, id: 'request-1', created_at: new Date('2026-02-12') },
      ];
      mockService.findMine.mockResolvedValueOnce(mockRequests);

      const result = await controller.findMine({ user: mockUser });

      expect(result[0].id).toEqual('request-2');
      expect(result[1].id).toEqual('request-1');
    });
  });

  describe('findOne', () => {
    it('should return single request by id', async () => {
      mockService.findByIdForUser.mockResolvedValueOnce(mockServiceRequest);

      const result = await controller.findOne('request-1', { user: mockUser });

      expect(mockService.findByIdForUser).toHaveBeenCalledWith('request-1', mockUser);
      expect(result.id).toEqual('request-1');
    });

    it('should include district information', async () => {
      mockService.findByIdForUser.mockResolvedValueOnce(mockServiceRequest);

      const result = await controller.findOne('request-1', { user: mockUser });

      expect(result.district).toBeDefined();
      expect(result.district.id).toEqual('district-1');
    });

    it('should return all request details', async () => {
      mockService.findByIdForUser.mockResolvedValueOnce(mockServiceRequest);

      const result = await controller.findOne('request-1', { user: mockUser });

      expect(result.address_detail).toEqual('Test Address');
      expect(result.status).toEqual('PENDING');
      expect(result.hours_requested).toBe(3);
      expect(result.price_total).toBe(150);
    });
  });

  describe('findAvailable', () => {
    it('should return provider available requests', async () => {
      const providerUser = {
        id: 'provider-1',
        role: UserRole.PROVIDER,
      };
      const available = [
        {
          id: 'request-available-1',
          district_name: 'Dubai Marina',
          hours_requested: 2,
          price_total: 40,
          scheduled_at: new Date('2026-03-01T10:00:00Z'),
          time_remaining_seconds: 120,
        },
      ];
      mockService.findAvailableForProvider.mockResolvedValueOnce(available);

      const result = await controller.findAvailable({ user: providerUser });

      expect(mockService.findAvailableForProvider).toHaveBeenCalledWith(providerUser);
      expect(result).toEqual(available);
    });
  });

  describe('findAssigned', () => {
    it('should return provider assigned requests', async () => {
      const providerUser = {
        id: 'provider-1',
        role: UserRole.PROVIDER,
      };
      const assigned = [
        { id: 'request-1', status: 'ACCEPTED' },
        { id: 'request-2', status: 'IN_PROGRESS' },
      ];
      mockService.findAssignedForProvider.mockResolvedValueOnce(assigned);

      const result = await controller.findAssigned({ user: providerUser });

      expect(mockService.findAssignedForProvider).toHaveBeenCalledWith('provider-1');
      expect(result).toEqual(assigned);
    });
  });

  describe('accept', () => {
    it('should accept request using provider user', async () => {
      const providerUser = {
        id: 'provider-1',
        role: UserRole.PROVIDER,
      };
      const accepted = { ...mockServiceRequest, status: 'ACCEPTED', provider_id: 'provider-1' };
      mockService.acceptRequest.mockResolvedValueOnce(accepted);

      const result = await controller.accept('request-1', { user: providerUser });

      expect(mockService.acceptRequest).toHaveBeenCalledWith('request-1', providerUser);
      expect(result.status).toEqual('ACCEPTED');
    });
  });

  describe('start', () => {
    it('should start assigned request', async () => {
      const providerUser = {
        id: 'provider-1',
        role: UserRole.PROVIDER,
      };
      mockService.startRequest.mockResolvedValueOnce({
        ...mockServiceRequest,
        status: 'IN_PROGRESS',
        provider_id: providerUser.id,
      });

      const result = await controller.start('request-1', { user: providerUser });

      expect(mockService.startRequest).toHaveBeenCalledWith('request-1', providerUser);
      expect(result.status).toBe('IN_PROGRESS');
    });
  });

  describe('complete', () => {
    it('should complete assigned request', async () => {
      const providerUser = {
        id: 'provider-1',
        role: UserRole.PROVIDER,
      };
      mockService.completeRequest.mockResolvedValueOnce({
        ...mockServiceRequest,
        status: 'COMPLETED',
        provider_id: providerUser.id,
      });

      const result = await controller.complete('request-1', { user: providerUser });

      expect(mockService.completeRequest).toHaveBeenCalledWith('request-1', providerUser);
      expect(result.status).toBe('COMPLETED');
    });
  });

  describe('cancel', () => {
    it('should cancel request with reason', async () => {
      const reasonDto = { cancellation_reason: 'Client unavailable' };
      mockService.cancelRequest.mockResolvedValueOnce({
        ...mockServiceRequest,
        status: 'CANCELLED',
        cancellation_reason: reasonDto.cancellation_reason,
      });

      const result = await controller.cancel('request-1', { user: mockUser }, reasonDto);

      expect(mockService.cancelRequest).toHaveBeenCalledWith('request-1', mockUser, reasonDto);
      expect(result.status).toBe('CANCELLED');
    });
  });

  describe('createRating', () => {
    it('should create rating for completed request', async () => {
      const dto = { stars: 5, comment: 'Excellent' };
      mockService.createRating.mockResolvedValueOnce({
        id: 'rating-1',
        service_request_id: 'request-1',
        stars: 5,
        comment: 'Excellent',
      });

      const result = await controller.createRating('request-1', { user: mockUser }, dto);

      expect(mockService.createRating).toHaveBeenCalledWith('request-1', mockUser, dto);
      expect(result.stars).toBe(5);
    });
  });
});
