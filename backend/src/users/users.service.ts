import { Injectable, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { id },
      relations: ['district'],
    });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { email },
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
      email: userData.email,
      password_hash,
      full_name: userData.full_name,
      phone: userData.phone,
      role: userData.role as any,
      district_id: userData.district_id,
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

  async validateRefreshToken(userId: string, refreshToken: string): Promise<boolean> {
    const user = await this.findById(userId);

    if (!user || !user.refresh_token_hash) {
      return false;
    }

    return bcrypt.compare(refreshToken, user.refresh_token_hash);
  }
}
