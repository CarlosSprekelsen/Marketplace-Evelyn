import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class SetFcmTokenDto {
  @ApiProperty({
    example: 'fcm-device-token',
    description: 'Firebase Cloud Messaging registration token for this device',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  fcm_token: string;
}
