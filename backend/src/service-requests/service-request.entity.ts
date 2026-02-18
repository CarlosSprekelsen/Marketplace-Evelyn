import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { ApiProperty } from '@nestjs/swagger';
import { User } from '../users/user.entity';
import { District } from '../districts/district.entity';
import { RecurringRequest } from '../recurring-requests/recurring-request.entity';

export enum ServiceRequestStatus {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  EXPIRED = 'EXPIRED',
}

@Entity('service_requests')
@Index(['status', 'expires_at'])
export class ServiceRequest {
  @ApiProperty({
    description: 'Service request UUID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ApiProperty({
    description: 'Client ID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @Column({ type: 'uuid', nullable: false })
  client_id: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'client_id' })
  client: User;

  @ApiProperty({
    description: 'Provider ID (nullable until accepted)',
    example: '123e4567-e89b-12d3-a456-426614174000',
    required: false,
  })
  @Column({ type: 'uuid', nullable: true })
  provider_id: string;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'provider_id' })
  provider: User;

  @ApiProperty({
    description: 'District ID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @Column({ type: 'uuid', nullable: false })
  district_id: string;

  @ManyToOne(() => District)
  @JoinColumn({ name: 'district_id' })
  district: District;

  @ApiProperty({ description: 'Street / Avenue', example: 'Calle 50' })
  @Column({ type: 'varchar', length: 200, nullable: false })
  address_street: string;

  @ApiProperty({ description: 'House / Building number', example: 'Edificio 5' })
  @Column({ type: 'varchar', length: 50, nullable: false })
  address_number: string;

  @ApiProperty({ description: 'Floor / Apartment', example: 'Piso 3, Apt 302', required: false })
  @Column({ type: 'varchar', length: 100, nullable: true })
  address_floor_apt: string | null;

  @ApiProperty({ description: 'Reference point', example: 'Frente al parque', required: false })
  @Column({ type: 'varchar', length: 300, nullable: true })
  address_reference: string | null;

  @ApiProperty({ description: 'Latitude of service address', required: false, example: 25.2048 })
  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  address_latitude: number | null;

  @ApiProperty({ description: 'Longitude of service address', required: false, example: 55.2708 })
  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  address_longitude: number | null;

  @ApiProperty({
    description: 'Hours requested (1-8)',
    example: 3,
  })
  @Column({ type: 'integer', nullable: false })
  hours_requested: number;

  @ApiProperty({
    description: 'Total price',
    example: 45.0,
  })
  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: false })
  price_total: number;

  @ApiProperty({
    description: 'Scheduled date and time (UTC)',
    example: '2026-03-01T10:00:00.000Z',
  })
  @Column({ type: 'timestamp', nullable: false })
  scheduled_at: Date;

  @ApiProperty({
    description: 'Request status',
    enum: ServiceRequestStatus,
    example: ServiceRequestStatus.PENDING,
  })
  @Column({
    type: 'enum',
    enum: ServiceRequestStatus,
    default: ServiceRequestStatus.PENDING,
  })
  status: ServiceRequestStatus;

  @ApiProperty({
    description: 'Acceptance timestamp',
    example: '2026-02-13T10:05:00.000Z',
    required: false,
  })
  @Column({ type: 'timestamp', nullable: true })
  accepted_at: Date;

  @ApiProperty({
    description: 'Start timestamp',
    example: '2026-03-01T10:00:00.000Z',
    required: false,
  })
  @Column({ type: 'timestamp', nullable: true })
  started_at: Date;

  @ApiProperty({
    description: 'Completion timestamp',
    example: '2026-03-01T13:00:00.000Z',
    required: false,
  })
  @Column({ type: 'timestamp', nullable: true })
  completed_at: Date;

  @ApiProperty({
    description: 'Cancellation timestamp',
    example: '2026-02-13T11:00:00.000Z',
    required: false,
  })
  @Column({ type: 'timestamp', nullable: true })
  cancelled_at: Date;

  @ApiProperty({
    description: 'ID of user who cancelled',
    example: '123e4567-e89b-12d3-a456-426614174000',
    required: false,
  })
  @Column({ type: 'uuid', nullable: true })
  cancelled_by: string;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'cancelled_by' })
  cancelledByUser: User;

  @ApiProperty({
    description: 'Role of user who cancelled',
    example: 'CLIENT',
    required: false,
  })
  @Column({ type: 'varchar', nullable: true })
  cancelled_by_role: string;

  @ApiProperty({
    description: 'Cancellation reason (required if cancelled)',
    example: 'Changed my mind',
    required: false,
  })
  @Column({ type: 'text', nullable: true })
  cancellation_reason: string;

  @ApiProperty({
    description: 'Recurring request ID (if generated by a recurrence)',
    required: false,
  })
  @Column({ type: 'uuid', nullable: true })
  recurring_request_id: string | null;

  @ManyToOne(() => RecurringRequest, { nullable: true })
  @JoinColumn({ name: 'recurring_request_id' })
  recurringRequest: RecurringRequest;

  @ApiProperty({
    description: 'Expiration timestamp (5 minutes from creation)',
    example: '2026-02-13T10:05:00.000Z',
  })
  @Column({ type: 'timestamp', nullable: false })
  expires_at: Date;

  @ApiProperty({
    description: 'Creation timestamp',
    example: '2026-02-13T10:00:00.000Z',
  })
  @CreateDateColumn({ type: 'timestamp' })
  created_at: Date;

  @ApiProperty({
    description: 'Last update timestamp',
    example: '2026-02-13T10:00:00.000Z',
  })
  @UpdateDateColumn({ type: 'timestamp' })
  updated_at: Date;
}
