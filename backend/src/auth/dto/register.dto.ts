import { ApiProperty } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  MinLength,
  IsEnum,
  IsUUID,
  IsIn,
  Matches,
} from 'class-validator';
import { UserRole } from '../../users/user.entity';

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'password123', minLength: 6 })
  @IsString()
  @MinLength(6)
  @IsNotEmpty()
  password: string;

  @ApiProperty({ example: 'John Doe' })
  @IsString()
  @IsNotEmpty()
  full_name: string;

  @ApiProperty({ example: '+971501234567' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\+971\d{9}$/, { message: 'phone must match +971XXXXXXXXX format' })
  phone: string;

  @ApiProperty({ enum: [UserRole.CLIENT, UserRole.PROVIDER], example: UserRole.CLIENT })
  @IsEnum(UserRole)
  @IsIn([UserRole.CLIENT, UserRole.PROVIDER], { message: 'Role must be CLIENT or PROVIDER' })
  @IsNotEmpty()
  role: UserRole;

  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  @IsNotEmpty()
  district_id: string;
}
