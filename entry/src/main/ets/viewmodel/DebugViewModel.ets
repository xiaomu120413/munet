import BuildProfile from 'BuildProfile';
import { IfaceTraffic } from '../model/NetworkInfo';
import { HostResult, ListeningPort, PortResult } from '../model/ScanInfo';
import { ScanRepository } from '../repository/ScanRepository';
import { SystemRepository } from '../repository/SystemRepository';

/**
 * Debug-only ViewModel for scaffold self-tests. Keeps native calls out of the
 * view layer; remove once the About view owns version reporting.
 */
export class DebugViewModel {
  private readonly systemRepo: SystemRepository;
  private readonly scanRepo: ScanRepository;

  constructor(systemRepo: SystemRepository = new SystemRepository(),
    scanRepo: ScanRepository = new ScanRepository()) {
    this.systemRepo = systemRepo;
    this.scanRepo = scanRepo;
  }

  /** False in release builds; gates debug-only UI (footer self-test etc.). */
  isDebug(): boolean {
    return BuildProfile.DEBUG;
  }

  coreVersion(): string {
    return this.systemRepo.coreVersion();
  }

  probeSelfTest(): string {
    return this.systemRepo.probeSelfTest();
  }

  /**
   * Headless smoke test for remote/CI verification (debug builds only).
   * Probes a port expression and returns a one-line summary.
   */
  async runHeadlessProbe(host: string, portExpr: string): Promise<string> {
    const ports: number[] = this.scanRepo.parsePorts(portExpr);
    if (ports.length === 0) {
      return 'invalid port expression: ' + portExpr;
    }
    const started: number = Date.now();
    const results: PortResult[] = await this.scanRepo.scan(host, ports,
      Math.min(64, ports.length), 1500, () => {
      });
    const open: string[] = [];
    for (const result of results) {
      if (!result.open) {
        continue;
      }
      const service: string = this.scanRepo.serviceName(result.port);
      open.push(String(result.port) + (service.length > 0 ? '/' + service : '') +
        ':' + result.rttMs + 'ms');
    }
    return 'host=' + host + ' total=' + ports.length + ' open=[' + open.join(', ') +
      '] elapsed=' + (Date.now() - started) + 'ms';
  }

  /**
   * Headless smoke test for the CIDR sweep (debug builds only).
   */
  async runHeadlessSweep(cidr: string, portExpr: string): Promise<string> {
    const ports: number[] = this.scanRepo.parsePorts(portExpr);
    const started: number = Date.now();
    const results: HostResult[] = await this.scanRepo.sweep(cidr, ports, 128, 1000, () => {
    });
    const online: string[] = [];
    for (const host of results) {
      if (!host.online) {
        continue;
      }
      online.push(host.ip + '[' + host.openPorts.join(',') + ']');
    }
    return 'cidr=' + cidr + ' hosts=' + results.length + ' online=' + online.length +
      ' [' + online.join(' ') + '] elapsed=' + (Date.now() - started) + 'ms';
  }

  /** Headless probe of per-interface traffic (permission spike). */
  async runHeadlessTraffic(nic: string): Promise<string> {
    const traffic: IfaceTraffic | null = await this.systemRepo.ifaceTraffic(nic);
    if (traffic === null) {
      return 'nic=' + nic + ' traffic=denied';
    }
    return 'nic=' + nic + ' rx=' + traffic.rxBytes + ' tx=' + traffic.txBytes;
  }

  /** Headless probe of /proc/net/tcp readability (sandbox spike). */
  runHeadlessListeners(): string {
    const ports: ListeningPort[] | null = this.scanRepo.readLocalListeningPorts();
    if (ports === null) {
      return 'listeners=denied';
    }
    const sample: string[] = [];
    const limit: number = Math.min(ports.length, 8);
    for (let i = 0; i < limit; i++) {
      sample.push(ports[i].port + '/' + ports[i].family + '@' + ports[i].address);
    }
    return 'listeners=' + ports.length + ' sample=[' + sample.join(', ') + ']';
  }
}
