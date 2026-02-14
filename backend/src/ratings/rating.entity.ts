import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { ApiProperty } from '@nestjs/swagger';
import { ServiceRequest } from '../service-requests/service-request.entity';
import { User } from '../users/user.entity';

@Entity('ratings')
export class Rating {
  @ApiProperty({
    description: 'Rating UUID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ApiProperty({
    description: 'Service request ID (unique)',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @Column({ type: 'uuid', unique: true, nullable: false })
  service_request_id: string;

  @ManyToOne(() => ServiceRequest)
  @JoinColumn({ name: 'service_request_id' })
  serviceRequest: ServiceRequest;

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
    description: 'Provider ID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @Column({ type: 'uuid', nullable: false })
  provider_id: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'provider_id' })
  provider: User;

  @ApiProperty({
    description: 'Rating stars (1-5)',
    example: 5,
    minimum: 1,
    maximum: 5,
  })
  @Column({ type: 'integer', nullable: false })
  stars: number;

  @ApiProperty({
    description: 'Optional comment (max 500 chars)',
    example: 'Excellent service, very professional!',
    required: false,
  })
  @Column({ type: 'text', nullable: true })
  comment: string | null;

  @ApiProperty({
    description: 'Creation timestamp',
    example: '2026-02-13T10:00:00.000Z',
  })
  @CreateDateColumn({ type: 'timestamp' })
  created_at: Date;
}
