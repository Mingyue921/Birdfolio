import { common } from '@kit.AbilityKit';
import {
  AccountExportResult,
  AuthCodeRequestResult,
  AuthSession,
  AuthVerifyInput
} from '../models/BetaModels';
import { ApiService } from './ApiService';
import { AuthStorage } from './AuthStorage';

export interface RestoredAuthSession {
  session: AuthSession | null;
  expired: boolean;
}

/**
 * Coordinates remote authentication with local session persistence.
 * UI state, messages and navigation remain in Index; this class is only
 * responsible for network calls and durable session state.
 */
export class AuthController {
  private readonly context: common.UIAbilityContext;
  private readonly backendUrl: string;
  private readonly session: AuthSession | null;

  constructor(context: common.UIAbilityContext, backendUrl: string, session: AuthSession | null = null) {
    this.context = context;
    this.backendUrl = backendUrl;
    this.session = session;
  }

  private api(): ApiService {
    return new ApiService(this.backendUrl, AuthStorage.accessToken(this.session));
  }

  async restore(): Promise<RestoredAuthSession> {
    const saved = await AuthStorage.load(this.context);
    if (saved === null) return { session: null, expired: false };
    if (AuthStorage.isAccessTokenFresh(saved) || saved.refreshToken.length === 0) {
      return { session: saved, expired: false };
    }
    try {
      const refreshed = await new ApiService(this.backendUrl).refreshSession(saved.refreshToken);
      if (!await AuthStorage.save(this.context, refreshed)) {
        await AuthStorage.clear(this.context);
        return { session: null, expired: true };
      }
      return { session: refreshed, expired: false };
    } catch (_error) {
      await AuthStorage.clear(this.context);
      return { session: null, expired: true };
    }
  }

  requestCode(email: string): Promise<AuthCodeRequestResult> {
    return new ApiService(this.backendUrl).requestLoginCode(email);
  }

  async verify(input: AuthVerifyInput): Promise<AuthSession> {
    const session = await new ApiService(this.backendUrl).verifyLoginCode(input);
    if (!await AuthStorage.save(this.context, session)) throw new Error('本地会话保存失败');
    return session;
  }

  async logout(): Promise<boolean> {
    if (this.session !== null) {
      try {
        await this.api().logout(this.session.refreshToken);
      } catch (_error) {
        // A network failure must not trap the user in a local session.
      }
    }
    return AuthStorage.clear(this.context);
  }

  exportAccount(): Promise<AccountExportResult> {
    return this.api().exportAccount();
  }

  async deleteAccount(): Promise<boolean> {
    await this.api().deleteAccount();
    return AuthStorage.clear(this.context);
  }
}
