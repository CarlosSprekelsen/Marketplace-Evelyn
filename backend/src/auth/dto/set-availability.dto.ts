import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

export class SetAvailabilityDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  is_available: boolean;
}
