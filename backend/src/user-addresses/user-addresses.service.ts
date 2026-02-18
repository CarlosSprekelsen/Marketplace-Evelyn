import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserAddress } from './user-address.entity';
import { CreateUserAddressDto } from './dto/create-user-address.dto';
import { UpdateUserAddressDto } from './dto/update-user-address.dto';
import { District } from '../districts/district.entity';

@Injectable()
export class UserAddressesService {
  constructor(
    @InjectRepository(UserAddress)
    private readonly addressesRepository: Repository<UserAddress>,
    @InjectRepository(District)
    private readonly districtsRepository: Repository<District>,
  ) {}

  async create(userId: string, dto: CreateUserAddressDto): Promise<UserAddress> {
    const count = await this.addressesRepository.count({ where: { user_id: userId } });
    if (count >= 10) {
      throw new BadRequestException('Maximum of 10 saved addresses reached');
    }

    const district = await this.districtsRepository.findOne({
      where: { id: dto.district_id, is_active: true },
    });
    if (!district) {
      throw new BadRequestException('District not found or inactive');
    }

    if (dto.is_default) {
      await this.addressesRepository.update({ user_id: userId }, { is_default: false });
    }

    const address = this.addressesRepository.create({
      user_id: userId,
      label: dto.label,
      label_custom: dto.label_custom ?? null,
      district_id: dto.district_id,
      address_street: dto.address_street,
      address_number: dto.address_number,
      address_floor_apt: dto.address_floor_apt ?? null,
      address_reference: dto.address_reference ?? null,
      latitude: dto.latitude ?? null,
      longitude: dto.longitude ?? null,
      is_default: dto.is_default ?? false,
    });

    const saved = await this.addressesRepository.save(address);
    return this.addressesRepository.findOne({
      where: { id: saved.id },
      relations: ['district'],
    }) as Promise<UserAddress>;
  }

  async findAllByUser(userId: string): Promise<UserAddress[]> {
    return this.addressesRepository.find({
      where: { user_id: userId },
      relations: ['district'],
      order: { is_default: 'DESC', created_at: 'DESC' },
    });
  }

  async findOne(id: string, userId: string): Promise<UserAddress> {
    const address = await this.addressesRepository.findOne({
      where: { id },
      relations: ['district'],
    });
    if (!address) {
      throw new NotFoundException('Address not found');
    }
    if (address.user_id !== userId) {
      throw new ForbiddenException('You can only access your own addresses');
    }
    return address;
  }

  async update(id: string, userId: string, dto: UpdateUserAddressDto): Promise<UserAddress> {
    const address = await this.findOne(id, userId);

    if (dto.district_id && dto.district_id !== address.district_id) {
      const district = await this.districtsRepository.findOne({
        where: { id: dto.district_id, is_active: true },
      });
      if (!district) {
        throw new BadRequestException('District not found or inactive');
      }
    }

    if (dto.is_default) {
      await this.addressesRepository.update({ user_id: userId }, { is_default: false });
    }

    Object.assign(address, dto);
    await this.addressesRepository.save(address);
    return this.addressesRepository.findOne({
      where: { id },
      relations: ['district'],
    }) as Promise<UserAddress>;
  }

  async remove(id: string, userId: string): Promise<void> {
    await this.findOne(id, userId);
    await this.addressesRepository.delete(id);
  }

  async setDefault(id: string, userId: string): Promise<UserAddress> {
    const address = await this.findOne(id, userId);
    await this.addressesRepository.manager.transaction(async (manager) => {
      await manager.update(UserAddress, { user_id: userId }, { is_default: false });
      await manager.update(UserAddress, { id }, { is_default: true });
    });
    address.is_default = true;
    return address;
  }
}
