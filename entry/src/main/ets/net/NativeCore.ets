import native from 'libnettools.so';
import { IfaceInfo, ProbeResult } from '../model/NetworkInfo';
import { HostResult, ListeningPort, PortResult } from '../model/ScanInfo';

/**
 * Data source: the C++ native core (libnettools.so). Only this module may
 * import the .so; everything above goes through repositories.
 */

/** TCP probe: non-blocking connect raced against a timeout. */
export function probeTcp(host: string, port: number, timeoutMs: number): ProbeResult {
  return native.probeTcp(host, port, timeoutMs);
}

/** Batch TCP scan with native thread-pool concurrency. onProgress is called
 *  from the JS thread (ThreadSafeFunction), throttled by the core. */
export function scanPorts(host: string, ports: number[], concurrency: number,
  timeoutMs: number, onProgress: (done: number, total: number) => void): Promise<PortResult[]> {
  return native.scanPorts(host, ports, concurrency, timeoutMs, onProgress);
}

/** Cancel the in-flight batch scan; already-probed results are still returned. */
export function cancelScan(): void {
  native.cancelScan();
}

/** IPv4 CIDR sweep: probes each host's port list, stops per host on first hit. */
export function sweepCidr(cidr: string, ports: number[], concurrency: number,
  timeoutMs: number, onProgress: (done: number, total: number) => void): Promise<HostResult[]> {
  return native.sweepCidr(cidr, ports, concurrency, timeoutMs, onProgress);
}

/**
 * Listening TCP sockets of this device, parsed from /proc/net/tcp[6].
 * Returns null when the sandbox denies access to /proc.
 */
export function readListeningPorts(): ListeningPort[] | null {
  return native.listListeningPorts();
}

/** Parse "80,443,1000-2000" into a sorted, de-duplicated port list. */
export function parsePortExpr(expr: string): number[] {
  return native.parsePortExpr(expr);
}

/** All interfaces and addresses visible via getifaddrs. */
export function readInterfaces(): IfaceInfo[] {
  try {
    return native.listInterfaces();
  } catch (err) {
    return [];
  }
}

export function coreVersion(): string {
  return native.version();
}
