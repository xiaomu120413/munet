import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'NetTools';

/** Shared application logging configuration. Keep sensitive data out of messages. */
export class Logger {
  static info(format: string, ...args: (string | number | boolean)[]): void {
    hilog.info(DOMAIN, TAG, format, ...args);
  }

  static warn(format: string, ...args: (string | number | boolean)[]): void {
    hilog.warn(DOMAIN, TAG, format, ...args);
  }

  static error(format: string, ...args: (string | number | boolean)[]): void {
    hilog.error(DOMAIN, TAG, format, ...args);
  }
}
