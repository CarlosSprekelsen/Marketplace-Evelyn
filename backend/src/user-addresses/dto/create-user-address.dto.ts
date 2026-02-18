import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { AddressLabel } from '../user-address.entity';

export class CreateUserAddressDto {
  @ApiProperty({ enum: AddressLabel, example: 'CASA' })
  @IsEnum(AddressLabel)
  label: AddressLabel;

  @ApiProperty({ example: 'Mi casa de playa', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  label_custom?: string;

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

  @ApiProperty({ example: 9.0, required: false })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiProperty({ example: -79.5, required: false })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiProperty({ example: true, required: false })
  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
}
