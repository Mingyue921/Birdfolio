import { AuthService } from '@tencentmap/base';
import { LogLevel } from '@tencentmap/base';
import { LogConfig } from '@tencentmap/map';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TENCENT_MAP_KEY } from './MapSecret';

const MAP_LOG_DOMAIN: number = 0x0000;
const MAP_LOG_TAG: string = 'BirdfolioMap';

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
      hilog.warn(MAP_LOG_DOMAIN, MAP_LOG_TAG, 'Tencent Map key is not configured');
      return false;
    }
    LogConfig.initLogOptions({
      sdkLogOn: true,
      sdkLogLevel: LogLevel.DEBUG,
      engineLogOn: true,
      engineLogLevel: LogLevel.DEBUG
    });
    AuthService.getInstance().setKey(key);
    MapService.initialized = true;
    hilog.info(MAP_LOG_DOMAIN, MAP_LOG_TAG, 'Tencent Map key configured and SDK logging enabled');
    return true;
  }

  static isConfigured(): boolean {
    const key: string = TENCENT_MAP_KEY.trim();
    return key.length > 0 && key !== MapService.TEMPLATE_KEY;
  }
}
