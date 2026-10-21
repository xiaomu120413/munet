import { HostResult, ListeningPort, PortResult } from '../model/ScanInfo';
import {
  cancelScan,
  parsePortExpr,
  readInterfaces,
  readListeningPorts,
  scanPorts,
  sweepCidr
} from '../net/NativeCore';
import { COMMON_PORTS, SWEEP_PORTS, WEB_PORTS } from '../net/PortPresets';
import { serviceName as lookupServiceName } from '../net/ServiceNames';

/**
 * Use-case level aggregation for ping and port scanning: presets, expression
 * parsing, service names and the native batch scanner.
 */
export class ScanRepository {
  commonPorts(): number[] {
    return COMMON_PORTS;
  }

  webPorts(): number[] {
    return WEB_PORTS;
  }

  sweepPorts(): number[] {
    return SWEEP_PORTS;
  }

  parsePorts(expr: string): number[] {
    return parsePortExpr(expr);
  }

  serviceName(port: number): string {
    return lookupServiceName(port);
  }

  /** Listening sockets of this device; null when /proc is not readable. */
  readLocalListeningPorts(): ListeningPort[] | null {
    return readListeningPorts();
  }

  /**
   * Local addresses to probe for occupied ports. /proc/net/tcp is blocked in
   * the app sandbox, so local mode connects to loopback plus every local IPv4
   * address (covers wildcard and per-interface binds).
   */
  localScanTargets(): string[] {
    const targets: string[] = ['127.0.0.1', '::1'];
    const interfaces = readInterfaces();
    for (const iface of interfaces) {
      if (iface.family !== 'v4') {
        continue;
      }
      if (!targets.includes(iface.address)) {
        targets.push(iface.address);
      }
    }
    return targets;
  }

  async scan(host: string, ports: number[], concurrency: number, timeoutMs: number,
    onProgress: (done: number, total: number) => void): Promise<PortResult[]> {
    return scanPorts(host, ports, concurrency, timeoutMs, onProgress);
  }

  async sweep(cidr: string, ports: number[], concurrency: number, timeoutMs: number,
    onProgress: (done: number, total: number) => void): Promise<HostResult[]> {
    return sweepCidr(cidr, ports, concurrency, timeoutMs, onProgress);
  }

  cancel(): void {
    cancelScan();
  }
}
