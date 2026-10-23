import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { ScanRepository } from '../../../main/ets/repository/ScanRepository';
import { DiscoveryRepository } from '../../../main/ets/repository/DiscoveryRepository';
import { LocalNetRepository } from '../../../main/ets/repository/LocalNetRepository';
import { HistoryRepository } from '../../../main/ets/repository/HistoryRepository';
import { PortScanViewModel } from '../../../main/ets/viewmodel/PortScanViewModel';
import { LanDiscoveryViewModel } from '../../../main/ets/viewmodel/LanDiscoveryViewModel';
import { HistoryViewModel } from '../../../main/ets/viewmodel/HistoryViewModel';
import { PingViewModel } from '../../../main/ets/viewmodel/PingViewModel';
import { HostResult, PortResult, PortScanMode } from '../../../main/ets/model/ScanInfo';
import { DiscoveredHost, ExportFormat, ScanKind, ScanRecord, ScanStatus } from '../../../main/ets/model/HistoryInfo';

class MemoryHistory extends HistoryRepository {
  exported: number = 0;
  cleared: boolean = false;
  isReady(): boolean { return true; }
  async addScanRecord(record: ScanRecord): Promise<void> {}
  async upsertHosts(hosts: HostResult[], names: Map<string, string>): Promise<void> {}
  async queryScanRecords(): Promise<ScanRecord[]> {
    return [{ id: 1, ts: 1, kind: ScanKind.PING, target: '127.0.0.1', status: ScanStatus.DONE, summary: '{}' },
      { id: 2, ts: 2, kind: ScanKind.PORT_SCAN, target: '本机', status: ScanStatus.CANCELLED, summary: '{"open":2}' }];
  }
  async queryHosts(): Promise<DiscoveredHost[]> {
    return [{ ip: '127.0.0.1', firstSeen: 1, lastSeen: 2, hostname: '', openPorts: [80] }];
  }
  async exportHistory(context: common.Context, format: ExportFormat): Promise<boolean> {
    this.exported = (await this.queryScanRecords()).length;
    return false;
  }
  async clearAll(): Promise<void> { this.cleared = true; }
}
class RefreshHistory extends MemoryHistory {
  defer: boolean = false;
  finish: (records: ScanRecord[]) => void = () => {};
  async queryScanRecords(): Promise<ScanRecord[]> {
    if (!this.defer) { return super.queryScanRecords(); }
    return new Promise<ScanRecord[]>((resolve: (records: ScanRecord[]) => void) => { this.finish = resolve; });
  }
}
class DeferredScan extends ScanRepository {
  calls: number = 0;
  finish: (results: PortResult[]) => void = () => {};
  commonPorts(): number[] { return [80]; }
  cancel(): void {}
  async scan(host: string, ports: number[], concurrency: number, timeout: number,
    progress: (done: number, total: number) => void): Promise<PortResult[]> {
    this.calls++;
    return new Promise<PortResult[]>((resolve: (results: PortResult[]) => void) => { this.finish = resolve; });
  }
}
class DeferredDiscovery extends DiscoveryRepository {
  calls: number = 0;
  finish: (results: HostResult[]) => void = () => {};
  cancel(): void {}
  async sweep(cidr: string, ports: number[], concurrency: number, timeout: number,
    progress: (done: number, total: number) => void): Promise<HostResult[]> {
    this.calls++;
    return new Promise<HostResult[]>((resolve: (results: HostResult[]) => void) => { this.finish = resolve; });
  }
}
class LoopbackNet extends LocalNetRepository {
  hostCount(cidr: string): number { return 1; }
}
export default function uiMigrationTest() {
  describe('UiMigration', () => {
    it('historyRefreshKeepsLoadedRowsAndFilterUntilReplacementArrives', 0, async () => {
      const repo: RefreshHistory = new RefreshHistory();
      const vm: HistoryViewModel = new HistoryViewModel(repo);
      expect(vm.hasLoaded).assertFalse();
      await vm.load();
      vm.selectFilter(ScanKind.PING);
      vm.recordOffset = 120;
      expect(vm.hasLoaded).assertTrue();
      repo.defer = true;
      const refresh: Promise<void> = vm.load();
      expect(vm.isLoading).assertTrue();
      expect(vm.hasLoaded).assertTrue();
      expect(vm.records.length).assertEqual(1);
      expect(vm.records[0].id).assertEqual(1);
      expect(vm.recordOffset).assertEqual(120);
      repo.finish([{ id: 3, ts: 3, kind: ScanKind.PING, target: 'localhost',
        status: ScanStatus.DONE, summary: '{}' }]);
      await refresh;
      expect(vm.isLoading).assertFalse();
      expect(vm.filterKind).assertEqual(ScanKind.PING);
      expect(vm.records[0].id).assertEqual(3);
    });
    it('portCorrectionClearsStaleValidationAndRevalidatesOnStart', 0, async () => {
      const repo: DeferredScan = new DeferredScan();
      const vm: PortScanViewModel = new PortScanViewModel(repo, new MemoryHistory());
      vm.selectMode(PortScanMode.CUSTOM);
      vm.setTarget('127.0.0.1');
      vm.setCustomExpr('70000');
      await vm.start();
      expect(vm.error.length > 0).assertTrue();
      expect(repo.calls).assertEqual(0);
      vm.setCustomExpr('8080');
      expect(vm.error).assertEqual('');
      expect(vm.portCount()).assertEqual(1);
      vm.setTarget('');
      await vm.start();
      expect(vm.error).assertEqual('请输入目标地址');
      vm.setTarget('127.0.0.1');
      expect(vm.error).assertEqual('');
      const scan: Promise<void> = vm.start();
      expect(repo.calls).assertEqual(1);
      repo.finish([]);
      await scan;
    });
    it('pingStopWaitsForNativeCompletionBeforeRestart', 0, async () => {
      const repo: DeferredScan = new DeferredScan();
      const vm: PingViewModel = new PingViewModel(repo, new LoopbackNet(), new MemoryHistory());
      vm.setTarget('127.0.0.1');
      const first: Promise<void> = vm.start();
      vm.stop();
      expect(vm.isRunning).assertTrue();
      await vm.start();
      expect(repo.calls).assertEqual(1);
      repo.finish([]);
      await first;
      expect(vm.isRunning).assertFalse();
      expect(vm.records.length).assertEqual(0);
    });
    it('portStopWaitsForNativeCompletionBeforeRestart', 0, async () => {
      const repo: DeferredScan = new DeferredScan();
      const vm: PortScanViewModel = new PortScanViewModel(repo, new MemoryHistory());
      vm.setTarget('127.0.0.1');
      const first: Promise<void> = vm.start();
      vm.stop();
      expect(vm.isRunning).assertTrue();
      await vm.start();
      expect(repo.calls).assertEqual(1);
      repo.finish([]);
      await first;
      expect(vm.isRunning).assertFalse();
      expect(vm.cancelled).assertTrue();
      const second: Promise<void> = vm.start();
      expect(repo.calls).assertEqual(2);
      repo.finish([]);
      await second;
      expect(vm.cancelled).assertFalse();
    });
    it('lanStopWaitsForNativeCompletionBeforeRestart', 0, async () => {
      const repo: DeferredDiscovery = new DeferredDiscovery();
      const vm: LanDiscoveryViewModel = new LanDiscoveryViewModel(repo, new LoopbackNet(), new MemoryHistory());
      vm.setCidr('127.0.0.1/32');
      const first: Promise<void> = vm.start();
      vm.stop();
      expect(vm.isRunning).assertTrue();
      await vm.start();
      expect(repo.calls).assertEqual(1);
      repo.finish([]);
      await first;
      expect(vm.isRunning).assertFalse();
      expect(vm.cancelled).assertTrue();
    });
    it('filterDoesNotLimitExportAndCancellationIsSilent', 0, async () => {
      const repo: MemoryHistory = new MemoryHistory();
      const vm: HistoryViewModel = new HistoryViewModel(repo);
      await vm.load();
      vm.selectFilter(ScanKind.PING);
      expect(vm.records.length).assertEqual(1);
      expect(await vm.export({} as common.Context, ExportFormat.CSV)).assertFalse();
      expect(repo.exported).assertEqual(2);
      expect(vm.error).assertEqual('');
      expect(vm.isExporting).assertFalse();
      vm.showView(true);
      expect(vm.filterKind).assertEqual(ScanKind.PING);
      await vm.clear();
      expect(repo.cleared).assertTrue();
      expect(vm.records.length).assertEqual(0);
      expect(vm.hosts.length).assertEqual(0);
      expect(vm.hasRecords()).assertFalse();
    });
  });
}
