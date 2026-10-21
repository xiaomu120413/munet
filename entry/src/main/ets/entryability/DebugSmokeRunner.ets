import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import BuildProfile from 'BuildProfile';
import { ScanRecord } from '../model/HistoryInfo';
import { HistoryRepository } from '../repository/HistoryRepository';
import { DebugViewModel } from '../viewmodel/DebugViewModel';
import { PingViewModel } from '../viewmodel/PingViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'NetTools';

/**
 * Debug-only headless smoke tests, triggered by Want parameters on start:
 *
 *   --ps netprobe.history 1                 dump persisted scan records
 *   --ps netprobe.stats <nic>               per-interface traffic (permission)
 *   --ps netprobe.listeners 1               /proc/net/tcp readability (sandbox)
 *   --ps netprobe.ping.host <ip> ...        Ping view model end-to-end
 *   --ps netprobe.sweep.cidr <cidr> ...     CIDR sweep
 *   --ps netprobe.host <ip> --ps netprobe.ports <expr>
 *
 * They exist because the shared device's foreground is often occupied by
 * other windows. Everything here is a no-op in release builds.
 */
export function runDebugSmoke(want: Want, context: common.Context): void {
  if (!BuildProfile.DEBUG) {
    return;
  }
  const params: Record<string, Object> | undefined = want.parameters;
  if (params === undefined) {
    return;
  }
  if (runHistory(params, context)) {
    return;
  }
  if (runTraffic(params)) {
    return;
  }
  if (runListeners(params)) {
    return;
  }
  if (runPing(params)) {
    return;
  }
  if (runSweep(params)) {
    return;
  }
  runProbe(params);
}

function stringParam(params: Record<string, Object>, key: string): string | undefined {
  const value: Object | undefined = params[key];
  if (typeof value !== 'string') {
    return undefined;
  }
  return value as string;
}

function runHistory(params: Record<string, Object>, context: common.Context): boolean {
  if (stringParam(params, 'netprobe.history') === undefined) {
    return false;
  }
  const repo: HistoryRepository = new HistoryRepository();
  repo.initialize(context).then(() => {
    return repo.queryScanRecords();
  }).then((records: ScanRecord[]) => {
    hilog.info(DOMAIN, TAG, 'headless history records=%{public}d', records.length);
    const limit: number = Math.min(records.length, 5);
    for (let i = 0; i < limit; i++) {
      const record: ScanRecord = records[i];
      hilog.info(DOMAIN, TAG,
        'headless history item: kind=%{public}s target=%{public}s status=%{public}s summary=%{public}s',
        record.kind, record.target, record.status, record.summary);
    }
  }).catch((err: Error) => {
    hilog.error(DOMAIN, TAG, 'headless history failed: %{public}s', err.message);
  });
  return true;
}

function runTraffic(params: Record<string, Object>): boolean {
  const nic: string | undefined = stringParam(params, 'netprobe.stats');
  if (nic === undefined) {
    return false;
  }
  const debugVm: DebugViewModel = new DebugViewModel();
  debugVm.runHeadlessTraffic(nic).then((summary: string) => {
    hilog.info(DOMAIN, TAG, 'headless stats result: %{public}s', summary);
  }).catch((err: Error) => {
    hilog.error(DOMAIN, TAG, 'headless stats failed: %{public}s', err.message);
  });
  return true;
}

function runListeners(params: Record<string, Object>): boolean {
  if (stringParam(params, 'netprobe.listeners') === undefined) {
    return false;
  }
  const debugVm: DebugViewModel = new DebugViewModel();
  hilog.info(DOMAIN, TAG, 'headless listeners result: %{public}s',
    debugVm.runHeadlessListeners());
  return true;
}

function runPing(params: Record<string, Object>): boolean {
  const host: string | undefined = stringParam(params, 'netprobe.ping.host');
  if (host === undefined) {
    return false;
  }
  const portText: string | undefined = stringParam(params, 'netprobe.ping.port');
  const countText: string | undefined = stringParam(params, 'netprobe.ping.count');
  let port: number = 80;
  if (portText !== undefined) {
    const parsedPort: number = Number(portText);
    if (!Number.isNaN(parsedPort)) {
      port = parsedPort;
    }
  }
  let count: number = 3;
  if (countText !== undefined) {
    const parsedCount: number = Number(countText);
    if (!Number.isNaN(parsedCount)) {
      count = parsedCount;
    }
  }

  const vm: PingViewModel = new PingViewModel();
  vm.setTarget(host);
  vm.setCount(count);
  vm.selectPort(port);
  hilog.info(DOMAIN, TAG, 'headless ping start host=%{public}s port=%{public}d count=%{public}d',
    host, port, count);
  vm.start().then(() => {
    const parts: string[] = [];
    for (const record of vm.records) {
      parts.push(record.ok ? record.rttMs + 'ms' : record.error);
    }
    hilog.info(DOMAIN, TAG,
      'headless ping result: sent=%{public}d recv=%{public}d loss=%{public}d%% seq=[%{public}s]',
      vm.stats.sent, vm.stats.received, vm.stats.lossPercent, parts.join(', '));
  }).catch((err: Error) => {
    hilog.error(DOMAIN, TAG, 'headless ping failed: %{public}s', err.message);
  });
  return true;
}

function runSweep(params: Record<string, Object>): boolean {
  const cidr: string | undefined = stringParam(params, 'netprobe.sweep.cidr');
  if (cidr === undefined) {
    return false;
  }
  const portsText: string | undefined = stringParam(params, 'netprobe.sweep.ports');
  const ports: string = portsText === undefined ? '80,443,22,445,3389,8080' : portsText;

  const debugVm: DebugViewModel = new DebugViewModel();
  hilog.info(DOMAIN, TAG, 'headless sweep start cidr=%{public}s ports=%{public}s', cidr, ports);
  debugVm.runHeadlessSweep(cidr, ports).then((summary: string) => {
    hilog.info(DOMAIN, TAG, 'headless sweep result: %{public}s', summary);
  }).catch((err: Error) => {
    hilog.error(DOMAIN, TAG, 'headless sweep failed: %{public}s', err.message);
  });
  return true;
}

function runProbe(params: Record<string, Object>): void {
  const host: string | undefined = stringParam(params, 'netprobe.host');
  const ports: string | undefined = stringParam(params, 'netprobe.ports');
  if (host === undefined || ports === undefined) {
    return;
  }
  hilog.info(DOMAIN, TAG, 'headless probe start host=%{public}s ports=%{public}s', host, ports);
  const debugVm: DebugViewModel = new DebugViewModel();
  debugVm.runHeadlessProbe(host, ports).then((summary: string) => {
    hilog.info(DOMAIN, TAG, 'headless probe result: %{public}s', summary);
  }).catch((err: Error) => {
    hilog.error(DOMAIN, TAG, 'headless probe failed: %{public}s', err.message);
  });
}
