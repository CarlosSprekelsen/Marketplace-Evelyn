import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { WinstonModule } from 'nest-winston';
import * as winston from 'winston';
import { join } from 'path';
import session from 'express-session';
import { RedisStore } from 'connect-redis';
import type { RedisClientType } from 'redis';
import { AppModule } from './app.module';
import { LoggingInterceptor } from './common/logging.interceptor';
import { GlobalExceptionFilter } from './common/http-exception.filter';

async function bootstrap() {
  const isProduction = process.env.NODE_ENV === 'production';
  const logger = new Logger('Bootstrap');

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: WinstonModule.createLogger({
      transports: [
        new winston.transports.Console({
          format: isProduction
            ? winston.format.combine(winston.format.timestamp(), winston.format.json())
            : winston.format.combine(
                winston.format.timestamp(),
                winston.format.colorize(),
                winston.format.printf((info) => {
                  const ctx = typeof info.context === 'string' ? info.context : 'App';
                  return `${String(info.timestamp)} [${ctx}] ${info.level}: ${String(info.message)}`;
                }),
              ),
        }),
      ],
    }),
  });

  // Security headers
  app.use(helmet());

  app.setBaseViewsDir(join(__dirname, 'admin-web', 'views'));
  app.setViewEngine('hbs');

  app.set('trust proxy', 1);
  const redisClient = app.get<RedisClientType>('REDIS_CLIENT');
  const sessionSecret = (
    process.env.ADMIN_WEB_SESSION_SECRET ??
    process.env.JWT_SECRET ??
    ''
  ).trim();
  if (sessionSecret.length === 0) {
    logger.warn('ADMIN_WEB_SESSION_SECRET is empty. Using insecure fallback session secret.');
  }
  app.use(
    session({
      store: new RedisStore({
        client: redisClient,
        prefix: 'admin-web:sess:',
      }),
      name: 'admin_web_sid',
      secret: sessionSecret.length > 0 ? sessionSecret : 'admin-web-dev-secret-change-me',
      resave: false,
      saveUninitialized: false,
      rolling: true,
      proxy: isProduction,
      cookie: {
        httpOnly: true,
        sameSite: 'strict',
        secure: isProduction ? 'auto' : false,
        maxAge: 8 * 60 * 60 * 1000,
      },
    }),
  );

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // CORS configuration
  const allowedOrigins = process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim())
    : ['http://localhost:3000', 'http://localhost:8080'];

  app.enableCors({
    origin: isProduction ? allowedOrigins : true,
    credentials: true,
  });

  // Global interceptors and filters
  app.useGlobalInterceptors(new LoggingInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  // Swagger documentation (disabled in production)
  if (!isProduction) {
    const config = new DocumentBuilder()
      .setTitle('MarketPlace Evelyn API')
      .setDescription('API de MarketPlace Evelyn - Limpieza por horas')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);
  }

  const port = process.env.PORT ?? 3000;
  await app.listen(port);

  logger.log(`Application is running on port ${String(port)}`);
  if (!isProduction) {
    logger.log(`Swagger docs available at: http://localhost:${String(port)}/api/docs`);
  }
}

bootstrap().catch((error: unknown) => {
  console.error('Application failed to start:', error);
  process.exit(1);
});
