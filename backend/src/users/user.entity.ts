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
import { District } from '../districts/district.entity';

export enum UserRole {
  CLIENT = 'CLIENT',
  PROVIDER = 'PROVIDER',
  ADMIN = 'ADMIN',
}

@Entity('users')
export class User {
  @ApiProperty({
    description: 'User UUID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ApiProperty({
    description: 'User email',
    example: 'user@example.com',
  })
  @Column({ type: 'varchar', unique: true, nullable: false })
  email: string;

  @Column({ type: 'varchar', nullable: false })
  password_hash: string;

  @ApiProperty({
    description: 'User role',
    enum: UserRole,
    example: UserRole.CLIENT,
  })
  @Column({ type: 'enum', enum: UserRole, nullable: false })
  role: UserRole;

  @ApiProperty({
    description: 'Full name',
    example: 'John Doe',
  })
  @Column({ type: 'varchar', nullable: false })
  full_name: string;

  @ApiProperty({
    description: 'Phone number',
    example: '+971501234567',
  })
  @Column({ type: 'varchar', nullable: false })
  phone: string;

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
    description: 'Whether the user is verified',
    example: false,
  })
  @Column({ type: 'boolean', default: false })
  is_verified: boolean;

  @ApiProperty({
    description: 'Whether the user is blocked',
    example: false,
  })
  @Column({ type: 'boolean', default: false })
  is_blocked: boolean;

  @ApiProperty({
    description: 'Whether the provider is available for jobs',
    example: true,
  })
  @Column({ type: 'boolean', default: true })
  is_available: boolean;

  @ApiProperty({
    description: 'Firebase Cloud Messaging token for push notifications',
    example: 'fcm-token-example',
    required: false,
  })
  @Column({ type: 'varchar', nullable: true })
  fcm_token: string | null;

  @Column({ type: 'varchar', nullable: true })
  refresh_token_hash: string;

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
