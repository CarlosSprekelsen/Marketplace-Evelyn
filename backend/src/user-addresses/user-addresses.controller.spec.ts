import { UserAddressesController } from './user-addresses.controller';
import { AddressLabel } from './user-address.entity';

describe('UserAddressesController', () => {
  let controller: UserAddressesController;
  let mockService: {
    create: jest.Mock;
    findAllByUser: jest.Mock;
    update: jest.Mock;
    remove: jest.Mock;
    setDefault: jest.Mock;
  };

  const mockReq = { user: { id: 'user-1' } };

  const mockAddress = {
    id: 'addr-1',
    user_id: 'user-1',
    label: AddressLabel.CASA,
    address_street: 'Calle 50',
    address_number: 'Edificio 5',
  };

  beforeEach(() => {
    mockService = {
      create: jest.fn().mockResolvedValue(mockAddress),
      findAllByUser: jest.fn().mockResolvedValue([mockAddress]),
      update: jest.fn().mockResolvedValue(mockAddress),
      remove: jest.fn().mockResolvedValue(undefined),
      setDefault: jest.fn().mockResolvedValue(mockAddress),
    };

    controller = new UserAddressesController(mockService as any);
  });

  it('should create an address', async () => {
    const dto = {
      label: AddressLabel.CASA,
      district_id: 'dist-1',
      address_street: 'Calle 50',
      address_number: 'Edificio 5',
    };

    const result = await controller.create(mockReq, dto);

    expect(mockService.create).toHaveBeenCalledWith('user-1', dto);
    expect(result.id).toBe('addr-1');
  });

  it('should list addresses', async () => {
    const result = await controller.findAll(mockReq);

    expect(mockService.findAllByUser).toHaveBeenCalledWith('user-1');
    expect(result).toHaveLength(1);
  });

  it('should delete an address', async () => {
    const result = await controller.remove(mockReq, 'addr-1');

    expect(mockService.remove).toHaveBeenCalledWith('addr-1', 'user-1');
    expect(result.message).toBe('Address deleted');
  });

  it('should set default', async () => {
    const result = await controller.setDefault(mockReq, 'addr-1');

    expect(mockService.setDefault).toHaveBeenCalledWith('addr-1', 'user-1');
    expect(result.id).toBe('addr-1');
  });
});
