/**
 * Scanning domain types: port/host probe results, ping records and scan modes.
 * Pure data only; no imports outside this layer.
 */
export interface PortResult {
  port: number;
  open: boolean;
  rttMs: number;
  error: string; // '' | 'timeout' | 'refused' | 'dns' | 'other'
}

export interface HostResult {
  ip: string;
  online: boolean;
  openPorts: number[];
}

export interface ListeningPort {
  port: number;
  address: string;
  family: string; // 'v4' | 'v6'
  uid: number;
}

export interface PingRecord {
  seq: number;
  ok: boolean;
  rttMs: number;
  error: string;
  port: number;
  timestamp: number;
}

export interface PingStats {
  sent: number;
  received: number;
  lossPercent: number;
  avgMs: number;
  minMs: number;
  maxMs: number;
}

export enum PortScanMode {
  COMMON = 'common',
  WEB = 'web',
  TOP1024 = 'top1024',
  CUSTOM = 'custom'
}
