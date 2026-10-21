/**
 * Persistence domain types: scan records, discovered hosts, kinds/statuses
 * and export formats. Pure data only.
 */
export enum ScanKind {
  PING = 'ping',
  PORT_SCAN = 'portscan',
  LAN_DISCOVERY = 'landiscovery'
}

export enum ScanStatus {
  DONE = 'done',
  CANCELLED = 'cancelled',
  ERROR = 'error'
}

export interface ScanRecord {
  id: number;
  ts: number;
  kind: ScanKind;
  target: string;
  status: ScanStatus;
  summary: string; // JSON, shape depends on kind
}

export interface DiscoveredHost {
  ip: string;
  firstSeen: number;
  lastSeen: number;
  hostname: string;
  openPorts: number[];
}

export enum ExportFormat {
  CSV = 'csv',
  JSON = 'json'
}
