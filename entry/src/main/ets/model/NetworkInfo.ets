/**
 * Network domain types: interfaces, Wi-Fi, probe outcomes and traffic.
 * Pure data only; no imports outside this layer.
 */
export interface LinkAddr {
  address: string;
  prefixLength: number;
  family: string; // 'v4' | 'v6'
}

export interface NicInfo {
  netId: number;
  interfaceName: string;
  bearerTypes: string[];
  isDefault: boolean;
  linkAddresses: LinkAddr[];
  gateway: string;
  dns: string[];
  domains: string;
  mtu: number;
  ipv4Valid: boolean | undefined;
  ipv6Valid: boolean | undefined;
}

export interface WifiInfo {
  ssid: string;
  rssi: number;
  band: number;
  frequency: number;
  linkSpeed: number;
}

export interface IfaceInfo {
  name: string;
  address: string;
  family: string; // 'v4' | 'v6'
  prefixLength: number;
  loopback: boolean;
  up: boolean;
}

export interface ProbeResult {
  ok: boolean;
  rttMs: number;
  error: string; // '' | 'timeout' | 'refused' | 'dns' | 'other'
}

export interface IfaceTraffic {
  rxBytes: number;
  txBytes: number;
}
