import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

export class SetUserBlockedDto {
  @ApiProperty({ example: false })
  @IsBoolean()
  is_blocked: boolean;
}
