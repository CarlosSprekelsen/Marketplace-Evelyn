import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ServiceRequest, ServiceRequestStatus } from './service-request.entity';
import { CreateServiceRequestDto } from './dto/create-service-request.dto';
import { PricingService } from '../pricing/pricing.service';
import { District } from '../districts/district.entity';
import { User, UserRole } from '../users/user.entity';

@Injectable()
export class ServiceRequestsService {
  constructor(
    @InjectRepository(ServiceRequest)
    private readonly serviceRequestsRepository: Repository<ServiceRequest>,
    @InjectRepository(District)
    private readonly districtsRepository: Repository<District>,
    private readonly pricingService: PricingService,
  ) {}

  async create(client: User, dto: CreateServiceRequestDto) {
    const district = await this.districtsRepository.findOne({
      where: { id: dto.district_id, is_active: true },
    });

    if (!district) {
      throw new BadRequestException('District not found or inactive');
    }

    const scheduledAt = new Date(dto.scheduled_at);
    if (Number.isNaN(scheduledAt.getTime())) {
      throw new BadRequestException('scheduled_at is invalid');
    }
    if (scheduledAt.getTime() <= Date.now()) {
      throw new BadRequestException('scheduled_at must be in the future');
    }

    const quote = await this.pricingService.getQuote(dto.district_id, dto.hours_requested);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    const request = this.serviceRequestsRepository.create({
      client_id: client.id,
      district_id: dto.district_id,
      address_detail: dto.address_detail,
      hours_requested: dto.hours_requested,
      price_total: quote.price_total,
      scheduled_at: scheduledAt,
      status: ServiceRequestStatus.PENDING,
      expires_at: expiresAt,
    });

    const saved = await this.serviceRequestsRepository.save(request);
    return this.serviceRequestsRepository.findOne({
      where: { id: saved.id },
      relations: ['district', 'provider'],
    });
  }

  async findMine(clientId: string) {
    return this.serviceRequestsRepository.find({
      where: { client_id: clientId },
      relations: ['district', 'provider'],
      order: { created_at: 'DESC' },
    });
  }

  async findByIdForUser(id: string, user: User) {
    const request = await this.serviceRequestsRepository.findOne({
      where: { id },
      relations: ['district', 'provider', 'client'],
    });

    if (!request) {
      throw new NotFoundException('Service request not found');
    }

    if (user.role === UserRole.CLIENT && request.client_id !== user.id) {
      throw new ForbiddenException('You can only access your own service requests');
    }

    if (user.role === UserRole.PROVIDER && request.provider_id !== user.id) {
      throw new ForbiddenException('You can only access assigned service requests');
    }

    return request;
  }

  async expirePendingRequests() {
    return this.serviceRequestsRepository
      .createQueryBuilder()
      .update(ServiceRequest)
      .set({ status: ServiceRequestStatus.EXPIRED })
      .where('status = :status', { status: ServiceRequestStatus.PENDING })
      .andWhere('expires_at < NOW()')
      .execute();
  }
}
