import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { RecurringRequestsService } from './recurring-requests.service';

describe('RecurringRequestsService', () => {
  let service: RecurringRequestsService;
  let recurringRepository: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
    find: jest.Mock;
    update: jest.Mock;
  };
  let districtsRepository: { findOne: jest.Mock };
  let usersRepository: { findOne: jest.Mock };
  let serviceRequestsService: { create: jest.Mock };

  beforeEach(() => {
    recurringRepository = {
      create: jest.fn((data) => ({ id: 'rec-1', ...data })),
      save: jest.fn((data) => Promise.resolve({ id: 'rec-1', ...data })),
      findOne: jest.fn(),
      find: jest.fn(),
      update: jest.fn(),
    };
    districtsRepository = { findOne: jest.fn() };
    usersRepository = { findOne: jest.fn() };
    serviceRequestsService = { create: jest.fn() };

    service = new RecurringRequestsService(
      recurringRepository as any,
      districtsRepository as any,
      usersRepository as any,
      serviceRequestsService as any,
    );
  });

  describe('create', () => {
    const dto = {
      district_id: 'dist-1',
      address_detail: 'Building 5, Apt 302',
      hours_requested: 3,
      day_of_week: 2,
      time_of_day: '10:00',
    };

    it('should create a recurring request when district is valid', async () => {
      districtsRepository.findOne.mockResolvedValue({ id: 'dist-1', is_active: true });
      recurringRepository.findOne.mockResolvedValue({
        id: 'rec-1',
        ...dto,
        client_id: 'client-1',
        is_active: true,
        district: { id: 'dist-1', name: 'Dubai Marina' },
      });

      const result = await service.create('client-1', dto);

      expect(recurringRepository.create).toHaveBeenCalled();
      expect(recurringRepository.save).toHaveBeenCalled();
      expect(result.id).toBe('rec-1');
      expect(result.is_active).toBe(true);
    });

    it('should reject when district not found', async () => {
      districtsRepository.findOne.mockResolvedValue(null);

      await expect(service.create('client-1', dto)).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('cancel', () => {
    it('should deactivate an owned recurring request', async () => {
      recurringRepository.findOne.mockResolvedValue({ id: 'rec-1', client_id: 'client-1' });

      await service.cancel('rec-1', 'client-1');

      expect(recurringRepository.update).toHaveBeenCalledWith('rec-1', { is_active: false });
    });

    it('should reject when not found', async () => {
      recurringRepository.findOne.mockResolvedValue(null);

      await expect(service.cancel('rec-999', 'client-1')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should reject when not owner', async () => {
      recurringRepository.findOne.mockResolvedValue({ id: 'rec-1', client_id: 'other-client' });

      await expect(service.cancel('rec-1', 'client-1')).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('computeNextScheduledAt', () => {
    it('should return a future date for the given day and time', () => {
      const result = service.computeNextScheduledAt(2, '10:00'); // Tuesday 10:00

      expect(result.getTime()).toBeGreaterThan(Date.now());
      // ISO day: 1=Mon..7=Sun. JS getUTCDay: 0=Sun..6=Sat
      const jsDay = result.getUTCDay();
      const isoDay = jsDay === 0 ? 7 : jsDay;
      expect(isoDay).toBe(2); // Tuesday
      expect(result.getUTCHours()).toBe(10);
      expect(result.getUTCMinutes()).toBe(0);
    });
  });

  describe('generateDueRequests', () => {
    it('should generate service requests for due recurrences', async () => {
      const pastDate = new Date(Date.now() - 60000);
      recurringRepository.find.mockResolvedValue([
        {
          id: 'rec-1',
          client_id: 'client-1',
          district_id: 'dist-1',
          address_detail: 'Apt 5',
          hours_requested: 2,
          next_scheduled_at: pastDate,
        },
      ]);
      usersRepository.findOne.mockResolvedValue({
        id: 'client-1',
        is_blocked: false,
        district: { id: 'dist-1' },
      });
      serviceRequestsService.create.mockResolvedValue({ id: 'sr-1' });

      const count = await service.generateDueRequests();

      expect(count).toBe(1);
      expect(serviceRequestsService.create).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'client-1' }),
        expect.objectContaining({
          district_id: 'dist-1',
          hours_requested: 2,
        }),
      );
      expect(recurringRepository.update).toHaveBeenCalledWith('rec-1', {
        next_scheduled_at: expect.any(Date),
      });
    });

    it('should skip blocked clients', async () => {
      recurringRepository.find.mockResolvedValue([
        {
          id: 'rec-1',
          client_id: 'blocked-client',
          next_scheduled_at: new Date(),
        },
      ]);
      usersRepository.findOne.mockResolvedValue({ id: 'blocked-client', is_blocked: true });

      const count = await service.generateDueRequests();

      expect(count).toBe(0);
      expect(serviceRequestsService.create).not.toHaveBeenCalled();
    });

    it('should return 0 when no due recurrences', async () => {
      recurringRepository.find.mockResolvedValue([]);

      const count = await service.generateDueRequests();

      expect(count).toBe(0);
    });
  });
});
