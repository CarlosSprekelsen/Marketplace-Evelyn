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

export enum AddressLabel {
  CASA = 'CASA',
  OFICINA = 'OFICINA',
  OTRO = 'OTRO',
}

@Entity('user_addresses')
@Index(['user_id', 'is_default'])
export class UserAddress {
  @ApiProperty({ description: 'Address UUID' })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', nullable: false })
  user_id: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ApiProperty({ description: 'Label', enum: AddressLabel })
  @Column({ type: 'enum', enum: AddressLabel, nullable: false })
  label: AddressLabel;

  @ApiProperty({ description: 'Custom label (when label=OTRO)', required: false })
  @Column({ type: 'varchar', length: 50, nullable: true })
  label_custom: string | null;

  @ApiProperty({ description: 'District ID' })
  @Column({ type: 'uuid', nullable: false })
  district_id: string;

  @ManyToOne(() => District)
  @JoinColumn({ name: 'district_id' })
  district: District;

  @ApiProperty({ description: 'Street name' })
  @Column({ type: 'varchar', length: 200, nullable: false })
  address_street: string;

  @ApiProperty({ description: 'House/building number' })
  @Column({ type: 'varchar', length: 50, nullable: false })
  address_number: string;

  @ApiProperty({ description: 'Floor/apartment', required: false })
  @Column({ type: 'varchar', length: 100, nullable: true })
  address_floor_apt: string | null;

  @ApiProperty({ description: 'Reference point', required: false })
  @Column({ type: 'varchar', length: 300, nullable: true })
  address_reference: string | null;

  @ApiProperty({ description: 'Latitude for geocoding', required: false })
  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number | null;

  @ApiProperty({ description: 'Longitude for geocoding', required: false })
  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number | null;

  @ApiProperty({ description: 'Whether this is the default address' })
  @Column({ type: 'boolean', default: false })
  is_default: boolean;

  @ApiProperty({ description: 'Creation timestamp' })
  @CreateDateColumn({ type: 'timestamp' })
  created_at: Date;

  @ApiProperty({ description: 'Last update timestamp' })
  @UpdateDateColumn({ type: 'timestamp' })
  updated_at: Date;
}
