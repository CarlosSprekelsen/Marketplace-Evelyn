import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

export class SetUserVerifiedDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  is_verified: boolean;
}
