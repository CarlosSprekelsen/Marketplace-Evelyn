import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { District } from './district.entity';
import { User, UserRole } from '../users/user.entity';

@Injectable()
export class DistrictsService {
  constructor(
    @InjectRepository(District)
    private readonly districtsRepository: Repository<District>,
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {}

  async findActive(): Promise<
    Array<Pick<District, 'id' | 'name'> & { has_active_providers: boolean }>
  > {
    const districts = await this.districtsRepository.find({
      where: { is_active: true },
      select: ['id', 'name'],
      order: { name: 'ASC' },
    });

    const providerCounts = await this.usersRepository
      .createQueryBuilder('u')
      .select('u.district_id', 'district_id')
      .addSelect('COUNT(*)', 'cnt')
      .where('u.role = :role', { role: UserRole.PROVIDER })
      .andWhere('u.is_verified = true')
      .andWhere('u.is_blocked = false')
      .andWhere('u.is_available = true')
      .groupBy('u.district_id')
      .getRawMany<{ district_id: string; cnt: string }>();

    const activeDistricts = new Set(
      providerCounts.filter((row) => Number(row.cnt) > 0).map((row) => row.district_id),
    );

    return districts.map((d) => ({
      id: d.id,
      name: d.name,
      has_active_providers: activeDistricts.has(d.id),
    }));
  }
}
