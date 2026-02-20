import { Body, Controller, Get, Param, Post, Query, Req, Res } from '@nestjs/common';
import type { Request, Response } from 'express';
import { PricingService } from '../pricing/pricing.service';
import { ServiceRequestStatus } from '../service-requests/service-request.entity';
import { ServiceRequestsService } from '../service-requests/service-requests.service';
import { UserRole } from '../users/user.entity';
import { UsersService } from '../users/users.service';

type AdminWebSession = Request['session'] & {
  admin_user_id?: string;
  admin_email?: string;
  admin_role?: UserRole;
};

@Controller('admin-web')
export class AdminWebController {
  constructor(
    private readonly usersService: UsersService,
    private readonly serviceRequestsService: ServiceRequestsService,
    private readonly pricingService: PricingService,
  ) {}

  @Get('login')
  loginPage(
    @Req() req: Request,
    @Res() res: Response,
    @Query('message') message?: string,
  ): void {
    const session = this.getSession(req);
    if (session.admin_user_id && session.admin_role === UserRole.ADMIN) {
      res.redirect('/admin-web/dashboard');
      return;
    }

    res.render('login', {
      message: this.mapMessage(message),
      error: null,
      email: '',
    });
  }

  @Post('login')
  async login(
    @Req() req: Request,
    @Res() res: Response,
    @Body('email') rawEmail?: string,
    @Body('password') rawPassword?: string,
  ): Promise<void> {
    const email = (rawEmail ?? '').trim().toLowerCase();
    const password = (rawPassword ?? '').trim();

    if (!email || !password) {
      res.status(400).render('login', {
        message: null,
        error: 'Email y password son requeridos.',
        email,
      });
      return;
    }

    const user = await this.usersService.findByEmail(email);
    if (!user || user.role !== UserRole.ADMIN || user.is_blocked) {
      res.status(401).render('login', {
        message: null,
        error: 'Credenciales invalidas o sin permisos de administrador.',
        email,
      });
      return;
    }

    const isPasswordValid = await this.usersService.validatePassword(user, password);
    if (!isPasswordValid) {
      res.status(401).render('login', {
        message: null,
        error: 'Credenciales invalidas o sin permisos de administrador.',
        email,
      });
      return;
    }

    const session = this.getSession(req);
    session.admin_user_id = user.id;
    session.admin_email = user.email;
    session.admin_role = user.role;

    await this.saveSession(session);
    res.redirect('/admin-web/dashboard');
  }

  @Post('logout')
  async logout(@Req() req: Request, @Res() res: Response): Promise<void> {
    const session = this.getSession(req);
    await this.destroySession(session);
    res.clearCookie('admin_web_sid');
    res.redirect('/admin-web/login?message=logged_out');
  }

  @Get('dashboard')
  async dashboard(@Req() req: Request, @Res() res: Response): Promise<void> {
    const session = this.requireAdminSession(req, res);
    if (!session) {
      return;
    }

    const [users, pendingProviders, requests] = await Promise.all([
      this.usersService.listUsers(),
      this.usersService.findPendingProviders(),
      this.serviceRequestsService.findAllForAdmin(),
    ]);

    const requestsByStatus = Object.values(ServiceRequestStatus).map((status) => ({
      status,
      count: requests.filter((request) => request.status === status).length,
    }));

    res.render('dashboard', {
      adminEmail: session.admin_email ?? '',
      totalUsers: users.length,
      pendingProviders: pendingProviders.length,
      totalRequests: requests.length,
      requestsByStatus,
    });
  }

  @Get('pricing')
  async pricing(
    @Req() req: Request,
    @Res() res: Response,
    @Query('success') success?: string,
    @Query('error') error?: string,
  ): Promise<void> {
    const session = this.requireAdminSession(req, res);
    if (!session) {
      return;
    }

    const pricingRules = await this.pricingService.listRulesForAdmin();

    res.render('pricing', {
      adminEmail: session.admin_email ?? '',
      successMessage: success === '1' ? 'Regla de precio actualizada correctamente.' : null,
      errorMessage: error ? decodeURIComponent(error) : null,
      rules: pricingRules.map((rule) => ({
        id: rule.id,
        districtName: rule.district?.name ?? rule.district_id,
        pricePerHour: Number(rule.price_per_hour).toFixed(2),
        currency: rule.currency,
        minHours: rule.min_hours,
        maxHours: rule.max_hours,
        isActive: rule.is_active,
      })),
    });
  }

  @Post('pricing/:id')
  async updatePricing(
    @Req() req: Request,
    @Res() res: Response,
    @Param('id') id: string,
    @Body('price_per_hour') rawPrice?: string,
    @Body('currency') rawCurrency?: string,
  ): Promise<void> {
    const session = this.requireAdminSession(req, res);
    if (!session) {
      return;
    }

    const price = Number((rawPrice ?? '').trim());
    if (!Number.isFinite(price) || price <= 0) {
      res.redirect('/admin-web/pricing?error=' + encodeURIComponent('price_per_hour invalido.'));
      return;
    }

    const normalizedCurrency = (rawCurrency ?? '').trim().toUpperCase();
    if (normalizedCurrency && !/^[A-Z]{3}$/.test(normalizedCurrency)) {
      res.redirect('/admin-web/pricing?error=' + encodeURIComponent('currency debe ser ISO-4217.'));
      return;
    }

    try {
      await this.pricingService.updatePricingRuleById(id, {
        price_per_hour: price,
        currency: normalizedCurrency || undefined,
      });
      res.redirect('/admin-web/pricing?success=1');
    } catch (error) {
      res.redirect(
        '/admin-web/pricing?error=' +
          encodeURIComponent(this.extractErrorMessage(error, 'No se pudo actualizar la regla.')),
      );
    }
  }

  @Get('users')
  async users(
    @Req() req: Request,
    @Res() res: Response,
    @Query('role') role?: string,
  ): Promise<void> {
    const session = this.requireAdminSession(req, res);
    if (!session) {
      return;
    }

    const roleFilter =
      role && Object.values(UserRole).includes(role as UserRole) ? (role as UserRole) : undefined;

    const users = await this.usersService.listUsers(roleFilter);

    res.render('users', {
      adminEmail: session.admin_email ?? '',
      selectedRole: roleFilter ?? '',
      selectedClient: roleFilter === UserRole.CLIENT,
      selectedProvider: roleFilter === UserRole.PROVIDER,
      selectedAdmin: roleFilter === UserRole.ADMIN,
      users: users.map((user) => ({
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        districtName: user.district?.name ?? user.district_id,
        isVerified: user.is_verified ? 'Yes' : 'No',
        isBlocked: user.is_blocked ? 'Yes' : 'No',
        createdAt: user.created_at.toISOString(),
      })),
    });
  }

  private getSession(req: Request): AdminWebSession {
    return req.session as AdminWebSession;
  }

  private requireAdminSession(req: Request, res: Response): AdminWebSession | null {
    const session = this.getSession(req);
    if (session.admin_user_id && session.admin_role === UserRole.ADMIN) {
      return session;
    }
    res.redirect('/admin-web/login');
    return null;
  }

  private async saveSession(session: AdminWebSession): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      session.save((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }

  private async destroySession(session: AdminWebSession): Promise<void> {
    await new Promise<void>((resolve) => {
      session.destroy(() => resolve());
    });
  }

  private mapMessage(message?: string): string | null {
    if (message === 'logged_out') {
      return 'Sesion cerrada.';
    }
    return null;
  }

  private extractErrorMessage(error: unknown, fallback: string): string {
    if (error instanceof Error && error.message.trim()) {
      return error.message;
    }
    return fallback;
  }
}
