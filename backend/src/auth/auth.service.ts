import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from '../users/users.service';
import { District } from '../districts/district.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
    @InjectRepository(District)
    private districtsRepository: Repository<District>,
  ) {}

  async register(registerDto: RegisterDto) {
    // Validate district exists and is active
    const district = await this.districtsRepository.findOne({
      where: { id: registerDto.district_id },
    });

    if (!district) {
      throw new BadRequestException('District not found');
    }

    if (!district.is_active) {
      throw new BadRequestException('District is not active');
    }

    if (!registerDto.accepted_terms) {
      throw new BadRequestException('You must accept terms and conditions');
    }

    // Create user
    const user = await this.usersService.create({
      email: registerDto.email,
      password: registerDto.password,
      full_name: registerDto.full_name,
      phone: registerDto.phone,
      role: registerDto.role,
      district_id: registerDto.district_id,
      terms_accepted_at: new Date(),
    });

    // Generate tokens
    const tokens = await this.generateTokens(user.id, user.email);

    // Save refresh token hash
    await this.usersService.updateRefreshTokenHash(user.id, tokens.refresh_token);

    // Remove sensitive data
    const { password_hash, refresh_token_hash, ...userWithoutSensitiveData } = user;

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      user: userWithoutSensitiveData,
    };
  }

  async login(loginDto: LoginDto) {
    // Find user
    const user = await this.usersService.findByEmail(loginDto.email);

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Check if user is blocked
    if (user.is_blocked) {
      throw new UnauthorizedException('User is blocked');
    }

    // Validate password
    const isPasswordValid = await this.usersService.validatePassword(user, loginDto.password);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Generate tokens
    const tokens = await this.generateTokens(user.id, user.email);

    // Save refresh token hash
    await this.usersService.updateRefreshTokenHash(user.id, tokens.refresh_token);

    // Remove sensitive data
    const { password_hash, refresh_token_hash, ...userWithoutSensitiveData } = user;

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      user: userWithoutSensitiveData,
    };
  }

  async refresh(userId: string, refreshToken: string) {
    // Validate refresh token
    const isValid = await this.usersService.validateRefreshToken(userId, refreshToken);

    if (!isValid) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Get user
    const user = await this.usersService.findById(userId);

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    // Generate new tokens (rotation)
    const tokens = await this.generateTokens(user.id, user.email);

    // Save new refresh token hash
    await this.usersService.updateRefreshTokenHash(user.id, tokens.refresh_token);

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
    };
  }

  async logout(userId: string) {
    // Invalidate refresh token
    await this.usersService.updateRefreshTokenHash(userId, null);

    return { message: 'Logged out successfully' };
  }

  async getProfile(userId: string) {
    const user = await this.usersService.findById(userId);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Remove sensitive data
    const { password_hash, refresh_token_hash, ...userWithoutSensitiveData } = user;

    return userWithoutSensitiveData;
  }

  private async generateTokens(userId: string, email: string) {
    const payload = { sub: userId, email };

    const [access_token, refresh_token] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get('jwt.secret') as string,
        expiresIn: this.configService.get('jwt.expiresIn'),
      }),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get('jwt.refreshSecret') as string,
        expiresIn: this.configService.get('jwt.refreshExpiresIn'),
      }),
    ]);

    return { access_token, refresh_token };
  }
}
