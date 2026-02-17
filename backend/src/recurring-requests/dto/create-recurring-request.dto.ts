import { ApiProperty } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateRecurringRequestDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  district_id: string;

  @ApiProperty({ example: 'Calle 50' })
  @IsNotEmpty()
  @MaxLength(200)
  address_street: string;

  @ApiProperty({ example: 'Edificio 5' })
  @IsNotEmpty()
  @MaxLength(50)
  address_number: string;

  @ApiProperty({ example: 'Piso 3, Apt 302', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  address_floor_apt?: string;

  @ApiProperty({ example: 'Frente al parque', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  address_reference?: string;

  @ApiProperty({ example: 3, minimum: 1, maximum: 8 })
  @IsInt()
  @Min(1)
  @Max(8)
  hours_requested: number;

  @ApiProperty({ example: 2, description: 'Day of week: 1=Monday, 7=Sunday (ISO 8601)' })
  @IsInt()
  @Min(1)
  @Max(7)
  day_of_week: number;

  @ApiProperty({ example: '10:00', description: 'Time in HH:mm, rounded to :00 or :30' })
  @IsNotEmpty()
  @Matches(/^([01]\d|2[0-1]):(00|30)$/, {
    message: 'time_of_day must be HH:00 or HH:30 between 00:00 and 21:30',
  })
  time_of_day: string;
}
