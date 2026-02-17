import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsUUID, Matches, Max, MaxLength, Min } from 'class-validator';

export class CreateRecurringRequestDto {
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
