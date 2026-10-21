import { IfaceInfo, NicInfo, WifiInfo } from '../model/NetworkInfo';
import {
  fetchAddress,
  fetchNics as fetchNicsFromSource,
  fetchWifiInfo as fetchWifiInfoFromSource
} from '../net/LocalNetInfo';
import { readInterfaces as readInterfacesFromCore } from '../net/NativeCore';
import { deriveCidr, hostCountForCidr } from '../net/Subnet';

/**
 * Use-case level aggregation for the local-network view.
 *
 * ViewModels depend on repositories instead of data sources, which keeps
 * system APIs out of presentation code and lets ohosTest inject fakes.
 */
export class LocalNetRepository {
  async fetchNics(): Promise<NicInfo[]> {
    return fetchNicsFromSource();
  }

  async fetchWifiInfo(): Promise<WifiInfo | null> {
    return fetchWifiInfoFromSource();
  }

  readInterfaces(): IfaceInfo[] {
    return readInterfacesFromCore();
  }

  async resolveAddress(host: string): Promise<string> {
    return fetchAddress(host);
  }

  /** CIDR of the default network's first IPv4 link address, or ''. */
  async defaultCidr(): Promise<string> {
    const nics: NicInfo[] = await fetchNicsFromSource();
    for (const nic of nics) {
      if (!nic.isDefault) {
        continue;
      }
      for (const addr of nic.linkAddresses) {
        if (addr.family === 'v4') {
          return deriveCidr(addr.address, addr.prefixLength);
        }
      }
    }
    return '';
  }

  hostCount(cidr: string): number {
    return hostCountForCidr(cidr);
  }
}
