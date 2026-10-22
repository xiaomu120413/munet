import { hilog } from '@kit.PerformanceAnalysisKit';
import { ScanKind, ScanStatus } from '../model/HistoryInfo';
import { PortResult, PortScanMode } from '../model/ScanInfo';
import { HistoryRepository } from '../repository/HistoryRepository';
import { ScanRepository } from '../repository/ScanRepository';

const MIN_CONCURRENCY: number = 10;
const MAX_CONCURRENCY: number = 512;
const MIN_TIMEOUT_MS: number = 200;
const MAX_TIMEOUT_MS: number = 10000;

/**
 * ViewModel for the port-scan view: port-set selection, scan parameters,
 * live progress and results.
 */
@Observed
export class PortScanViewModel {
  target: string = '';
  mode: PortScanMode = PortScanMode.COMMON;
  customExpr: string = '';
  concurrency: number = 128;
  timeoutMs: number = 1500;
  scanLocalHost: boolean = false;
  localTargetCount: number = 0;

  isRunning: boolean = false;
  done: number = 0;
  total: number = 0;
  elapsedMs: number = 0;
  openResults: PortResult[] = [];
  closedCount: number = 0;
  error: string = '';
  cancelled: boolean = false;
  failed: boolean = false;

  private readonly repo: ScanRepository;
  private readonly historyRepo: HistoryRepository;
  private startTime: number = 0;

  constructor(repo: ScanRepository = new ScanRepository(),
    historyRepo: HistoryRepository = new HistoryRepository()) {
    this.repo = repo;
    this.historyRepo = historyRepo;
  }

  setTarget(value: string): void {
    this.target = value;
  }

  setScanLocalHost(value: boolean): void {
    this.scanLocalHost = value;
    this.error = '';
  }

  selectMode(mode: PortScanMode): void {
    this.mode = mode;
    this.error = '';
  }

  setCustomExpr(value: string): void {
    this.customExpr = value;
  }

  setConcurrency(value: number): void {
    this.concurrency = Math.max(MIN_CONCURRENCY, Math.min(MAX_CONCURRENCY, value));
  }

  setTimeoutMs(value: number): void {
    this.timeoutMs = Math.max(MIN_TIMEOUT_MS, Math.min(MAX_TIMEOUT_MS, value));
  }

  ports(): number[] {
    if (this.mode === PortScanMode.COMMON) {
      return this.repo.commonPorts();
    }
    if (this.mode === PortScanMode.WEB) {
      return this.repo.webPorts();
    }
    if (this.mode === PortScanMode.TOP1024) {
      return this.repo.parsePorts('1-1024');
    }
    return this.repo.parsePorts(this.customExpr);
  }

  portCount(): number {
    return this.ports().length;
  }

  /** Total TCP probes a scan would issue (ports × local targets in local mode). */
  expectedProbes(): number {
    const probes: number = this.portCount();
    if (!this.scanLocalHost) {
      return probes;
    }
    return probes * this.repo.localScanTargets().length;
  }

  serviceLabel(port: number): string {
    const name: string = this.repo.serviceName(port);
    return name.length > 0 ? name : '—';
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      return;
    }
    const ports: number[] = this.ports();
    if (ports.length === 0) {
      this.error = '端口表达式无效，示例：80,443,1000-2000';
      return;
    }
    const localMode: boolean = this.scanLocalHost;
    const host: string = this.target.trim();
    if (!localMode && host.length === 0) {
      this.error = '请输入目标地址';
      return;
    }
    const targets: string[] = localMode ? this.repo.localScanTargets() : [host];
    const targetLabel: string = localMode ? '本机' : host;
    this.localTargetCount = targets.length;

    this.error = '';
    this.cancelled = false;
    this.failed = false;
    this.isRunning = true;
    this.done = 0;
    this.total = ports.length * targets.length;
    this.elapsedMs = 0;
    this.openResults = [];
    this.closedCount = 0;
    this.startTime = Date.now();

    let succeeded: boolean = false;
    try {
      const merged: Map<number, PortResult> = new Map<number, PortResult>();
      let processed: number = 0;
      for (const address of targets) {
        if (this.cancelled) {
          break;
        }
        const base: number = processed;
        const results: PortResult[] = await this.repo.scan(address, ports, this.concurrency,
          this.timeoutMs, (done: number, total: number) => {
            this.done = Math.min(base + done, this.total);
            this.elapsedMs = Date.now() - this.startTime;
          });
        processed += ports.length;
        for (const result of results) {
          if (!result.open) {
            continue;
          }
          const existing: PortResult | undefined = merged.get(result.port);
          if (existing === undefined || result.rttMs < existing.rttMs) {
            merged.set(result.port, result);
          }
        }
      }
      succeeded = true;
      if (!this.cancelled) {
        this.done = this.total;
        this.elapsedMs = Date.now() - this.startTime;
      }
      const open: PortResult[] = [];
      merged.forEach((value: PortResult) => {
        open.push(value);
      });
      open.sort((a: PortResult, b: PortResult): number => a.port - b.port);
      this.openResults = open;
      const probed: number = this.cancelled ? this.done : this.total;
      this.closedCount = Math.max(0, probed - open.length);
    } catch (err) {
      this.failed = !this.cancelled;
      if (!this.cancelled) { this.error = '扫描失败，请稍后重试'; }
    }
    this.isRunning = false;

    if (succeeded) {
      const status: ScanStatus = this.cancelled ? ScanStatus.CANCELLED : ScanStatus.DONE;
      const summary: string = JSON.stringify({
        open: this.openResults.length,
        total: this.total,
        elapsedMs: this.elapsedMs
      });
      this.historyRepo.addScanRecord({
        id: 0,
        ts: Date.now(),
        kind: ScanKind.PORT_SCAN,
        target: targetLabel,
        status: status,
        summary: summary
      }).catch((err: Error) => {
        hilog.error(0x0000, 'NetTools', 'portscan history write failed: %{public}s',
          err.message);
      });
    }
  }

  stop(): void {
    this.cancelled = true;
    this.repo.cancel();
  }

  leave(): void {
    if (this.isRunning) {
      this.stop();
    }
  }

  dismissError(): void {
    this.error = '';
  }

  elapsedLabel(): string {
    return (this.elapsedMs / 1000).toFixed(1) + ' s';
  }

  /** One-line result summary for the view. */
  summaryLabel(): string {
    if (this.scanLocalHost) {
      return '占用 ' + this.openResults.length + ' 个 · 扫描 ' +
        this.localTargetCount + ' 个地址';
    }
    return '开放 ' + this.openResults.length + ' 个 · 关闭/超时 ' +
      this.closedCount + ' 个';
  }
}
