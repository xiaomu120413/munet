import { common } from '@kit.AbilityKit';
import { HostResult } from '../model/ScanInfo';
import { MdnsSession } from '../net/MdnsDiscovery';
import { cancelScan, sweepCidr } from '../net/NativeCore';
import { SWEEP_PORTS } from '../net/PortPresets';

/**
 * Use-case level aggregation for LAN discovery: CIDR sweep plus best-effort
 * mDNS hostname collection.
 */
export class DiscoveryRepository {
  private session: MdnsSession | undefined = undefined;

  sweepPorts(): number[] {
    return SWEEP_PORTS;
  }

  startMdns(context: common.Context): void {
    const session: MdnsSession = new MdnsSession();
    session.start(context);
    this.session = session;
  }

  stopMdns(): Map<string, string> {
    const session: MdnsSession | undefined = this.session;
    this.session = undefined;
    if (session === undefined) {
      return new Map<string, string>();
    }
    session.stop();
    return session.hostnames();
  }

  async sweep(cidr: string, ports: number[], concurrency: number, timeoutMs: number,
    onProgress: (done: number, total: number) => void): Promise<HostResult[]> {
    return sweepCidr(cidr, ports, concurrency, timeoutMs, onProgress);
  }

  cancel(): void {
    cancelScan();
  }
}
