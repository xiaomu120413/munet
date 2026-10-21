export interface ProbeResult {
  ok: boolean;
  rttMs: number;
  error: string;
}

export interface IfaceInfo {
  name: string;
  address: string;
  family: string; // 'v4' | 'v6'
  prefixLength: number;
  loopback: boolean;
  up: boolean;
}

export interface PortResult {
  port: number;
  open: boolean;
  rttMs: number;
  error: string;
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

export const version: () => string;

export const probeTcp: (host: string, port: number, timeoutMs: number) => ProbeResult;

export const listInterfaces: () => IfaceInfo[];

export const parsePortExpr: (expr: string) => number[];

export const scanPorts: (
  host: string,
  ports: number[],
  concurrency: number,
  timeoutMs: number,
  onProgress: (done: number, total: number) => void
) => Promise<PortResult[]>;

export const sweepCidr: (
  cidr: string,
  ports: number[],
  concurrency: number,
  timeoutMs: number,
  onProgress: (done: number, total: number) => void
) => Promise<HostResult[]>;

export const listListeningPorts: () => ListeningPort[] | null;

export const cancelScan: () => void;
