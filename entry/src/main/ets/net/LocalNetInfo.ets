import { connection } from '@kit.NetworkKit';
import { wifiManager } from '@kit.ConnectivityKit';
import { LinkAddr, NicInfo, WifiInfo } from '../model/NetworkInfo';

const BEARER_LABELS: string[] = ['蜂窝', 'Wi-Fi', '蓝牙', '以太网', 'VPN'];

function bearerLabel(type: number): string {
  if (type >= 0 && type < BEARER_LABELS.length) {
    return BEARER_LABELS[type];
  }
  return '其他';
}

function familyOf(address: string): string {
  return address.includes(':') ? 'v6' : 'v4';
}

/**
 * Data source: NetManager. Reads every network, default network first.
 * Nets whose properties cannot be read are skipped (they may disappear
 * mid-enumeration).
 */
export async function fetchNics(): Promise<NicInfo[]> {
  const nets: connection.NetHandle[] = await connection.getAllNets();

  let defaultNetId: number = -1;
  try {
    const defaultNet: connection.NetHandle = await connection.getDefaultNet();
    defaultNetId = defaultNet.netId;
  } catch (err) {
    defaultNetId = -1;
  }

  const result: NicInfo[] = [];
  for (const net of nets) {
    try {
      const props: connection.ConnectionProperties = await connection.getConnectionProperties(net);

      let bearer: string[] = [];
      try {
        const caps: connection.NetCapabilities = await connection.getNetCapabilities(net);
        bearer = caps.bearerTypes.map((type: number): string => bearerLabel(type));
      } catch (err) {
        bearer = [];
      }

      const linkAddresses: LinkAddr[] = props.linkAddresses.map(
        (link: connection.LinkAddress): LinkAddr => {
          const address: string = link.address.address;
          return {
            address: address,
            prefixLength: link.prefixLength,
            family: familyOf(address)
          };
        }
      );

      let gateway: string = '';
      let fallbackGateway: string = '';
      for (const route of props.routes) {
        const gw: string = route.gateway.address;
        if (gw.length === 0) {
          continue;
        }
        if (route.isDefaultRoute) {
          gateway = gw;
          break;
        }
        if (route.destination.prefixLength === 0) {
          fallbackGateway = gw;
        }
      }
      if (gateway.length === 0) {
        gateway = fallbackGateway;
      }

      const dns: string[] = props.dnses.map((item: connection.NetAddress): string => item.address);

      result.push({
        netId: net.netId,
        interfaceName: props.interfaceName,
        bearerTypes: bearer,
        isDefault: net.netId === defaultNetId,
        linkAddresses: linkAddresses,
        gateway: gateway,
        dns: dns,
        domains: props.domains,
        mtu: props.mtu,
        ipv4Valid: props.isIPv4LinkValid,
        ipv6Valid: props.isIPv6LinkValid
      });
    } catch (err) {
      // Net vanished during enumeration; skip it.
    }
  }

  result.sort((a: NicInfo, b: NicInfo): number => {
    if (a.isDefault !== b.isDefault) {
      return a.isDefault ? -1 : 1;
    }
    return a.netId - b.netId;
  });
  return result;
}

/**
 * Data source: Wi-Fi details of the current connection. Returns null when
 * Wi-Fi is not the transport or the info is unavailable.
 */
export async function fetchWifiInfo(): Promise<WifiInfo | null> {
  try {
    const linked: wifiManager.WifiLinkedInfo = await wifiManager.getLinkedInfo();
    return {
      ssid: linked.ssid,
      rssi: linked.rssi,
      band: linked.band,
      frequency: linked.frequency,
      linkSpeed: linked.linkSpeed
    };
  } catch (err) {
    return null;
  }
}

/** Resolve a host name to a single address (throws on failure). */
export async function fetchAddress(host: string): Promise<string> {
  const net: connection.NetHandle = await connection.getDefaultNet();
  const address: connection.NetAddress = await net.getAddressByName(host);
  return address.address;
}
