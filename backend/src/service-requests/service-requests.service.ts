import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { ServiceRequest, ServiceRequestStatus } from './service-request.entity';
import { CreateServiceRequestDto } from './dto/create-service-request.dto';
import { PricingService } from '../pricing/pricing.service';
import { District } from '../districts/district.entity';
import { User, UserRole } from '../users/user.entity';
import { Rating } from '../ratings/rating.entity';
import { CancelServiceRequestDto } from './dto/cancel-service-request.dto';
import { CreateRatingDto } from './dto/create-rating.dto';

@Injectable()
export class ServiceRequestsService {
  constructor(
    @InjectRepository(ServiceRequest)
    private readonly serviceRequestsRepository: Repository<ServiceRequest>,
    @InjectRepository(District)
    private readonly districtsRepository: Repository<District>,
    @InjectRepository(Rating)
    private readonly ratingsRepository: Repository<Rating>,
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

  async findAvailableForProvider(provider: User) {
    if (provider.role !== UserRole.PROVIDER) {
      throw new ForbiddenException('Only providers can view available requests');
    }

    const pendingRequests = await this.serviceRequestsRepository.find({
      where: {
        district_id: provider.district_id,
        status: ServiceRequestStatus.PENDING,
      },
      relations: ['district'],
      order: { created_at: 'ASC' },
      take: 10,
    });

    const now = Date.now();
    return pendingRequests
      .filter((request) => request.expires_at.getTime() > now)
      .map((request) => ({
        id: request.id,
        district_name: request.district?.name ?? '',
        hours_requested: request.hours_requested,
        price_total: this.toNumber(request.price_total),
        scheduled_at: request.scheduled_at,
        expires_at: request.expires_at,
        time_remaining_seconds: Math.max(
          0,
          Math.floor((request.expires_at.getTime() - now) / 1000),
        ),
      }));
  }

  async acceptRequest(id: string, provider: User) {
    if (provider.role !== UserRole.PROVIDER) {
      throw new ForbiddenException('Only providers can accept requests');
    }
    if (!provider.is_verified) {
      throw new ForbiddenException('Provider must be verified to accept requests');
    }
    if (provider.is_blocked) {
      throw new ForbiddenException('Blocked provider cannot accept requests');
    }

    const existing = await this.serviceRequestsRepository.findOne({
      where: { id },
      select: ['id', 'district_id'],
    });

    if (!existing) {
      throw new NotFoundException('Service request not found');
    }

    if (existing.district_id !== provider.district_id) {
      throw new ForbiddenException('Provider can only accept requests from own district');
    }

    const updateResult = await this.serviceRequestsRepository
      .createQueryBuilder()
      .update(ServiceRequest)
      .set({
        provider_id: provider.id,
        status: ServiceRequestStatus.ACCEPTED,
        accepted_at: () => 'NOW()',
      })
      .where('id = :id', { id })
      .andWhere('status = :status', { status: ServiceRequestStatus.PENDING })
      .andWhere('expires_at > NOW()')
      .andWhere('provider_id IS NULL')
      .execute();

    if ((updateResult.affected ?? 0) === 0) {
      throw new ConflictException('Ya fue tomado o expiró');
    }

    const accepted = await this.serviceRequestsRepository.findOne({
      where: { id },
      relations: ['district', 'client', 'provider'],
    });

    if (!accepted) {
      throw new NotFoundException('Accepted service request not found');
    }

    return accepted;
  }

  async findAssignedForProvider(providerId: string) {
    return this.serviceRequestsRepository.find({
      where: {
        provider_id: providerId,
        status: In([
          ServiceRequestStatus.ACCEPTED,
          ServiceRequestStatus.IN_PROGRESS,
          ServiceRequestStatus.COMPLETED,
        ]),
      },
      relations: ['district'],
      order: { created_at: 'DESC' },
    });
  }

  async startRequest(id: string, provider: User) {
    const request = await this.serviceRequestsRepository.findOne({
      where: { id },
      relations: ['provider', 'district', 'client'],
    });

    if (!request) {
      throw new NotFoundException('Service request not found');
    }

    if (request.provider_id !== provider.id) {
      throw new ForbiddenException('Only assigned provider can start this service');
    }

    if (request.status !== ServiceRequestStatus.ACCEPTED) {
      throw new BadRequestException('Only ACCEPTED requests can be started');
    }

    request.status = ServiceRequestStatus.IN_PROGRESS;
    request.started_at = new Date();
    await this.serviceRequestsRepository.save(request);

    return request;
  }

  async completeRequest(id: string, provider: User) {
    const request = await this.serviceRequestsRepository.findOne({
      where: { id },
      relations: ['provider', 'district', 'client'],
    });

    if (!request) {
      throw new NotFoundException('Service request not found');
    }

    if (request.provider_id !== provider.id) {
      throw new ForbiddenException('Only assigned provider can complete this service');
    }

    if (request.status !== ServiceRequestStatus.IN_PROGRESS) {
      throw new BadRequestException('Only IN_PROGRESS requests can be completed');
    }

    request.status = ServiceRequestStatus.COMPLETED;
    request.completed_at = new Date();
    await this.serviceRequestsRepository.save(request);

    return request;
  }

  async cancelRequest(id: string, user: User, dto: CancelServiceRequestDto) {
    const request = await this.serviceRequestsRepository.findOne({
      where: { id },
      relations: ['provider', 'district', 'client'],
    });

    if (!request) {
      throw new NotFoundException('Service request not found');
    }

    const canCancel = this.canUserCancelRequest(request, user);
    if (!canCancel.allowed) {
      if (canCancel.reason === 'invalid_status') {
        throw new BadRequestException(
          `Cannot cancel service request with status ${request.status}`,
        );
      }
      throw new ForbiddenException(canCancel.reason);
    }

    request.status = ServiceRequestStatus.CANCELLED;
    request.cancelled_at = new Date();
    request.cancelled_by = user.id;
    request.cancelled_by_role = user.role;
    request.cancellation_reason = dto.cancellation_reason;
    await this.serviceRequestsRepository.save(request);

    return request;
  }

  async createRating(serviceRequestId: string, client: User, dto: CreateRatingDto) {
    const request = await this.serviceRequestsRepository.findOne({
      where: { id: serviceRequestId },
      relations: ['provider', 'client'],
    });

    if (!request) {
      throw new NotFoundException('Service request not found');
    }

    if (request.client_id !== client.id) {
      throw new ForbiddenException('Only request owner can rate this service');
    }

    if (request.status !== ServiceRequestStatus.COMPLETED) {
      throw new BadRequestException('Service request must be COMPLETED before rating');
    }

    if (!request.provider_id) {
      throw new BadRequestException('Service request has no assigned provider');
    }

    const existing = await this.ratingsRepository.findOne({
      where: { service_request_id: serviceRequestId },
    });

    if (existing) {
      throw new ConflictException('Rating already exists for this service request');
    }

    const rating = this.ratingsRepository.create({
      service_request_id: serviceRequestId,
      client_id: client.id,
      provider_id: request.provider_id,
      stars: dto.stars,
      comment: dto.comment ?? null,
    });

    return this.ratingsRepository.save(rating);
  }

  async getProviderRatings(providerId: string) {
    const ratings = await this.ratingsRepository.find({
      where: { provider_id: providerId },
      order: { created_at: 'DESC' },
    });

    const total = ratings.length;
    const average =
      total === 0 ? 0 : ratings.reduce((sum, rating) => sum + rating.stars, 0) / total;

    return {
      provider_id: providerId,
      average_stars: Number(average.toFixed(2)),
      total_ratings: total,
      ratings: ratings.map((rating) => ({
        id: rating.id,
        service_request_id: rating.service_request_id,
        client_id: rating.client_id,
        stars: rating.stars,
        comment: rating.comment,
        created_at: rating.created_at,
      })),
    };
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

  private canUserCancelRequest(
    request: ServiceRequest,
    user: User,
  ): { allowed: boolean; reason: string } {
    if (
      ![
        ServiceRequestStatus.PENDING,
        ServiceRequestStatus.ACCEPTED,
        ServiceRequestStatus.IN_PROGRESS,
      ].includes(request.status)
    ) {
      return { allowed: false, reason: 'invalid_status' };
    }

    if (user.role === UserRole.ADMIN) {
      return { allowed: true, reason: '' };
    }

    if (request.status === ServiceRequestStatus.PENDING) {
      if (user.role === UserRole.CLIENT && request.client_id === user.id) {
        return { allowed: true, reason: '' };
      }
      return { allowed: false, reason: 'Only client owner or admin can cancel PENDING request' };
    }

    if (request.status === ServiceRequestStatus.ACCEPTED) {
      if (user.role === UserRole.CLIENT && request.client_id === user.id) {
        return { allowed: true, reason: '' };
      }
      if (user.role === UserRole.PROVIDER && request.provider_id === user.id) {
        return { allowed: true, reason: '' };
      }
      return {
        allowed: false,
        reason: 'Only owner client, assigned provider, or admin can cancel ACCEPTED request',
      };
    }

    if (request.status === ServiceRequestStatus.IN_PROGRESS) {
      return { allowed: false, reason: 'Only admin can cancel IN_PROGRESS request' };
    }

    return { allowed: false, reason: 'invalid_status' };
  }

  private toNumber(value: number | string): number {
    if (typeof value === 'number') {
      return value;
    }
    return Number(value);
  }
}
