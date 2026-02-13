import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsInt, IsNotEmpty, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class CreateServiceRequestDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  district_id: string;

  @ApiProperty({ example: 'Calle 1 #23, Edificio Azul, Piso 2' })
  @IsNotEmpty()
  @MaxLength(500)
  address_detail: string;

  @ApiProperty({ example: 3, minimum: 1, maximum: 8 })
  @IsInt()
  @Min(1)
  @Max(8)
  hours_requested: number;

  @ApiProperty({ example: '2026-03-01T10:00:00Z' })
  @IsDateString()
  scheduled_at: string;
}
