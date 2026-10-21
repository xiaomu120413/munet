import { statistics } from '@kit.NetworkKit';
import { IfaceTraffic } from '../model/NetworkInfo';
import { coreVersion, probeTcp } from '../net/NativeCore';

/**
 * Native-core and system diagnostics. Debug-only for now; the About view will
 * take over version reporting when it lands.
 */
export class SystemRepository {
  coreVersion(): string {
    return coreVersion();
  }

  probeSelfTest(): string {
    return JSON.stringify(probeTcp('127.0.0.1', 1, 500));
  }

  /**
   * Cumulative per-interface traffic since boot. Returns null when the
   * platform rejects the call (GET_NETWORK_STATS is system_basic).
   */
  async ifaceTraffic(nic: string): Promise<IfaceTraffic | null> {
    try {
      const rxBytes: number = await statistics.getIfaceRxBytes(nic);
      const txBytes: number = await statistics.getIfaceTxBytes(nic);
      return { rxBytes: rxBytes, txBytes: txBytes };
    } catch (err) {
      return null;
    }
  }
}
