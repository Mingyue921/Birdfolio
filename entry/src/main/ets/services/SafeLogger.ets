import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReleaseLogPolicy } from './ReleaseLogPolicy';

const DOMAIN = 0x0000;

/** Release-safe logger: callers pass stable event names, never user or file data. */
export class SafeLogger {
  static info(tag: string, event: string): void { hilog.info(DOMAIN, tag, '%{public}s', SafeLogger.event(event)); }
  static warn(tag: string, event: string): void { hilog.warn(DOMAIN, tag, '%{public}s', SafeLogger.event(event)); }
  static error(tag: string, event: string): void { hilog.error(DOMAIN, tag, '%{public}s', SafeLogger.event(event)); }

  static event(value: string): string {
    return ReleaseLogPolicy.event(value);
  }
}
