import { common } from '@kit.AbilityKit';
import {
  DiscoveredHost,
  ExportFormat,
  ScanKind,
  ScanRecord,
  ScanStatus
} from '../model/HistoryInfo';
import { HistoryRepository } from '../repository/HistoryRepository';

/**
 * ViewModel for the history view: persisted scan records and discovered-host
 * archive, with filtering, export and clear actions.
 */
@Observed
export class HistoryViewModel {
  records: ScanRecord[] = [];
  hosts: DiscoveredHost[] = [];
  isLoading: boolean = true;
  hasLoaded: boolean = false;
  error: string = '';
  filterKind: ScanKind | undefined = undefined;
  showHosts: boolean = false;
  isExporting: boolean = false;
  isClearing: boolean = false;
  recordOffset: number = 0;
  hostOffset: number = 0;

  private allRecords: ScanRecord[] = [];
  private readonly repo: HistoryRepository;
  private loading: boolean = false;

  constructor(repo: HistoryRepository = new HistoryRepository()) {
    this.repo = repo;
  }

  async load(): Promise<void> {
    if (this.isClearing || this.loading) { return; }
    this.loading = true;
    this.isLoading = true;
    this.error = '';
    try {
      const records: ScanRecord[] = await this.repo.queryScanRecords();
      const hosts: DiscoveredHost[] = await this.repo.queryHosts();
      this.allRecords = records;
      this.hosts = hosts;
      this.applyFilter();
      this.hasLoaded = true;
      if (!this.repo.isReady()) {
        this.error = '本地存储不可用，历史记录功能受限';
      }
    } catch (err) {
      this.error = '读取历史记录失败';
    }
    this.isLoading = false;
    this.loading = false;
  }

  selectFilter(kind: ScanKind | undefined): void {
    this.filterKind = kind;
    this.applyFilter();
  }

  showView(showHosts: boolean): void {
    this.showHosts = showHosts;
  }

  private applyFilter(): void {
    const kind: ScanKind | undefined = this.filterKind;
    if (kind === undefined) {
      this.records = this.allRecords;
      return;
    }
    this.records = this.allRecords.filter((record: ScanRecord) => record.kind === kind);
  }

  async clear(): Promise<void> {
    if (this.isClearing || this.isExporting || this.isLoading) { return; }
    this.isClearing = true;
    this.error = '';
    try {
      await this.repo.clearAll();
      this.allRecords = [];
      this.records = [];
      this.hosts = [];
      this.recordOffset = 0;
      this.hostOffset = 0;
    } catch (err) {
      this.error = '清空失败';
    }
    this.isClearing = false;
  }

  hasRecords(): boolean { return this.allRecords.length > 0; }

  /** Exports all records (not just the current filter) to a user-chosen file. */
  async export(context: common.Context, format: ExportFormat): Promise<boolean> {
    if (this.isExporting || this.isClearing || this.isLoading) { return false; }
    if (this.allRecords.length === 0) {
      this.error = '暂无记录可导出';
      return false;
    }
    this.error = '';
    this.isExporting = true;
    try {
      const saved: boolean = await this.repo.exportHistory(context, format);
      return saved;
    } catch (err) {
      this.error = '导出失败';
      return false;
    } finally {
      this.isExporting = false;
    }
  }

  dismissError(): void {
    this.error = '';
  }

  kindLabel(kind: ScanKind): string {
    if (kind === ScanKind.PING) {
      return 'Ping';
    }
    if (kind === ScanKind.PORT_SCAN) {
      return '端口扫描';
    }
    return '局域网';
  }

  summaryText(record: ScanRecord): string {
    let data: Record<string, Object> = {};
    try {
      data = JSON.parse(record.summary) as Record<string, Object>;
    } catch (err) {
      return record.summary;
    }
    if (record.kind === ScanKind.PING) {
      return '收 ' + this.numberField(data, 'recv') + '/' + this.numberField(data, 'sent') +
        ' · 丢包 ' + this.numberField(data, 'loss') + '%' +
        (this.numberField(data, 'recv') > 0 ? ' · 平均 ' + this.numberField(data, 'avg') + ' ms' : '') + this.statusSuffix(record);
    }
    if (record.kind === ScanKind.PORT_SCAN) {
      return (record.target === '本机' ? '占用 ' : '开放 ') + this.numberField(data, 'open') + ' 个 · ' +
        (this.numberField(data, 'elapsedMs') / 1000).toFixed(1) + ' s' + this.statusSuffix(record);
    }
    return '在线 ' + this.numberField(data, 'online') + ' 台 · 共 ' +
      this.numberField(data, 'total') + ' 台' + this.statusSuffix(record);
  }

  formatTime(ts: number): string {
    const date: Date = new Date(ts);
    return (date.getMonth() + 1) + '/' + date.getDate() + ' ' +
      this.pad(date.getHours()) + ':' + this.pad(date.getMinutes());
  }

  hostNameLabel(host: DiscoveredHost): string {
    return host.hostname.length > 0 ? host.hostname : '—';
  }

  hostPortsLabel(host: DiscoveredHost): string {
    return host.openPorts.length > 0 ? host.openPorts.join(', ') : '—';
  }

  private statusSuffix(record: ScanRecord): string {
    return record.status === ScanStatus.CANCELLED ? ' · 已停止' : (record.status === ScanStatus.ERROR ? ' · 失败' : '');
  }

  private numberField(data: Record<string, Object>, key: string): number {
    const value: Object | undefined = data[key];
    return typeof value === 'number' ? value as number : 0;
  }

  private pad(value: number): string {
    return value < 10 ? '0' + value : String(value);
  }
}
