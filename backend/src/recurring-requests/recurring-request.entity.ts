import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { ApiProperty } from '@nestjs/swagger';
import { User } from '../users/user.entity';
import { District } from '../districts/district.entity';

@Entity('recurring_requests')
export class RecurringRequest {
  @ApiProperty({ description: 'UUID', example: '123e4567-e89b-12d3-a456-426614174000' })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', nullable: false })
  client_id: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'client_id' })
  client: User;

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

  @ApiProperty({ description: 'Hours requested (1-8)', example: 3 })
  @Column({ type: 'integer', nullable: false })
  hours_requested: number;

  @ApiProperty({ description: 'Day of week (1=Mon, 7=Sun, ISO 8601)', example: 2 })
  @Column({ type: 'integer', nullable: false })
  day_of_week: number;

  @ApiProperty({ description: 'Time of day (HH:mm, rounded to :00 or :30)', example: '10:00' })
  @Column({ type: 'varchar', length: 5, nullable: false })
  time_of_day: string;

  @ApiProperty({ description: 'Whether recurrence is active', example: true })
  @Column({ type: 'boolean', default: true })
  is_active: boolean;

  @ApiProperty({ description: 'Next scheduled generation date (UTC)' })
  @Column({ type: 'timestamp', nullable: false })
  next_scheduled_at: Date;

  @CreateDateColumn({ type: 'timestamp' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamp' })
  updated_at: Date;
}
