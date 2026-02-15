import { CallHandler, ExecutionContext, Injectable, NestInterceptor, Logger } from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { randomUUID } from 'crypto';
import { Request, Response } from 'express';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const ctx = context.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    const requestId = randomUUID();
    request['requestId'] = requestId;
    response.setHeader('X-Request-Id', requestId);

    const { method, url } = request;
    const start = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          const duration = Date.now() - start;
          this.logger.log(`${method} ${url} ${response.statusCode} ${duration}ms [${requestId}]`);
        },
        error: () => {
          const duration = Date.now() - start;
          this.logger.warn(`${method} ${url} ${response.statusCode} ${duration}ms [${requestId}]`);
        },
      }),
    );
  }
}
