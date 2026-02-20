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
import { District } from '../districts/district.entity';

@Entity('pricing_rules')
@Index('UQ_pricing_rules_district_active', ['district_id'], {
  unique: true,
  where: '"is_active" = true',
})
export class PricingRule {
  @ApiProperty({
    description: 'Pricing rule UUID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ApiProperty({
    description: 'District ID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @Column({ type: 'uuid', nullable: false })
  district_id: string;

  @ManyToOne(() => District)
  @JoinColumn({ name: 'district_id' })
  district: District;

  @ApiProperty({
    description: 'Price per hour',
    example: 15.0,
  })
  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: false })
  price_per_hour: number;

  @ApiProperty({
    description: 'ISO 4217 currency code',
    example: 'AED',
  })
  @Column({ type: 'varchar', length: 3, default: 'AED' })
  currency: string;

  @ApiProperty({
    description: 'Minimum hours',
    example: 1,
  })
  @Column({ type: 'integer', default: 1 })
  min_hours: number;

  @ApiProperty({
    description: 'Maximum hours',
    example: 8,
  })
  @Column({ type: 'integer', default: 8 })
  max_hours: number;

  @ApiProperty({
    description: 'Whether the pricing rule is active',
    example: true,
  })
  @Column({ type: 'boolean', default: true })
  is_active: boolean;

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
