import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { UserAddressesService } from './user-addresses.service';
import { AddressLabel } from './user-address.entity';

describe('UserAddressesService', () => {
  let service: UserAddressesService;
  let addressesRepository: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
    find: jest.Mock;
    count: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
  };
  let districtsRepository: { findOne: jest.Mock };

  const userId = 'user-1';
  const dto = {
    label: AddressLabel.CASA,
    district_id: 'dist-1',
    address_street: 'Calle 50',
    address_number: 'Edificio 5',
    is_default: false,
  };

  beforeEach(() => {
    addressesRepository = {
      create: jest.fn((data) => ({ id: 'addr-1', ...data })),
      save: jest.fn((data) => Promise.resolve({ id: 'addr-1', ...data })),
      findOne: jest.fn(),
      find: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    };
    districtsRepository = { findOne: jest.fn() };

    service = new UserAddressesService(
      addressesRepository as any,
      districtsRepository as any,
    );
  });

  describe('create', () => {
    it('should create an address successfully', async () => {
      addressesRepository.count.mockResolvedValue(0);
      districtsRepository.findOne.mockResolvedValue({ id: 'dist-1', is_active: true });
      addressesRepository.findOne.mockResolvedValue({
        id: 'addr-1',
        user_id: userId,
        ...dto,
        district: { id: 'dist-1', name: 'Panama City' },
      });

      const result = await service.create(userId, dto);

      expect(addressesRepository.create).toHaveBeenCalled();
      expect(addressesRepository.save).toHaveBeenCalled();
      expect(result.id).toBe('addr-1');
    });

    it('should throw when max 10 addresses reached', async () => {
      addressesRepository.count.mockResolvedValue(10);

      await expect(service.create(userId, dto)).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw when district not found', async () => {
      addressesRepository.count.mockResolvedValue(0);
      districtsRepository.findOne.mockResolvedValue(null);

      await expect(service.create(userId, dto)).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should clear other defaults when is_default is true', async () => {
      addressesRepository.count.mockResolvedValue(0);
      districtsRepository.findOne.mockResolvedValue({ id: 'dist-1', is_active: true });
      addressesRepository.findOne.mockResolvedValue({ id: 'addr-1', ...dto, is_default: true });

      await service.create(userId, { ...dto, is_default: true });

      expect(addressesRepository.update).toHaveBeenCalledWith(
        { user_id: userId },
        { is_default: false },
      );
    });
  });

  describe('findOne', () => {
    it('should return address when owned by user', async () => {
      addressesRepository.findOne.mockResolvedValue({
        id: 'addr-1',
        user_id: userId,
      });

      const result = await service.findOne('addr-1', userId);
      expect(result.id).toBe('addr-1');
    });

    it('should throw NotFoundException when not found', async () => {
      addressesRepository.findOne.mockResolvedValue(null);

      await expect(service.findOne('addr-999', userId)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should throw ForbiddenException when not owned', async () => {
      addressesRepository.findOne.mockResolvedValue({
        id: 'addr-1',
        user_id: 'other-user',
      });

      await expect(service.findOne('addr-1', userId)).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('remove', () => {
    it('should delete an owned address', async () => {
      addressesRepository.findOne.mockResolvedValue({
        id: 'addr-1',
        user_id: userId,
      });

      await service.remove('addr-1', userId);

      expect(addressesRepository.delete).toHaveBeenCalledWith('addr-1');
    });
  });

  describe('setDefault', () => {
    it('should set address as default and clear others', async () => {
      const addr = { id: 'addr-1', user_id: userId, is_default: false };
      addressesRepository.findOne.mockResolvedValue(addr);

      await service.setDefault('addr-1', userId);

      expect(addressesRepository.update).toHaveBeenCalledWith(
        { user_id: userId },
        { is_default: false },
      );
      expect(addressesRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({ is_default: true }),
      );
    });
  });
});
