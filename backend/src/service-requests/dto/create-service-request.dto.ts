import { ApiProperty } from '@nestjs/swagger';
import {
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  Validate,
  ValidatorConstraint,
  ValidatorConstraintInterface,
  ValidationArguments,
} from 'class-validator';

@ValidatorConstraint({ name: 'isRoundedSlot', async: false })
class IsRoundedSlotConstraint implements ValidatorConstraintInterface {
  validate(value: unknown, _args: ValidationArguments): boolean {
    if (typeof value !== 'string') return false;
    const date = new Date(value);
    if (isNaN(date.getTime())) return false;
    const minutes = date.getUTCMinutes();
    return minutes === 0 || minutes === 30;
  }

  defaultMessage(_args: ValidationArguments): string {
    return 'scheduled_at must be rounded to :00 or :30 minutes';
  }
}

export class CreateServiceRequestDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  district_id: string;

  @ApiProperty({
    example: '123e4567-e89b-12d3-a456-426614174000',
    required: false,
    description: 'Saved address ID. If provided, address fields are populated from it.',
  })
  @IsOptional()
  @IsUUID()
  address_id?: string;

  @ApiProperty({ example: 'Calle 50', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  address_street?: string;

  @ApiProperty({ example: 'Edificio 5', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  address_number?: string;

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

  @ApiProperty({ example: '2026-03-01T10:00:00Z' })
  @IsDateString()
  @Validate(IsRoundedSlotConstraint)
  scheduled_at: string;
}
