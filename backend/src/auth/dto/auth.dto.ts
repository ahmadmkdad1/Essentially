import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsIn,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { Role } from '../../common/enums.js';
import { User } from '../../users/user.entity.js';

export class RegisterDto {
  @ApiProperty({ example: 'Ahmad Mokdad' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  fullName: string;

  @ApiProperty({ example: 'ahmad@example.com' })
  @IsEmail()
  @MaxLength(160)
  email: string;

  @ApiProperty({ minLength: 8, example: 'Secret123' })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).+$/, {
    message: 'password must contain at least one letter and one number',
  })
  password: string;

  @ApiProperty({ enum: [Role.USER, Role.PROVIDER] })
  @IsIn([Role.USER, Role.PROVIDER], {
    message: 'role must be USER or PROVIDER',
  })
  role: Role.USER | Role.PROVIDER;

  @ApiPropertyOptional({ example: '+961 70 123 456' })
  @IsOptional()
  @Matches(/^\+?[0-9 ()-]{6,30}$/, {
    message: 'phone must be a valid phone number',
  })
  phone?: string;

  @ApiPropertyOptional({ description: 'Required for providers' })
  @ValidateIf((o: RegisterDto) => o.role === Role.PROVIDER)
  @IsString()
  @IsNotEmpty({ message: 'businessName is required for providers' })
  @MaxLength(120)
  businessName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;
}

export class LoginDto {
  @ApiProperty({ example: 'user@essentially.app' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'Demo@1234' })
  @IsString()
  @IsNotEmpty()
  password: string;
}

export class AuthResponseDto {
  @ApiProperty()
  accessToken: string;

  @ApiProperty({ type: User })
  user: User;
}
