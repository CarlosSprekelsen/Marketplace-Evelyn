import { Injectable, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, UserRole } from './user.entity';
import * as bcrypt from 'bcrypt';
import { PushNotificationsService } from '../notifications/push-notifications.service';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private readonly pushNotificationsService: PushNotificationsService,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { id },
      relations: ['district'],
    });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { email: email.toLowerCase() },
      relations: ['district'],
    });
  }

  async create(userData: {
    email: string;
    password: string;
    full_name: string;
    phone: string;
    role: string;
    district_id: string;
    terms_accepted_at?: Date;
  }): Promise<User> {
    // Check if email already exists
    const existingUser = await this.findByEmail(userData.email);
    if (existingUser) {
      throw new ConflictException('Email already registered');
    }

    // Hash password
    const password_hash = await bcrypt.hash(userData.password, 10);

    // Create user
    const user = this.usersRepository.create({
      email: userData.email.toLowerCase(),
      password_hash,
      full_name: userData.full_name,
      phone: userData.phone,
      role: userData.role as any,
      district_id: userData.district_id,
      terms_accepted_at: userData.terms_accepted_at ?? null,
    });

    const saved = await this.usersRepository.save(user);

    // Reload with relations so district is included in the response
    const loaded = await this.findById(saved.id);
    if (!loaded) {
      throw new Error('Failed to reload user after creation');
    }
    return loaded;
  }

  async validatePassword(user: User, password: string): Promise<boolean> {
    return bcrypt.compare(password, user.password_hash);
  }

  async updateRefreshTokenHash(userId: string, refreshToken: string | null): Promise<void> {
    let refresh_token_hash: string | null = null;

    if (refreshToken) {
      refresh_token_hash = await bcrypt.hash(refreshToken, 10);
    }

    await this.usersRepository.update(userId, { refresh_token_hash } as any);
  }

  async setPasswordResetToken(userId: string, resetToken: string, expiresAt: Date): Promise<void> {
    const password_reset_token_hash = await bcrypt.hash(resetToken, 10);
    await this.usersRepository.update(userId, {
      password_reset_token_hash,
      password_reset_expires_at: expiresAt,
    } as any);
  }

  async validatePasswordResetToken(user: User, resetToken: string): Promise<boolean> {
    if (!user.password_reset_token_hash || !user.password_reset_expires_at) {
      return false;
    }

    if (user.password_reset_expires_at.getTime() < Date.now()) {
      return false;
    }

    return bcrypt.compare(resetToken, user.password_reset_token_hash);
  }

  async updatePassword(userId: string, newPassword: string): Promise<void> {
    const password_hash = await bcrypt.hash(newPassword, 10);
    await this.usersRepository.update(userId, {
      password_hash,
      refresh_token_hash: null,
    } as any);
  }

  async clearPasswordResetToken(userId: string): Promise<void> {
    await this.usersRepository.update(userId, {
      password_reset_token_hash: null,
      password_reset_expires_at: null,
    } as any);
  }

  async adminResetPassword(userId: string, newPassword: string): Promise<User> {
    const password_hash = await bcrypt.hash(newPassword, 10);
    await this.usersRepository.update(userId, {
      password_hash,
      refresh_token_hash: null,
      password_reset_token_hash: null,
      password_reset_expires_at: null,
    } as any);
    const user = await this.findById(userId);
    if (!user) {
      throw new Error('User not found after password reset');
    }
    return user;
  }

  async setAvailability(userId: string, isAvailable: boolean): Promise<User> {
    await this.usersRepository.update(userId, { is_available: isAvailable });
    const user = await this.findById(userId);
    if (!user) {
      throw new Error('User not found after update');
    }
    return user;
  }

  async validateRefreshToken(userId: string, refreshToken: string): Promise<boolean> {
    const user = await this.findById(userId);

    if (!user || !user.refresh_token_hash) {
      return false;
    }

    return bcrypt.compare(refreshToken, user.refresh_token_hash);
  }

  async setFcmToken(userId: string, fcmToken: string | null): Promise<User> {
    await this.usersRepository.update(userId, { fcm_token: fcmToken });
    const user = await this.findById(userId);
    if (!user) {
      throw new Error('User not found after FCM token update');
    }
    return user;
  }

  async listUsers(role?: UserRole): Promise<User[]> {
    return this.usersRepository.find({
      where: role ? { role } : undefined,
      relations: ['district'],
      order: { created_at: 'DESC' },
    });
  }

  async findPendingProviders(): Promise<User[]> {
    return this.usersRepository.find({
      where: {
        role: UserRole.PROVIDER,
        is_verified: false,
        is_blocked: false,
      },
      relations: ['district'],
      order: { created_at: 'ASC' },
    });
  }

  async setVerified(userId: string, isVerified: boolean): Promise<User> {
    await this.usersRepository.update(userId, { is_verified: isVerified });
    const user = await this.findById(userId);
    if (!user) {
      throw new Error('User not found after verification update');
    }

    if (user.role === UserRole.PROVIDER) {
      await this.pushNotificationsService.sendToTokens([user.fcm_token], {
        title: isVerified ? 'Cuenta verificada' : 'Verificacion revocada',
        body: isVerified
          ? 'Tu cuenta ha sido aprobada. Ya puedes ver y aceptar trabajos disponibles.'
          : 'Tu verificacion ha sido revocada. Contacta soporte para mas informacion.',
        data: {
          type: isVerified ? 'ACCOUNT_VERIFIED' : 'ACCOUNT_UNVERIFIED',
        },
      });
    }

    return user;
  }

  async setBlocked(userId: string, isBlocked: boolean): Promise<User> {
    await this.usersRepository.update(userId, { is_blocked: isBlocked });
    const user = await this.findById(userId);
    if (!user) {
      throw new Error('User not found after block update');
    }
    return user;
  }
}
