/**
 * Persistence data source: opens nettools.db (relationalStore) and owns the
 * scan_record / discovered_host schema and CRUD. Initialization is idempotent.
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DiscoveredHost, ScanKind, ScanRecord, ScanStatus } from '../model/HistoryInfo';
import { HostResult } from '../model/ScanInfo';

const DB_NAME: string = 'nettools.db';
const MAX_RECORDS: number = 500;

let store: relationalStore.RdbStore | undefined = undefined;
let initPromise: Promise<void> | undefined = undefined;

function kindFrom(value: string): ScanKind {
  if (value === ScanKind.PORT_SCAN) {
    return ScanKind.PORT_SCAN;
  }
  if (value === ScanKind.LAN_DISCOVERY) {
    return ScanKind.LAN_DISCOVERY;
  }
  return ScanKind.PING;
}

function statusFrom(value: string): ScanStatus {
  if (value === ScanStatus.CANCELLED) {
    return ScanStatus.CANCELLED;
  }
  if (value === ScanStatus.ERROR) {
    return ScanStatus.ERROR;
  }
  return ScanStatus.DONE;
}

async function doInitialize(context: common.Context): Promise<void> {
  const config: relationalStore.StoreConfig = {
    name: DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  };
  const rdb: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
  await rdb.executeSql(`CREATE TABLE IF NOT EXISTS scan_record (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ts INTEGER NOT NULL,
      kind TEXT NOT NULL,
      target TEXT NOT NULL,
      status TEXT NOT NULL,
      summary TEXT NOT NULL
    )`);
  await rdb.executeSql('CREATE INDEX IF NOT EXISTS idx_scan_ts ON scan_record(ts DESC)');
  await rdb.executeSql('CREATE INDEX IF NOT EXISTS idx_scan_kind ON scan_record(kind, ts DESC)');
  await rdb.executeSql(`CREATE TABLE IF NOT EXISTS discovered_host (
      ip TEXT PRIMARY KEY,
      first_seen INTEGER NOT NULL,
      last_seen INTEGER NOT NULL,
      hostname TEXT,
      open_ports TEXT NOT NULL
    )`);
  store = rdb;
}

export async function initialize(context: common.Context): Promise<void> {
  if (initPromise !== undefined) {
    return initPromise;
  }
  initPromise = doInitialize(context);
  return initPromise;
}

export function isReady(): boolean {
  return store !== undefined;
}

export async function addScanRecord(record: ScanRecord): Promise<void> {
  const rdb: relationalStore.RdbStore | undefined = store;
  if (rdb === undefined) {
    throw new Error('history store not initialized');
  }
  const values: relationalStore.ValuesBucket = {
    ts: record.ts,
    kind: record.kind,
    target: record.target,
    status: record.status,
    summary: record.summary
  };
  await rdb.insert('scan_record', values);
  await rdb.executeSql(
    'DELETE FROM scan_record WHERE id NOT IN (SELECT id FROM scan_record ORDER BY ts DESC LIMIT ?)',
    [MAX_RECORDS]);
}

export async function queryScanRecords(): Promise<ScanRecord[]> {
  const rdb: relationalStore.RdbStore | undefined = store;
  if (rdb === undefined) {
    return [];
  }
  const resultSet: relationalStore.ResultSet = await rdb.querySql(
    'SELECT id, ts, kind, target, status, summary FROM scan_record ORDER BY ts DESC LIMIT ?',
    [MAX_RECORDS]);
  const records: ScanRecord[] = [];
  while (resultSet.goToNextRow()) {
    records.push({
      id: resultSet.getLong(resultSet.getColumnIndex('id')),
      ts: resultSet.getLong(resultSet.getColumnIndex('ts')),
      kind: kindFrom(resultSet.getString(resultSet.getColumnIndex('kind'))),
      target: resultSet.getString(resultSet.getColumnIndex('target')),
      status: statusFrom(resultSet.getString(resultSet.getColumnIndex('status'))),
      summary: resultSet.getString(resultSet.getColumnIndex('summary'))
    });
  }
  resultSet.close();
  return records;
}

/** Upserts online hosts discovered by a sweep, keeping first_seen stable. */
export async function upsertDiscoveredHosts(hosts: HostResult[],
  names: Map<string, string>): Promise<void> {
  const rdb: relationalStore.RdbStore | undefined = store;
  if (rdb === undefined) {
    throw new Error('history store not initialized');
  }
  const now: number = Date.now();
  for (const host of hosts) {
    if (!host.online) {
      continue;
    }
    const discoveredName: string | undefined = names.get(host.ip);
    const hostname: string = discoveredName === undefined ? '' : discoveredName;
    const openPorts: string = JSON.stringify(host.openPorts);

    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates('discovered_host');
    predicates.equalTo('ip', host.ip);
    const existing: relationalStore.ResultSet = await rdb.query(predicates, ['ip']);
    const found: boolean = existing.rowCount > 0;
    existing.close();

    if (found) {
      const values: relationalStore.ValuesBucket = {
        last_seen: now,
        hostname: hostname,
        open_ports: openPorts
      };
      const updatePredicates: relationalStore.RdbPredicates =
        new relationalStore.RdbPredicates('discovered_host');
      updatePredicates.equalTo('ip', host.ip);
      await rdb.update(values, updatePredicates);
    } else {
      const values: relationalStore.ValuesBucket = {
        ip: host.ip,
        first_seen: now,
        last_seen: now,
        hostname: hostname,
        open_ports: openPorts
      };
      await rdb.insert('discovered_host', values);
    }
  }
}

export async function queryDiscoveredHosts(): Promise<DiscoveredHost[]> {
  const rdb: relationalStore.RdbStore | undefined = store;
  if (rdb === undefined) {
    return [];
  }
  const resultSet: relationalStore.ResultSet = await rdb.querySql(
    'SELECT ip, first_seen, last_seen, hostname, open_ports FROM discovered_host ORDER BY last_seen DESC');
  const hosts: DiscoveredHost[] = [];
  while (resultSet.goToNextRow()) {
    const portsText: string = resultSet.getString(resultSet.getColumnIndex('open_ports'));
    const ports: number[] = [];
    try {
      const parsed: Object = JSON.parse(portsText);
      if (Array.isArray(parsed)) {
        for (const item of parsed as number[]) {
          ports.push(Number(item));
        }
      }
    } catch (err) {
    }
    hosts.push({
      ip: resultSet.getString(resultSet.getColumnIndex('ip')),
      firstSeen: resultSet.getLong(resultSet.getColumnIndex('first_seen')),
      lastSeen: resultSet.getLong(resultSet.getColumnIndex('last_seen')),
      hostname: resultSet.getString(resultSet.getColumnIndex('hostname')),
      openPorts: ports
    });
  }
  resultSet.close();
  return hosts;
}

export async function clearAll(): Promise<void> {
  const rdb: relationalStore.RdbStore | undefined = store;
  if (rdb === undefined) {
    throw new Error('history store not initialized');
  }
  await rdb.executeSql('DELETE FROM scan_record');
  await rdb.executeSql('DELETE FROM discovered_host');
}
