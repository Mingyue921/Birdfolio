import { AuthService } from '@tencentmap/base';
import { TENCENT_MAP_KEY } from './MapSecret';
import { SafeLogger } from './SafeLogger';

/**
 * Tencent Map authentication entry point.
 * Keep the key here locally and do not commit a real key to a public repository.
 */
export class MapService {
  private static readonly TEMPLATE_KEY: string = 'PASTE_TENCENT_MAP_KEY_HERE';
  private static initialized: boolean = false;

  static init(): boolean {
    if (MapService.initialized) return true;
    const key: string = TENCENT_MAP_KEY.trim();
    if (key.length === 0 || key === MapService.TEMPLATE_KEY) {
      SafeLogger.warn('BirdfolioMap', 'map_key_not_configured');
      return false;
    }
    AuthService.getInstance().setKey(key);
    MapService.initialized = true;
    SafeLogger.info('BirdfolioMap', 'map_key_configured');
    return true;
  }

  static isConfigured(): boolean {
    const key: string = TENCENT_MAP_KEY.trim();
    return key.length > 0 && key !== MapService.TEMPLATE_KEY;
  }
}
