import { ApiProperty } from '@nestjs/swagger';
import {
  IsDateString,
  IsInt,
  IsNotEmpty,
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
  @Validate(IsRoundedSlotConstraint)
  scheduled_at: string;
}
