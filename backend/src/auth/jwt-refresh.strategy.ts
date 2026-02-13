import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(private configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromBodyField('refresh_token'),
      ignoreExpiration: false,
      secretOrKey: configService.get('jwt.refreshSecret') as string,
      passReqToCallback: true,
    });
  }

  async validate(req: any, payload: any) {
    const refreshToken = req.body.refresh_token;
    return {
      userId: payload.sub,
      email: payload.email,
      refreshToken,
    };
  }
}
