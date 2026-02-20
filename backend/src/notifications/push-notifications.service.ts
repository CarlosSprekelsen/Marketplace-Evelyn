import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFileSync } from 'fs';
import { cert, getApps, initializeApp, App as FirebaseApp, ServiceAccount } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';

type PushPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private firebaseApp: FirebaseApp | null | undefined;
  private legacyWarningShown = false;

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

    const firebaseApp = this.getFirebaseApp();
    if (firebaseApp) {
      await this.sendViaHttpV1(firebaseApp, tokens, payload);
      return;
    }

    await this.sendViaLegacy(tokens, payload);
  }

  private getFirebaseApp(): FirebaseApp | null {
    if (this.firebaseApp !== undefined) {
      return this.firebaseApp;
    }

    const serviceAccount = this.resolveServiceAccount();
    if (!serviceAccount) {
      this.firebaseApp = null;
      return this.firebaseApp;
    }

    try {
      const existing = getApps().find((app) => app.name === 'marketplace-evelyn-fcm');
      if (existing) {
        this.firebaseApp = existing;
        return this.firebaseApp;
      }

      const projectIdFromConfig =
        this.configService.get<string>('firebase.projectId')?.trim() ||
        serviceAccount.projectId ||
        undefined;

      this.firebaseApp = initializeApp(
        {
          credential: cert(serviceAccount),
          projectId: projectIdFromConfig,
        },
        'marketplace-evelyn-fcm',
      );
      this.logger.log('Firebase Admin SDK initialized for FCM HTTP v1.');
      return this.firebaseApp;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Failed to initialize Firebase Admin SDK: ${message}`);
      this.firebaseApp = null;
      return this.firebaseApp;
    }
  }

  private resolveServiceAccount(): ServiceAccount | null {
    const rawJson = this.configService.get<string>('firebase.serviceAccountJson')?.trim() ?? '';
    if (rawJson.length > 0) {
      return this.parseServiceAccount(rawJson, 'FIREBASE_SERVICE_ACCOUNT_JSON');
    }

    const base64 = this.configService.get<string>('firebase.serviceAccountBase64')?.trim() ?? '';
    if (base64.length > 0) {
      try {
        const decoded = Buffer.from(base64, 'base64').toString('utf8');
        return this.parseServiceAccount(decoded, 'FIREBASE_SERVICE_ACCOUNT_BASE64');
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.warn(`Invalid FIREBASE_SERVICE_ACCOUNT_BASE64: ${message}`);
        return null;
      }
    }

    const path = this.configService.get<string>('firebase.serviceAccountPath')?.trim() ?? '';
    if (path.length > 0) {
      try {
        const fileContent = readFileSync(path, 'utf8');
        return this.parseServiceAccount(fileContent, 'FIREBASE_SERVICE_ACCOUNT_PATH');
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.warn(`Unable to read FIREBASE_SERVICE_ACCOUNT_PATH file: ${message}`);
        return null;
      }
    }

    return null;
  }

  private parseServiceAccount(content: string, source: string): ServiceAccount | null {
    try {
      const parsed = JSON.parse(content) as Record<string, unknown>;
      const projectId = this.readRequiredString(parsed, 'project_id');
      const clientEmail = this.readRequiredString(parsed, 'client_email');
      const privateKey = this.readRequiredString(parsed, 'private_key').replace(/\\n/g, '\n');

      if (!projectId || !clientEmail || !privateKey) {
        this.logger.warn(
          `Firebase service account from ${source} is missing project_id/client_email/private_key.`,
        );
        return null;
      }

      return {
        projectId,
        clientEmail,
        privateKey,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Failed to parse Firebase service account from ${source}: ${message}`);
      return null;
    }
  }

  private readRequiredString(payload: Record<string, unknown>, key: string): string {
    const value = payload[key];
    if (typeof value !== 'string') {
      return '';
    }
    return value.trim();
  }

  private async sendViaHttpV1(
    firebaseApp: FirebaseApp,
    tokens: string[],
    payload: PushPayload,
  ): Promise<void> {
    const chunkSize = 500; // Admin SDK multicast limit.
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      const message: MulticastMessage = {
        tokens: chunk,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data ?? {},
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' } },
      };

      try {
        const response = await getMessaging(firebaseApp).sendEachForMulticast(message);
        if (response.failureCount > 0) {
          response.responses.forEach((result, index) => {
            if (!result.success) {
              this.logger.warn(`FCM v1 token failed (${chunk[index]}): ${result.error?.message}`);
            }
          });
        }
        this.logger.log(
          `FCM v1 sent. success=${response.successCount} failure=${response.failureCount} total=${chunk.length}`,
        );
      } catch (error) {
        const messageText = error instanceof Error ? error.message : String(error);
        this.logger.warn(`FCM v1 request error: ${messageText}`);
      }
    }
  }

  private async sendViaLegacy(tokens: string[], payload: PushPayload): Promise<void> {
    const serverKey = this.configService.get<string>('fcm.serverKey')?.trim() ?? '';
    if (serverKey.length === 0) {
      this.logger.warn(
        'Skipping push notification because Firebase service account is not configured and legacy FCM_SERVER_KEY is empty.',
      );
      return;
    }

    if (!this.legacyWarningShown) {
      this.legacyWarningShown = true;
      this.logger.warn(
        'Using deprecated FCM legacy API fallback. Configure FIREBASE_SERVICE_ACCOUNT_* for HTTP v1.',
      );
    }

    const chunkSize = 500; // Legacy API accepts up to 1000; keep smaller batches.
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      await this.dispatchLegacyChunk(serverKey, chunk, payload);
    }
  }

  private async dispatchLegacyChunk(
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
        return;
      }

      this.logger.log(`FCM sent to ${tokens.length} device(s).`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`FCM request error: ${message}`);
    }
  }
}
