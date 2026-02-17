import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { UserRole } from '../users/user.entity';

describe('AuthService', () => {
  const baseUser = {
    id: 'user-1',
    email: 'user@mail.com',
    password_hash: 'hashed-password',
    refresh_token_hash: 'hashed-refresh',
    password_reset_token_hash: null,
    password_reset_expires_at: null,
    role: UserRole.CLIENT,
    full_name: 'User Test',
    phone: '999',
    district_id: 'district-1',
    is_verified: false,
    is_blocked: false,
    created_at: new Date(),
    updated_at: new Date(),
  } as any;

  let authService: AuthService;
  let usersService: {
    create: jest.Mock;
    findByEmail: jest.Mock;
    findById: jest.Mock;
    validatePassword: jest.Mock;
    updateRefreshTokenHash: jest.Mock;
    validateRefreshToken: jest.Mock;
    setPasswordResetToken: jest.Mock;
    validatePasswordResetToken: jest.Mock;
    updatePassword: jest.Mock;
    clearPasswordResetToken: jest.Mock;
  };
  let jwtService: { signAsync: jest.Mock };
  let configService: { get: jest.Mock };
  let districtsRepository: { findOne: jest.Mock };

  beforeEach(() => {
    usersService = {
      create: jest.fn(),
      findByEmail: jest.fn(),
      findById: jest.fn(),
      validatePassword: jest.fn(),
      updateRefreshTokenHash: jest.fn(),
      validateRefreshToken: jest.fn(),
      setPasswordResetToken: jest.fn(),
      validatePasswordResetToken: jest.fn(),
      updatePassword: jest.fn(),
      clearPasswordResetToken: jest.fn(),
    };

    jwtService = {
      signAsync: jest
        .fn()
        .mockResolvedValueOnce('access-token')
        .mockResolvedValueOnce('refresh-token'),
    };

    configService = {
      get: jest.fn((key: string) => {
        if (key === 'jwt.secret') return 'jwt-secret';
        if (key === 'jwt.expiresIn') return '30m';
        if (key === 'jwt.refreshSecret') return 'refresh-secret';
        if (key === 'jwt.refreshExpiresIn') return '30d';
        if (key === 'nodeEnv') return 'test';
        return undefined;
      }),
    };

    districtsRepository = {
      findOne: jest.fn(),
    };

    authService = new AuthService(
      usersService as any,
      jwtService as any,
      configService as any,
      districtsRepository as any,
    );
  });

  it('register success: creates user, hashes refresh token, returns tokens + user', async () => {
    districtsRepository.findOne.mockResolvedValue({ id: 'district-1', is_active: true });
    usersService.create.mockResolvedValue(baseUser);

    const result = await authService.register({
      email: baseUser.email,
      password: '123456',
      full_name: baseUser.full_name,
      phone: baseUser.phone,
      role: UserRole.CLIENT,
      district_id: baseUser.district_id,
      accepted_terms: true,
    });

    expect(result).toEqual({
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      user: expect.objectContaining({
        id: baseUser.id,
        email: baseUser.email,
      }),
    });
    expect(usersService.updateRefreshTokenHash).toHaveBeenCalledWith(baseUser.id, 'refresh-token');
  });

  it('login success: returns tokens + user', async () => {
    usersService.findByEmail.mockResolvedValue(baseUser);
    usersService.validatePassword.mockResolvedValue(true);
    jwtService.signAsync
      .mockReset()
      .mockResolvedValueOnce('access-login')
      .mockResolvedValueOnce('refresh-login');

    const result = await authService.login({
      email: baseUser.email,
      password: '123456',
    });

    expect(result.access_token).toBe('access-login');
    expect(result.refresh_token).toBe('refresh-login');
    expect(result.user).toEqual(expect.objectContaining({ id: baseUser.id }));
  });

  it('login failed: throws on invalid credentials', async () => {
    usersService.findByEmail.mockResolvedValue(baseUser);
    usersService.validatePassword.mockResolvedValue(false);

    await expect(
      authService.login({
        email: baseUser.email,
        password: 'wrong',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refresh success: validates old token and rotates tokens', async () => {
    usersService.validateRefreshToken.mockResolvedValue(true);
    usersService.findById.mockResolvedValue(baseUser);
    jwtService.signAsync
      .mockReset()
      .mockResolvedValueOnce('access-rotated')
      .mockResolvedValueOnce('refresh-rotated');

    const result = await authService.refresh(baseUser.id, 'old-refresh-token');

    expect(result).toEqual({
      access_token: 'access-rotated',
      refresh_token: 'refresh-rotated',
    });
    expect(usersService.updateRefreshTokenHash).toHaveBeenCalledWith(
      baseUser.id,
      'refresh-rotated',
    );
  });

  it('refresh invalid token: throws unauthorized', async () => {
    usersService.validateRefreshToken.mockResolvedValue(false);

    await expect(authService.refresh(baseUser.id, 'invalid')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('blocked user: login is rejected', async () => {
    usersService.findByEmail.mockResolvedValue({ ...baseUser, is_blocked: true });

    await expect(
      authService.login({
        email: baseUser.email,
        password: '123456',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('register with missing district: rejected', async () => {
    districtsRepository.findOne.mockResolvedValue(null);

    await expect(
      authService.register({
        email: baseUser.email,
        password: '123456',
        full_name: baseUser.full_name,
        phone: baseUser.phone,
        role: UserRole.CLIENT,
        district_id: 'missing-district',
        accepted_terms: true,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('register with terms not accepted: rejected', async () => {
    districtsRepository.findOne.mockResolvedValue({ id: 'district-1', is_active: true });

    await expect(
      authService.register({
        email: baseUser.email,
        password: '123456',
        full_name: baseUser.full_name,
        phone: baseUser.phone,
        role: UserRole.CLIENT,
        district_id: baseUser.district_id,
        accepted_terms: false,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('forgot password: returns generic message when user does not exist', async () => {
    usersService.findByEmail.mockResolvedValue(null);

    const result = await authService.forgotPassword({ email: 'missing@mail.com' });

    expect(result).toEqual({
      message: 'Si el email existe, recibiras instrucciones para restablecer tu contrasena.',
    });
    expect(usersService.setPasswordResetToken).not.toHaveBeenCalled();
  });

  it('forgot password: stores reset token and returns it in non-production', async () => {
    usersService.findByEmail.mockResolvedValue(baseUser);
    usersService.setPasswordResetToken.mockResolvedValue(undefined);

    const result = await authService.forgotPassword({ email: baseUser.email });

    expect(result.message).toBe(
      'Si el email existe, recibiras instrucciones para restablecer tu contrasena.',
    );
    expect(result).toHaveProperty('reset_token');
    const resetToken = (result as any).reset_token;
    expect(typeof resetToken).toBe('string');
    expect((resetToken as string).length).toBeGreaterThan(10);
    expect(usersService.setPasswordResetToken).toHaveBeenCalledWith(
      baseUser.id,
      expect.any(String),
      expect.any(Date),
    );
  });

  it('reset password: updates password and clears reset token when token is valid', async () => {
    usersService.findByEmail.mockResolvedValue(baseUser);
    usersService.validatePasswordResetToken.mockResolvedValue(true);
    usersService.updatePassword.mockResolvedValue(undefined);
    usersService.clearPasswordResetToken.mockResolvedValue(undefined);

    const result = await authService.resetPassword({
      email: baseUser.email,
      reset_token: 'valid-reset-token',
      new_password: 'new-password-123',
    });

    expect(result).toEqual({ message: 'Password updated successfully' });
    expect(usersService.updatePassword).toHaveBeenCalledWith(baseUser.id, 'new-password-123');
    expect(usersService.clearPasswordResetToken).toHaveBeenCalledWith(baseUser.id);
  });

  it('reset password: rejects invalid token', async () => {
    usersService.findByEmail.mockResolvedValue(baseUser);
    usersService.validatePasswordResetToken.mockResolvedValue(false);

    await expect(
      authService.resetPassword({
        email: baseUser.email,
        reset_token: 'invalid-token',
        new_password: 'new-password-123',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
