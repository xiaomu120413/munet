import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ScanKind, ScanStatus } from '../model/HistoryInfo';
import { HostResult } from '../model/ScanInfo';
import { DiscoveryRepository } from '../repository/DiscoveryRepository';
import { HistoryRepository } from '../repository/HistoryRepository';
import { LocalNetRepository } from '../repository/LocalNetRepository';

const SWEEP_CONCURRENCY: number = 128;
const SWEEP_TIMEOUT_MS: number = 1000;

/**
 * ViewModel for LAN discovery: default-CIDR derivation, sweep with progress,
 * mDNS hostname merge and persistence of results.
 */
@Observed
export class LanDiscoveryViewModel {
  cidr: string = '';
  isRunning: boolean = false;
  done: number = 0;
  total: number = 0;
  elapsedMs: number = 0;
  onlineHosts: HostResult[] = [];
  offlineCount: number = 0;
  mdnsCount: number = 0;
  error: string = '';
  cancelled: boolean = false;
  failed: boolean = false;

  private readonly discoveryRepo: DiscoveryRepository;
  private readonly netRepo: LocalNetRepository;
  private readonly historyRepo: HistoryRepository;
  private context: common.Context | undefined = undefined;
  private startTime: number = 0;
  private names: Map<string, string> = new Map<string, string>();

  constructor(discoveryRepo: DiscoveryRepository = new DiscoveryRepository(),
    netRepo: LocalNetRepository = new LocalNetRepository(),
    historyRepo: HistoryRepository = new HistoryRepository()) {
    this.discoveryRepo = discoveryRepo;
    this.netRepo = netRepo;
    this.historyRepo = historyRepo;
  }

  setContext(context: common.Context): void {
    this.context = context;
  }

  async loadDefaultCidr(): Promise<void> {
    if (this.cidr.length > 0) {
      return;
    }
    try {
      const defaultCidr: string = await this.netRepo.defaultCidr();
      if (this.cidr.length > 0 || this.isRunning) { return; }
      this.cidr = defaultCidr;
      if (this.cidr.length === 0) {
        this.error = '未找到可扫描的 IPv4 网段';
      }
    } catch (err) {
      this.error = '读取默认网络失败';
    }
  }

  setCidr(value: string): void {
    this.cidr = value;
  }

  hostCount(): number {
    return this.netRepo.hostCount(this.cidr.trim());
  }

  hostnameFor(ip: string): string {
    const name: string | undefined = this.names.get(ip);
    return name === undefined ? '' : name;
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      return;
    }
    const cidr: string = this.cidr.trim();
    const total: number = this.netRepo.hostCount(cidr);
    if (total <= 0) {
      this.error = '网段格式无效，示例：192.168.1.0/24';
      return;
    }

    this.error = '';
    this.cancelled = false;
    this.failed = false;
    this.isRunning = true;
    this.done = 0;
    this.total = total;
    this.elapsedMs = 0;
    this.onlineHosts = [];
    this.offlineCount = 0;
    this.mdnsCount = 0;
    this.names = new Map<string, string>();
    this.startTime = Date.now();

    const context: common.Context | undefined = this.context;
    if (context !== undefined) {
      this.discoveryRepo.startMdns(context);
    }

    let succeeded: boolean = false;
    try {
      const results: HostResult[] = await this.discoveryRepo.sweep(cidr,
        this.discoveryRepo.sweepPorts(), SWEEP_CONCURRENCY, SWEEP_TIMEOUT_MS,
        (done: number, totalHosts: number) => {
          this.done = done;
          this.total = totalHosts;
          this.elapsedMs = Date.now() - this.startTime;
        });
      succeeded = true;
      if (context !== undefined) {
        this.names = this.discoveryRepo.stopMdns();
      }
      this.mdnsCount = this.names.size;
      const online: HostResult[] = results.filter((host: HostResult) => host.online);
      this.onlineHosts = online;
      this.offlineCount = results.length - online.length;
      this.total = results.length;
      if (!this.cancelled) {
        this.done = this.total;
        this.elapsedMs = Date.now() - this.startTime;
      }
      const status: ScanStatus = this.cancelled ? ScanStatus.CANCELLED : ScanStatus.DONE;
      const summary: string = JSON.stringify({
        online: online.length,
        total: results.length,
        mdns: this.names.size
      });
      this.historyRepo.addScanRecord({
        id: 0,
        ts: Date.now(),
        kind: ScanKind.LAN_DISCOVERY,
        target: cidr,
        status: status,
        summary: summary
      }).catch((err: Error) => {
        hilog.error(0x0000, 'NetTools', 'discovery history write failed: %{public}s',
          err.message);
      });
      this.historyRepo.upsertHosts(online, this.names).catch((err: Error) => {
        hilog.error(0x0000, 'NetTools', 'host archive upsert failed: %{public}s',
          err.message);
      });
    } catch (err) {
      this.failed = !this.cancelled;
      if (context !== undefined) {
        this.discoveryRepo.stopMdns();
      }
      if (!this.cancelled) { this.error = '扫描失败，请稍后重试'; }
    }
    this.isRunning = false;
    if (!succeeded) {
      this.mdnsCount = 0;
    }
  }

  stop(): void {
    this.cancelled = true;
    this.discoveryRepo.cancel();
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
    return '在线 ' + this.onlineHosts.length + ' 台 · 未响应 ' +
      this.offlineCount + ' 台 · mDNS 名称 ' + this.mdnsCount + ' 个';
  }
}
