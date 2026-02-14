import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CancelServiceRequestDto {
  @ApiProperty({
    example: 'No puedo atender en el horario acordado',
    maxLength: 500,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  cancellation_reason: string;
}
