import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { ServiceRequestStatus } from '../../service-requests/service-request.entity';

export class SetRequestStatusDto {
  @ApiProperty({ enum: ServiceRequestStatus, example: ServiceRequestStatus.CANCELLED })
  @IsEnum(ServiceRequestStatus)
  status: ServiceRequestStatus;

  @ApiProperty({
    example: 'Cancelled manually by admin',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  cancellation_reason?: string;
}
