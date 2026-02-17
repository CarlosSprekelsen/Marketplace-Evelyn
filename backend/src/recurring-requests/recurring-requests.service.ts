import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThanOrEqual, Repository } from 'typeorm';
import { RecurringRequest } from './recurring-request.entity';
import { CreateRecurringRequestDto } from './dto/create-recurring-request.dto';
import { District } from '../districts/district.entity';
import { ServiceRequestsService } from '../service-requests/service-requests.service';
import { User } from '../users/user.entity';

@Injectable()
export class RecurringRequestsService {
  private readonly logger = new Logger(RecurringRequestsService.name);

  constructor(
    @InjectRepository(RecurringRequest)
    private readonly recurringRepository: Repository<RecurringRequest>,
    @InjectRepository(District)
    private readonly districtsRepository: Repository<District>,
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    private readonly serviceRequestsService: ServiceRequestsService,
  ) {}

  async create(clientId: string, dto: CreateRecurringRequestDto): Promise<RecurringRequest> {
    const district = await this.districtsRepository.findOne({
      where: { id: dto.district_id, is_active: true },
    });
    if (!district) {
      throw new BadRequestException('District not found or inactive');
    }

    const nextScheduledAt = this.computeNextScheduledAt(dto.day_of_week, dto.time_of_day);

    const recurring = this.recurringRepository.create({
      client_id: clientId,
      district_id: dto.district_id,
      address_detail: dto.address_detail,
      hours_requested: dto.hours_requested,
      day_of_week: dto.day_of_week,
      time_of_day: dto.time_of_day,
      is_active: true,
      next_scheduled_at: nextScheduledAt,
    });

    const saved = await this.recurringRepository.save(recurring);
    return this.recurringRepository.findOne({
      where: { id: saved.id },
      relations: ['district'],
    }) as Promise<RecurringRequest>;
  }

  async findMine(clientId: string): Promise<RecurringRequest[]> {
    return this.recurringRepository.find({
      where: { client_id: clientId, is_active: true },
      relations: ['district'],
      order: { created_at: 'DESC' },
    });
  }

  async cancel(id: string, clientId: string): Promise<void> {
    const recurring = await this.recurringRepository.findOne({ where: { id } });
    if (!recurring) {
      throw new NotFoundException('Recurring request not found');
    }
    if (recurring.client_id !== clientId) {
      throw new ForbiddenException('You can only cancel your own recurring requests');
    }
    await this.recurringRepository.update(id, { is_active: false });
  }

  async generateDueRequests(): Promise<number> {
    const horizon = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const dueRecurrences = await this.recurringRepository.find({
      where: {
        is_active: true,
        next_scheduled_at: LessThanOrEqual(horizon),
      },
    });

    let generated = 0;

    for (const recurring of dueRecurrences) {
      try {
        const client = await this.usersRepository.findOne({
          where: { id: recurring.client_id },
          relations: ['district'],
        });
        if (!client || client.is_blocked) {
          this.logger.warn(`Skipping recurring ${recurring.id}: client unavailable or blocked`);
          continue;
        }

        await this.serviceRequestsService.create(client, {
          district_id: recurring.district_id,
          address_detail: recurring.address_detail,
          hours_requested: recurring.hours_requested,
          scheduled_at: recurring.next_scheduled_at.toISOString(),
        });

        const nextDate = this.advanceOneWeek(recurring.next_scheduled_at);
        await this.recurringRepository.update(recurring.id, { next_scheduled_at: nextDate });
        generated++;
      } catch (error) {
        this.logger.error(
          `Failed to generate request for recurring ${recurring.id}: ${String(error)}`,
        );
      }
    }

    return generated;
  }

  computeNextScheduledAt(dayOfWeek: number, timeOfDay: string): Date {
    const [hours, minutes] = timeOfDay.split(':').map(Number);
    const now = new Date();

    // Find next occurrence of dayOfWeek (1=Mon..7=Sun)
    const currentJsDay = now.getUTCDay(); // 0=Sun..6=Sat
    const currentIsoDay = currentJsDay === 0 ? 7 : currentJsDay;
    let daysUntil = dayOfWeek - currentIsoDay;
    if (daysUntil < 0) {
      daysUntil += 7;
    }

    const candidate = new Date(
      Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate() + daysUntil,
        hours,
        minutes,
      ),
    );

    // If candidate is in the past or today but time already passed, go to next week
    if (candidate.getTime() <= now.getTime()) {
      candidate.setUTCDate(candidate.getUTCDate() + 7);
    }

    return candidate;
  }

  private advanceOneWeek(date: Date): Date {
    const next = new Date(date.getTime());
    next.setUTCDate(next.getUTCDate() + 7);
    return next;
  }
}
