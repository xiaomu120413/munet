import { ScanKind, ScanStatus } from '../model/HistoryInfo';
import { PingRecord, PingStats, PortResult } from '../model/ScanInfo';
import { HistoryRepository } from '../repository/HistoryRepository';
import { LocalNetRepository } from '../repository/LocalNetRepository';
import { ScanRepository } from '../repository/ScanRepository';

const FALLBACK_PORTS: number[] = [443, 80, 22, 8080, 3389];
const PROBE_TIMEOUT_MS: number = 2000;
const MAX_RECORDS: number = 500;
const CONTINUOUS_INTERVAL_MS: number = 1000;

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, ms);
  });
}

/**
 * ViewModel for the TCP ping view: sequential probes with optional smart
 * port fallback, count/continuous modes and running statistics.
 */
@Observed
export class PingViewModel {
  target: string = '';
  selectedPort: number = 80;
  smartFallback: boolean = true;
  count: number = 4;
  continuous: boolean = false;

  isRunning: boolean = false;
  resolvedAddress: string = '';
  records: PingRecord[] = [];
  error: string = '';
  stats: PingStats = { sent: 0, received: 0, lossPercent: 0, avgMs: 0, minMs: 0, maxMs: 0 };

  private readonly scanRepo: ScanRepository;
  private readonly netRepo: LocalNetRepository;
  private readonly historyRepo: HistoryRepository;
  private runId: number = 0;

  constructor(scanRepo: ScanRepository = new ScanRepository(),
    netRepo: LocalNetRepository = new LocalNetRepository(),
    historyRepo: HistoryRepository = new HistoryRepository()) {
    this.scanRepo = scanRepo;
    this.netRepo = netRepo;
    this.historyRepo = historyRepo;
  }

  setTarget(value: string): void {
    this.target = value;
  }

  selectPort(port: number): void {
    this.selectedPort = port;
    this.smartFallback = false;
  }

  toggleSmartFallback(): void {
    this.smartFallback = !this.smartFallback;
  }

  setCount(count: number): void {
    this.count = count;
  }

  toggleContinuous(): void {
    this.continuous = !this.continuous;
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      return;
    }
    const host: string = this.target.trim();
    if (host.length === 0) {
      this.error = '请输入目标地址';
      return;
    }

    this.error = '';
    this.records = [];
    this.resolvedAddress = '';
    this.resetStats();

    try {
      this.resolvedAddress = this.isIpLiteral(host) ? host : await this.netRepo.resolveAddress(host);
    } catch (err) {
      this.error = '无法解析域名，请检查目标或网络';
      return;
    }

    this.isRunning = true;
    const runId: number = ++this.runId;
    const ports: number[] = this.smartFallback ? FALLBACK_PORTS : [this.selectedPort];
    let seq: number = 0;

    while (this.isRunning && runId === this.runId) {
      seq++;
      let results: PortResult[] = [];
      try {
        results = await this.scanRepo.scan(host, ports, ports.length, PROBE_TIMEOUT_MS,
          () => {
          });
      } catch (err) {
        if (runId === this.runId) {
          this.error = '探测失败，请稍后重试';
        }
        break;
      }
      if (!this.isRunning || runId !== this.runId) {
        break;
      }
      this.appendRecord(seq, results);
      if (!this.continuous && seq >= this.count) {
        break;
      }
      if (this.continuous) {
        await delay(CONTINUOUS_INTERVAL_MS);
      }
    }

    if (runId === this.runId) {
      const completed: boolean = this.isRunning;
      this.isRunning = false;
      if (this.records.length > 0) {
        const status: ScanStatus = completed ? ScanStatus.DONE : ScanStatus.CANCELLED;
        const summary: string = JSON.stringify({
          sent: this.stats.sent,
          recv: this.stats.received,
          loss: this.stats.lossPercent,
          avg: this.stats.avgMs
        });
        this.historyRepo.addScanRecord({
          id: 0,
          ts: Date.now(),
          kind: ScanKind.PING,
          target: host,
          status: status,
          summary: summary
        }).catch(() => {
        });
      }
    }
  }

  stop(): void {
    this.isRunning = false;
    this.scanRepo.cancel();
  }

  leave(): void {
    if (this.isRunning) {
      this.stop();
    }
  }

  dismissError(): void {
    this.error = '';
  }

  errorLabel(error: string): string {
    if (error === 'refused') {
      return '拒绝连接';
    }
    if (error === 'dns') {
      return '解析失败';
    }
    if (error === 'timeout') {
      return '超时';
    }
    return '失败';
  }

  formatTime(timestamp: number): string {
    const date: Date = new Date(timestamp);
    return this.pad(date.getHours(), 2) + ':' + this.pad(date.getMinutes(), 2) + ':' +
      this.pad(date.getSeconds(), 2) + '.' + this.pad(date.getMilliseconds(), 3);
  }

  private pad(value: number, width: number): string {
    let text: string = String(value);
    while (text.length < width) {
      text = '0' + text;
    }
    return text;
  }

  private appendRecord(seq: number, results: PortResult[]): void {
    let best: PortResult | undefined = undefined;
    for (const result of results) {
      if (!result.open) {
        continue;
      }
      if (best === undefined) {
        best = result;
      } else if (result.rttMs < best.rttMs) {
        best = result;
      }
    }

    let errorCode: string = 'timeout';
    if (best === undefined) {
      for (const result of results) {
        if (result.error === 'refused') {
          errorCode = 'refused';
          break;
        }
      }
    }

    const record: PingRecord = {
      seq: seq,
      ok: best !== undefined,
      rttMs: best === undefined ? 0 : best.rttMs,
      error: best === undefined ? errorCode : '',
      port: best === undefined ? 0 : best.port,
      timestamp: Date.now()
    };

    const records: PingRecord[] = this.records.slice();
    records.push(record);
    this.records = records.length > MAX_RECORDS
      ? records.slice(records.length - MAX_RECORDS)
      : records;
    this.updateStats();
  }

  private resetStats(): void {
    this.stats = { sent: 0, received: 0, lossPercent: 0, avgMs: 0, minMs: 0, maxMs: 0 };
  }

  private updateStats(): void {
    let received: number = 0;
    let sum: number = 0;
    let min: number = 0;
    let max: number = 0;
    let hasValue: boolean = false;

    for (const record of this.records) {
      if (!record.ok) {
        continue;
      }
      received++;
      sum += record.rttMs;
      if (!hasValue || record.rttMs < min) {
        min = record.rttMs;
        hasValue = true;
      }
      if (record.rttMs > max) {
        max = record.rttMs;
      }
    }

    const sent: number = this.records.length;
    this.stats = {
      sent: sent,
      received: received,
      lossPercent: sent === 0 ? 0 : Math.round((sent - received) * 100 / sent),
      avgMs: received === 0 ? 0 : Math.round(sum / received),
      minMs: min,
      maxMs: max
    };
  }

  private isIpLiteral(host: string): boolean {
    if (host.includes(':')) {
      return true;
    }
    const parts: string[] = host.split('.');
    if (parts.length !== 4) {
      return false;
    }
    for (const part of parts) {
      if (part.length === 0) {
        return false;
      }
      const value: number = Number(part);
      if (Number.isNaN(value) || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }
}
