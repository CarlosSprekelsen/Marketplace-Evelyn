import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type PushPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendToTokens(
    rawTokens: Array<string | null | undefined>,
    payload: PushPayload,
  ): Promise<void> {
    const tokens = Array.from(
      new Set(
        rawTokens.filter(
          (value): value is string => typeof value === 'string' && value.trim().length > 0,
        ),
      ),
    );
    if (tokens.length === 0) {
      return;
    }

    const serverKey = this.configService.get<string>('fcm.serverKey')?.trim() ?? '';
    if (serverKey.length === 0) {
      this.logger.debug('Skipping push notification because FCM_SERVER_KEY is not configured.');
      return;
    }

    const chunkSize = 500; // Legacy API accepts up to 1000; keep smaller batches.
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      await this.dispatchChunk(serverKey, chunk, payload);
    }
  }

  private async dispatchChunk(
    serverKey: string,
    tokens: string[],
    payload: PushPayload,
  ): Promise<void> {
    try {
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${serverKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          registration_ids: tokens,
          priority: 'high',
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data ?? {},
        }),
      });

      if (!response.ok) {
        const body = await response.text();
        this.logger.warn(`FCM request failed (${response.status}): ${body}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`FCM request error: ${message}`);
    }
  }
}
