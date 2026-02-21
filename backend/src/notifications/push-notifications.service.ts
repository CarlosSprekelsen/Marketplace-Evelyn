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

type PushSendOptions = {
  context?: string;
};

type PushTransport = 'http_v1' | 'legacy' | 'skipped';
type PushStatus = 'sent' | 'skipped' | 'error';

type PushEvent = {
  ts: string;
  context: string;
  transport: PushTransport;
  tokens: number;
  success: number;
  failure: number;
  status: PushStatus;
  reason?: string;
};

type PushCounters = {
  totalCalls: number;
  totalTokens: number;
  skippedNoTokens: number;
  skippedNoCredentials: number;
  httpV1Batches: number;
  httpV1SuccessTokens: number;
  httpV1FailedTokens: number;
  httpV1RequestErrors: number;
  legacyBatches: number;
  legacySuccessTokens: number;
  legacyFailedTokens: number;
  legacyRequestErrors: number;
};

type PushContextCounters = {
  calls: number;
  tokens: number;
};

type PushObservabilitySnapshot = {
  generatedAt: string;
  counters: PushCounters;
  byContext: Record<string, PushContextCounters>;
  recentEvents: PushEvent[];
};

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private firebaseApp: FirebaseApp | null | undefined;
  private legacyWarningShown = false;

  private static readonly maxRecentEvents = 50;
  private static readonly counters: PushCounters = {
    totalCalls: 0,
    totalTokens: 0,
    skippedNoTokens: 0,
    skippedNoCredentials: 0,
    httpV1Batches: 0,
    httpV1SuccessTokens: 0,
    httpV1FailedTokens: 0,
    httpV1RequestErrors: 0,
    legacyBatches: 0,
    legacySuccessTokens: 0,
    legacyFailedTokens: 0,
    legacyRequestErrors: 0,
  };
  private static readonly byContext = new Map<string, PushContextCounters>();
  private static readonly recentEvents: PushEvent[] = [];

  constructor(private readonly configService: ConfigService) {}

  async sendToTokens(
    rawTokens: Array<string | null | undefined>,
    payload: PushPayload,
    options?: PushSendOptions,
  ): Promise<void> {
    const context = this.normalizeContext(options?.context);
    const tokens = Array.from(
      new Set(
        rawTokens.filter(
          (value): value is string => typeof value === 'string' && value.trim().length > 0,
        ),
      ),
    );

    PushNotificationsService.counters.totalCalls += 1;
    this.recordContext(context, tokens.length);

    if (tokens.length === 0) {
      PushNotificationsService.counters.skippedNoTokens += 1;
      this.recordAndLogEvent({
        ts: new Date().toISOString(),
        context,
        transport: 'skipped',
        tokens: 0,
        success: 0,
        failure: 0,
        status: 'skipped',
        reason: 'empty_tokens',
      });
      return;
    }

    PushNotificationsService.counters.totalTokens += tokens.length;

    const firebaseApp = this.getFirebaseApp();
    if (firebaseApp) {
      await this.sendViaHttpV1(firebaseApp, tokens, payload, context);
      return;
    }

    await this.sendViaLegacy(tokens, payload, context);
  }

  getObservabilitySnapshot(): PushObservabilitySnapshot {
    const byContext: Record<string, PushContextCounters> = {};
    for (const [context, counters] of PushNotificationsService.byContext.entries()) {
      byContext[context] = {
        calls: counters.calls,
        tokens: counters.tokens,
      };
    }

    return {
      generatedAt: new Date().toISOString(),
      counters: {
        ...PushNotificationsService.counters,
      },
      byContext,
      recentEvents: [...PushNotificationsService.recentEvents],
    };
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
    context: string,
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

      PushNotificationsService.counters.httpV1Batches += 1;

      try {
        const response = await getMessaging(firebaseApp).sendEachForMulticast(message);

        PushNotificationsService.counters.httpV1SuccessTokens += response.successCount;
        PushNotificationsService.counters.httpV1FailedTokens += response.failureCount;

        if (response.failureCount > 0) {
          response.responses.forEach((result, index) => {
            if (!result.success) {
              const maskedToken = this.maskToken(chunk[index]);
              this.logger.warn(
                `FCM v1 token failed (${maskedToken}) for ${context}: ${result.error?.message}`,
              );
            }
          });
        }

        this.recordAndLogEvent({
          ts: new Date().toISOString(),
          context,
          transport: 'http_v1',
          tokens: chunk.length,
          success: response.successCount,
          failure: response.failureCount,
          status: 'sent',
        });
      } catch (error) {
        const messageText = error instanceof Error ? error.message : String(error);

        PushNotificationsService.counters.httpV1RequestErrors += 1;
        PushNotificationsService.counters.httpV1FailedTokens += chunk.length;

        this.recordAndLogEvent({
          ts: new Date().toISOString(),
          context,
          transport: 'http_v1',
          tokens: chunk.length,
          success: 0,
          failure: chunk.length,
          status: 'error',
          reason: messageText,
        });
      }
    }
  }

  private async sendViaLegacy(tokens: string[], payload: PushPayload, context: string): Promise<void> {
    const serverKey = this.configService.get<string>('fcm.serverKey')?.trim() ?? '';
    if (serverKey.length === 0) {
      PushNotificationsService.counters.skippedNoCredentials += 1;
      this.recordAndLogEvent({
        ts: new Date().toISOString(),
        context,
        transport: 'skipped',
        tokens: tokens.length,
        success: 0,
        failure: tokens.length,
        status: 'skipped',
        reason: 'missing_http_v1_and_legacy_credentials',
      });
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
      PushNotificationsService.counters.legacyBatches += 1;

      const result = await this.dispatchLegacyChunk(serverKey, chunk, payload);
      PushNotificationsService.counters.legacySuccessTokens += result.success;
      PushNotificationsService.counters.legacyFailedTokens += result.failure;
      if (!result.ok) {
        PushNotificationsService.counters.legacyRequestErrors += 1;
      }

      this.recordAndLogEvent({
        ts: new Date().toISOString(),
        context,
        transport: 'legacy',
        tokens: chunk.length,
        success: result.success,
        failure: result.failure,
        status: result.ok ? 'sent' : 'error',
        reason: result.reason,
      });
    }
  }

  private async dispatchLegacyChunk(
    serverKey: string,
    tokens: string[],
    payload: PushPayload,
  ): Promise<{ ok: boolean; success: number; failure: number; reason?: string }> {
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
        return {
          ok: false,
          success: 0,
          failure: tokens.length,
          reason: `legacy_http_${response.status}:${body.slice(0, 200)}`,
        };
      }

      let successCount = tokens.length;
      let failureCount = 0;
      try {
        const responseBody = (await response.json()) as {
          success?: unknown;
          failure?: unknown;
        };
        if (typeof responseBody.success === 'number') {
          successCount = responseBody.success;
        }
        if (typeof responseBody.failure === 'number') {
          failureCount = responseBody.failure;
        } else {
          failureCount = Math.max(tokens.length - successCount, 0);
        }
      } catch {
        // Some legacy responses may not parse as JSON. Keep fallback counts.
      }

      return {
        ok: true,
        success: successCount,
        failure: failureCount,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        ok: false,
        success: 0,
        failure: tokens.length,
        reason: message,
      };
    }
  }

  private normalizeContext(value: string | undefined): string {
    const normalized = value?.trim();
    return normalized && normalized.length > 0 ? normalized : 'unspecified';
  }

  private recordContext(context: string, tokens: number): void {
    const existing = PushNotificationsService.byContext.get(context);
    if (!existing) {
      PushNotificationsService.byContext.set(context, {
        calls: 1,
        tokens,
      });
      return;
    }

    existing.calls += 1;
    existing.tokens += tokens;
  }

  private recordAndLogEvent(event: PushEvent): void {
    PushNotificationsService.recentEvents.unshift(event);
    if (PushNotificationsService.recentEvents.length > PushNotificationsService.maxRecentEvents) {
      PushNotificationsService.recentEvents.splice(PushNotificationsService.maxRecentEvents);
    }

    const serialized = JSON.stringify({
      event: 'push_delivery',
      ...event,
    });
    if (event.status === 'error') {
      this.logger.warn(serialized);
      return;
    }

    this.logger.log(serialized);
  }

  private maskToken(token: string): string {
    if (token.length <= 14) {
      return '***';
    }
    return `${token.slice(0, 8)}...${token.slice(-6)}`;
  }
}
