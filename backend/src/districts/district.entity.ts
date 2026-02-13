import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';
import { ApiProperty } from '@nestjs/swagger';

@Entity('districts')
export class District {
  @ApiProperty({
    description: 'District UUID',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ApiProperty({
    description: 'District name',
    example: 'Dubai Marina',
  })
  @Column({ type: 'varchar', unique: true, nullable: false })
  name: string;

  @ApiProperty({
    description: 'Whether the district is active',
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
}
